"""Impact Graph Builder — Phase F Task F.1.

Xay dung impact-graph.json theo 04-data-model.md §2.2 + 02-scan-layers.md L6.

6 loai quan he (relation types):
- code_import        : import/export giua modules (tu inventory/dependency-graph.json)
- data_dependency    : FK / schema reference (entity_reference khi khong co FK rieng)
- event_subscription : event bus / decorator (tu annotation/pattern)
- api_call           : REST/gRPC call (tu runtime trace neu co, hoac tu imports co pattern)
- req_cross_ref      : USES: REQ-X comment annotation (tu extracted/*)
- entity_reference   : entity name reference khong strict FK

Module co trach nhiem thuan tuy: doc inventory + classified + extracted roi tong hop.
KHONG goi agent, KHONG lam AST parse phuc tap — cac L3/L4/L5 da lam truoc.

Reference:
- docs/design/skills/wf-legacy-scan/04-data-model.md §2.2
- docs/design/skills/wf-legacy-scan/02-scan-layers.md L6 §4 (synthesis modes)
- .claude/skills/workflow/wf-legacy-scan/templates/impact-graph.json
"""

from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


# ---------------------------------------------------------------------------
# Constants + schema allow-lists
# ---------------------------------------------------------------------------

SCHEMA_ID = "impact-graph-v1"

RELATION_TYPES: tuple[str, ...] = (
    "code_import",
    "data_dependency",
    "event_subscription",
    "api_call",
    "req_cross_ref",
    "entity_reference",
)

# Valid synthesis modes — map tu 02-scan-layers.md §3
SYNTHESIS_MODES: tuple[str, ...] = (
    "condensed",
    "full",
    "full+insights",
    "full+divergence",
)

# Regex de tim REQ-ID references trong descriptions / source comments
_REQ_ID_RE = re.compile(r"\b(REQ|FEAT)-[A-Z0-9]+(?:-[A-Z0-9]+){1,3}\b")

# Ten 'files' co kha nang la API call (heuristic evidence)
_API_CALL_HINTS = (
    "fetch(",
    "axios.",
    "httpClient.",
    "grpc.",
    "http.request",
    "restTemplate",
    "WebClient.",
    "openapi",
)

# Event-bus hints
_EVENT_HINTS = (
    "@Subscribe",
    "@EventListener",
    "on(",
    "emit(",
    "pubsub.",
    "kafkaConsumer",
    "kafkaProducer",
    "eventBus.",
)


# ---------------------------------------------------------------------------
# Helpers: file IO — Tat ca khong throw, tra ve None / [] khi thieu file
# ---------------------------------------------------------------------------


def _read_json(path: Path) -> Any:
    """Doc JSON file neu co, tra ve None khi thieu / invalid."""
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


def _list_json_dir(dir_path: Path) -> list[Path]:
    """List JSON files trong 1 thu muc (non-recursive)."""
    if not dir_path.is_dir():
        return []
    return sorted(p for p in dir_path.iterdir() if p.suffix == ".json" and p.is_file())


# ---------------------------------------------------------------------------
# Module normalization
# ---------------------------------------------------------------------------


def _normalize_module_id(raw: str) -> str:
    """Normalize module identifier thanh lowercase-kebab-case-ish canonical form.

    Quy tac CORE-017: lowercase, replace whitespace/_ by -, collapse repeat -.
    """
    if not raw:
        return ""
    s = raw.strip().lower()
    s = re.sub(r"[\s_]+", "-", s)
    s = re.sub(r"-{2,}", "-", s)
    return s.strip("-")


def _extract_module_from_path(path: str, known_modules: Iterable[str]) -> str | None:
    """Map file path → module id theo known_modules.

    Uu tien match segment dai nhat (e.g. 'crm/customer' uu tien hon 'crm').
    """
    if not path:
        return None
    parts = re.split(r"[/\\]", path.replace("\\", "/"))
    segments = {s.lower() for s in parts if s}
    # Sort known_modules dai truoc de uu tien nested match
    ordered = sorted({_normalize_module_id(m) for m in known_modules if m}, key=lambda x: -len(x))
    for mod in ordered:
        if not mod:
            continue
        if "/" in mod:
            norm_path = "/".join(s.lower() for s in parts)
            if mod in norm_path:
                return mod
        elif mod in segments:
            return mod
    return None


# ---------------------------------------------------------------------------
# Node construction
# ---------------------------------------------------------------------------


