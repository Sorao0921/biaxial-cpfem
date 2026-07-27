from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


def _read_lines(p: Path) -> list[str]:
    return Path(p).read_text(encoding="utf-8", errors="replace").splitlines(True)


def _strip_end(lines: list[str]) -> list[str]:
    while lines and not lines[-1].strip():
        lines.pop()
    if lines and lines[-1].strip().upper() == "*END":
        lines.pop()
    return lines


def _find_idx(lines: list[str], pred):
    return next((i for i, ln in enumerate(lines) if pred(ln)), None)


def _is_kw(line: str) -> bool:
    return line.lstrip().startswith("*")


def _insert(lines: list[str], idx: int, add: list[str]) -> list[str]:
    idx = max(0, min(idx, len(lines)))
    out = lines[:idx]
    if out and out[-1].strip() != "":
        out.append("\n")
    out.extend(add)
    if out and out[-1].strip() != "":
        out.append("\n")
    out.extend(lines[idx:])
    return out


def _has_any(lines: list[str], needles: list[str]) -> bool:
    u = "".join(lines).upper()
    return any(n.upper() in u for n in needles)


@dataclass(frozen=True)
class KeywordFiles:
    control_k: Path
    boundary_k: Path
    section_k: Path
    curve_k: Path


class KeywordSetBuilder:
    """Build keywordset_*.k from partset.k + fixed keyword files (pasted directly)."""

    def __init__(self, files: KeywordFiles) -> None:
        self.files = KeywordFiles(
            control_k=Path(files.control_k),
            boundary_k=Path(files.boundary_k),
            section_k=Path(files.section_k),
            curve_k=Path(files.curve_k),
        )

    @staticmethod
    def _block(p: Path) -> list[str]:
        """Read a keyword fragment file and sanitize it for inlining.

        - Removes any *KEYWORD and *END lines even if they appear in the middle.
          (An internal *END would cause LS-DYNA to ignore everything after it.)
        - Trims trailing blank lines.
        """
        raw = _read_lines(p)
        cleaned: list[str] = []
        for ln in raw:
            s = ln.strip().upper()
            if s in {"*KEYWORD", "*END"}:
                continue
            cleaned.append(ln)
        return _strip_end(cleaned)

    def build_keywordset(
        self,
        partset_k: Path,
        out_keywordset_k: Path,
        *,
        secid: int = 1,
    ) -> Path:
        """Create keywordset deck from partset.k + fixed keyword files (no orientation/CSV dependency)."""

        lines = _strip_end(_read_lines(partset_k))

        # ensure *KEYWORD
        if not any(ln.strip().upper() == "*KEYWORD" for ln in lines):
            lines = ["*KEYWORD\n", "\n"] + lines
        key_idx = _find_idx(lines, lambda ln: ln.strip().upper() == "*KEYWORD")
        assert key_idx is not None

        # 1) control (always inline first)
        control_insert_pos = key_idx + 1
        control_block = self._block(self.files.control_k)
        if control_block:
            lines = _insert(lines, control_insert_pos, control_block)
        control_end_pos = control_insert_pos + len(control_block)

        # 2) boundary (inline immediately AFTER the entire control.k block)
        # control.k may contain *DATABASE_* keywords etc., so we must anchor to the block end.
        boundary_block = self._block(self.files.boundary_k)
        if boundary_block:
            lines = _insert(lines, control_end_pos, boundary_block)

        # 5) section between part_1 and part_2 (or after part_1)
        if not _has_any(lines, ["*SECTION_"]):
            sec = self._block(self.files.section_k)
            part2_title = _find_idx(lines, lambda ln: ln.strip() == "part_2")
            if part2_title is not None:
                start = part2_title
                while start > 0 and lines[start].strip().upper() != "*PART":
                    start -= 1
                lines = _insert(lines, start, sec)
            else:
                part1_title = _find_idx(lines, lambda ln: ln.strip() == "part_1")
                if part1_title is not None:
                    j = part1_title + 1
                    while j < len(lines) and not _is_kw(lines[j]):
                        j += 1
                    lines = _insert(lines, j, sec)
                else:
                    lines = _insert(lines, key_idx + 1, sec)

        # 7) curve before *ELEMENT or *NODE
        if not _has_any(lines, ["*DEFINE_CURVE", "*CURVE"]):
            curve = self._block(self.files.curve_k)
            elem = _find_idx(
                lines, lambda ln: ln.lstrip().upper().startswith("*ELEMENT")
            )
            if elem is None:
                elem = _find_idx(lines, lambda ln: ln.strip().upper() == "*NODE")
            if elem is None:
                elem = len(lines)
            lines = _insert(lines, elem, curve)

        out_keywordset_k = Path(out_keywordset_k)
        out_keywordset_k.parent.mkdir(parents=True, exist_ok=True)
        out_keywordset_k.write_text(
            "".join(lines).rstrip("\n") + "\n*END\n", encoding="utf-8"
        )
        return out_keywordset_k
