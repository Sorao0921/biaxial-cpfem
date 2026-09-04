from __future__ import annotations

import argparse
import json
from pathlib import Path

import pandas as pd
from tqdm.auto import tqdm

from src.config.pipeline_paths import OUTPUTS_DIR, SPATIAL_MODELS_DIR, THEME1_DIR
from src.dashboard.catalog import scan_outputs
from src.theme1.contribution import complete_cases
from src.theme1.graph_spectral import (
    load_grain_signals,
    load_surface_graph,
    reconstruct_bands,
    spectral_summary,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Decompose Theme 1 surface-grain signals into graph-frequency bands."
    )
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
    return parser


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
    graphs = {}
    energy_frames = []
    mode_frames = []
    signal_frames = []
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
        modes, energies = spectral_summary(graph, signals)
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
        signal_frames.append(signals)
        mode_frames.append(modes)
        energy_frames.append(energies)

    all_signals = pd.concat(signal_frames, ignore_index=True)
    all_modes = pd.concat(mode_frames, ignore_index=True)
    all_energies = pd.concat(energy_frames, ignore_index=True)
    all_signals.to_csv(args.output_dir / "grain_signals.csv", index=False)
    all_modes.to_csv(args.output_dir / "mode_coefficients.csv", index=False)
    all_energies.to_csv(args.output_dir / "band_energies.csv", index=False)
    diagnostics = {
        "cases": len(cases),
        "seeds": sorted(graphs),
        "graph_weight": args.weight,
        "laplacian": "symmetric normalized",
        "band_cutoffs": ["lambda_max/3", "2*lambda_max/3"],
        "height": "signed residual from the least-squares reference plane",
        "height_components": ["height_std", "height_mean_low", "height_mean_mid", "height_mean_high"],
        "signals": ["height_mean", "shear_mean", "grain_rotation", "gos"],
    }
    (args.output_dir / "diagnostics.json").write_text(
        json.dumps(diagnostics, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(diagnostics, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
