"""Combine rendered map PNGs into a slide-ready grid."""
from io import BytesIO
from PIL import Image


def combine_map_pngs(images: list[bytes], columns: int, *, dpi: int = 200) -> bytes:
    """Preserve panel resolution and order; use white, equally sized grid cells."""
    if not images or columns < 1:
        raise ValueError("At least one image and a positive column count are required")
    panels = []
    for data in images:
        with Image.open(BytesIO(data)) as source:
            panel = Image.new("RGB", source.size, "white")
            rgba = source.convert("RGBA")
            panel.paste(rgba, mask=rgba.getchannel("A"))
            panels.append(panel)
    columns = min(columns, len(panels))
    width = max(panel.width for panel in panels)
    height = max(panel.height for panel in panels)
    gap = max(1, round(dpi * 0.08))
    rows = (len(panels) + columns - 1) // columns
    canvas = Image.new("RGB", (columns * width + (columns - 1) * gap,
                                rows * height + (rows - 1) * gap), "white")
    for index, panel in enumerate(panels):
        row, column = divmod(index, columns)
        canvas.paste(panel, (column * (width + gap) + (width - panel.width) // 2,
                            row * (height + gap)))
    output = BytesIO()
    canvas.save(output, format="PNG", dpi=(dpi, dpi))
    return output.getvalue()


def map_png_name(metric, record, *, initial=False):
    """Name a map by its metric and complete simulation case."""
    state = 1 if initial else record.state
    interval = f"_from_state{state-1:02d}" if metric.startswith("z_slip_activity") and state > 1 else ""
    selection = f"_view_state{record.state:02d}" if initial and record.state != 1 else ""
    return (f"{metric}_rho{record.rho:g}_seed{record.seed}_{record.texture}"
            f"_sd{record.sd}_state{state:02d}{interval}{selection}.png")


def combined_png_name(metric, records):
    """List every distinct comparison value without hiding gaps in state selections."""
    parts = [metric]
    for field in ("rho", "seed", "texture", "sd", "state"):
        values = sorted({getattr(record, field) for record in records})
        encoded = [str(value) if isinstance(value, str) else
                   (f"{value:02d}" if field == "state" else f"{value:g}")
                   for value in values]
        parts.append(field + "-".join(encoded))
    return "_".join(parts) + ".png"
