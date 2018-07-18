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

def _py_binary_path_impl(ctx):
    """rule to retrieve python script location."""
    content = ""
    for f in ctx.attr.py_binary_label.py.transitive_sources:
        if ctx.attr.name in f.path:
            content = content + f.path
    ctx.file_action(output = ctx.outputs.output, content = content)

py_binary_path = rule(
    attrs = {
        "py_binary_label": attr.label(mandatory = True),
    },
    outputs = {
        "output": "%{name}.txt",
    },
    implementation = _py_binary_path_impl,
)