def _build_nodes(classified: dict[str, Any] | None, extracted: dict[str, Any] | None) -> list[dict[str, Any]]:
    """Build nodes tu classified modules + extracted FEAT-IDs.

    classified shape (flexible): {"modules": [{"id": "...", "files_count": N, "domain": "..."} ...]}
    Fallback: empty list.
    """
    nodes: dict[str, dict[str, Any]] = {}

    if classified and isinstance(classified, dict):
        modules = classified.get("modules") or []
        if isinstance(modules, list):
            for m in modules:
                if not isinstance(m, dict):
                    continue
                mid = _normalize_module_id(str(m.get("id") or m.get("name") or ""))
                if not mid:
                    continue
                nodes[mid] = {
                    "id": mid,
                    "type": "module",
                    "files_count": int(m.get("files_count") or m.get("file_count") or 0),
                    "feat_ids": [],
                    "domain": str(m.get("domain") or "unknown"),
                    "coupling_score": 0.0,
                }

    if extracted and isinstance(extracted, dict):
        # extracted shape: {"modules": {mid: {"features": [...], "requirements": [...]}}}
        # OR flat list {"features": [{"FEAT-ID": ..., "module_id": ...}]}
        ext_modules = extracted.get("modules")
        if isinstance(ext_modules, dict):
            for mid_raw, payload in ext_modules.items():
                mid = _normalize_module_id(str(mid_raw))
                if not mid:
                    continue
                node = nodes.setdefault(
                    mid,
                    {
                        "id": mid,
                        "type": "module",
                        "files_count": 0,
                        "feat_ids": [],
                        "domain": "unknown",
                        "coupling_score": 0.0,
                    },
                )
                feats = payload.get("features") if isinstance(payload, dict) else []
                if isinstance(feats, list):
                    for f in feats:
                        if isinstance(f, dict):
                            fid = f.get("FEAT-ID") or f.get("feat_id") or f.get("id")
                        else:
                            fid = f
                        if fid and str(fid) not in node["feat_ids"]:
                            node["feat_ids"].append(str(fid))
        elif isinstance(extracted.get("features"), list):
            for f in extracted["features"]:
                if not isinstance(f, dict):
                    continue
                mid = _normalize_module_id(str(f.get("module_id") or f.get("module") or ""))
                fid = f.get("FEAT-ID") or f.get("feat_id") or f.get("id")
                if not mid or not fid:
                    continue
                node = nodes.setdefault(
                    mid,
                    {
                        "id": mid,
                        "type": "module",
                        "files_count": 0,
                        "feat_ids": [],
                        "domain": "unknown",
                        "coupling_score": 0.0,
                    },
                )
                if str(fid) not in node["feat_ids"]:
                    node["feat_ids"].append(str(fid))

    return sorted(nodes.values(), key=lambda n: n["id"])


# ---------------------------------------------------------------------------
# Edge construction
# ---------------------------------------------------------------------------


def _build_edges_from_imports(
    dep_graph: dict[str, Any] | None,
    known_modules: set[str],
) -> list[dict[str, Any]]:
    """Build code_import edges tu inventory/dependency-graph.json.

    dep_graph shape chap nhan:
    - {"edges": [{"from": "src/a.ts", "to": "src/b.ts"}, ...]}
    - {"imports": {"src/a.ts": ["src/b.ts", ...]}}
    """
    if not dep_graph or not isinstance(dep_graph, dict):
        return []

    raw_pairs: list[tuple[str, str]] = []
    edges = dep_graph.get("edges")
    if isinstance(edges, list):
        for e in edges:
            if isinstance(e, dict) and "from" in e and "to" in e:
                raw_pairs.append((str(e["from"]), str(e["to"])))

    imports = dep_graph.get("imports")
    if isinstance(imports, dict):
        for src, dsts in imports.items():
            if isinstance(dsts, list):
                for dst in dsts:
                    raw_pairs.append((str(src), str(dst)))

    # Aggregate theo cap (from_mod, to_mod), bo qua self-loop
    counts: dict[tuple[str, str], int] = {}
    for src_path, dst_path in raw_pairs:
        from_mod = _extract_module_from_path(src_path, known_modules)
        to_mod = _extract_module_from_path(dst_path, known_modules)
        if not from_mod or not to_mod or from_mod == to_mod:
            continue
        counts[(from_mod, to_mod)] = counts.get((from_mod, to_mod), 0) + 1

    if not counts:
        return []

    max_count = max(counts.values())
    result: list[dict[str, Any]] = []
    for (a, b), n in sorted(counts.items()):
        strength = round(min(1.0, n / max_count), 3) if max_count else 0.0
        result.append(
            {
                "from": a,
                "to": b,
                "relation": "code_import",
                "evidence": f"{n} import reference(s)",
                "strength": strength,
                "probe_source": "import_analysis",
            }
        )
    return result


