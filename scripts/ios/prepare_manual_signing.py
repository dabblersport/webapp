#!/usr/bin/env python3
"""Switch the Runner app target to manual distribution signing, on the CI runner only (KAN-568).

The committed Xcode project signs automatically (a developer's Xcode account). A CI runner has no
Apple account: it has the Apple Distribution certificate in a temporary keychain and the App
Store provisioning profile. This script edits the checked-out copy of
ios/Runner.xcodeproj/project.pbxproj IN PLACE, for the Runner app target's Release and Profile
configurations only:

    CODE_SIGN_STYLE = Manual
    "CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution"
    PROVISIONING_PROFILE_SPECIFIER = "<profile name>"

Debug, the RunnerTests targets and the Pods project are left alone. The edit is never committed
(the workflow runs it on a throwaway checkout).

    prepare_manual_signing.py <project.pbxproj> <bundle id> <profile name>
"""
import re
import sys

CONFIG_BLOCK = re.compile(
    r"(\t\t[0-9A-F]{24} /\* (?P<name>[^*]+) \*/ = \{\n\t\t\tisa = XCBuildConfiguration;\n.*?\n\t\t\};\n)", re.S)


def patch(text, bundle_id, profile_name):
    """Return (new_text, patched_config_names)."""
    patched = []
    exact = "PRODUCT_BUNDLE_IDENTIFIER = %s;" % bundle_id

    def rewrite(m):
        block, name = m.group(1), m.group("name").strip()
        if exact not in block or name not in ("Release", "Profile"):
            return block
        if "CODE_SIGN_STYLE = Automatic;" not in block:
            raise SystemExit("unexpected signing settings in the %s configuration" % name)
        block = block.replace(
            "CODE_SIGN_STYLE = Automatic;",
            'CODE_SIGN_STYLE = Manual;\n\t\t\t\t"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution";\n'
            '\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "%s";' % profile_name, 1)
        patched.append(name)
        return block

    return CONFIG_BLOCK.sub(rewrite, text), patched


def main(argv):
    if len(argv) != 4:
        print(__doc__)
        return 2
    path, bundle_id, profile_name = argv[1:]
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()
    new, patched = patch(text, bundle_id, profile_name)
    if sorted(patched) != ["Profile", "Release"]:
        raise SystemExit("expected to patch the Runner Release and Profile configurations, patched: %s" % patched)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(new)
    print("patched Runner configurations: %s" % ", ".join(sorted(patched)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
