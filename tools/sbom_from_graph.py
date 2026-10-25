# Copyright (C) 2026 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Generate CycloneDX JSON from Bazel dependency and packaged-JAR facts.

Maven coordinates and hashes come from rules_jvm_external tags. The optional
shipped-labels manifest maps packaged paths to producing targets, after any
packaging exclusions. Compile-only dependencies can be included or omitted.
"""

import argparse
import hashlib
import json
import os
import re
import sys
import uuid
from datetime import datetime, timezone

GENERATOR_NAME = "bazlets-sbom-from-graph"
GENERATOR_VERSION = "0.1.0"

# Fixed namespace so the serialNumber is deterministic, not random.
_SERIAL_NS = uuid.UUID("6ba7b811-9dad-11d1-80b4-00c04fd430c8")

# "<name>-<version>.jar" where the version starts with a digit.
_NAME_VER = re.compile(r"^(.+?)-(\d[\w.\-]*)\.jar$")


def _maven_purl(group, artifact, version):
    return "pkg:maven/%s/%s@%s" % (group, artifact, version)


def _parse_coordinate(coord):
    # maven_coordinates is "group:artifact:version[:packaging[:classifier]]".
    parts = coord.split(":")
    if len(parts) < 3:
        raise ValueError("malformed maven coordinate: %r" % coord)
    group, artifact, version = parts[0], parts[1], parts[2]
    classifier = parts[4] if len(parts) >= 5 else None
    return group, artifact, version, classifier


def load_facts(path):
    """{coord: {"label", "sha256", "deps"}} from the aspect's facts JSON."""
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    nodes = {}
    for e in data:
        nodes[e["coord"]] = {
            "label": e.get("label"),
            "sha256": e.get("sha256") or None,
            "deps": e.get("deps", []),
        }
    return nodes


def _load_shipped_labels(path):
    """[(name, owner_label)] for every jar the plugin bundles."""
    rows = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line or "\t" not in line:
                continue
            name, owner = line.split("\t", 1)
            rows.append((name, owner))
    return rows


def _component(coord, sha256, namespace, shipped):
    group, artifact, version, classifier = _parse_coordinate(coord)
    purl = _maven_purl(group, artifact, version)
    comp = {
        "type": "library",
        "bom-ref": purl,
        "group": group,
        "name": artifact,
        "version": version,
        "purl": purl,
    }
    if sha256:
        # The SHA-256 of the jar consumed from the Maven repository.
        comp["hashes"] = [{"alg": "SHA-256", "content": sha256}]
    props = [{"name": "%s:sbom:origin" % namespace, "value": "third-party-maven"}]
    if shipped is not None:
        # CycloneDX scope: required == shipped, excluded == not distributed.
        comp["scope"] = "required" if shipped else "excluded"
        props.append({"name": "%s:sbom:inclusion" % namespace,
                      "value": "shipped" if shipped else "compile-only"})
    if classifier and classifier != "jar":
        props.append({"name": "%s:maven:classifier" % namespace,
                      "value": classifier})
    comp["properties"] = props
    return comp


def _nonmaven_component(name, owner, namespace):
    """A bundled jar with no Maven identity (first-party plugin code)."""
    comp = {
        "type": "library",
        "bom-ref": "packaged:%s" % name,
        "scope": "required",
        "properties": [
            {"name": "%s:sbom:origin" % namespace, "value": "first-party"},
            {"name": "%s:sbom:inclusion" % namespace, "value": "shipped"},
            {"name": "%s:sbom:ownerLabel" % namespace, "value": owner},
        ],
    }
    name = name.rsplit("/", 1)[-1]
    m = _NAME_VER.match(name)
    if m:
        comp["name"], comp["version"] = m.group(1), m.group(2)
    else:
        comp["name"] = name[:-4] if name.endswith(".jar") else name
    return comp


def _dependency_graph(nodes):
    purl_of = {c: _maven_purl(*_parse_coordinate(c)[:3]) for c in nodes}
    edges = []
    for coord in sorted(nodes, key=lambda c: purl_of[c]):
        depends_on = sorted(
            {purl_of[d] for d in nodes[coord]["deps"]
             if d in purl_of and purl_of[d] != purl_of[coord]})
        edges.append({"ref": purl_of[coord], "dependsOn": depends_on})
    return edges


