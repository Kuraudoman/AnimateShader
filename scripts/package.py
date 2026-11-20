#!/usr/bin/env python3
"""
Package AnimateShader into a ready-to-drop Minecraft Iris/OptiFine .zip shader pack.
"""

import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHADERS_DIR = ROOT / "shaders"
OUT_ZIP = ROOT / "dist" / "AnimateShader-v1.0.6-mc26.3.zip"


def main():
    OUT_ZIP.parent.mkdir(parents=True, exist_ok=True)
    count = 0
    with zipfile.ZipFile(OUT_ZIP, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for path in sorted(SHADERS_DIR.rglob("*")):
            if path.is_file():
                rel = path.relative_to(ROOT)
                zf.write(path, arcname=str(rel))
                count += 1
        # Include LICENSE at zip root
        lic = ROOT / "LICENSE"
        if lic.exists():
            zf.write(lic, arcname="LICENSE")
    size_kb = OUT_ZIP.stat().st_size / 1024.0
    print(f"Packaged {count} shader files -> {OUT_ZIP} ({size_kb:.1f} KiB)")


if __name__ == "__main__":
    main()
