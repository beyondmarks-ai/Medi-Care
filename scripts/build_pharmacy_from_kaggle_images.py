#!/usr/bin/env python3
"""
Build `assets/data/pharmacy_catalog.csv` and copy images from an unzipped Kaggle image layout.

Why this exists
---------------
`TruMedicines-Pharmaceutical-images20k.dataset` in the project root is a **Microsoft
.NET / Azure ML** serialized `DataTable` (binary). Flutter cannot read it.

To use the TruMedicines / similar **image** datasets in the app:

1. On Kaggle, open the same dataset and download the ZIP (folders of images), not
   the .dataset file from another tool.
2. Unzip to a path like C:\\Data\\trumedicines so you have either
   train/CLASS_NAME/*.jpg   or   CLASS_NAME/*.jpg
3. Run this script with `--input` pointing to that folder.

The app loads CSV from `assets` and shows `image` paths via `Image.asset`; only
include as many images as you are willing to bundle (APK size).

Example
-------
  python scripts/build_pharmacy_from_kaggle_images.py ^
    --input "C:\\Data\\trumedicines_unzipped" --max-per-class 3 --max-total 300

Then add any new image files under `assets/images/pharmacy_pills/` to git if needed,
and run `flutter pub get` / full restart.
"""

from __future__ import annotations

import argparse
import csv
import re
import shutil
import sys
from pathlib import Path

IMAGE_EXT = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"}


def _list_image_files(class_dir: Path) -> list[Path]:
    out: list[Path] = []
    if not class_dir.is_dir():
        return out
    for p in sorted(class_dir.iterdir()):
        if p.is_file() and p.suffix.lower() in IMAGE_EXT:
            out.append(p)
    return out


def _discover_class_roots(root: Path) -> list[tuple[str, str, Path]]:
    """
    Yields (split, class_name, class_dir) where split may be 'train'|'test'|'valid' or 'flat'.
    """
    splits = ["train", "test", "valid", "Train", "Test", "Valid"]
    found: list[tuple[str, str, Path]] = []
    for sp in splits:
        base = root / sp
        if not base.is_dir():
            continue
        for d in sorted(base.iterdir()):
            if d.is_dir() and _list_image_files(d):
                found.append((sp.lower(), d.name, d))
    if found:
        return found
    for d in sorted(root.iterdir()):
        if d.is_dir() and _list_image_files(d):
            found.append(("catalog", d.name, d))
    return found


def _safe(s: str) -> str:
    s = re.sub(r"[^a-zA-Z0-9._-]+", "_", s.strip())[:80]
    return s or "item"


def main() -> int:
    ap = argparse.ArgumentParser(description="Kaggle image folders to medicare pharmacy CSV + assets")
    ap.add_argument(
        "--input",
        required=True,
        help="Unzipped dataset root (e.g. contains train/CLASS/ or CLASS/*.jpg)",
    )
    ap.add_argument(
        "--project-root",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
        help="Flutter project root (default: parent of scripts/)",
    )
    ap.add_argument("--max-per-class", type=int, default=4, help="Max images per class folder")
    ap.add_argument("--max-total", type=int, default=500, help="Max rows/images total")
    ap.add_argument(
        "--out-images",
        type=Path,
        default=None,
        help="Default: <project>/assets/images/pharmacy_pills",
    )
    ap.add_argument(
        "--out-csv",
        type=Path,
        default=None,
        help="Default: <project>/assets/data/pharmacy_catalog.csv",
    )
    ap.add_argument("--no-backup", action="store_true", help="Do not back up existing CSV")
    args = ap.parse_args()

    root = Path(args.input).resolve()
    if not root.is_dir():
        print(f"ERROR: --input is not a directory: {root}", file=sys.stderr)
        return 1

    project: Path = args.project_root
    out_img: Path = args.out_images or (project / "assets" / "images" / "pharmacy_pills")
    out_csv: Path = args.out_csv or (project / "assets" / "data" / "pharmacy_catalog.csv")

    out_img.mkdir(parents=True, exist_ok=True)

    rows: list[dict[str, str]] = []
    n = 0
    for split, class_name, class_dir in _discover_class_roots(root):
        if n >= args.max_total:
            break
        files = _list_image_files(class_dir)[: args.max_per_class]
        for fi, src in enumerate(files):
            if n >= args.max_total:
                break
            idx = n + 1
            ext = src.suffix.lower() or ".jpg"
            dest_name = f"p{idx:05d}_{_safe(class_name)}_{fi}{ext}"
            dest = out_img / dest_name
            shutil.copy2(src, dest)
            rel_asset = f"assets/images/pharmacy_pills/{dest_name}"
            display = class_name.replace("_", " ").replace("-", " ").strip() or f"Item {idx}"
            rows.append(
                {
                    "id": f"p{idx}",
                    "name": display,
                    "category": f"{split} / class",
                    "form": "Image sample",
                    "manufacturer": "",
                    "price": "",
                    "description": "Illustration from medicine-image dataset. Not medical advice. Verify with a pharmacist.",
                    "composition": class_name,
                    "pack_size": "1",
                    "image": rel_asset,
                }
            )
            n += 1

    if not rows:
        print(
            "ERROR: No images found. Expected e.g. input/train/CLASS_NAME/*.jpg or input/CLASS_NAME/*.jpg",
            file=sys.stderr,
        )
        return 1

    if out_csv.is_file() and not args.no_backup:
        bak = out_csv.with_suffix(out_csv.suffix + ".bak")
        shutil.copy2(out_csv, bak)
        print(f"Backed up previous catalog to {bak}")

    with out_csv.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(
            f,
            fieldnames=[
                "id",
                "name",
                "category",
                "form",
                "manufacturer",
                "price",
                "description",
                "composition",
                "pack_size",
                "image",
            ],
        )
        w.writeheader()
        w.writerows(rows)

    print(f"Wrote {len(rows)} rows to {out_csv}")
    print(f"Copied images to {out_img}")
    print("Ensure `pubspec.yaml` includes:")
    print("  - assets/images/pharmacy_pills/")
    print("Then: flutter pub get  (and full app restart, not only hot reload)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
