"""Tests cho impact_graph_builder — Phase F Task F.1.

Coverage:
- Node construction tu classified + extracted.
- Edge construction tu 4 nguon (imports, schema, entity refs, req cross-refs).
- Synthesis-mode gating (condensed skip edges, full filter, full+insights include all).
- Circular dependency detection (Tarjan SCC).
- Orphan module detection.
- Fanout summary + coupling score.
- Build from session_dir on disk.
- Atomic write output.
"""

from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

import pytest

_SHARED_ROOT = Path(__file__).resolve().parents[2]
if str(_SHARED_ROOT) not in sys.path:
    sys.path.insert(0, str(_SHARED_ROOT))

from ips import impact_graph_builder as igb  # noqa: E402


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _classified(*modules: dict) -> dict:
    return {"modules": list(modules)}


def _extracted_flat(*features: dict) -> dict:
    return {"features": list(features)}


def _extracted_nested(mods: dict) -> dict:
    return {"modules": mods}


# ---------------------------------------------------------------------------
# Schema + enum validation
# ---------------------------------------------------------------------------


class TestSchemaContract:
    def test_schema_id(self) -> None:
        result = igb.build_impact_graph()
        assert result["$schema"] == "impact-graph-v1"

    def test_relation_types_complete(self) -> None:
        assert igb.RELATION_TYPES == (
            "code_import",
            "data_dependency",
            "event_subscription",
            "api_call",
            "req_cross_ref",
            "entity_reference",
        )

    def test_synthesis_modes_complete(self) -> None:
        assert set(igb.SYNTHESIS_MODES) == {
            "condensed",
            "full",
            "full+insights",
            "full+divergence",
        }

    def test_invalid_synthesis_mode_raises(self) -> None:
        with pytest.raises(ValueError):
            igb.build_impact_graph(synthesis_mode="invalid-mode")

    def test_default_payload_has_required_keys(self) -> None:
        result = igb.build_impact_graph()
        for key in (
            "$schema",
            "synthesis_mode",
            "generated_at",
            "session_id",
            "nodes",
            "edges",
            "relation_types_allowed",
            "circular_dependencies",
            "orphan_modules",
            "summary",
        ):
            assert key in result, f"missing key {key!r}"

    def test_generated_at_default_is_iso8601_z(self) -> None:
        result = igb.build_impact_graph()
        assert result["generated_at"].endswith("Z")
        assert "T" in result["generated_at"]

    def test_generated_at_override(self) -> None:
        stamp = "2026-04-22T10:00:00Z"
        result = igb.build_impact_graph(generated_at=stamp)
        assert result["generated_at"] == stamp


# ---------------------------------------------------------------------------
# Nodes from classified + extracted
# ---------------------------------------------------------------------------


class TestNodeConstruction:
    def test_nodes_from_classified(self) -> None:
        classified = _classified(
            {"id": "crm/customer", "files_count": 12, "domain": "sales"},
            {"id": "finance/ar", "files_count": 8, "domain": "finance"},
        )
        result = igb.build_impact_graph(classified=classified)
        ids = [n["id"] for n in result["nodes"]]
        assert ids == ["crm/customer", "finance/ar"]
        assert result["nodes"][0]["domain"] == "sales"
        assert result["nodes"][0]["files_count"] == 12

    def test_nodes_normalized_to_kebab(self) -> None:
        classified = _classified({"id": "CRM_Customer", "files_count": 5})
        result = igb.build_impact_graph(classified=classified)
        assert result["nodes"][0]["id"] == "crm-customer"

    def test_feat_ids_from_extracted_flat(self) -> None:
        classified = _classified({"id": "billing", "files_count": 3})
        extracted = _extracted_flat(
            {"FEAT-ID": "FEAT-BILL-001", "module_id": "billing"},
            {"FEAT-ID": "FEAT-BILL-002", "module_id": "billing"},
        )
        result = igb.build_impact_graph(classified=classified, extracted=extracted)
        billing = next(n for n in result["nodes"] if n["id"] == "billing")
        assert "FEAT-BILL-001" in billing["feat_ids"]
        assert "FEAT-BILL-002" in billing["feat_ids"]

    def test_feat_ids_from_extracted_nested(self) -> None:
        extracted = _extracted_nested(
            {
                "crm/customer": {
                    "features": [
                        {"FEAT-ID": "FEAT-CRM-CUST-001"},
                        {"feat_id": "FEAT-CRM-CUST-002"},
                    ]
                }
            }
        )
        result = igb.build_impact_graph(extracted=extracted)
        node = next(n for n in result["nodes"] if n["id"] == "crm/customer")
        assert sorted(node["feat_ids"]) == ["FEAT-CRM-CUST-001", "FEAT-CRM-CUST-002"]

    def test_nodes_sorted_by_id(self) -> None:
        classified = _classified(
            {"id": "zeta"},
            {"id": "alpha"},
            {"id": "mike"},
        )
        result = igb.build_impact_graph(classified=classified)
        assert [n["id"] for n in result["nodes"]] == ["alpha", "mike", "zeta"]

    def test_empty_inputs_yield_empty_nodes(self) -> None:
        result = igb.build_impact_graph()
        assert result["nodes"] == []
        assert result["edges"] == []
        assert result["summary"]["total_nodes"] == 0


