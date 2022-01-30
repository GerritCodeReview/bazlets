# Copyright (C) 2016 The Android Open Source Project
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

sh_bang_template = (" && ".join([
    "echo '#!/bin/bash -e' > $@",
    "echo \"# this script should run from the root of your workspace.\" >> $@",
    "echo \"\" >> $@",
    "echo 'if [[ \"$$VERBOSE\" ]]; then set -x ; fi' >> $@",
    "echo \"\" >> $@",
    "echo %s >> $@",
    "echo \"\" >> $@",
    "echo 'python3 $$OUTPUT_BASE/%s' >> $@",
]))

def maven_package(
        version,
        group,
        repository = None,
        url = None,
        jar = {},
        src = {},
        doc = {}):
    build_cmd = ["bazelisk", "build"]
    mvn_cmd = [
        "$(location @com_googlesource_gerrit_bazlets//tools/maven:mvn.py)",
        "-v",
        version,
        "-g",
        group,
        "-r",
        ".",
    ]
    api_cmd = mvn_cmd[:]
    api_targets = []
    for type, d in [("jar", jar), ("java-source", src), ("javadoc", doc)]:
        for a, t in sorted(d.items()):
            api_cmd.append("-s %s:%s:$(location %s)" % (a, type, t))
            api_targets.append(t)

    native.genrule(
        name = "gen_api_install",
        cmd = sh_bang_template % (
            " ".join(build_cmd + api_targets),
            " ".join(api_cmd + ["-a", "install"]),
        ),
        srcs = api_targets + ["@com_googlesource_gerrit_bazlets//tools/maven:mvn.py"],
        outs = ["api_install.sh"],
        executable = True,
        testonly = 1,
    )

    if repository and url:
        native.genrule(
            name = "gen_api_deploy",
            cmd = sh_bang_template % (
                " ".join(build_cmd + api_targets),
                " ".join(api_cmd + [
                    "-a",
                    "deploy",
                    "--repository",
                    repository,
                    "--url",
                    url,
                ]),
            ),
            srcs = api_targets + ["@com_googlesource_gerrit_bazlets//tools/maven:mvn.py"],
            outs = ["api_deploy.sh"],
            executable = True,
            testonly = 1,
        )
