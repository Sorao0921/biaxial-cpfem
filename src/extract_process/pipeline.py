"""Command-line entry point for coordinate processing and ID enrichment."""

import argparse

from src.extract_process.coordinates import process_coordinates
from src.extract_process.id_enrichment import enrich_ids


def main(argv: list[str] | None = None, *, default_step: str = "edge") -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rho", type=float, required=True)
    parser.add_argument("--seed", type=int, required=True)
    parser.add_argument("--step", choices=("edge", "ids", "all"), default=default_step,
                        help="edge: drop coordinate edges; ids: enrich Euler/shear IDs; all: both")
    args = parser.parse_args(argv)
    if args.seed < 1:
        parser.error("--seed must be positive")
    if args.step in ("edge", "all"):
        process_coordinates(args.rho, args.seed)
    if args.step in ("ids", "all"):
        enrich_ids(args.rho, args.seed)


if __name__ == "__main__":
    main()