# ---------------------------------------------------------------------------
# Edges: code_import from dep_graph
# ---------------------------------------------------------------------------


class TestCodeImportEdges:
    def test_edges_shape(self) -> None:
        classified = _classified(
            {"id": "crm/customer", "files_count": 3},
            {"id": "finance/ar", "files_count": 2},
        )
        dep_graph = {
            "edges": [
                {"from": "src/crm/customer/a.ts", "to": "src/finance/ar/invoice.ts"}
            ]
        }
        result = igb.build_impact_graph(classified=classified, dep_graph=dep_graph)
        assert len(result["edges"]) == 1
        e = result["edges"][0]
        assert e["relation"] == "code_import"
        assert e["from"] == "crm/customer"
        assert e["to"] == "finance/ar"
        assert 0.0 < e["strength"] <= 1.0
        assert e["probe_source"] == "import_analysis"

    def test_imports_dict_shape(self) -> None:
        classified = _classified({"id": "billing"}, {"id": "customer"})
        dep_graph = {
            "imports": {
                "src/billing/invoice.ts": [
                    "src/customer/profile.ts",
                    "src/customer/address.ts",
                ]
            }
        }
        result = igb.build_impact_graph(classified=classified, dep_graph=dep_graph)
        assert len(result["edges"]) == 1
        assert result["edges"][0]["evidence"].startswith("2 import")

    def test_self_loop_excluded(self) -> None:
        classified = _classified({"id": "billing"})
        dep_graph = {
            "edges": [
                {"from": "src/billing/a.ts", "to": "src/billing/b.ts"},
            ]
        }
        result = igb.build_impact_graph(classified=classified, dep_graph=dep_graph)
        assert result["edges"] == []

    def test_unknown_module_ignored(self) -> None:
        classified = _classified({"id": "billing"})
        dep_graph = {
            "edges": [
                {"from": "src/billing/a.ts", "to": "src/ghost/b.ts"},
            ]
        }
        result = igb.build_impact_graph(classified=classified, dep_graph=dep_graph)
        assert result["edges"] == []

    def test_aggregated_count_in_evidence(self) -> None:
        classified = _classified({"id": "a"}, {"id": "b"})
        dep_graph = {
            "edges": [
                {"from": "src/a/x.ts", "to": "src/b/y.ts"},
                {"from": "src/a/x2.ts", "to": "src/b/y.ts"},
                {"from": "src/a/x3.ts", "to": "src/b/z.ts"},
            ]
        }
        result = igb.build_impact_graph(classified=classified, dep_graph=dep_graph)
        assert len(result["edges"]) == 1
        assert result["edges"][0]["evidence"].startswith("3 import")


# ---------------------------------------------------------------------------
# Edges: data_dependency from schema
# ---------------------------------------------------------------------------


class TestDataDependencyEdges:
    def test_foreign_keys_list_shape(self) -> None:
        classified = _classified(
            {"id": "invoice"}, {"id": "customer"}
        )
        schema = {
            "foreign_keys": [
                {"from_table": "invoice", "to_table": "customer", "column": "customer_id"}
            ]
        }
        result = igb.build_impact_graph(classified=classified, schema=schema)
        dd = [e for e in result["edges"] if e["relation"] == "data_dependency"]
        assert len(dd) == 1
        assert dd[0]["from"] == "invoice"
        assert dd[0]["to"] == "customer"
        assert dd[0]["probe_source"] == "schema_parse"

    def test_tables_dict_shape(self) -> None:
        classified = _classified({"id": "order"}, {"id": "customer"})
        schema = {
            "tables": {
                "order": {"fk": {"customer_id": "customer.id"}},
            }
        }
        result = igb.build_impact_graph(classified=classified, schema=schema)
        dd = [e for e in result["edges"] if e["relation"] == "data_dependency"]
        assert len(dd) == 1
        assert dd[0]["from"] == "order"
        assert dd[0]["to"] == "customer"


