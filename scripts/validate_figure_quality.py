"""Validate final manuscript artwork against the journal export requirements."""

from __future__ import annotations

import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIGURE_DIR = ROOT / "figures"
FULL_PAGE_MIN_WIDTH_PX = 7480
MIN_RASTER_DPI = 1000
EXPECTED_FIGURES = {
    "Figure1_workflow",
    "Figure2_cohort_flow",
    "Figure3_kendall_agreement",
    "Figure4_feature_budget",
    "Figure5_k30_forest",
}
EDITABLE_CHART_DATA = {
    "Figure3_kendall_agreement",
    "Figure4_feature_budget",
    "Figure5_k30_forest",
}


def read_png_metadata(path: Path) -> tuple[int, int, float | None, float | None]:
    """Return width, height, and optional x/y dpi from PNG chunks."""

    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("invalid PNG signature")
    width, height = struct.unpack(">II", data[16:24])

    offset = 8
    dpi_x = dpi_y = None
    while offset + 12 <= len(data):
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        chunk_type = data[offset + 4 : offset + 8]
        chunk = data[offset + 8 : offset + 8 + length]
        if chunk_type == b"pHYs" and len(chunk) == 9 and chunk[8] == 1:
            pixels_per_metre_x, pixels_per_metre_y = struct.unpack(">II", chunk[:8])
            dpi_x = pixels_per_metre_x * 0.0254
            dpi_y = pixels_per_metre_y * 0.0254
            break
        offset += 12 + length
    return width, height, dpi_x, dpi_y


errors: list[str] = []
png_paths = sorted(FIGURE_DIR.glob("Figure*.png"))
if not png_paths:
    errors.append("no Figure*.png files found")
found_stems = {path.stem for path in png_paths}
if found_stems != EXPECTED_FIGURES:
    missing = sorted(EXPECTED_FIGURES - found_stems)
    unexpected = sorted(found_stems - EXPECTED_FIGURES)
    if missing:
        errors.append(f"missing final figures: {', '.join(missing)}")
    if unexpected:
        errors.append(f"unexpected/legacy figures: {', '.join(unexpected)}")

for png_path in png_paths:
    try:
        width, height, dpi_x, dpi_y = read_png_metadata(png_path)
    except (OSError, ValueError, struct.error) as exc:
        errors.append(f"{png_path.name}: {exc}")
        continue

    pdf_path = png_path.with_suffix(".pdf")
    pdf_data = pdf_path.read_bytes() if pdf_path.exists() else b""
    if not pdf_data.startswith(b"%PDF-"):
        errors.append(f"{png_path.name}: matching valid PDF is missing")
    else:
        if b"/Subtype /Image" in pdf_data:
            errors.append(f"{pdf_path.name}: contains raster image objects")
        font_objects = pdf_data.count(b"/Type /Font")
        embedded_font_streams = pdf_data.count(b"/FontFile2") + pdf_data.count(
            b"/FontFile3"
        )
        if font_objects and not embedded_font_streams:
            errors.append(f"{pdf_path.name}: fonts are present but not embedded")
    if width < FULL_PAGE_MIN_WIDTH_PX:
        errors.append(
            f"{png_path.name}: bitmap-line-art width {width} px is below "
            f"{FULL_PAGE_MIN_WIDTH_PX} px"
        )
    if dpi_x is None or dpi_y is None:
        errors.append(f"{png_path.name}: physical dpi metadata is missing")
    elif min(dpi_x, dpi_y) + 0.1 < MIN_RASTER_DPI:
        errors.append(
            f"{png_path.name}: dpi {dpi_x:.1f} x {dpi_y:.1f} is below {MIN_RASTER_DPI}"
        )
    print(
        f"{png_path.name}: {width} x {height} px; "
        f"dpi={dpi_x:.1f} x {dpi_y:.1f}; "
        f"PDF={'vector + embedded fonts' if pdf_data else 'missing'}"
    )

for stem in sorted(EDITABLE_CHART_DATA):
    workbook = FIGURE_DIR / f"{stem}.xlsx"
    if not workbook.exists():
        errors.append(f"{workbook.name}: editable chart data are missing")

if errors:
    print("FIGURE QUALITY CHECK FAILED")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("FIGURE QUALITY CHECK PASSED")
