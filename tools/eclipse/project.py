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

class EclipseProject():

  # Path to the Bazel/Bazelisk binary
  bazel_exe = None
  # Root of the Bazel project (holding WORKSPACE file)
  ROOT = None

  def main(self):
    self.bazel_exe = self.find_bazel(self.args.bazel_exe)

    self.ROOT = self.find_root(self.args.root)

    project_name = (self.args.name if self.args.name
                    else os.path.basename(self.ROOT))

    self.gen_project(project_name, root=self.ROOT)
    self.gen_classpath(self.retrieve_ext_location().decode('utf-8'))

  def _get_argument_parser(self):
    opts = argparse.ArgumentParser("Create Eclipse Project")
    opts.add_argument('-r', '--root', help='Root directory entry',
                      required=True)
    opts.add_argument('-n', '--name', help='Project name')
    opts.add_argument('-x', '--exclude', action='append', help='Exclude paths')
    opts.add_argument('-b', '--batch', action='store_true',
                      dest='batch', help='Bazel batch option')
    opts.add_argument('--bazel',
                      help=('name of the bazel executable. Defaults to using'
                            ' bazelisk if found, or bazel if bazelisk is not'
                            ' found.'),
                      action='store', default=None, dest='bazel_exe')
    return opts

  def parse_args(self, args):
    self.args = self._get_argument_parser().parse_args(args)
    return self.args

  def find_root(self, root):
    ROOT = os.path.abspath(root)
    while not os.path.exists(os.path.join(ROOT, 'WORKSPACE')):
      if ROOT == '/':
        raise Exception(
          'Could not find root of project: no WORKSPACE file found')
      ROOT = os.path.dirname(ROOT)
    return ROOT

  def find_bazel(self, bazel_exe=None):
    if bazel_exe:
      try:
        return subprocess.check_output(
          ['which', bazel_exe]).strip().decode('UTF-8')
      except subprocess.CalledProcessError:
        raise Exception('Bazel command: %s not found' % bazel_exe)
    try:
      return subprocess.check_output(
        ['which', 'bazelisk']).strip().decode('UTF-8')
    except subprocess.CalledProcessError:
      try:
        return subprocess.check_output(
          ['which', 'bazel']).strip().decode('UTF-8')
      except subprocess.CalledProcessError:
        raise Exception(
          "Neither bazelisk nor bazel found. Please see"
          " Documentation/dev-bazel for instructions on installing"
          " one of them.")

  def _build_bazel_cmd(self, *args):
    cmd = [self.bazel_exe]
    if self.args.batch:
      cmd.append('--batch')
    for arg in args:
      cmd.append(arg)
    return cmd

  def retrieve_ext_location(self):
    return subprocess.check_output(
      self._build_bazel_cmd('info', 'output_base')).strip()

  def _query_classpath(self):
    t = '//tools/eclipse:main_classpath_collect'
    try:
      cmd = self._build_bazel_cmd('build', t)
      subprocess.check_call(cmd)
    except subprocess.CalledProcessError:
      raise Exception("Could not query classpath with:" % cmd)
    name = 'bazel-bin/tools/eclipse/' + t.split(':')[1] + '.runtime_classpath'
    return [line.rstrip('\n') for line in open(name)]

  def gen_project(name, root):
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

  def gen_classpath(self, ext):
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
    for p in self._query_classpath():
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
        if self.excluded(j):
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

    p = os.path.join(self.ROOT, '.classpath')
    with open(p, 'w') as fd:
      doc.writexml(fd, addindent='\t', newl='\n', encoding='UTF-8')

  def excluded(self, lib):
    if self.args.exclude:
      for x in self.args.exclude:
        if x in lib:
          return True
    return False

def main():
  try:
    ec = EclipseProject()
    ec.parse_args(args=sys.argv[1:])
    ec.main()
  except KeyboardInterrupt:
    print('Interrupted by user', file=sys.stderr)
    exit(1)


if __name__ == '__main__':
  main()
