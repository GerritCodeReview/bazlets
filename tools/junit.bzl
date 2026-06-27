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

# Starlark rule to generate a Junit4 TestSuite
# Assumes srcs are all .java Test files
# Assumes junit4 is already added to deps by the user.

# See https://github.com/bazelbuild/bazel/issues/1017 for background.

load("@rules_java//java:defs.bzl", "java_test")

_OUTPUT = """import org.junit.runners.Suite;
import org.junit.runner.RunWith;

@RunWith(Suite.class)
@Suite.SuiteClasses({%s})
@SuppressWarnings("DefaultPackage")
public class %s {}
"""

_PREFIXES = ("org", "com", "edu")

def _SafeIndex(l, val):
    for i, v in enumerate(l):
        if val == v:
            return i
    return -1

def _AsClassName(fname):
    fname = [x.path for x in fname.files.to_list()][0]
    toks = fname[:-5].split("/")
    findex = -1
    for s in _PREFIXES:
        findex = _SafeIndex(toks, s)
        if findex != -1:
            break
    if findex == -1:
        fail("%s does not contain any of %s" % (fname, _PREFIXES))
    return ".".join(toks[findex:]) + ".class"

def _impl(ctx):
    classes = ",".join(
        [_AsClassName(x) for x in ctx.attr.srcs],
    )
    ctx.actions.write(output = ctx.outputs.out, content = _OUTPUT % (
        classes,
        ctx.attr.outname,
    ))

_gen_suite = rule(
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "outname": attr.string(),
    },
    outputs = {"out": "%{name}.java"},
    implementation = _impl,
)

def junit_tests(name, srcs, suite_srcs = None, **kwargs):
    """Generate a JUnit4 @RunWith(Suite) test class and run it as a java_test.

    Args:
      name: name of the java_test target.
      srcs: sources compiled into the test. May be plain `.java` files or a
          generated `.srcjar` (for example a transformed servlet-flavour test
          srcjar).
      suite_srcs: optional. The sources whose file *paths* are scanned to derive
          the `@Suite.SuiteClasses` list. Defaults to `srcs`.

          Pass this only when `srcs` is a `.srcjar`: a srcjar is a single opaque
          artifact whose entries cannot be enumerated at analysis time, so the
          suite cannot be generated from it. Point `suite_srcs` at the canonical
          `.java` test files instead. This is valid because the servlet-flavour
          transform preserves package and class names, so the canonical files
          yield exactly the class names present in the transformed srcjar.
          The canonical EE8/EE10 generated-test targets use this.
      **kwargs: forwarded to java_test (deps, runtime_deps, size, ...).
    """
    s_name = name.replace("-", "_") + "TestSuite"
    _gen_suite(
        name = s_name,
        srcs = suite_srcs if suite_srcs else srcs,
        outname = s_name,
        # The generated suite is always test-scoped; marking it testonly also
        # lets suite_srcs reference testonly filegroups (the canonical test
        # sources of a generated-flavour module).
        testonly = True,
    )
    jvm_flags = kwargs.get("jvm_flags", [])
    jvm_flags = jvm_flags
    java_test(
        name = name,
        test_class = s_name,
        srcs = srcs + [":" + s_name],
        **dict(kwargs, jvm_flags = jvm_flags)
    )
