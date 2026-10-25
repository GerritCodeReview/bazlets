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

"""Regression coverage for shared WAR and plugin SBOM generation."""

import json
from pathlib import Path
import tempfile
import unittest

import sbom_from_graph as sbom


class SbomTest(unittest.TestCase):
    def setUp(self):
        self.nodes = {
            "example:runtime:1": {
                "label": "@@maven//:runtime", "sha256": "a" * 64,
                "deps": ["example:provided:2"],
            },
            "example:provided:2": {
                "label": "@@maven//:provided", "sha256": "b" * 64,
                "deps": [],
            },
        }
        self.shipped = [
            ("WEB-INF/lib/runtime-1.jar", "@@maven//:runtime"),
            ("WEB-INF/lib/local.jar", "@@//:local"),
        ]

    def build(self, **kwargs):
        return sbom.build_sbom(
            self.nodes, "@@//:release", "example", "release", "3", "0",
            "example", shipped_labels=self.shipped, **kwargs)

    def test_war_keeps_compile_only_components_separate(self):
        result = self.build()
        components = {c["name"]: c for c in result["components"]}
        self.assertEqual("required", components["runtime"]["scope"])
        self.assertEqual("excluded", components["provided"]["scope"])
        self.assertEqual("a" * 64, components["runtime"]["hashes"][0]["content"])
        self.assertEqual("local", components["local"]["name"])

    def test_bundled_only_drops_provided_components_and_edges(self):
        result = self.build(drop_compile_only=True)
        self.assertEqual({"runtime", "local"},
                         {c["name"] for c in result["components"]})
        self.assertEqual([{"ref": "pkg:maven/example/runtime@1", "dependsOn": []}],
                         result["dependencies"])

    def test_packaged_path_distinguishes_jars_with_same_basename(self):
        self.shipped.append(("WEB-INF/pgm-lib/local.jar", "@@//:other"))
        components = self.build()["components"]
        self.assertEqual(len(components), len({c["bom-ref"] for c in components}))
        self.assertEqual(2, sum(c["name"] == "local" for c in components))

    def test_product_version_file_overrides_default(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            facts = directory / "facts.json"
            facts.write_text(json.dumps([
                {"coord": coord, **node} for coord, node in self.nodes.items()
            ]))
            version = directory / "version.txt"
            version.write_text("3.16.0-SNAPSHOT\n")
            output = directory / "bom.json"
            self.assertEqual(0, sbom.main([
                "--graph-facts", str(facts), "--output", str(output),
                "--product-version-file", str(version),
            ]))
            result = json.loads(output.read_text())
            self.assertEqual("3.16.0-SNAPSHOT",
                             result["metadata"]["component"]["version"])


if __name__ == "__main__":
    unittest.main()
