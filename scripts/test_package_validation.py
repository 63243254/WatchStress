"""Exercise installation-breaking bundle graph failures, not real device signing."""
import contextlib
import copy
import io
import plistlib
import tempfile
import unittest
from pathlib import Path
from zipfile import ZipFile

from validate_ipa import validate


class BundleGraphTests(unittest.TestCase):
    def setUp(self):
        group = "group.com.personal.watchstress"
        self.phone_dir = "Payload/Phone.app/"
        self.watch_dir = self.phone_dir + "Watch/Watch.app/"
        self.widget_dir = self.watch_dir + "PlugIns/Face.appex/"
        self.bundles = {
            self.phone_dir: {
                "CFBundleIdentifier": "com.personal.watchstress",
                "CFBundleExecutable": "Phone",
                "NSHealthShareUsageDescription": "Read HRV",
                "StressAppGroup": group,
            },
            self.watch_dir: {
                "CFBundleIdentifier": "com.personal.watchstress.watchkitapp",
                "CFBundleExecutable": "Watch",
                "NSHealthShareUsageDescription": "Read HRV",
                "WKCompanionAppBundleIdentifier": "com.personal.watchstress",
                "WKApplication": True,
                "StressAppGroup": group,
            },
            self.widget_dir: {
                "CFBundleIdentifier": "com.personal.watchstress.watchkitapp.complication",
                "CFBundleExecutable": "Face",
                "NSExtension": {"NSExtensionPointIdentifier": "com.apple.widgetkit-extension"},
                "StressAppGroup": group,
            },
        }

    def check(self, bundles, omit_executable=None):
        with tempfile.TemporaryDirectory(prefix="watchstress-package-test-") as temporary:
            path = Path(temporary) / "fixture.ipa"
            with ZipFile(path, "w") as archive:
                for directory, info in bundles.items():
                    archive.writestr(directory + "Info.plist", plistlib.dumps(info))
                    if directory != omit_executable:
                        # Deliberately a structural fixture, not a compiled executable.
                        archive.writestr(directory + info["CFBundleExecutable"], b"fixture")
            with contextlib.redirect_stdout(io.StringIO()):
                validate(str(path))

    def testAcceptsCompleteBundleGraph(self):
        self.check(self.bundles)

    def testRejectsPhoneOnlyPackage(self):
        with self.assertRaisesRegex(ValueError, "Watch companion"):
            self.check({self.phone_dir: self.bundles[self.phone_dir]})

    def testRejectsBrokenCompanionRelationship(self):
        bundles = copy.deepcopy(self.bundles)
        bundles[self.watch_dir]["WKCompanionAppBundleIdentifier"] = "com.another.phone"
        with self.assertRaisesRegex(ValueError, "does not match"):
            self.check(bundles)

    def testRejectsMissingComplication(self):
        bundles = copy.deepcopy(self.bundles)
        del bundles[self.widget_dir]
        with self.assertRaisesRegex(ValueError, "complication"):
            self.check(bundles)

    def testRejectsMismatchedAppGroup(self):
        bundles = copy.deepcopy(self.bundles)
        bundles[self.widget_dir]["StressAppGroup"] = "group.com.another.app"
        with self.assertRaisesRegex(ValueError, "StressAppGroup"):
            self.check(bundles)

    def testRejectsMissingWatchExecutable(self):
        with self.assertRaisesRegex(ValueError, "Missing compiled executable"):
            self.check(self.bundles, omit_executable=self.watch_dir)


if __name__ == "__main__":
    unittest.main()