# ---------------------------------------------------------------------------
# Edges: entity_reference from classified
# ---------------------------------------------------------------------------


class TestEntityReferenceEdges:
    def test_entity_cross_module(self) -> None:
        classified = _classified(
            {"id": "reporting", "entity_refs": ["customer"]},
            {"id": "crm", "entities": ["customer"]},
        )
        result = igb.build_impact_graph(classified=classified)
        ent = [e for e in result["edges"] if e["relation"] == "entity_reference"]
        assert len(ent) == 1
        assert ent[0]["from"] == "reporting"
        assert ent[0]["to"] == "crm"
        assert "customer" in ent[0]["evidence"]


# ---------------------------------------------------------------------------
# Edges: req_cross_ref from extracted
# ---------------------------------------------------------------------------


class TestReqCrossRefEdges:
    def test_feat_reference_cross_module(self) -> None:
        extracted = _extracted_nested(
            {
                "crm": {
                    "features": [{"FEAT-ID": "FEAT-CRM-001"}],
                },
                "reporting": {
                    "features": [{"FEAT-ID": "FEAT-RPT-001"}],
                    "description": "Uses customer data from FEAT-CRM-001 to build reports.",
                },
            }
        )
        result = igb.build_impact_graph(extracted=extracted)
        rf = [e for e in result["edges"] if e["relation"] == "req_cross_ref"]
        assert len(rf) == 1
        assert rf[0]["from"] == "reporting"
        assert rf[0]["to"] == "crm"
        assert rf[0]["probe_source"] == "req_cross_ref_scan"


# ---------------------------------------------------------------------------
# Synthesis mode gating
# ---------------------------------------------------------------------------


class TestSynthesisModeGating:
    def _sample_inputs(self) -> dict:
        classified = _classified(
            {"id": "a", "entity_refs": ["b_entity"]},
            {"id": "b", "entities": ["b_entity"]},
        )
        dep_graph = {"edges": [{"from": "src/a/x.ts", "to": "src/b/y.ts"}]}
        schema = {
            "foreign_keys": [{"from_table": "a", "to_table": "b", "column": "b_id"}]
        }
        extracted = _extracted_nested(
            {
                "a": {
                    "features": [{"FEAT-ID": "FEAT-A-001"}],
                    "description": "note",
                },
                "b": {
                    "features": [{"FEAT-ID": "FEAT-B-001"}],
                    "description": "uses FEAT-A-001",
                },
            }
        )
        return {
            "classified": classified,
            "dep_graph": dep_graph,
            "schema": schema,
            "extracted": extracted,
        }

    def test_condensed_has_no_edges(self) -> None:
        result = igb.build_impact_graph(
            synthesis_mode="condensed", **self._sample_inputs()
        )
        assert result["edges"] == []
        # Nhung nodes van phai co
        assert len(result["nodes"]) == 2

    def test_full_only_import_and_schema(self) -> None:
        result = igb.build_impact_graph(
            synthesis_mode="full", **self._sample_inputs()
        )
        rels = {e["relation"] for e in result["edges"]}
        assert rels == {"code_import", "data_dependency"}

    def test_full_insights_includes_all(self) -> None:
        result = igb.build_impact_graph(
            synthesis_mode="full+insights", **self._sample_inputs()
        )
        rels = {e["relation"] for e in result["edges"]}
        # Expect: code_import + data_dependency + entity_reference + req_cross_ref
        assert rels >= {"code_import", "data_dependency", "entity_reference", "req_cross_ref"}

    def test_full_divergence_includes_all(self) -> None:
        result = igb.build_impact_graph(
            synthesis_mode="full+divergence", **self._sample_inputs()
        )
        rels = {e["relation"] for e in result["edges"]}
        assert "req_cross_ref" in rels


# ---------------------------------------------------------------------------
# Analysis: circular deps
# ---------------------------------------------------------------------------