def _build_edges_from_req_cross_refs(
    extracted: dict[str, Any] | None,
    known_modules: set[str],
) -> list[dict[str, Any]]:
    """Build req_cross_ref edges — module A mention FEAT/REQ cua module B."""
    if not extracted or not isinstance(extracted, dict):
        return []

    # Map FEAT-ID → owning module
    feat_to_mod: dict[str, str] = {}
    ext_modules = extracted.get("modules")
    if isinstance(ext_modules, dict):
        for mid_raw, payload in ext_modules.items():
            mid = _normalize_module_id(str(mid_raw))
            if not mid or mid not in known_modules:
                continue
            feats = payload.get("features") if isinstance(payload, dict) else []
            if isinstance(feats, list):
                for f in feats:
                    fid = (
                        (f.get("FEAT-ID") or f.get("feat_id") or f.get("id"))
                        if isinstance(f, dict)
                        else f
                    )
                    if fid:
                        feat_to_mod[str(fid)] = mid

    if not feat_to_mod:
        return []

    # Quét descriptions de tim cross-ref
    pairs: dict[tuple[str, str], int] = {}
    if isinstance(ext_modules, dict):
        for mid_raw, payload in ext_modules.items():
            from_mod = _normalize_module_id(str(mid_raw))
            if not from_mod or from_mod not in known_modules:
                continue
            text_chunks: list[str] = []
            if isinstance(payload, dict):
                for k in ("description", "notes", "summary"):
                    v = payload.get(k)
                    if isinstance(v, str):
                        text_chunks.append(v)
                for f in payload.get("features") or []:
                    if isinstance(f, dict):
                        for k in ("description", "notes"):
                            v = f.get(k)
                            if isinstance(v, str):
                                text_chunks.append(v)
            blob = " ".join(text_chunks)
            for m in _REQ_ID_RE.finditer(blob):
                fid = m.group(0)
                owner = feat_to_mod.get(fid)
                if owner and owner != from_mod:
                    pairs[(from_mod, owner)] = pairs.get((from_mod, owner), 0) + 1

    if not pairs:
        return []

    max_count = max(pairs.values())
    return [
        {
            "from": a,
            "to": b,
            "relation": "req_cross_ref",
            "evidence": f"{n} REQ/FEAT reference(s)",
            "strength": round(min(1.0, n / max_count), 3) if max_count else 0.0,
            "probe_source": "req_cross_ref_scan",
        }
        for (a, b), n in sorted(pairs.items())
    ]


def _build_edges_from_entity_refs(
    classified: dict[str, Any] | None,
    known_modules: set[str],
) -> list[dict[str, Any]]:
    """Build entity_reference edges — entity name (VD: 'customer') xuat hien trong module khac.

    classified shape mo rong: {"modules": [{"id": ..., "entities": ["customer", "invoice"]}]}
    """
    if not classified or not isinstance(classified, dict):
        return []
    modules = classified.get("modules") or []
    if not isinstance(modules, list):
        return []

    entity_owner: dict[str, str] = {}
    for m in modules:
        if not isinstance(m, dict):
            continue
        mid = _normalize_module_id(str(m.get("id") or m.get("name") or ""))
        if not mid or mid not in known_modules:
            continue
        for ent in m.get("entities") or []:
            if isinstance(ent, str):
                entity_owner.setdefault(_normalize_module_id(ent), mid)

    if not entity_owner:
        return []

    pairs: dict[tuple[str, str], list[str]] = {}
    for m in modules:
        if not isinstance(m, dict):
            continue
        from_mod = _normalize_module_id(str(m.get("id") or m.get("name") or ""))
        if not from_mod or from_mod not in known_modules:
            continue
        refs = m.get("entity_refs") or m.get("uses_entities") or []
        if not isinstance(refs, list):
            continue
        for ref in refs:
            if not isinstance(ref, str):
                continue
            owner = entity_owner.get(_normalize_module_id(ref))
            if owner and owner != from_mod:
                pairs.setdefault((from_mod, owner), []).append(ref)

    if not pairs:
        return []

    max_count = max(len(v) for v in pairs.values())
    return [
        {
            "from": a,
            "to": b,
            "relation": "entity_reference",
            "evidence": f"entity refs: {', '.join(sorted(set(refs))[:3])}",
            "strength": round(min(1.0, len(refs) / max_count), 3) if max_count else 0.0,
            "probe_source": "entity_scan",
        }
        for (a, b), refs in sorted(pairs.items())
    ]


