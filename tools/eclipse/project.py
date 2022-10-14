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
opts.add_argument('-r', '--root', help='Root directory entry', required=True)
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

root = args.root
ROOT = os.path.abspath(root)
while not os.path.exists(os.path.join(ROOT, 'WORKSPACE')):
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
  name = 'bazel-bin/tools/eclipse/' + t.split(':')[1] + '.runtime_classpath'
  return [line.rstrip('\n') for line in open(name)]

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
  srcs = re.compile('(.*/external/[^/]+)/jar/(.*)[.]jar')
  for p in _query_classpath():
    m = java_library.match(p)
    if m:
      src.add(m.group(1).lstrip('/'))
    else:
      if ext is not None and p.startswith("external"):
        p = os.path.join(ext, p)
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

  for libs in [lib]:
    for j in sorted(libs):
      if excluded(j):
        continue
      s = None
      m = srcs.match(j)
      if m:
        prefix = m.group(1)
        suffix = m.group(2)
        p = os.path.join(prefix, "src", "%s-src.jar" % suffix)
        if os.path.exists(p):
          s = p
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
