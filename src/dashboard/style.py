"""Readable typography shared by all dashboard figures and PNG exports."""

TITLE_SIZE = 20
TICK_SIZE = 16
LABEL_SIZE = 17


def apply_figure_style(figure):
    for axis in figure.axes:
        for location in ("left", "center", "right"):
            title = axis.get_title(loc=location)
            if title:
                axis.set_title(title.replace(" | ", "\n"), loc=location,
                               fontsize=TITLE_SIZE, pad=18, linespacing=1.2)
        axis.tick_params(axis="both", which="both", labelsize=TICK_SIZE)
        for dimension in (axis.xaxis, axis.yaxis):
            dimension.label.set_fontsize(LABEL_SIZE)
            dimension.get_offset_text().set_fontsize(TICK_SIZE)
        legend = axis.get_legend()
        if legend is not None:
            for text in legend.get_texts():
                text.set_fontsize(TICK_SIZE)
    if figure._suptitle is not None:
        figure._suptitle.set_fontsize(TITLE_SIZE)
    return figure
