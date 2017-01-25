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

def _project_path_impl(ctx):
  """rule to print python script location."""
#  print(ctx.attr._gen_project_script.py.transitive_sources[0])
  content = ""
  for f in ctx.attr._gen_project_script.py.transitive_sources:
      content += f.path
  ctx.file_action(output = ctx.outputs.output, content=content)

project_path = rule(
    attrs = {
        "_gen_project_script": attr.label(default = Label("//tools/eclipse:project"))
    },
    outputs = {
        "output": "%{name}.txt",
    },
    implementation = _project_path_impl,
)
