#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""parse-workflow-spec.py — Parse WF-L*.md business workflow spec (16 sections) -> raw JSON.

Usage:
  python -X utf8 parse-workflow-spec.py <spec.md> <out.json>

Output JSON shape:
{
  "wf_id": "WF-L1-01",
  "source": "<path>",
  "sections": {"1": "...", "2": "...", ..., "16": "..."},
  "actors": [{"actor": ..., "role": ..., "permissions": ...}],      # from section 3 table
  "steps": [{"n": ..., "system": ..., "action": ..., "expected": ...}],  # section 7 table
  "state_machine": [...raw lines...],                               # section 8
  "business_rules": ["BR-WFxx-NN: ..."],                            # section 9
  "sla": [...raw lines...],                                         # section 11
  "scenarios": {"happy": [...], "edge": [...], "negative": [...]},  # section 15 TC mentions
}

Graceful: file khong ton tai / khong match heading -> exit 1 voi thong bao (skill co
manual-parse fallback theo procedures/phase1-analyze.md Step 1.1).
"""
import json
import re
import sys
from pathlib import Path

SECTION_RE = re.compile(r"^#{1,3}\s*(?:§\s*)?(\d{1,2})(?:\s*[.\-—:]|\s|$)")
WF_ID_RE = re.compile(r"WF-L\d-\d{2}")
TABLE_ROW_RE = re.compile(r"^\|(.+)\|\s*$")
BR_RE = re.compile(r"\bBR-WF\d{1,2}-\d{1,3}\b")
TC_RE = re.compile(r"\bTC-[A-Z0-9]+(?:-[0-9]+)?\b")


def split_sections(text: str) -> dict:
    """Split markdown by numbered section headings (## §N / ## N. / ## N — / ### N)."""
    sections: dict[str, str] = {}
    current = None
    buf: list[str] = []
    for line in text.splitlines():
        m = SECTION_RE.match(line)
        if m:
            if current is not None:
                sections[current] = "\n".join(buf).strip()
            current = m.group(1)
            buf = []
        elif current is not None:
            buf.append(line)
    if current is not None:
        sections[current] = "\n".join(buf).strip()
    return sections


def parse_table(body: str, min_cols: int = 2) -> list[list[str]]:
    rows = []
    for line in body.splitlines():
        m = TABLE_ROW_RE.match(line.strip())
        if not m:
            continue
        cells = [c.strip() for c in m.group(1).split("|")]
        if len(cells) >= min_cols and not all(re.fullmatch(r":?-{2,}:?", c) for c in cells):
            rows.append(cells)
    return rows


def extract_actors(body: str) -> list[dict]:
    out = []
    for cells in parse_table(body):
        row = {"actor": cells[0]}
        if len(cells) > 1:
            row["role"] = cells[1]
        if len(cells) > 2:
            row["permissions"] = cells[2]
        out.append(row)
    return out


def extract_steps(body: str) -> list[dict]:
    out = []
    for cells in parse_table(body):
        step = {"raw": cells}
        if len(cells) >= 4:
            step = {"n": cells[0], "system": cells[1], "action": cells[2], "expected": cells[3]}
        elif len(cells) == 3:
            step = {"n": cells[0], "action": cells[1], "expected": cells[2]}
        out.append(step)
    return out


def extract_scenarios(body: str) -> dict:
    groups = {"happy": [], "edge": [], "negative": []}
    current = None
    for line in body.splitlines():
        low = line.lower()
        if re.search(r"\bhappy\b|happy path", low):
            current = "happy"
        elif re.search(r"\bedge\b", low):
            current = "edge"
        elif re.search(r"negative|lỗi|fail\b", low):
            current = "negative"
        for tc in TC_RE.findall(line):
            key = current or "edge"
            if tc not in groups[key]:
                groups[key].append(tc)
    return groups


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: parse-workflow-spec.py <spec.md> <out.json>", file=sys.stderr)
        return 1
    src = Path(sys.argv[1])
    out = Path(sys.argv[2])
    if not src.is_file():
        print(f"ERROR: spec not found: {src}", file=sys.stderr)
        return 1

    text = src.read_text(encoding="utf-8", errors="replace")
    wf_ids = WF_ID_RE.findall(text)
    sections = split_sections(text)

    result = {
        "wf_id": wf_ids[0] if wf_ids else "",
        "source": str(src),
        "sections_found": sorted(sections.keys(), key=lambda k: int(k)),
        "sections": sections,
        "actors": extract_actors(sections.get("3", "")),
        "steps": extract_steps(sections.get("7", "")),
        "state_machine": sections.get("8", "").splitlines(),
        "business_rules": sorted(set(BR_RE.findall(text))),
        "sla": sections.get("11", "").splitlines(),
        "scenarios": extract_scenarios(sections.get("15", "")),
    }
    if not wf_ids:
        print(f"WARN: no WF-L*-NN id found in {src}", file=sys.stderr)

    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"OK: {len(result['sections_found'])} sections, "
          f"{len(result['actors'])} actors, {len(result['steps'])} steps, "
          f"{len(result['business_rules'])} BRs -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
