"""Smart Health-compliant Matplotlib figure export helpers.

Scientific charts and diagrams are exported as vector PDF primary artwork. PNG is
only a supplementary/fallback copy and follows the journal's raster categories:
300 dpi for photographs/continuous-tone images and 1,000 dpi for bitmap line art.
"""

from __future__ import annotations

import math
import struct
from pathlib import Path
from typing import Literal

import matplotlib as mpl
from matplotlib.figure import Figure


MIN_WIDTH_PX = {
    "photograph": {"single": 1063, "full": 2244},
    "line_drawing": {"single": 3543, "full": 7480},
}
MIN_DPI = {"photograph": 300, "line_drawing": 1000}

JOURNAL_RCPARAMS = {
    # Keep text editable while embedding TrueType fonts in PDF/EPS output.
    "pdf.fonttype": 42,
    "ps.fonttype": 42,
    "savefig.facecolor": "white",
    "savefig.edgecolor": "white",
    "savefig.transparent": False,
}


def configure_journal_artwork() -> None:
    """Apply font-embedding and opaque-background settings globally."""

    mpl.rcParams.update(JOURNAL_RCPARAMS)


def _tight_width_inches(fig: Figure, pad_inches: float) -> float:
    """Return the width that will remain after tight-bbox cropping."""

    fig.canvas.draw()
    renderer = fig.canvas.get_renderer()
    bbox = fig.get_tightbbox(renderer)
    return max(float(bbox.width) + 2 * pad_inches, 1e-6)


def _png_size(path: Path) -> tuple[int, int]:
    """Read PNG dimensions from the IHDR chunk without an extra dependency."""

    with path.open("rb") as stream:
        signature = stream.read(24)
    if signature[:8] != b"\x89PNG\r\n\x1a\n" or signature[12:16] != b"IHDR":
        raise ValueError(f"Not a valid PNG file: {path}")
    return struct.unpack(">II", signature[16:24])


def save_submission_figure(
    fig: Figure,
    output_stem: str | Path,
    *,
    raster_kind: Literal["photograph", "line_drawing"] = "line_drawing",
    column_width: Literal["single", "full"] = "full",
    write_png: bool = True,
    pad_inches: float = 0.02,
    write_eps: bool = False,
) -> dict[str, Path]:
    """Save primary vector PDF artwork and an optional compliant fallback PNG.

    Parameters
    ----------
    fig:
        Matplotlib figure to export.
    output_stem:
        Output path without an extension.
    raster_kind:
        Smart Health raster class for the optional PNG: ``photograph`` is 300 dpi;
        ``line_drawing`` is 1,000 dpi. Matplotlib charts and diagrams belong to the
        latter class if a PNG fallback is produced.
    column_width:
        Select the matching journal minimum pixel width after tight-bbox cropping.
    write_png:
        Write a supplementary/fallback PNG. The vector PDF is always written.
    pad_inches:
        White margin around the tight bounding box.
    write_eps:
        Also write EPS when specifically requested. PDF remains preferable for
        figures containing transparency.
    """

    configure_journal_artwork()
    stem = Path(output_stem)
    stem.parent.mkdir(parents=True, exist_ok=True)

    common = {"bbox_inches": "tight", "pad_inches": pad_inches, "facecolor": "white"}

    paths = {"pdf": stem.with_suffix(".pdf")}
    fig.savefig(paths["pdf"], **common)
    if write_eps:
        paths["eps"] = stem.with_suffix(".eps")
        fig.savefig(paths["eps"], **common)
    print(f"Saved primary artwork: {paths['pdf']} (vector PDF; TrueType fonts embedded)")

    if write_png:
        min_width_px = MIN_WIDTH_PX[raster_kind][column_width]
        tight_width = _tight_width_inches(fig, pad_inches)
        effective_dpi = max(MIN_DPI[raster_kind], math.ceil(min_width_px / tight_width))
        paths["png"] = stem.with_suffix(".png")
        fig.savefig(paths["png"], dpi=effective_dpi, **common)

        width, height = _png_size(paths["png"])
        if width < min_width_px:
            raise RuntimeError(
                f"PNG width check failed for {paths['png']}: {width} < {min_width_px} px"
            )
        print(
            f"Saved fallback: {paths['png']} ({raster_kind}; "
            f"{width} x {height} px; {effective_dpi} dpi)"
        )
    return paths
