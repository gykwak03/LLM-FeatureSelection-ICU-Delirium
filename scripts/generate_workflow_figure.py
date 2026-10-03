"""Generate manuscript Figure 1 as native vector artwork."""

from __future__ import annotations

from pathlib import Path
import sys

import matplotlib.pyplot as plt
from matplotlib.patches import Circle, FancyArrowPatch, Polygon, Rectangle


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.figure_export import configure_journal_artwork, save_submission_figure


configure_journal_artwork()

INK = "#111111"
MID = "#333333"
LIGHT = "#e8e8e8"
SOFT = "#f5f5f5"


def add_rect(ax, x, y, width, height, *, fill="white", lw=1.0, dashed=False):
    patch = Rectangle(
        (x, y),
        width,
        height,
        facecolor=fill,
        edgecolor=INK,
        linewidth=lw,
        linestyle=(0, (5, 4)) if dashed else "solid",
    )
    ax.add_patch(patch)
    return patch


def add_text(ax, x, y, text, *, size=8.2, weight="normal", color=INK, ha="center"):
    ax.text(
        x,
        y,
        text,
        ha=ha,
        va="center",
        fontsize=size,
        fontweight=weight,
        color=color,
        fontfamily="DejaVu Sans",
    )


def add_arrow(ax, start, end):
    ax.add_patch(
        FancyArrowPatch(
            start,
            end,
            arrowstyle="-|>",
            mutation_scale=8,
            linewidth=1.0,
            color=INK,
            shrinkA=0,
            shrinkB=0,
        )
    )


def add_bullet(ax, x, y, text, *, second_line=None):
    ax.add_patch(Circle((x, y), 6, facecolor=INK, edgecolor="none"))
    add_text(ax, x + 28, y, text, size=7.4, weight="bold", ha="left")
    if second_line:
        add_text(ax, x + 28, y + 38, second_line, size=7.4, weight="bold", ha="left")


fig, ax = plt.subplots(figsize=(7.0, 9.025))
ax.set_xlim(0, 1400)
ax.set_ylim(1805, 0)
ax.axis("off")

# Literature-derived feature pool.
add_rect(ax, 300, 45, 800, 145)
add_text(ax, 700, 100, "Published ICU delirium prediction studies", size=10.2, weight="bold")
add_text(ax, 700, 145, "11 PubMed-indexed studies · 221 reported feature labels", size=8.3)
add_arrow(ax, (700, 190), (700, 235))

add_rect(ax, 105, 245, 1190, 265)
add_rect(ax, 105, 245, 1190, 65, fill=LIGHT)
add_text(ax, 700, 278, "Feature-pool construction", size=9.3, weight="bold")
add_rect(ax, 185, 340, 465, 120, fill=SOFT, lw=0.9)
add_text(ax, 417.5, 387, "Identity rule", size=8.7, weight="bold")
add_text(ax, 417.5, 426, "Merge labels denoting the same quantity", size=7.2)
add_rect(ax, 750, 340, 465, 120, fill=SOFT, lw=0.9)
add_text(ax, 982.5, 387, "Determinacy rule", size=8.7, weight="bold")
add_text(ax, 982.5, 426, "Retain features ascertainable at 24 hours", size=7.2)

add_arrow(ax, (700, 510), (700, 555))
ax.add_patch(
    Polygon(
        [(390, 565), (1010, 565), (970, 660), (350, 660)],
        closed=True,
        facecolor="white",
        edgecolor=INK,
        linewidth=1.0,
    )
)
add_text(ax, 680, 615, "107 candidate clinical features", size=10.7, weight="bold")
add_arrow(ax, (680, 660), (680, 705))

# LLM procedures.
add_rect(ax, 60, 715, 1280, 395, dashed=True)
add_text(ax, 700, 760, "LLM-based feature prioritisation", size=10.7, weight="bold")
add_text(ax, 700, 825, "Models", size=9.3, weight="bold")
for x, name in ((115, "GPT-4.1"), (527, "Claude Sonnet 4.5"), (940, "Gemini 2.5 Pro")):
    add_rect(ax, x, 860, 345, 72)
    add_text(ax, x + 172.5, 896, name, size=8.2)
add_text(ax, 700, 975, "Feature-selection procedures", size=9.3, weight="bold")
for x, name in ((115, "Scoring"), (415, "Ranking"), (715, "Sequencing")):
    add_rect(ax, x, 1015, 270, 76)
    add_text(ax, x + 135, 1053, name, size=8.2)
add_rect(ax, 1015, 1015, 270, 76)
add_text(ax, 1150, 1040, "Log-prior scoring", size=7.4)
add_text(ax, 1150, 1068, "(GPT-4.1 only)", size=7.2)

# Run-specific and aggregate outputs.
ax.plot([700, 700], [1110, 1150], color=INK, lw=1.0)
ax.plot([370, 1030], [1150, 1150], color=INK, lw=1.0)
add_arrow(ax, (370, 1150), (370, 1190))
add_arrow(ax, (1030, 1150), (1030, 1190))
add_rect(ax, 120, 1200, 500, 100)
add_text(ax, 370, 1250, "Run-specific rankings", size=9.0, weight="bold")
add_rect(ax, 780, 1200, 500, 100)
add_text(ax, 1030, 1250, "Five-run aggregated rankings", size=9.0, weight="bold")
ax.plot([370, 370, 1030, 1030], [1300, 1340, 1340, 1300], color=INK, lw=1.0)
ax.plot([700, 700], [1340, 1370], color=INK, lw=1.0)
ax.plot([350, 1050], [1370, 1370], color=INK, lw=1.0)
add_arrow(ax, (350, 1370), (350, 1415))
add_arrow(ax, (1050, 1370), (1050, 1415))

# Analysis branches.
add_rect(ax, 55, 1425, 590, 350)
add_rect(ax, 55, 1425, 590, 70, fill=LIGHT)
add_text(ax, 350, 1460, "Ranking reproducibility", size=9.2, weight="bold")
add_bullet(ax, 92, 1577, "Mean rank SD across five runs")
add_bullet(
    ax,
    92,
    1690,
    "Kendall τ-b within and across",
    second_line="model–procedure combinations",
)

add_rect(ax, 755, 1425, 590, 350)
add_rect(ax, 755, 1425, 590, 70, fill=LIGHT)
add_text(ax, 1050, 1460, "Downstream predictive utility", size=9.2, weight="bold")
add_bullet(ax, 792, 1548, "Run-level stability")
add_bullet(ax, 792, 1638, "Performance across feature budgets")
add_bullet(
    ax,
    792,
    1715,
    "Performance across LLM procedures",
    second_line="and data-driven selectors",
)

fig.subplots_adjust(left=0.01, right=0.99, bottom=0.01, top=0.99)
save_submission_figure(
    fig,
    ROOT / "figures" / "Figure1_workflow",
    raster_kind="line_drawing",
    column_width="full",
)
plt.close(fig)
