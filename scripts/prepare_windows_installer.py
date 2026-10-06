"""Prepare pinned community iLoader sources for WatchStress's shared cache."""
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

ILOADER_REV = "70f37e9b4afc659ab44ec1944c034093f4cda416"
ISIDELOAD_REV = "f7b9f3da570edd6824c29680545e710846d07df5"


def prepare(iloader: Path, isideload: Path) -> None:
    for source, revision in ((iloader, ILOADER_REV), (isideload, ISIDELOAD_REV)):
        actual = subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip()
        if actual != revision:
            raise ValueError(f"Unexpected upstream revision in {source.name}.")
    patch = Path(__file__).with_name("watchstress-isideload.patch").resolve()
    subprocess.run(["git", "-C", str(isideload), "apply", "--check", str(patch)], check=True)
    subprocess.run(["git", "-C", str(isideload), "apply", str(patch)], check=True)

    manifest = iloader / "src-tauri" / "Cargo.toml"
    text = manifest.read_text(encoding="utf-8")
    dependency = ('isideload = { version = "0.3.17", features = ["fs-storage"], '
                  'git = "https://github.com/Rzbck/isideload", package = "isideload", '
                  f'rev = "{ISIDELOAD_REV}" }}')
    if text.count(dependency) != 1:
        raise ValueError("Pinned iLoader dependency no longer matches the expected source.")
    local_path = (isideload / "isideload").resolve().as_posix()
    manifest.write_text(text.replace(dependency, f'isideload = {{ path = "{local_path}", features = ["fs-storage"] }}'), encoding="utf-8")

    config_path = iloader / "src-tauri" / "tauri.conf.json"
    config = json.loads(config_path.read_text(encoding="utf-8"))
    config["productName"] = "WatchStress Installer"
    config["identifier"] = "com.personal.watchstress.installer"
    config["app"]["windows"][0]["title"] = "WatchStress Installer (experimental)"
    config["bundle"]["createUpdaterArtifacts"] = False
    config_path.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Pinned community sources patched. No Apple credentials are used during this build.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("iloader", type=Path)
    parser.add_argument("isideload", type=Path)
    args = parser.parse_args()
    prepare(args.iloader, args.isideload)
