from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path

import numpy as np

from src.config.pipeline_paths import build_pre_directories
from src.crystal_plasticity.voro_seeds import voro_seeds
from src.crystal_plasticity.voro_seeds_to_mesh import voro_seeds_to_mesh
from src.pre_process.mesh import mesh

# ============================================================
# Case settings
# Change SEED to select another post-processing directory.
# ============================================================
SEED = 1


# ===========================================================
# Do not change below this line unless you have to.
# ===========================================================
@dataclass(frozen=True)
class VoroSeedConfig:
    """Configuration for Voronoi seed generation."""

    grain_size: tuple[float, float, float] = (0.02, 0.015, 0.01)


# Module-level default to avoid calling VoroSeedConfig() at function definition time
DEFAULT_VOROSEED_CONFIG = VoroSeedConfig()


def make_partset(
    initmesh_k: Path,
    out_partset_k: Path,
    config: VoroSeedConfig | None = None,
    *,
    seed: int = SEED,
    overwrite: bool = False,
) -> Path:
    """Create a partset keyword deck (element->grain/part assignment) from initmesh.k."""

    initmesh_k = Path(initmesh_k)
    out_partset_k = Path(out_partset_k)

    metadata_path = out_partset_k.with_suffix(".json")

    if not initmesh_k.exists():
        raise FileNotFoundError(f"initmesh.k not found: {initmesh_k}")

    existing_outputs = [
        path for path in (out_partset_k, metadata_path) if path.exists()
    ]
    if existing_outputs and not overwrite:
        existing_text = "\n".join(f" - {path}" for path in existing_outputs)
        raise FileExistsError(
            "The following output already exists.\n"
            "Generation was stopped to prevent accidental overwrite.\n"
            f"{existing_text}\n"
            "Use --overwrite only when replacement is intentional."
        )

    if config is None:
        config = DEFAULT_VOROSEED_CONFIG

    out_partset_k.parent.mkdir(parents=True, exist_ok=True)

    np.random.seed(seed)

    model = mesh(str(initmesh_k))

    # Some project versions expect array-like input; make scalar elem_id work.
    _orig_ret = model.ret_elem_center_pos

    def _ret_elem_center_pos(elem_id):
        if np.isscalar(elem_id):
            xs, ys, zs = _orig_ret(np.array([elem_id], dtype=int))
            return float(xs[0]), float(ys[0]), float(zs[0])
        return _orig_ret(elem_id)

    model.ret_elem_center_pos = _ret_elem_center_pos

    voro_obj = voro_seeds()
    voro_obj.init_region_box(
        (np.max(model.node_set.x_array) - np.min(model.node_set.x_array)),
        (np.max(model.node_set.y_array) - np.min(model.node_set.y_array)),
        (np.max(model.node_set.z_array) - np.min(model.node_set.z_array)),
    )

    voro_obj.generate_seeds(list(config.grain_size))
    voro_seeds_to_mesh(voro_obj, model)

    model.write_keyword(str(out_partset_k))

    metadata = {
        "seed": seed,
        "initmesh_k": str(initmesh_k.resolve()),
        "partset_k": str(out_partset_k.resolve()),
    }

    metadata_path.write_text(
        json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    return out_partset_k


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""

    parser = argparse.ArgumentParser(
        description=(
            "Generate partset_seed{seed}.k using paths defined in pipeline_paths.py."
        )
    )

    parser.add_argument(
        "--seed",
        type=int,
        default=SEED,
        help=(
            "Seed number used both for random generation and for "
            "the partset_seed{seed}.k output path "
            f"(default: {SEED})."
        ),
    )

    parser.add_argument(
        "--overwrite",
        action="store_true",
        help=(
            "Allow replacement of an existing partset keyword "
            "and its metadata JSON file."
        ),
    )

    return parser.parse_args()


def main() -> None:
    """Generate a partset using the common pipeline paths."""

    args = parse_args()

    pre_dirs = build_pre_directories(
        seed=args.seed,
    )

    output_path = make_partset(
        initmesh_k=pre_dirs.initmesh,
        out_partset_k=pre_dirs.partset,
        seed=args.seed,
        overwrite=args.overwrite,
    )

    metadata_path = output_path.with_suffix(output_path.suffix + ".json")

    print("Partset generation completed.")
    print(f"  random seed : {args.seed}")
    print(f"  initmesh    : {pre_dirs.initmesh}")
    print(f"  partset     : {output_path}")
    print(f"  metadata    : {metadata_path}")


if __name__ == "__main__":
    main()
    main()
    main()
