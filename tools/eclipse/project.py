#!/usr/bin/env python3
# Copyright (C) 2017 The Android Open Source Project
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
#

from __future__ import print_function
import argparse
import os
import subprocess
import re
import sys
import xml.dom.minidom

def JRE(java_vers='25'):
  return '/'.join([
    'org.eclipse.jdt.launching.JRE_CONTAINER',
    'org.eclipse.jdt.internal.debug.ui.launcher.StandardVMType',
    'JavaSE-%s' % java_vers,
  ])

opts = argparse.ArgumentParser("Create Eclipse Project")
opts.add_argument('-r', '--root', help='Root directory entry')
opts.add_argument('-n', '--name', help='Project name')
opts.add_argument('-x', '--exclude', action='append', help='Exclude paths')
opts.add_argument('-j', '--java', action='store', dest='java',
                  help='Java version for the JRE container (default: 25)')
opts.add_argument('--jgit-root', action='store', dest='jgit_root',
                  help='Base path of the JGit submodule; combine with '
                       '--jgit-module to import module sources')
opts.add_argument('--jgit-module', action='append', default=[],
                  dest='jgit_module',
                  help='JGit module directory under --jgit-root to import as '
                       'source, e.g. org.eclipse.jgit (repeatable). The '
                       'consumer picks the modules it depends on.')
opts.add_argument('--java-prettify-root', action='store',
                  dest='java_prettify_root',
                  help='Import java-prettify submodule sources from this path')
opts.add_argument('--drop-jar', action='append', default=[], dest='drop_jar',
                  help='Library jar basename to omit, e.g. because its sources '
                       'are imported as an overlay instead (repeatable)')
opts.add_argument('--extra-src', action='append', default=[], dest='extra_src',
                  help='Additional in-repo source root to add, e.g. a resources '
                       'directory not produced as a java_library (repeatable)')
opts.add_argument('-b', '--batch', action='store_true',
                  dest='batch', help='Bazel batch option')
opts.add_argument('--bazel',
                  help=('name of the bazel executable. Defaults to using'
                        ' bazelisk if found, or bazel if bazelisk is not'
                        ' found.'),
                  action='store', default=None, dest='bazel_exe')
args = opts.parse_args()

if not args.root:
  opts.error('Root option not provided')
  sys.exit(1)

if args.jgit_module and not args.jgit_root:
  opts.error('--jgit-module requires --jgit-root')

root = args.root
ROOT = os.path.abspath(root)
while not os.path.exists(os.path.join(ROOT, 'MODULE.bazel')):
  ROOT = os.path.dirname(ROOT)

batch_option = '--batch' if args.batch else None

def find_bazel():
  if args.bazel_exe:
    try:
      return subprocess.check_output(
        ['which', args.bazel_exe]).strip().decode('UTF-8')
    except subprocess.CalledProcessError:
      print('Bazel command: %s not found' % args.bazel_exe, file=sys.stderr)
      sys.exit(1)
  try:
    return subprocess.check_output(
      ['which', 'bazelisk']).strip().decode('UTF-8')
  except subprocess.CalledProcessError:
    try:
      return subprocess.check_output(
        ['which', 'bazel']).strip().decode('UTF-8')
    except subprocess.CalledProcessError:
      print("Neither bazelisk nor bazel found. Please see"
            " Documentation/dev-bazel for instructions on installing"
            " one of them.")
      sys.exit(1)

bazel_exe = find_bazel()

def _build_bazel_cmd(*args):
  cmd = [bazel_exe]
  if batch_option:
    cmd.append('--batch')
  for arg in args:
    cmd.append(arg)
  return cmd

def _query_classpath():
  t = '//tools/eclipse:main_classpath_collect'
  try:
    subprocess.check_call(_build_bazel_cmd('build', t))
  except subprocess.CalledProcessError:
    exit(1)
  base = 'bazel-bin/tools/eclipse/' + t.split(':')[1]
  runtime = [line.rstrip('\n') for line in open(base + '.runtime_classpath')]
  # rules_jvm_external resolves source jars lazily; the classpath_collector
  # rule materializes them and lists them in .source_classpath.
  sources = []
  sources_name = base + '.source_classpath'
  if os.path.exists(sources_name):
    sources = [line.rstrip('\n') for line in open(sources_name)]
  return runtime, sources