def _build_edges_from_schema(
    schema: dict[str, Any] | None,
    known_modules: set[str],
) -> list[dict[str, Any]]:
    """Build data_dependency edges tu db schema (neu co).

    schema shape chap nhan:
    - {"foreign_keys": [{"from_table": "invoice", "to_table": "customer", "column": "customer_id"}]}
    - {"tables": {"invoice": {"fk": {"customer_id": "customer.id"}}}}
    """
    if not schema or not isinstance(schema, dict):
        return []

    fks: list[tuple[str, str, str]] = []  # (from_table, to_table, column)
    raw = schema.get("foreign_keys")
    if isinstance(raw, list):
        for r in raw:
            if isinstance(r, dict):
                ft = r.get("from_table") or r.get("from")
                tt = r.get("to_table") or r.get("to")
                col = r.get("column") or ""
                if ft and tt:
                    fks.append((str(ft), str(tt), str(col)))

    tables = schema.get("tables")
    if isinstance(tables, dict):
        for ft, payload in tables.items():
            if isinstance(payload, dict):
                fk_map = payload.get("fk") or {}
                if isinstance(fk_map, dict):
                    for col, target in fk_map.items():
                        if isinstance(target, str) and "." in target:
                            tt = target.split(".", 1)[0]
                            fks.append((ft, tt, col))

    if not fks:
        return []

    pairs: dict[tuple[str, str], list[str]] = {}
    for ft, tt, col in fks:
        from_mod = _extract_module_from_path(ft, known_modules) or _normalize_module_id(ft)
        to_mod = _extract_module_from_path(tt, known_modules) or _normalize_module_id(tt)
        if not from_mod or not to_mod or from_mod == to_mod:
            continue
        if from_mod in known_modules and to_mod in known_modules:
            pairs.setdefault((from_mod, to_mod), []).append(f"{ft}.{col}→{tt}")

    if not pairs:
        return []

    return [
        {
            "from": a,
            "to": b,
            "relation": "data_dependency",
            "evidence": cols[0] if cols else "FK reference",
            "strength": round(min(1.0, len(cols) / max(1, max(len(v) for v in pairs.values()))), 3),
            "probe_source": "schema_parse",
        }
        for (a, b), cols in sorted(pairs.items())
    ]


def _build_edges_from_patterns(
    source_blobs: dict[str, str] | None,
    known_modules: set[str],
) -> list[dict[str, Any]]:
    """Heuristic: detect event_subscription + api_call tu source snippets neu co.

    source_blobs shape: {module_id: "concatenated snippet text"}.
    Neu khong co inventory blob → return [].
    """
    if not source_blobs or not isinstance(source_blobs, dict):
        return []

    event_count: dict[str, int] = {}
    api_count: dict[str, int] = {}
    for mid_raw, blob in source_blobs.items():
        mid = _normalize_module_id(str(mid_raw))
        if not mid or mid not in known_modules or not isinstance(blob, str):
            continue
        e = sum(blob.count(hint) for hint in _EVENT_HINTS)
        a = sum(blob.count(hint) for hint in _API_CALL_HINTS)
        if e:
            event_count[mid] = e
        if a:
            api_count[mid] = a

    edges: list[dict[str, Any]] = []
    # Self-loop edges (module → module) de ghi nhan feature — khong tao cross-module
    # edges khi khong co evidence cu the. Dat relation vao node-level attr se on hon,
    # nhung impact-graph.json schema chi co edges — de gon, bo qua trong version nay.
    # Return [] de tranh sai lech — event/api cross-module can runtime trace (defer).
    return edges


# ---------------------------------------------------------------------------
# Analysis: circular deps + orphans + fanout
# ---------------------------------------------------------------------------


