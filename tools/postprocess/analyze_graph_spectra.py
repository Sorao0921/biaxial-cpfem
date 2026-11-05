from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

import pandas as pd
from tqdm.auto import tqdm

from src.config.pipeline_paths import OUTPUTS_DIR, SPATIAL_MODELS_DIR, THEME1_DIR
from src.dashboard.catalog import scan_outputs
from src.postprocess.case_data import complete_cases
from src.postprocess.graph_spectral import (
    load_grain_signals,
    load_surface_graph,
    reconstruct_bands,
    spectral_summary,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Decompose Theme 1 surface-grain signals into graph-frequency bands."
    )
    parser.add_argument("--resume", action="store_true",
                        help="Preserve existing CSV rows and calculate only missing cases.")
    parser.add_argument("--outputs", type=Path, default=OUTPUTS_DIR)
    parser.add_argument("--spatial-models", type=Path, default=SPATIAL_MODELS_DIR)
    parser.add_argument("--output-dir", type=Path, default=THEME1_DIR / "graph_spectra")
    parser.add_argument(
        "--weight",
        choices=("binary", "boundary_length", "boundary_length_over_distance"),
        default="boundary_length_over_distance",
    )
    parser.add_argument("--rho", type=float)
    parser.add_argument("--seed", type=int)
    parser.add_argument("--texture")
    parser.add_argument("--sd", type=int)
    parser.add_argument("--state", type=int)
    parser.add_argument(
        "--skip-mode-coefficients",
        action="store_true",
        help="Skip the large per-mode CSV; band energies and reconstructed signals are still written.",
    )
    return parser


def _append_csv(frame: pd.DataFrame, path: Path, *, first: bool) -> None:
    frame.to_csv(path, mode="w" if first else "a", header=first, index=False)


def _case_ids(path: Path) -> set[str]:
    if not path.is_file():
        return set()
    result: set[str] = set()
    for chunk in pd.read_csv(path, usecols=["case_id"], chunksize=100_000):
        result.update(chunk["case_id"].astype(str))
    return result


def _complete_energy_ids(path: Path) -> set[str]:
    if not path.is_file():
        return set()
    expected = {(signal, band) for signal in
                ("height_mean", "shear_mean", "grain_rotation", "gos")
                for band in ("low", "mid", "high")}
    rows: dict[str, list[tuple[str, str]]] = {}
    for chunk in pd.read_csv(path, usecols=["case_id", "signal", "band"], chunksize=100_000):
        for case_id, signal, band in chunk.itertuples(index=False, name=None):
            rows.setdefault(case_id, []).append((signal, band))
    return {key for key, values in rows.items() if len(values) == 12 and set(values) == expected}


def _copy_existing(source: Path, target: Path, replace_ids: set[str]) -> bool:
    """Stream preserved rows into staging, dropping cases being repaired."""
    written = False
    if source.is_file():
        for chunk in pd.read_csv(source, chunksize=100_000):
            chunk = chunk.loc[~chunk["case_id"].isin(replace_ids)]
            _append_csv(chunk, target, first=not written)
            written = True
    return written


