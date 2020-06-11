# Copyright (C) 2020 The Android Open Source Project
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

def _gerrit_api_version_impl(ctx):
    ctx.file("version.txt", "Gerrit-ApiVersion: " + ctx.attr.version, False)
    ctx.file("BUILD.bazel", 'exports_files(["version.txt"])', False)

gerrit_api_version = repository_rule(
    implementation = _gerrit_api_version_impl,
    local = True,
    attrs = {
        "version": attr.string(
            mandatory = True,
        ),
    },
)
