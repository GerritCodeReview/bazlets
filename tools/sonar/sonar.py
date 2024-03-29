#!/usr/bin/env python3
# Copyright (C) 2018 The Android Open Source Project
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


# This script runs a Sonarqube analysis for a Gerrit plugin and uploads the
# results to the local Sonarqube instance, similar to what `mvn sonar:sonar`
# would do.
#
# It will build the plugin, generate sonar-project.properties file and then
# call sonar-scanner (sonar-scanner must be installed and available in the
# path).
#
# This script must be called from the root folder of a gerrit plugin supporting
# standalone bazel build:
#
# ./bazlets/tools/sonar.py
#

from __future__ import print_function
from os import path
import re
from shutil import rmtree
from tempfile import mkdtemp
from subprocess import check_call, check_output, CalledProcessError
from zipfile import ZipFile

from gen_sonar_project_properties import generate_project_properties


def get_plugin_name():
  target_names = check_output(['bazel', 'query', 'kind(java_binary, //...)']).decode('utf-8')
  return re.search('(?<=//:)(.*)(?=__non_stamped)', target_names).group(1)


plugin_dir = check_output(['bazel', 'info', 'workspace']).decode('utf-8').strip()
plugin_name = get_plugin_name()
temp_dir = mkdtemp()
try:
  try:
    check_call(['bazel', 'build', '//:' + plugin_name])
  except CalledProcessError as err:
    exit(1)

  classes_dir = path.join(temp_dir, 'classes')
  with ZipFile(path.join(plugin_dir, 'bazel-genfiles', plugin_name + '.jar'),
               "r") as z:
    z.extractall(classes_dir)

  sonar_project_properties = path.join(temp_dir, 'sonar-project.properties')

  generate_project_properties(plugin_name, plugin_dir, classes_dir,
                              sonar_project_properties)
  try:
    check_call(['sonar-scanner',
                '-Dproject.settings=' + sonar_project_properties, ])
  except CalledProcessError as err:
    exit(1)
finally:
  rmtree(path.join(plugin_dir, '.scannerwork'), ignore_errors=True)
  rmtree(temp_dir, ignore_errors=True)