def main() -> int:
    args = build_parser().parse_args()
    cases = complete_cases(
        scan_outputs(args.outputs, prefer_raw_height=True), args.spatial_models
    )
    for field in ("rho", "seed", "texture", "sd", "state"):
        value = getattr(args, field)
        if value is not None:
            cases = [case for case in cases if getattr(case, field) == value]
    if not cases:
        raise SystemExit("No cases found for the given arguments.")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    diagnostics_path = args.output_dir / "diagnostics.json"
    previous = {}
    if args.resume and diagnostics_path.is_file():
        previous = json.loads(diagnostics_path.read_text(encoding="utf-8"))
        if previous.get("graph_weight") != args.weight:
            raise SystemExit("Existing graph weight differs; use a separate --output-dir.")
    graphs = {}
    final_paths = {
        "signals": args.output_dir / "grain_signals.csv",
        "modes": args.output_dir / "mode_coefficients.csv",
        "energies": args.output_dir / "band_energies.csv",
    }
    active_names = ["signals", "energies"]
    if not args.skip_mode_coefficients:
        active_names.append("modes")
    existing_ids = {name: _case_ids(final_paths[name]) for name in active_names} if args.resume else {}
    completed = set.intersection(*existing_ids.values()) if existing_ids else set()
    if args.resume:
        completed &= _complete_energy_ids(final_paths["energies"])
    cases = [case for case in cases if case.case_id not in completed]
    if not cases:
        print("All selected cases are already calculated; no files changed.")
        return 0
    replace_ids = {case.case_id for case in cases}
    partial_paths = {
        name: path.with_name(f".{path.name}.partial")
        for name, path in final_paths.items()
    }
    for path in partial_paths.values():
        path.unlink(missing_ok=True)

    written = {name: False for name in active_names}
    if args.resume:
        for name in active_names:
            written[name] = _copy_existing(final_paths[name], partial_paths[name], replace_ids)

    for case in tqdm(cases, desc="Theme 1 graph spectra", unit="case", dynamic_ncols=True):
        graph = graphs.get(case.seed)
        if graph is None:
            graph = load_surface_graph(case.spatial_model_dir, weight=args.weight)
            graphs[case.seed] = graph
            seed_dir = args.output_dir / "graphs" / f"seed{case.seed}"
            seed_dir.mkdir(parents=True, exist_ok=True)
            graph.node_table.to_csv(seed_dir / "nodes.csv", index=False)
            graph.edge_table.to_csv(seed_dir / "edges.csv", index=False)
            pd.DataFrame(
                {
                    "mode": range(len(graph.eigenvalues)),
                    "eigenvalue": graph.eigenvalues,
                }
            ).to_csv(seed_dir / "eigenvalues.csv", index=False)

        signals = load_grain_signals(case, graph)
        modes, energies = spectral_summary(
            graph, signals, include_modes=not args.skip_mode_coefficients
        )
        indexed = signals.set_index("part_id").reindex(graph.node_ids)
        for signal_name in ("height_mean", "shear_mean", "grain_rotation", "gos"):
            components = reconstruct_bands(
                graph, indexed[signal_name].to_numpy(float)
            )
            for band, values in components.items():
                signals[f"{signal_name}_{band}"] = values
        signals["height_intragranular_energy"] = (
            signals["height_std"] ** 2 * signals["height_elements"]
        )
        metadata = {
            "case_id": case.case_id,
            "rho": case.rho,
            "seed": case.seed,
            "texture": case.texture,
            "sd": case.sd,
            "state": case.state,
        }
        for frame in (signals, modes, energies):
            for column, value in reversed(tuple(metadata.items())):
                frame.insert(0, column, value)
        frames = {"signals": signals, "energies": energies, "modes": modes}
        for name in active_names:
            _append_csv(frames[name], partial_paths[name], first=not written[name])
            written[name] = True

    os.replace(partial_paths["signals"], final_paths["signals"])
    os.replace(partial_paths["energies"], final_paths["energies"])
    if args.skip_mode_coefficients:
        if not args.resume:
            final_paths["modes"].unlink(missing_ok=True)
    else:
        os.replace(partial_paths["modes"], final_paths["modes"])
    diagnostics = {
        "cases": len(_case_ids(final_paths["energies"])),
        "cases_calculated": len(cases),
        "resume": args.resume,
        "seeds": sorted(set(previous.get("seeds", [])) | set(graphs)),
        "graph_weight": args.weight,
        "laplacian": "symmetric normalized",
        "band_cutoffs": ["lambda_max/3", "2*lambda_max/3"],
        "height": "signed residual from the least-squares reference plane",
        "height_components": ["height_std", "height_mean_low", "height_mean_mid", "height_mean_high"],
        "signals": ["height_mean", "shear_mean", "grain_rotation", "gos"],
        "mode_coefficients_written": not args.skip_mode_coefficients,
        "result_writing": "incremental",
    }
    (args.output_dir / "diagnostics.json").write_text(
        json.dumps(diagnostics, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(diagnostics, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
