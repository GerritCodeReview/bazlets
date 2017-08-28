#!/usr/bin/env python
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

from __future__ import print_function
from optparse import OptionParser
from os import path, environ
from subprocess import check_output, CalledProcessError
from sys import stderr

def mvn(action):
  return ['mvn', '--file', path.join(root, 'fake_pom_%s.xml' % action)]

opts = OptionParser()
opts.add_option('--repository', help='maven repository id')
opts.add_option('--url', help='maven repository url')
opts.add_option('-o')
opts.add_option('-r', '--root', help='Root directory')
opts.add_option('-g', help='maven group id')
opts.add_option('-a', help='action (valid actions are: install,deploy)')
opts.add_option('-v', help='gerrit version')
opts.add_option('-s', action='append', help='triplet of artifactId:type:path')

args, ctx = opts.parse_args()
if not args.g:
  print('group is empty', file=stderr)
  exit(1)

if not args.v:
  print('version is empty', file=stderr)
  exit(1)

if not args.root:
  opts.error('Root option not provided')
  exit(1)

common = [
  '-DgroupId=%s' % args.g,
  '-Dversion=%s' % args.v,
]

root = path.abspath(args.root)
while not path.exists(path.join(root, 'WORKSPACE')):
  root = path.dirname(root)

if 'install' == args.a:
  cmd = mvn(args.a) + ['install:install-file'] + common
elif 'deploy' == args.a:
  cmd = mvn(args.a) + [
    'gpg:sign-and-deploy-file',
    '-DrepositoryId=%s' % args.repository,
    '-Durl=%s' % args.url,
  ] + common
else:
  print("unknown action -a %s" % args.a, file=stderr)
  exit(1)

for spec in args.s:
  artifact, packaging_type, src = spec.split(':')
  exe = cmd + [
    '-DartifactId=%s' % artifact,
    '-Dpackaging=%s' % packaging_type,
    '-Dfile=%s' % src,
  ]
  try:
    if environ.get('VERBOSE'):
      print(' '.join(exe), file=stderr)
    check_output(exe)
  except CalledProcessError as e:
    print(
      '%s command failed: %s\n%s\n%s' % (args.a, ' '.join(exe), e, e.output),
      file=stderr)
    exit(1)


out = stderr
if args.o:
  out = open(args.o, 'w')

with out as fd:
  if args.repository:
    print('Repository: %s' % args.repository, file=fd)
  if args.url:
    print('URL: %s' % args.url, file=fd)
  print('Version: %s' % args.v, file=fd)
