"""Check the nested phone/watch/widget graph before attempting sideloading.

This checks package structure, not signatures, device compatibility, or sensor access.
"""
from __future__ import annotations

import argparse
import plistlib
from pathlib import PurePosixPath
from zipfile import BadZipFile, ZipFile


def validate(path: str) -> None:
    with ZipFile(path) as archive:
        names = archive.namelist()
        phone_files = [
            name for name in names
            if name.startswith("Payload/")
            and len(PurePosixPath(name).parts) == 3
            and name.endswith(".app/Info.plist")
        ]
        if len(phone_files) != 1:
            raise ValueError("Expected exactly one iPhone app under Payload.")
        phone_path = phone_files[0].removesuffix("Info.plist")
        watch_files = [
            name for name in names
            if name.startswith(phone_path + "Watch/")
            and len(PurePosixPath(name).parts) == 5
            and name.endswith(".app/Info.plist")
        ]
        if len(watch_files) != 1:
            raise ValueError("The iPhone app must embed exactly one Watch companion.")
        watch_path = watch_files[0].removesuffix("Info.plist")
        widget_files = [
            name for name in names
            if name.startswith(watch_path + "PlugIns/")
            and len(PurePosixPath(name).parts) == 7
            and name.endswith(".appex/Info.plist")
        ]
        if len(widget_files) != 1:
            raise ValueError("The Watch app must embed its complication extension.")

        phone = plistlib.loads(archive.read(phone_files[0]))
        watch = plistlib.loads(archive.read(watch_files[0]))
        widget = plistlib.loads(archive.read(widget_files[0]))
        phone_id = phone["CFBundleIdentifier"]
        watch_id = watch["CFBundleIdentifier"]
        widget_id = widget["CFBundleIdentifier"]
        if watch.get("WKCompanionAppBundleIdentifier") != phone_id:
            raise ValueError("Watch companion identifier does not match the iPhone app.")
        if not watch.get("WKApplication", False):
            raise ValueError("The Watch app is missing the single-target WKApplication flag.")
        if not watch_id.startswith(phone_id + ".") or not widget_id.startswith(watch_id + "."):
            raise ValueError("Nested identifiers must preserve the phone/watch/widget relationship.")
        if widget.get("NSExtension", {}).get("NSExtensionPointIdentifier") != "com.apple.widgetkit-extension":
            raise ValueError("The embedded extension is not a WidgetKit extension.")
        groups = {info.get("StressAppGroup") for info in (phone, watch, widget)}
        group = next(iter(groups), "")
        if len(groups) != 1 or not isinstance(group, str) or not group.startswith("group.") or "$" in group:
            raise ValueError("All three bundles must declare the same StressAppGroup.")

        for info_path, info in ((phone_files[0], phone), (watch_files[0], watch), (widget_files[0], widget)):
            executable = info.get("CFBundleExecutable")
            executable_path = info_path.removesuffix("Info.plist") + str(executable)
            if not executable or executable_path not in names:
                raise ValueError(f"Missing compiled executable for {info_path}.")
        for info in (phone, watch):
            if not info.get("NSHealthShareUsageDescription"):
                raise ValueError("A health-reading app is missing its permission description.")

        print(f"Package structure passed: {phone_id} -> {watch_id} -> {widget_id}")
        print("Signing, installation, HealthKit access, and face updates remain unverified.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa")
    args = parser.parse_args()
    try:
        validate(args.ipa)
    except (ValueError, KeyError, OSError, BadZipFile) as error:
        parser.exit(1, f"Package validation failed: {error}\n")

