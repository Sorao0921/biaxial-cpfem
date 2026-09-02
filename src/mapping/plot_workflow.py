from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable

from src.config.pipeline_paths import build_mapping_directories, build_post_directories
from src.mapping.orientation_metric_plot import plot_orientation_metric_layers
from src.mapping.plot_style import HEIGHT_RANGE
from src.mapping.shear_strain_plot import METRICS as SHEAR_METRICS
from src.mapping.shear_strain_plot import plot_shear_strain_layers
from src.mapping.surface_height_plot import plot_surface_height_contour


ORIENTATION_METRICS = ("ipf", "rotation", "gos")
PLOT_TYPES = ("height", "orientation", "shear")
MessageHandler = Callable[[str], None]


@dataclass(frozen=True)
class PlotSummary:
    saved: int = 0
    skipped: int = 0

    def __add__(self, other: "PlotSummary") -> "PlotSummary":
        return PlotSummary(
            saved=self.saved + other.saved,
            skipped=self.skipped + other.skipped,
        )


def _emit(handler: MessageHandler | None, message: str) -> None:
    if handler is not None:
        handler(message)


def _require_files(paths: Iterable[Path], message: str) -> None:
    missing = [path for path in paths if not path.is_file()]
    if missing:
        details = "\n".join(f"  {path}" for path in missing)
        raise FileNotFoundError(f"{message}\n{details}")


def plot_surface_heights(
    rho: float,
    seed: int,
    *,
    coordinates_csv: Path | None = None,
    output_dir: Path | None = None,
    levels: int = 30,
    cmap: str = "coolwarm",
    value_range: tuple[float, float] = HEIGHT_RANGE,
    dpi: int = 200,
    overwrite: bool = False,
    on_message: MessageHandler | None = None,
) -> PlotSummary:
    post = build_post_directories(rho, seed)
    if coordinates_csv is None:
        if not post.raw_coords_dir.is_dir():
            raise FileNotFoundError(
                f"Raw coordinate directory not found: {post.raw_coords_dir}"
            )
        csv_paths = sorted(post.raw_coords_dir.glob("*/coordinates_*.csv"))
    else:
        csv_paths = [Path(coordinates_csv)]
    if not csv_paths:
        raise FileNotFoundError(
            f"No coordinate CSV files found in: {post.raw_coords_dir}"
        )
    _require_files(csv_paths, "Coordinate CSV file(s) not found:")

    output_root = Path(output_dir) if output_dir else post.height_contours_dir
    summary = PlotSummary()
    for csv_path in csv_paths:
        target_dir = output_root if coordinates_csv else output_root / csv_path.parent.name
        target = target_dir / f"height_contour_{csv_path.stem}.png"
        try:
            saved = plot_surface_height_contour(
                csv_path,
                target,
                levels=levels,
                cmap=cmap,
                value_range=value_range,
                dpi=dpi,
                overwrite=overwrite,
            )
        except FileExistsError as error:
            summary += PlotSummary(skipped=1)
            _emit(on_message, f"[height: skip] {error}")
        else:
            summary += PlotSummary(saved=1)
            _emit(on_message, f"[height: saved] {saved}")
    return summary


def plot_orientation_metrics(
    rho: float,
    seed: int,
    *,
    metrics_csv: Path | None = None,
    spatial_model_dir: Path | None = None,
    output_dir: Path | None = None,
    metrics: tuple[str, ...] = ORIENTATION_METRICS,
    all_layers: bool = False,
    dpi: int = 200,
    overwrite: bool = False,
    on_message: MessageHandler | None = None,
) -> PlotSummary:
    unknown = set(metrics).difference(ORIENTATION_METRICS)
    if unknown:
        raise ValueError(f"Unknown orientation metric(s): {sorted(unknown)}")
    post = build_post_directories(rho, seed)
    spatial_dir = Path(spatial_model_dir) if spatial_model_dir else build_mapping_directories(seed).spatial_model_dir
    _require_files(
        (spatial_dir / "nodes.csv", spatial_dir / "elements.csv"),
        f"Spatial model for seed {seed} is incomplete. Missing:",
    )
    if metrics_csv is None:
        csv_paths = sorted(post.orientation_metrics_dir.glob("*/grain_metrics_*.csv"))
    else:
        csv_paths = [Path(metrics_csv)]
    if not csv_paths:
        raise FileNotFoundError(
            f"No grain-metrics CSV files found in: {post.orientation_metrics_dir}"
        )
    _require_files(csv_paths, "Grain-metrics CSV file(s) not found:")

    output_root = Path(output_dir) if output_dir else post.orientation_plots_dir
    summary = PlotSummary()
    for csv_path in csv_paths:
        target_dir = (
            output_root
            if metrics_csv
            else output_root / csv_path.parent.name / csv_path.stem
        )
        for metric in metrics:
            try:
                saved_paths = plot_orientation_metric_layers(
                    spatial_dir,
                    csv_path,
                    target_dir,
                    metric=metric,
                    all_layers=all_layers,
                    dpi=dpi,
                    overwrite=overwrite,
                )
            except FileExistsError as error:
                summary += PlotSummary(skipped=1)
                _emit(on_message, f"[orientation: skip] {csv_path.name} / {metric}: {error}")
            else:
                summary += PlotSummary(saved=len(saved_paths))
                for saved in saved_paths:
                    _emit(on_message, f"[orientation: saved] {saved}")
    return summary