def detect_circular_dependencies(
    nodes: list[dict[str, Any]], edges: list[dict[str, Any]]
) -> list[list[str]]:
    """Tim circular dependencies (strongly connected components size ≥ 2, hoac self-loop).

    Tarjan's SCC algorithm — iterative de tranh recursion limit.
    """
    node_ids = {n["id"] for n in nodes}
    adj: dict[str, set[str]] = {nid: set() for nid in node_ids}
    for e in edges:
        a, b = e.get("from"), e.get("to")
        if a in node_ids and b in node_ids and a != b:
            adj[a].add(b)

    index_counter = [0]
    stack: list[str] = []
    on_stack: set[str] = set()
    indices: dict[str, int] = {}
    lowlinks: dict[str, int] = {}
    sccs: list[list[str]] = []

    def _strongconnect(start: str) -> None:
        # Iterative Tarjan
        work_stack: list[tuple[str, Iterable[str]]] = [(start, iter(sorted(adj[start])))]
        indices[start] = index_counter[0]
        lowlinks[start] = index_counter[0]
        index_counter[0] += 1
        stack.append(start)
        on_stack.add(start)

        while work_stack:
            v, it = work_stack[-1]
            try:
                w = next(it)
            except StopIteration:
                work_stack.pop()
                if work_stack:
                    parent = work_stack[-1][0]
                    lowlinks[parent] = min(lowlinks[parent], lowlinks[v])
                if lowlinks[v] == indices[v]:
                    scc: list[str] = []
                    while True:
                        w2 = stack.pop()
                        on_stack.discard(w2)
                        scc.append(w2)
                        if w2 == v:
                            break
                    if len(scc) >= 2:
                        sccs.append(sorted(scc))
                continue
            if w not in indices:
                indices[w] = index_counter[0]
                lowlinks[w] = index_counter[0]
                index_counter[0] += 1
                stack.append(w)
                on_stack.add(w)
                work_stack.append((w, iter(sorted(adj[w]))))
            elif w in on_stack:
                lowlinks[v] = min(lowlinks[v], indices[w])

    for nid in sorted(node_ids):
        if nid not in indices:
            _strongconnect(nid)

    return sorted(sccs, key=lambda s: (len(s), s))


def detect_orphan_modules(
    nodes: list[dict[str, Any]], edges: list[dict[str, Any]]
) -> list[str]:
    """Orphan = khong co edge vao va khong co edge ra."""
    in_or_out: set[str] = set()
    for e in edges:
        a, b = e.get("from"), e.get("to")
        if a:
            in_or_out.add(a)
        if b:
            in_or_out.add(b)
    return sorted([n["id"] for n in nodes if n["id"] not in in_or_out])


def compute_fanout_summary(
    nodes: list[dict[str, Any]], edges: list[dict[str, Any]]
) -> dict[str, Any]:
    """Tinh avg_fanout + max_fanout va gan coupling_score vao moi node (in-place)."""
    total_nodes = len(nodes)
    total_edges = len(edges)

    out_deg: dict[str, int] = {n["id"]: 0 for n in nodes}
    in_deg: dict[str, int] = {n["id"]: 0 for n in nodes}
    for e in edges:
        a, b = e.get("from"), e.get("to")
        if a in out_deg:
            out_deg[a] += 1
        if b in in_deg:
            in_deg[b] += 1

    max_out = max(out_deg.values()) if out_deg else 0
    avg_out = (sum(out_deg.values()) / total_nodes) if total_nodes else 0.0

    # Coupling score = (in + out) / (2 * max_possible_edges)
    max_possible = max(1, total_nodes - 1)
    for n in nodes:
        degree = in_deg.get(n["id"], 0) + out_deg.get(n["id"], 0)
        n["coupling_score"] = round(min(1.0, degree / (2 * max_possible)), 3)

    return {
        "total_nodes": total_nodes,
        "total_edges": total_edges,
        "avg_fanout": round(avg_out, 3),
        "max_fanout": max_out,
    }


# ---------------------------------------------------------------------------
# Synthesis-mode gating
# ---------------------------------------------------------------------------