class TestCircularDependencies:
    def test_no_cycle(self) -> None:
        classified = _classified({"id": "a"}, {"id": "b"}, {"id": "c"})
        dep_graph = {
            "edges": [
                {"from": "src/a/x.ts", "to": "src/b/y.ts"},
                {"from": "src/b/y.ts", "to": "src/c/z.ts"},
            ]
        }
        result = igb.build_impact_graph(classified=classified, dep_graph=dep_graph)
        assert result["circular_dependencies"] == []

    def test_simple_cycle(self) -> None:
        classified = _classified({"id": "a"}, {"id": "b"})
        dep_graph = {
            "edges": [
                {"from": "src/a/x.ts", "to": "src/b/y.ts"},
                {"from": "src/b/y.ts", "to": "src/a/x.ts"},
            ]
        }
        result = igb.build_impact_graph(classified=classified, dep_graph=dep_graph)
        assert result["circular_dependencies"] == [["a", "b"]]

    def test_three_node_cycle(self) -> None:
        classified = _classified({"id": "a"}, {"id": "b"}, {"id": "c"})
        dep_graph = {
            "edges": [
                {"from": "src/a/x.ts", "to": "src/b/y.ts"},
                {"from": "src/b/y.ts", "to": "src/c/z.ts"},
                {"from": "src/c/z.ts", "to": "src/a/x.ts"},
            ]
        }
        result = igb.build_impact_graph(classified=classified, dep_graph=dep_graph)
        assert result["circular_dependencies"] == [["a", "b", "c"]]


# ---------------------------------------------------------------------------
# Analysis: orphans + fanout
# ---------------------------------------------------------------------------


class TestOrphanAndFanout:
    def test_orphan_module(self) -> None:
        classified = _classified({"id": "a"}, {"id": "b"}, {"id": "lonely"})
        dep_graph = {"edges": [{"from": "src/a/x.ts", "to": "src/b/y.ts"}]}
        result = igb.build_impact_graph(classified=classified, dep_graph=dep_graph)
        assert result["orphan_modules"] == ["lonely"]

    def test_fanout_summary(self) -> None:
        classified = _classified(
            {"id": "hub"}, {"id": "a"}, {"id": "b"}, {"id": "c"}
        )
        dep_graph = {
            "edges": [
                {"from": "src/hub/x.ts", "to": "src/a/y.ts"},
                {"from": "src/hub/x.ts", "to": "src/b/y.ts"},
                {"from": "src/hub/x.ts", "to": "src/c/y.ts"},
            ]
        }
        result = igb.build_impact_graph(classified=classified, dep_graph=dep_graph)
        assert result["summary"]["total_nodes"] == 4
        assert result["summary"]["total_edges"] == 3
        assert result["summary"]["max_fanout"] == 3
        assert result["summary"]["avg_fanout"] == pytest.approx(0.75, abs=0.01)

    def test_coupling_score_set_on_nodes(self) -> None:
        classified = _classified({"id": "a"}, {"id": "b"})
        dep_graph = {
            "edges": [{"from": "src/a/x.ts", "to": "src/b/y.ts"}]
        }
        result = igb.build_impact_graph(classified=classified, dep_graph=dep_graph)
        a_node = next(n for n in result["nodes"] if n["id"] == "a")
        b_node = next(n for n in result["nodes"] if n["id"] == "b")
        # 1 edge, 2 nodes → degree(a)=1, degree(b)=1, max_possible=1
        # coupling = 1 / (2*1) = 0.5
        assert a_node["coupling_score"] == 0.5
        assert b_node["coupling_score"] == 0.5


# ---------------------------------------------------------------------------
# Session-dir integration
# ---------------------------------------------------------------------------


class TestBuildFromSessionDir:
    def test_reads_files_from_disk(self, tmp_path: Path) -> None:
        session = tmp_path / "scan-sess-001"
        (session / "inventory").mkdir(parents=True)
        (session / "classified").mkdir(parents=True)
        (session / "extracted").mkdir(parents=True)

        (session / "inventory" / "dependency-graph.json").write_text(
            json.dumps(
                {
                    "edges": [
                        {"from": "src/crm/a.ts", "to": "src/finance/b.ts"}
                    ]
                }
            ),
            encoding="utf-8",
        )
        (session / "classified" / "modules-summary.json").write_text(
            json.dumps({"modules": [{"id": "crm"}, {"id": "finance"}]}),
            encoding="utf-8",
        )
        (session / "extracted" / "modules-summary.json").write_text(
            json.dumps({"modules": {"crm": {"features": [{"FEAT-ID": "FEAT-CRM-001"}]}}}),
            encoding="utf-8",
        )

        result = igb.build_from_session_dir(session, synthesis_mode="full")
        assert result["$schema"] == "impact-graph-v1"
        assert result["session_id"] == "scan-sess-001"
        assert len(result["nodes"]) == 2
        assert any(e["relation"] == "code_import" for e in result["edges"])

    def test_missing_files_yield_empty_graph(self, tmp_path: Path) -> None:
        session = tmp_path / "empty"
        session.mkdir()
        result = igb.build_from_session_dir(session)
        assert result["nodes"] == []
        assert result["edges"] == []

    def test_aggregate_extracted_from_per_module_dir(self, tmp_path: Path) -> None:
        session = tmp_path / "sess"
        (session / "classified").mkdir(parents=True)
        (session / "extracted" / "modules").mkdir(parents=True)

        (session / "classified" / "modules-summary.json").write_text(
            json.dumps({"modules": [{"id": "billing"}]}),
            encoding="utf-8",
        )
        (session / "extracted" / "modules" / "billing.json").write_text(
            json.dumps(
                {
                    "module_id": "billing",
                    "features": [{"FEAT-ID": "FEAT-BILL-001"}],
                }
            ),
            encoding="utf-8",
        )

        result = igb.build_from_session_dir(session, synthesis_mode="full+insights")
        billing = next(n for n in result["nodes"] if n["id"] == "billing")
        assert "FEAT-BILL-001" in billing["feat_ids"]


