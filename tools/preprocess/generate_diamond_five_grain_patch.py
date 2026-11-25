"""Generate the diamond five-grain LS-DYNA model."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

if not __package__:
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from src.config.pipeline_paths import INPUTS_DIR, MODELS_DIR
from src.make_model_process.diamond_five_grain import write_diamond_model

CONSTS_DIR = INPUTS_DIR / "keywords_diamond" / "consts"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=MODELS_DIR / "diamond_models")
    parser.add_argument("--central-diagonal", type=float, default=0.015, help="mm")
    args = parser.parse_args()

    output = args.output_dir / "diamond_center_5grains.k"
    try:
        write_diamond_model(
            CONSTS_DIR / "initmesh_diamond.k",
            CONSTS_DIR / "section.k",
            output,
            central_diagonal=args.central_diagonal,
        )
    except ValueError as exc:
        parser.error(str(exc))
    print(f"Wrote {output}")


if __name__ == "__main__":
    main()
