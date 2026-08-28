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

JRE = '/'.join([
  'org.eclipse.jdt.launching.JRE_CONTAINER',
  'org.eclipse.jdt.internal.debug.ui.launcher.StandardVMType',
  'JavaSE-11',
])

opts = argparse.ArgumentParser("Create Eclipse Project")
opts.add_argument('-r', '--root', help='Root directory entry')
opts.add_argument('-n', '--name', help='Project name')
opts.add_argument('-x', '--exclude', action='append', help='Exclude paths')
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

def retrieve_ext_location():
  return subprocess.check_output(_build_bazel_cmd('info', 'output_base')).strip()

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

def _resolve_repo_path(ext, p):
  if ext is not None and p.startswith("external"):
    return os.path.join(ext, p)
  return p

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

def gen_classpath(ext):
  def make_classpath():
    impl = xml.dom.minidom.getDOMImplementation()
    return impl.createDocument(None, 'classpath', None)

  def classpathentry(kind, path, src=None, out=None, exported=None):
    e = doc.createElement('classpathentry')
    e.setAttribute('kind', kind)
    # TODO(davido): Remove this and other exclude BUILD files hack
    # when this Bazel bug is fixed:
    # https://github.com/bazelbuild/bazel/issues/1083
    if kind == 'src':
      e.setAttribute('excluding', '**/BUILD')
    e.setAttribute('path', path)
    if src:
      e.setAttribute('sourcepath', src)
    if out:
      e.setAttribute('output', out)
    if exported:
      e.setAttribute('exported', 'true')
    doc.documentElement.appendChild(e)

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
      lib.add(_resolve_repo_path(ext, p))

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

  for libs in [lib]:
    for j in sorted(libs):
      if excluded(j):
        continue

      j = _prefer_unprocessed_jar(j)

      # Skip processed_/header_ jars that were not materialized locally;
      # Eclipse would otherwise flag a missing required library.
      b = os.path.basename(j)
      if (b.startswith("processed_") or b.startswith("header_")) \
         and not os.path.exists(j):
        continue

      s = None
      # Attach the source jar published by the collector on an unambiguous
      # basename match; if several source jars normalize to the same basename,
      # skip rather than risk attaching the wrong one.
      key = _normalize_jar_basename(j)
      matches = source_by_basename.get(key, [])
      if len(matches) == 1:
        s = _resolve_repo_path(ext, matches[0])
      classpathentry('lib', j, s)

  classpathentry('con', JRE)
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
  gen_classpath(retrieve_ext_location().decode('utf-8'))

except KeyboardInterrupt:
  print('Interrupted by user', file=sys.stderr)
  exit(1)