# ---------------------------------------------------------------------------
# Atomic write output
# ---------------------------------------------------------------------------


class TestWriteImpactGraph:
    def test_writes_json_payload(self, tmp_path: Path) -> None:
        payload = igb.build_impact_graph(
            classified=_classified({"id": "a"}),
            generated_at="2026-04-22T10:00:00Z",
        )
        out = tmp_path / "impact-graph.json"
        igb.write_impact_graph(payload, out)
        loaded = json.loads(out.read_text(encoding="utf-8"))
        assert loaded["$schema"] == "impact-graph-v1"
        assert loaded["generated_at"] == "2026-04-22T10:00:00Z"

    def test_atomic_write_no_tmp_leftover(self, tmp_path: Path) -> None:
        payload = igb.build_impact_graph()
        out = tmp_path / "sub" / "impact-graph.json"
        igb.write_impact_graph(payload, out)
        assert out.exists()
        assert not out.with_suffix(out.suffix + ".tmp").exists()


# ---------------------------------------------------------------------------
# End-to-end with ≥ 3 relation types (acceptance: F.1)
# ---------------------------------------------------------------------------


class TestAcceptanceCriteria:
    def test_three_or_more_relation_types(self) -> None:
        """AC: >= 3 relation types detected trong full+insights mode."""
        classified = _classified(
            {
                "id": "crm",
                "entities": ["customer"],
            },
            {
                "id": "billing",
                "entity_refs": ["customer"],
            },
            {"id": "reporting"},
        )
        dep_graph = {
            "edges": [
                {"from": "src/billing/a.ts", "to": "src/crm/cust.ts"},
                {"from": "src/reporting/z.ts", "to": "src/crm/cust.ts"},
            ]
        }
        schema = {
            "foreign_keys": [
                {"from_table": "billing", "to_table": "crm", "column": "customer_id"}
            ]
        }
        extracted = _extracted_nested(
            {
                "crm": {"features": [{"FEAT-ID": "FEAT-CRM-001"}]},
                "reporting": {
                    "features": [{"FEAT-ID": "FEAT-RPT-001"}],
                    "description": "depends on FEAT-CRM-001",
                },
            }
        )
        result = igb.build_impact_graph(
            classified=classified,
            dep_graph=dep_graph,
            schema=schema,
            extracted=extracted,
            synthesis_mode="full+insights",
        )
        rels = {e["relation"] for e in result["edges"]}
        assert len(rels) >= 3, f"AC expects >=3 relation types, got {rels}"

    def test_circular_detected_if_exists(self) -> None:
        """AC: circular deps detected."""
        classified = _classified({"id": "a"}, {"id": "b"})
        dep_graph = {
            "edges": [
                {"from": "src/a/x.ts", "to": "src/b/y.ts"},
                {"from": "src/b/y.ts", "to": "src/a/x.ts"},
            ]
        }
        result = igb.build_impact_graph(classified=classified, dep_graph=dep_graph)
        assert result["circular_dependencies"] == [["a", "b"]]

    def test_orphans_listed(self) -> None:
        """AC: orphan modules listed."""
        classified = _classified({"id": "a"}, {"id": "orphan"})
        dep_graph = {"edges": [{"from": "src/a/x.ts", "to": "src/a/y.ts"}]}
        result = igb.build_impact_graph(classified=classified, dep_graph=dep_graph)
        assert "orphan" in result["orphan_modules"]

    def test_schema_ref_matches_template(self) -> None:
        """AC: Schema ref = impact-graph-v1."""
        result = igb.build_impact_graph()
        assert result["$schema"] == igb.SCHEMA_ID == "impact-graph-v1"