def plot_shear_strains(
    rho: float,
    seed: int,
    *,
    shear_strain_csv: Path | None = None,
    spatial_model_dir: Path | None = None,
    output_dir: Path | None = None,
    metrics: tuple[str, ...] = SHEAR_METRICS,
    aggregation: str = "both",
    activity_threshold: float = 0.0,
    all_layers: bool = False,
    dpi: int = 200,
    overwrite: bool = False,
    on_message: MessageHandler | None = None,
) -> PlotSummary:
    unknown = set(metrics).difference(SHEAR_METRICS)
    if unknown:
        raise ValueError(f"Unknown shear-strain metric(s): {sorted(unknown)}")
    if aggregation not in {"element", "grain", "both"}:
        raise ValueError("aggregation must be one of: element, grain, both")
    post = build_post_directories(rho, seed)
    spatial_dir = Path(spatial_model_dir) if spatial_model_dir else build_mapping_directories(seed).spatial_model_dir
    _require_files(
        (spatial_dir / "nodes.csv", spatial_dir / "elements.csv"),
        f"Spatial model for seed {seed} is incomplete. Missing:",
    )
    if shear_strain_csv is None:
        csv_paths = sorted(post.id_set_shear_strain_dir.glob("*/*.csv"))
    else:
        csv_paths = [Path(shear_strain_csv)]
    if not csv_paths:
        raise FileNotFoundError(
            f"No shear-strain CSV files found in: {post.id_set_shear_strain_dir}"
        )
    _require_files(csv_paths, "Shear-strain CSV file(s) not found:")

    aggregations = ("element", "grain") if aggregation == "both" else (aggregation,)
    output_root = Path(output_dir) if output_dir else post.shear_strain_contours_dir
    summary = PlotSummary()
    for csv_path in csv_paths:
        target_dir = (
            output_root
            if shear_strain_csv
            else output_root / csv_path.parent.name / csv_path.stem
        )
        for metric in metrics:
            for aggregation_name in aggregations:
                try:
                    saved_paths = plot_shear_strain_layers(
                        spatial_dir,
                        csv_path,
                        target_dir,
                        metric=metric,
                        aggregation=aggregation_name,
                        activity_threshold=activity_threshold,
                        all_layers=all_layers,
                        dpi=dpi,
                        overwrite=overwrite,
                    )
                except FileExistsError as error:
                    summary += PlotSummary(skipped=1)
                    _emit(on_message, f"[shear: skip] {csv_path.name} / {metric} / {aggregation_name}: {error}")
                else:
                    summary += PlotSummary(saved=len(saved_paths))
                    for saved in saved_paths:
                        _emit(on_message, f"[shear: saved] {saved}")
    return summary


def plot_all_mapping_results(
    rho: float,
    seed: int,
    *,
    plot_types: tuple[str, ...] = PLOT_TYPES,
    orientation_metrics: tuple[str, ...] = ORIENTATION_METRICS,
    shear_metrics: tuple[str, ...] = SHEAR_METRICS,
    aggregation: str = "both",
    activity_threshold: float = 0.0,
    height_levels: int = 30,
    height_cmap: str = "coolwarm",
    height_value_range: tuple[float, float] = HEIGHT_RANGE,
    all_layers: bool = False,
    dpi: int = 200,
    overwrite: bool = False,
    on_message: MessageHandler | None = None,
) -> dict[str, PlotSummary]:
    unknown = set(plot_types).difference(PLOT_TYPES)
    if unknown:
        raise ValueError(f"Unknown plot type(s): {sorted(unknown)}")
    summaries: dict[str, PlotSummary] = {}
    if "height" in plot_types:
        summaries["height"] = plot_surface_heights(
            rho, seed, levels=height_levels, cmap=height_cmap,
            value_range=height_value_range, dpi=dpi, overwrite=overwrite,
            on_message=on_message,
        )
    if "orientation" in plot_types:
        summaries["orientation"] = plot_orientation_metrics(
            rho, seed, metrics=orientation_metrics, all_layers=all_layers,
            dpi=dpi, overwrite=overwrite, on_message=on_message,
        )
    if "shear" in plot_types:
        summaries["shear"] = plot_shear_strains(
            rho, seed, metrics=shear_metrics, aggregation=aggregation,
            activity_threshold=activity_threshold, all_layers=all_layers,
            dpi=dpi, overwrite=overwrite, on_message=on_message,
        )
    return summaries