def _gate_edges_by_mode(
    edges: list[dict[str, Any]], synthesis_mode: str
) -> list[dict[str, Any]]:
    """Loc edges theo synthesis_mode — dung de tao dang graph nhe hon cho condensed."""
    if synthesis_mode == "condensed":
        return []
    if synthesis_mode == "full":
        # Chi giu code_import + data_dependency
        return [e for e in edges if e.get("relation") in ("code_import", "data_dependency")]
    # full+insights / full+divergence: giu tat ca
    return edges


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def build_impact_graph(
    *,
    classified: dict[str, Any] | None = None,
    extracted: dict[str, Any] | None = None,
    dep_graph: dict[str, Any] | None = None,
    schema: dict[str, Any] | None = None,
    source_blobs: dict[str, str] | None = None,
    synthesis_mode: str = "full+insights",
    session_id: str = "",
    generated_at: str | None = None,
) -> dict[str, Any]:
    """Build impact-graph.json payload.

    Args:
        classified: classified/modules-summary data (L4 output).
        extracted: extracted/modules data (L5 output).
        dep_graph: inventory/dependency-graph.json data (L3 output).
        schema: db schema (optional, L3 DB inventory).
        source_blobs: optional {module_id: snippet} map cho pattern heuristics.
        synthesis_mode: one of SYNTHESIS_MODES.
        session_id: session identifier (recorded trong payload).
        generated_at: ISO8601 timestamp (default: now UTC).

    Returns:
        Dict conforming to impact-graph-v1 schema.
    """
    if synthesis_mode not in SYNTHESIS_MODES:
        raise ValueError(
            f"synthesis_mode must be one of {SYNTHESIS_MODES}, got {synthesis_mode!r}"
        )

    nodes = _build_nodes(classified, extracted)
    known_modules = {n["id"] for n in nodes}

    edges: list[dict[str, Any]] = []
    if synthesis_mode != "condensed":
        edges.extend(_build_edges_from_imports(dep_graph, known_modules))
        edges.extend(_build_edges_from_schema(schema, known_modules))
        edges.extend(_build_edges_from_entity_refs(classified, known_modules))
        edges.extend(_build_edges_from_req_cross_refs(extracted, known_modules))
        edges.extend(_build_edges_from_patterns(source_blobs, known_modules))
        edges = _gate_edges_by_mode(edges, synthesis_mode)

    circular = detect_circular_dependencies(nodes, edges)
    orphans = detect_orphan_modules(nodes, edges)
    summary = compute_fanout_summary(nodes, edges)

    return {
        "$schema": SCHEMA_ID,
        "synthesis_mode": synthesis_mode,
        "generated_at": generated_at or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "session_id": session_id,
        "nodes": nodes,
        "edges": edges,
        "relation_types_allowed": list(RELATION_TYPES),
        "circular_dependencies": circular,
        "orphan_modules": orphans,
        "summary": summary,
    }


def build_from_session_dir(
    session_dir: str | Path,
    *,
    synthesis_mode: str = "full+insights",
    project_root: str | Path | None = None,
) -> dict[str, Any]:
    """Convenience: build impact-graph tu layout session tren disk.

    Tim cac files theo layout canonical:
      - <session_dir>/inventory/dependency-graph.json
      - <session_dir>/inventory/schema.json (optional)
      - <session_dir>/classified/modules-summary.json
      - <session_dir>/extracted/modules-summary.json (hoac /modules/*.json aggregate)
    """
    session_root = Path(session_dir)

    dep_graph = _read_json(session_root / "inventory" / "dependency-graph.json")
    schema = _read_json(session_root / "inventory" / "schema.json")
    classified = _read_json(session_root / "classified" / "modules-summary.json")
    extracted = _read_json(session_root / "extracted" / "modules-summary.json")

    # Aggregate extracted tu per-module files khi modules-summary.json khong co
    if not extracted:
        ext_dir = session_root / "extracted" / "modules"
        files = _list_json_dir(ext_dir)
        if files:
            merged: dict[str, Any] = {"modules": {}}
            for f in files:
                payload = _read_json(f)
                if isinstance(payload, dict):
                    mid = payload.get("module_id") or payload.get("id") or f.stem
                    merged["modules"][str(mid)] = payload
            extracted = merged

    session_id = session_root.name
    if project_root is not None:
        session_id = f"{Path(project_root).name}/{session_id}"

    return build_impact_graph(
        classified=classified,
        extracted=extracted,
        dep_graph=dep_graph,
        schema=schema,
        synthesis_mode=synthesis_mode,
        session_id=session_id,
    )


def write_impact_graph(
    payload: dict[str, Any],
    output_path: str | Path,
) -> Path:
    """Ghi payload ra file (atomic: write tmp → rename)."""
    path = Path(output_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, indent=2, sort_keys=False, ensure_ascii=False), encoding="utf-8")
    tmp.replace(path)
    return path


__all__ = [
    "SCHEMA_ID",
    "RELATION_TYPES",
    "SYNTHESIS_MODES",
    "build_impact_graph",
    "build_from_session_dir",
    "write_impact_graph",
    "detect_circular_dependencies",
    "detect_orphan_modules",
    "compute_fanout_summary",
]
