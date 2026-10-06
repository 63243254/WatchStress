"""Add local placeholder signatures preserving capabilities for later resigning.

No Apple credentials or provisioning profiles are used. This cannot make the app
installable on an iPhone or Watch by itself.
"""
from __future__ import annotations

import argparse
import plistlib
import subprocess
import tempfile
from pathlib import Path


def prepare(app: Path) -> None:
    watch_apps = list((app / "Watch").glob("*.app"))
    if len(watch_apps) != 1:
        raise ValueError("Expected one embedded Watch app before resigning preparation.")
    watch = watch_apps[0]
    widgets = list((watch / "PlugIns").glob("*.appex"))
    if len(widgets) != 1:
        raise ValueError("Expected one embedded Watch complication.")

    with tempfile.TemporaryDirectory(prefix="watchstress-entitlements-") as temporary:
        # Sign deepest first so the parent's resource seal includes child signatures.
        for bundle, needs_health in ((widgets[0], False), (watch, True), (app, True)):
            with (bundle / "Info.plist").open("rb") as stream:
                info = plistlib.load(stream)
            group = info.get("StressAppGroup")
            if not isinstance(group, str) or not group.startswith("group.") or "$" in group:
                raise ValueError(f"Unresolved or invalid StressAppGroup in {bundle.name}.")
            entitlements = {"com.apple.security.application-groups": [group]}
            if needs_health:
                entitlements["com.apple.developer.healthkit"] = True
            path = Path(temporary) / (bundle.name + ".entitlements")
            path.write_bytes(plistlib.dumps(entitlements))
            subprocess.run(
                ["codesign", "--force", "--sign", "-", "--generate-entitlement-der",
                 "--entitlements", str(path), str(bundle)],
                check=True,
            )
            result = subprocess.run(
                ["codesign", "--display", "--entitlements", "-", str(bundle)],
                check=True, capture_output=True,
            )
            actual = plistlib.loads(result.stdout)
            if actual != entitlements:
                raise ValueError(f"Capability metadata did not survive signing of {bundle.name}.")
        subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    print("Local placeholder signatures verified; Apple device signing is still required.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    args = parser.parse_args()
    prepare(args.app)

