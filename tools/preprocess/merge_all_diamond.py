"""Merge user-supplied diamond keyword files, in the macro workflow's two stages."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import sys
from functools import lru_cache

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from src.config.diamond_cases import SEEDS, DEGREES, KEYWORDS_DIR, PARTSMAT_DIR, OUTPUT_DIR
from src.make_model_process.keyword_output import write_output
from src.make_model_process.diamond_keywordset import prepare_inputs, validate_keywordset, validate_material_links

# Case settings. Orientation and material parameters belong in the supplied .k files.
RHOS = [-0.5, 0.0, 0.5, 1.0]
PARTSMAT_GLOB = "partsmat_*.k"
OVERWRITE_EXISTING = False

# Paths relative to KEYWORDS_DIR; {rho} and {seed} are available in every template.
PARTSET_TEMPLATE = "consts/partset_diamond.k"
CONTROL_TEMPLATE = "consts/control.k"
SECTION_TEMPLATE = "consts/section.k"
BOUNDARY_TEMPLATE = "keyword_rho_{rho}_diamond/boundary_diamond_rho_{rho}.k"
CURVE_TEMPLATE = "keyword_rho_{rho}_diamond/curve_rho_{rho}.k"
PARTSMAT_SUBDIR_TEMPLATE = "seed_{seed}/deg_{deg}"


@dataclass(frozen=True)
class DiamondFiles:
    rho: float
    seed: int
    degree: float
    partset: Path
    control: Path
    section: Path
    boundary: Path
    curve: Path
    partsmat_dir: Path
    keywordset: Path
    merged_dir: Path


def build_paths(
    rho: float,
    seed: int,
    degree: float,
    keywords_dir: Path,
    partsmat_dir: Path,
    output_dir: Path,
) -> DiamondFiles:
    values = {"rho": f"{rho:g}", "seed": seed}
    case_dir = output_dir / f"rho_{rho:g}" / f"seed_{seed}"
    def select(template,alternatives=()):
        primary=keywords_dir/template.format(**values)
        if primary.is_file():return primary
        for alternative in alternatives:
            candidate=keywords_dir/alternative.format(**values)
            if candidate.is_file():return candidate
        return primary
    return DiamondFiles(
        rho,seed,degree,
        select(PARTSET_TEMPLATE),select(CONTROL_TEMPLATE),select(SECTION_TEMPLATE),
        select(BOUNDARY_TEMPLATE,('keyword_rho_{rho}_diamond/boundary_rho_{rho}.k',
                                  'keyword_rho_{rho}/boundary_diamond_rho_{rho}.k')),
        select(CURVE_TEMPLATE,('keyword_rho_{rho}/curve_diamond_rho_{rho}.k',)),
        partsmat_dir/PARTSMAT_SUBDIR_TEMPLATE.format(**values,deg=f'{degree:g}'),
        case_dir/'keywordset.k',case_dir/f'deg_{degree:g}',
    )



def validate_inputs(jobs: list[DiamondFiles]) -> dict[Path, list[Path]]:
    """Validate the entire batch before writing any output."""
    errors = set()
    materials = {}
    for job in jobs:
        for name in ["partset", "control", "section", "boundary", "curve"]:
            path = getattr(job, name)
            if not path.is_file():
                errors.add(f"missing file [{name}]: {path}")
        if job.partsmat_dir not in materials:
            matches = sorted(job.partsmat_dir.glob(PARTSMAT_GLOB))
            matches = [path for path in matches if path.is_file()]
            materials[job.partsmat_dir] = matches
            if not matches:
                errors.add(f"no partsmat files: {job.partsmat_dir / PARTSMAT_GLOB}")
    if errors:
        raise FileNotFoundError(
            "Required inputs were not found:\n" + "\n".join(sorted(errors))
        )
    return materials


def read_fragment(path: Path) -> str:
    path=Path(path);stat=path.stat()
    return _read_fragment_cached(str(path.resolve()),stat.st_mtime_ns,stat.st_size)


@lru_cache(maxsize=32)
def _read_fragment_cached(filename,mtime,size) -> str:
    path=Path(filename)
    """Keep all keyword data; remove only deck wrappers and deck-level TITLE."""
    lines = []
    title = False
    for line in path.read_text(encoding="utf-8").splitlines(keepends=True):
        text = line.strip()
        if text.startswith("*"):
            keyword = text.split()[0].upper()
            title = keyword == "*TITLE"
            if keyword in {"*KEYWORD", "*END", "*TITLE"}:
                continue
        if not title:
            lines.append(line)
    return "".join(lines).rstrip() + "\n"


def render_deck(sources: list[Path]) -> str:
    return '*KEYWORD\n'+'\n'.join(read_fragment(source) for source in sources)+'*END\n'


def write_deck(output: Path, sources: list[Path],overwrite=False,reuse_existing=False) -> bool:
    if Path(output).resolve() in {Path(p).resolve() for p in sources}:
        raise ValueError('Output deck must not replace an input fragment')
    return write_output(output,render_deck(sources).encode('utf-8'),overwrite,reuse_existing)


def build_keywordset(job: DiamondFiles, overwrite=False,reuse_existing=False) -> bool:
    if job.keywordset.exists() and not overwrite and not reuse_existing:return False
    sources=[job.control,job.boundary,job.section,job.curve,job.partset]
    body=render_deck(sources)
    if (job.partset.parent/'initmesh_diamond.k').is_file():validate_keywordset(body)
    written=write_output(job.keywordset,body.encode('utf-8'),overwrite,reuse_existing)
    if written:print(f'Wrote keywordset: {job.keywordset}')
    return written


def merge_models(job: DiamondFiles, partsmat_files: list[Path],overwrite=False,reuse_existing=False) -> tuple[int,int]:
    written=skipped=0
    info=validate_keywordset(read_fragment(job.keywordset)) if (job.partset.parent/'initmesh_diamond.k').is_file() else None
    for partsmat in partsmat_files:
        case_name=partsmat.stem.removeprefix('partsmat_');output=job.merged_dir/f'{case_name}.k'
        if output.exists() and not overwrite and not reuse_existing:skipped+=1;continue
        if info is not None:validate_material_links(read_fragment(partsmat),info)
        if write_deck(output,[job.keywordset,partsmat],overwrite,reuse_existing):written+=1
        else:skipped+=1
    return written,skipped


def main(argv=None) -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rhos", "--rho", nargs="+", type=float, default=RHOS)
    parser.add_argument("--seeds", "--seed", nargs="+", type=int, default=SEEDS)
    parser.add_argument(
        "--degs", "--degrees", "--angles", nargs="+", type=float, default=DEGREES
    )
    parser.add_argument("--keywords-dir", type=Path, default=KEYWORDS_DIR)
    parser.add_argument("--partsmat-dir", type=Path, default=PARTSMAT_DIR)
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR)
    parser.add_argument("--overwrite", action="store_true", default=OVERWRITE_EXISTING)
    parser.add_argument("--reuse-existing",action="store_true",help="Reuse only byte-identical outputs")
    parser.add_argument("--prepare-keywords",action=argparse.BooleanOptionalAction,default=True)
    args = parser.parse_args(argv)
    if len(set(args.seeds)) != len(args.seeds) or any(seed < 0 for seed in args.seeds):
        parser.error("Seeds must be unique nonnegative integers")
    if len(set(args.rhos)) != len(args.rhos) or any(
        not float("-inf") < rho < float("inf") for rho in args.rhos
    ):
        parser.error("Rhos must be unique finite numbers")
    if len(set(args.degs)) != len(args.degs) or any(
        not 0 <= deg < float("inf") for deg in args.degs
    ):
        parser.error("Degrees must be unique nonnegative finite numbers")
    if args.prepare_keywords:
        prepare_inputs(args.keywords_dir,args.rhos,overwrite=args.overwrite)
    jobs = [
        build_paths(
            rho, seed, deg, args.keywords_dir, args.partsmat_dir, args.output_dir
        )
        for rho in args.rhos
        for seed in args.seeds
        for deg in args.degs
    ]
    materials = validate_inputs(jobs)
    written = skipped = 0
    built = set()
    for job in jobs:
        if job.keywordset not in built:
            build_keywordset(job, args.overwrite,args.reuse_existing)
            built.add(job.keywordset)
        new, old = merge_models(job, materials[job.partsmat_dir], args.overwrite,args.reuse_existing)
        written += new
        skipped += old
    print(f"Merged models: {written} written, {skipped} skipped")


if __name__ == "__main__":
    main()