def _normalize_jar_basename(p):
  b = os.path.basename(p)
  for pref in ('processed_', 'header_'):
    if b.startswith(pref):
      b = b[len(pref):]
  if b.endswith('-sources.jar'):
    b = b[:-len('-sources.jar')] + '.jar'
  return b

def _prefer_unprocessed_jar(jar):
  b = os.path.basename(jar)
  if b.startswith('processed_'):
    alt = os.path.join(os.path.dirname(jar), b[len('processed_'):])
  elif b.startswith('header_'):
    alt = os.path.join(os.path.dirname(jar), b[len('header_'):])
  else:
    return jar
  if os.path.exists(alt):
    return alt
  return jar

def gen_project(name, root=ROOT):
  p = os.path.join(root, '.project')
  with open(p, 'w') as fd:
    print("""\
<?xml version="1.0" encoding="UTF-8"?>
<projectDescription>
  <name>%(name)s</name>
  <buildSpec>
    <buildCommand>
      <name>org.eclipse.jdt.core.javabuilder</name>
    </buildCommand>
  </buildSpec>
  <natures>
    <nature>org.eclipse.jdt.core.javanature</nature>
  </natures>
</projectDescription>\
    """ % {"name": name}, file=fd)

def gen_classpath():
  def make_classpath():
    impl = xml.dom.minidom.getDOMImplementation()
    return impl.createDocument(None, 'classpath', None)

  def classpathentry(kind, path, src=None, out=None, exported=None,
                     excluding=None, third_party=False):
    e = doc.createElement('classpathentry')
    e.setAttribute('kind', kind)
    # TODO(davido): Remove this and other exclude BUILD files hack
    # when this Bazel bug is fixed:
    # https://github.com/bazelbuild/bazel/issues/1083
    if kind == 'src':
      exclude = '**/BUILD'
      if excluding:
        exclude += '|' + excluding
      e.setAttribute('excluding', exclude)
    e.setAttribute('path', path)
    if src:
      e.setAttribute('sourcepath', src)
    if out:
      e.setAttribute('output', out)
    if exported:
      e.setAttribute('exported', 'true')
    # Overlay sources come from third-party submodules; don't surface their
    # optional problems in the importing project.
    if third_party:
      atts = doc.createElement('attributes')
      ign = doc.createElement('attribute')
      ign.setAttribute('name', 'ignore_optional_problems')
      ign.setAttribute('value', 'true')
      atts.appendChild(ign)
      e.appendChild(atts)
    doc.documentElement.appendChild(e)

  def overlay_src(path, excluding=None):
    if os.path.exists(os.path.join(ROOT, path)):
      classpathentry('src', path, excluding=excluding, third_party=True)

  def import_source_overlays():
    # Opt-in: when a consumer vendors JGit / java-prettify as submodules, import
    # the modules it depends on as source folders so Eclipse compiles them from
    # source (navigable + editable) instead of treating them as opaque jars.
    # The consumer names the JGit modules -- its dependency set differs from
    # other consumers' -- and bazlets only applies the per-module conventions.
    if args.jgit_root:
      for mod in args.jgit_module:
        base = os.path.join(args.jgit_root, mod)
        # org.eclipse.jgit.archive ships an OSGi activator Eclipse cannot
        # compile without the OSGi runtime; exclude it.
        excluding = ('org/eclipse/jgit/archive/FormatActivator.java'
                     if mod.endswith('.archive') else None)
        overlay_src(os.path.join(base, 'src'), excluding=excluding)
        overlay_src(os.path.join(base, 'resources'))
    if args.java_prettify_root:
      overlay_src(os.path.join(args.java_prettify_root, 'src'))

  # Optional generated-source mapping for the JGit EE8 servlet bridge, whose
  # javax sources are generated (not in the submodule tree). Enabled with
  # --jgit-root.
  generated_jgit_sources = {}
  if args.jgit_root:
    generated_jgit_sources = {
        "org.eclipse.jgit.http.server.ee8/libjgit-servlet-ee8.jar":
            "org.eclipse.jgit.http.server.ee8/jgit-http-server-ee8-srcs.srcjar",
    }

  def generated_jgit_source(jar):
    for jar_suffix, src_suffix in generated_jgit_sources.items():
      if jar.endswith(jar_suffix):
        candidate = jar[:-len(jar_suffix)] + src_suffix
        if os.path.exists(candidate):
          return candidate
    return None

  doc = make_classpath()
  src = set()
  lib = set()

  java_library = re.compile('bazel-out/(?:.*)-fastbuild/bin(.*)/[^/]+[.]jar$')

  runtime_cp, source_cp = _query_classpath()

  # Index source jars by normalized basename. A basename can map to more than
  # one source jar; keep them all and attach only on an unambiguous match.
  source_by_basename = {}
  for p in source_cp:
    source_by_basename.setdefault(_normalize_jar_basename(p), []).append(p)

  for p in runtime_cp:
    m = java_library.match(p)
    # In-repo java_library outputs live under bazel-out/.../bin with a path
    # that does not start with /external/. Everything else is an external
    # library: rules_jvm_external Maven jars now appear as
    # bazel-out/.../bin/external/.../processed_*.jar (they used to be plain
    # external/<repo>/jar/*.jar), and both must land in the library set.
    if m and not m.group(1).startswith("/external/"):
      src.add(m.group(1).lstrip('/'))
    else:
      # Bazel's internal runner deploy jars: Eclipse runs tests with its own
      # runner, and rules_java's Runner_deploy.jar bundles a copy of
      # JUnit/Hamcrest that would shadow the real, source-attached Maven jar.
      if p.endswith("external/bazel_tools/tools/jdk/TestRunner_deploy.jar") \
         or p.endswith("/java_tools/Runner_deploy.jar"):
        continue
      lib.add(p)

  src_paths = {}
  for s in sorted(src):
    out = None

    if s.startswith('lib/'):
      out = 'eclipse-out/lib'

    p = os.path.join(s, 'java')
    if os.path.exists(p):
      classpathentry('src', p, out=out)
      continue

    for env in ['main', 'test', 'java', 'javatests']:
      o = None
      if out:
        o = out + '/' + env
      elif env == 'test' or env == 'javatests':
        o = 'eclipse-out/test'

      if s.startswith(env + '/'):
        src_paths[env] = o
        continue

      for srctype in ['java', 'resources']:
        p = os.path.join(s, 'src', env, srctype)
        if os.path.exists(p):
          src_paths[p] = o

  for s in src_paths:
    classpathentry('src', s, out=src_paths[s])

  # In-repo source roots that are not java_library outputs (e.g. a resources
  # directory) and so are not discovered above.
  for extra in args.extra_src:
    if os.path.exists(os.path.join(ROOT, extra)):
      classpathentry('src', extra)

  import_source_overlays()

  for j in sorted(lib):
    if excluded(j):
      continue

    j = _prefer_unprocessed_jar(j)
    b = os.path.basename(j)
    key = _normalize_jar_basename(j)

    # Caller asked to omit this library, e.g. because its sources are imported
    # as an overlay above and the jar would only shadow them. Match either the
    # raw basename or the normalized one (so processed_libfoo.jar is dropped by
    # --drop-jar libfoo.jar too).
    if b in args.drop_jar or key in args.drop_jar:
      continue

    # Skip processed_/header_ jars that were not materialized locally;
    # Eclipse would otherwise flag a missing required library.
    if (b.startswith("processed_") or b.startswith("header_")) \
       and not os.path.exists(j):
      continue

    # Prefer a generated JGit srcjar (EE8 bridge); otherwise attach the
    # collector's source jar on an unambiguous basename match.
    s = generated_jgit_source(j)
    if not s:
      matches = source_by_basename.get(key, [])
      if len(matches) == 1:
        s = matches[0]
    classpathentry('lib', j, s)

  classpathentry('con', JRE(args.java) if args.java else JRE())
  classpathentry('output', 'eclipse-out/classes')

  p = os.path.join(ROOT, '.classpath')
  with open(p, 'w') as fd:
    doc.writexml(fd, addindent='\t', newl='\n', encoding='UTF-8')

def excluded(lib):
  if args.exclude:
    for x in args.exclude:
      if x in lib:
        return True
  return False

try:
  name = args.name if args.name else os.path.basename(ROOT)
  gen_project(name)
  gen_classpath()

except KeyboardInterrupt:
  print('Interrupted by user', file=sys.stderr)
  exit(1)