def _timestamp(source_date_epoch):
    if source_date_epoch is None:
        source_date_epoch = os.environ.get("SOURCE_DATE_EPOCH")
    epoch = int(source_date_epoch) if source_date_epoch else 0
    return datetime.fromtimestamp(epoch, tz=timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ")


def build_sbom(nodes, target, product_group, product_name, product_version,
               source_date_epoch, namespace, shipped_labels=None,
               drop_compile_only=False):
    label_to_coord = {}
    for coord, node in nodes.items():
        if node.get("label"):
            label_to_coord[node["label"]] = coord

    shipped_owners = None
    if shipped_labels is not None:
        shipped_owners = set(owner for _, owner in shipped_labels)

    # In a plugin, the compile-only closure is the Gerrit-provided Plugin API,
    # already covered by gerrit.war's own SBOM. Drop it and report only what the
    # plugin itself bundles.
    graph_nodes = nodes
    if drop_compile_only and shipped_owners is not None:
        graph_nodes = {c: n for c, n in nodes.items()
                       if n.get("label") in shipped_owners}

    components = []
    for coord in sorted(graph_nodes, key=lambda c: _maven_purl(
            *_parse_coordinate(c)[:3])):
        node = graph_nodes[coord]
        shipped = None
        if shipped_owners is not None:
            shipped = node.get("label") in shipped_owners
        components.append(_component(coord, node["sha256"], namespace, shipped))

    # Bundled jars with no Maven identity (first-party plugin code).
    if shipped_labels is not None:
        seen = set()
        for name, owner in sorted(shipped_labels):
            if owner in label_to_coord or name in seen:
                continue
            seen.add(name)
            components.append(_nonmaven_component(name, owner, namespace))

    fingerprint = hashlib.sha256(
        json.dumps(sorted((c, graph_nodes[c]["sha256"] or "")
                          for c in graph_nodes),
                   sort_keys=True).encode("utf-8")).hexdigest()
    serial = uuid.uuid5(_SERIAL_NS, "%s:%s" % (product_version, fingerprint))

    counts = {}
    for c in components:
        for p in c.get("properties", []):
            if p["name"].endswith(":inclusion"):
                counts[p["value"]] = counts.get(p["value"], 0) + 1

    root_purl = _maven_purl(product_group, product_name, product_version)
    if shipped_labels is None:
        scope = "target-dependency-closure"
    elif drop_compile_only:
        scope = "bundled-dependencies"
    else:
        scope = "bundled-and-compile-deps"
    props = [
        {"name": "%s:sbom:scope" % namespace, "value": scope},
        {"name": "%s:sbom:source" % namespace, "value": target},
        {"name": "%s:sbom:graphFingerprint" % namespace, "value": fingerprint},
    ] + [
        {"name": "%s:sbom:inclusion:%s" % (namespace, k), "value": str(v)}
        for k, v in sorted(counts.items())
    ]

    return {
        "bomFormat": "CycloneDX",
        "specVersion": "1.7",
        "serialNumber": "urn:uuid:%s" % serial,
        "version": 1,
        "metadata": {
            "timestamp": _timestamp(source_date_epoch),
            "tools": {"components": [{
                "type": "application",
                "name": GENERATOR_NAME,
                "version": GENERATOR_VERSION,
            }]},
            "component": {
                "type": "application",
                "bom-ref": root_purl,
                "group": product_group,
                "name": product_name,
                "version": product_version,
                "purl": root_purl,
            },
            "properties": props,
        },
        "components": components,
        "dependencies": _dependency_graph(graph_nodes),
    }


def main(argv):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--graph-facts", required=True,
                   help="JSON facts collected by the sbom aspect")
    p.add_argument("--shipped-labels", default=None,
                   help="manifest of bundled jars (name<TAB>owner label), to "
                        "mark shipped vs compile-only by owner")
    p.add_argument("--output", required=True, help="CycloneDX JSON output path")
    p.add_argument("--target", default="(unknown)",
                   help="label of the plugin target the SBOM describes")
    p.add_argument("--product-group", default="com.googlesource.gerrit.plugins")
    p.add_argument("--product-name", default="plugin")
    p.add_argument("--product-version", default="0",
                   help="product version for the root component")
    p.add_argument("--product-version-file", default=None,
                   help="file containing the product version; overrides the flag")
    p.add_argument("--source-date-epoch", default=None,
                   help="Unix epoch for the SBOM timestamp (defaults to "
                        "$SOURCE_DATE_EPOCH, then 0)")
    p.add_argument("--property-namespace", default="gerrit",
                   help="top-level CycloneDX property namespace (lower-case)")
    p.add_argument("--drop-compile-only", action="store_true",
                   help="omit compile-only (provided) deps -- e.g. the Gerrit "
                        "Plugin API closure -- and report only bundled jars")
    args = p.parse_args(argv)

    version = args.product_version
    if args.product_version_file:
        with open(args.product_version_file, encoding="utf-8") as fh:
            version = fh.read().strip()
        if not version:
            p.error("product version file is empty")

    nodes = load_facts(args.graph_facts)
    if not nodes:
        sys.stderr.write("error: no Maven nodes in graph facts\n")
        return 1
    shipped = _load_shipped_labels(args.shipped_labels) \
        if args.shipped_labels else None
    sbom = build_sbom(nodes, args.target, args.product_group, args.product_name,
                      version, args.source_date_epoch,
                      args.property_namespace, shipped_labels=shipped,
                      drop_compile_only=args.drop_compile_only)
    with open(args.output, "w", encoding="utf-8") as fh:
        json.dump(sbom, fh, indent=2, sort_keys=True)
        fh.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
