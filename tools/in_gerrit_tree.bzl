def in_gerrit_tree_enabled():
    """Constraints for target_compatible_with to enable Gerrit-tree-only targets.

    Use as:
      target_compatible_with = in_gerrit_tree_enabled()

    In the Gerrit source tree (flag true), targets remain compatible and run.
    In standalone plugin workspaces (flag false), targets are marked
    incompatible and are reported as SKIPPED by Bazel.
    """
    return select({
        "@com_googlesource_gerrit_bazlets//flags:in_gerrit_tree_enabled": [],
        "//conditions:default": ["@platforms//:incompatible"],
    })
