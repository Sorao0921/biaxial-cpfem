from __future__ import annotations

from pathlib import Path


def _strip_end(lines: list[str]) -> list[str]:
    while lines and not lines[-1].strip():
        lines.pop()
    if lines and lines[-1].strip().upper().startswith("*END"):
        lines.pop()
    return lines


def merge_keywordset_and_partsmat(
    keywordset_k: Path,
    partsmat_k: Path,
    out_k: Path,
) -> Path:
    """Merge keywordset_*.k and partsmat_*.k into a final deck."""

    keywordset_k = Path(keywordset_k)
    partsmat_k = Path(partsmat_k)
    out_k = Path(out_k)
    out_k.parent.mkdir(parents=True, exist_ok=True)

    base = _strip_end(
        keywordset_k.read_text(encoding="utf-8", errors="replace").splitlines(True)
    )
    add = _strip_end(
        partsmat_k.read_text(encoding="utf-8", errors="replace").splitlines(True)
    )

    with open(out_k, "w", encoding="utf-8") as f:
        if base:
            f.writelines(base)
            if not base[-1].endswith("\n"):
                f.write("\n")
        f.write("\n")
        if add:
            f.writelines(add)
            if not add[-1].endswith("\n"):
                f.write("\n")
        f.write("*END\n")

    return out_k
