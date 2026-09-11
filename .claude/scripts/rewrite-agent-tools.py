#!/usr/bin/env python3
"""
Rewrite tools: line in each agent frontmatter — TỐI GIẢN cực mạnh.

Triết lý: chỉ giữ tool CỐT LÕI cho mỗi vai trò. Giảm context window tối đa.
Mọi MCP nâng cao (GitNexus/Serena/Context7/MCP Resources) đã bỏ.
Playwright chỉ giữ cho agent có CORE FUNCTION là browser testing, ở mức tối thiểu.
WebSearch/WebFetch bỏ — main Claude session có thể research thay agent.

4 Tiers:
  T1 (5 tools): docs-only — Read, Write, Edit, Glob, Grep
  T2 (6 tools): + Bash — agents chạy script
  T3 (8 tools): + Agent + TodoWrite — orchestrators spawn sub-agents
  T4 (16 tools): T2 + Playwright tối thiểu (10) — browser testing agents

Run: python rewrite-agent-tools.py
"""
from __future__ import annotations
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "agents"

# ---------- Tool building blocks ----------
CORE = ["Read", "Write", "Edit", "Glob", "Grep"]
BASH = ["Bash"]
SPAWN = ["Agent", "TodoWrite"]

# Playwright tối thiểu — đủ cho a11y/evidence/perf testing
PLAYWRIGHT_MIN = [
    "mcp__plugin_playwright_playwright__browser_navigate",
    "mcp__plugin_playwright_playwright__browser_snapshot",
    "mcp__plugin_playwright_playwright__browser_take_screenshot",
    "mcp__plugin_playwright_playwright__browser_console_messages",
    "mcp__plugin_playwright_playwright__browser_network_requests",
    "mcp__plugin_playwright_playwright__browser_click",
    "mcp__plugin_playwright_playwright__browser_type",
    "mcp__plugin_playwright_playwright__browser_wait_for",
    "mcp__plugin_playwright_playwright__browser_evaluate",
    "mcp__plugin_playwright_playwright__browser_close",
]


def join(*groups):
    seen = []
    for g in groups:
        for t in g:
            if t not in seen:
                seen.append(t)
    return ", ".join(seen)


# ---------- Profiles ----------

# T1: Pure docs-only — read, write, edit text/MD files
P_DOCS = join(CORE)

# T2: Docs + Bash — chạy scripts
P_DOCS_BASH = join(CORE, BASH)

# T3: Orchestrator — spawn sub-agents
P_ORCH = join(CORE, BASH, SPAWN)

# T4: Browser tester — testing agents có CORE FUNCTION là browser
P_BROWSER = join(CORE, BASH, PLAYWRIGHT_MIN)


# ---------- Agent → Profile mapping ----------
AGENT_PROFILE = {
    # ===== ORCHESTRATORS (Tier 3) =====
    "orchestrator.md": P_ORCH,
    "review/review-orchestrator.md": P_ORCH,

    # ===== BUSINESS (25 agents) — Tier 1 docs =====
    "business/business-analyst.md": P_DOCS,
    "business/compliance-expert.md": P_DOCS,
    "business/customer-expert.md": P_DOCS,
    "business/data-expert.md": P_DOCS,
    "business/ecommerce-expert.md": P_DOCS,
    "business/education-expert.md": P_DOCS,
    "business/enterprise-risk-expert.md": P_DOCS,
    "business/finance-expert.md": P_DOCS,
    "business/healthcare-expert.md": P_DOCS,
    "business/hr-expert.md": P_DOCS,
    "business/insurance-expert.md": P_DOCS,
    "business/investment-expert.md": P_DOCS,
    "business/legal-expert.md": P_DOCS,
    "business/logistics-expert.md": P_DOCS,
    "business/manufacturing-expert.md": P_DOCS,
    "business/marketing-expert.md": P_DOCS,
    "business/operations-expert.md": P_DOCS,
    "business/paid-media-expert.md": P_DOCS,
    "business/procurement-expert.md": P_DOCS,
    "business/product-expert.md": P_DOCS,
    "business/quality-excellence-expert.md": P_DOCS,
    "business/real-estate-expert.md": P_DOCS,
    "business/retail-expert.md": P_DOCS,
    "business/sales-expert.md": P_DOCS,
    "business/strategy-expert.md": P_DOCS,

    # ===== DESIGN (7 agents) — Tier 1 docs =====
    "design/brand-guardian.md": P_DOCS,
    "design/image-prompt-engineer.md": P_DOCS,
    "design/inclusive-visuals-specialist.md": P_DOCS,
    "design/ui-designer.md": P_DOCS,
    "design/ux-architect.md": P_DOCS,
    "design/ux-designer.md": P_DOCS,
    "design/ux-researcher.md": P_DOCS,

    # ===== ENGINEERING (14 agents) =====
    # Most write code/configs — Tier 2 (Bash needed)
    "engineering/ai-data-remediation-engineer.md": P_DOCS_BASH,
    "engineering/ai-engineer.md": P_DOCS_BASH,
    "engineering/architect.md": P_DOCS_BASH,
    "engineering/automation-architect.md": P_DOCS_BASH,
    "engineering/data-engineer.md": P_DOCS_BASH,
    "engineering/dba.md": P_DOCS_BASH,
    "engineering/developer.md": P_DOCS_BASH,
    "engineering/devops.md": P_DOCS_BASH,
    "engineering/embedded-engineer.md": P_DOCS_BASH,
    "engineering/frontend-developer.md": P_DOCS_BASH,
    "engineering/mobile-developer.md": P_DOCS_BASH,
    "engineering/security.md": P_DOCS_BASH,
    "engineering/sre.md": P_DOCS_BASH,
    "engineering/tech-writer.md": P_DOCS,   # pure docs

    # ===== REVIEW (6 agents) — Tier 1 docs (audit MD files) =====
    "review/agent-auditor.md": P_DOCS,
    "review/cross-reference-auditor.md": P_DOCS,
    "review/skill-auditor.md": P_DOCS,
    "review/template-auditor.md": P_DOCS,
    "review/workflow-auditor.md": P_DOCS,
    # review-orchestrator already in ORCHESTRATORS section above

    # ===== TESTING (9 agents) =====
    # Browser testers (Tier 4)
    "testing/accessibility-auditor.md": P_BROWSER,
    "testing/evidence-collector.md": P_BROWSER,
    "testing/performance-benchmarker.md": P_BROWSER,
    "testing/integration-certifier.md": P_BROWSER,
    "testing/reality-checker.md": P_BROWSER,
    # Non-browser testers (Tier 2)
    "testing/api-tester.md": P_DOCS_BASH,
    "testing/code-reviewer.md": P_DOCS_BASH,
    "testing/model-qa.md": P_DOCS_BASH,
    "testing/qa-lead.md": P_DOCS_BASH,
}

# Files SKIP (wildcard or templates)
SKIP = {
    "claude.md",                          # built-in default, tools: '*'
    "README.md",
    "review/README.md",
    "spec/README.md",
    "spec/knowledge-template.md",
    "spec/agent-definition-template.md",  # template — keep maximum example
}


def rewrite_tools_line(path: Path, new_tools: str) -> tuple[bool, str]:
    text = path.read_text(encoding="utf-8")
    pattern = re.compile(r"^tools:\s*.*$", flags=re.MULTILINE)
    m = pattern.search(text)
    if not m:
        return False, "no tools: line"
    new_text = pattern.sub(f"tools: {new_tools}", text, count=1)
    if new_text == text:
        return False, "unchanged"
    path.write_text(new_text, encoding="utf-8")
    return True, "ok"


def main() -> int:
    if not ROOT.exists():
        print(f"ERROR: agents root not found: {ROOT}", file=sys.stderr)
        return 2

    changed = 0
    skipped = 0
    errors = 0
    missing = []

    for path in sorted(ROOT.glob("*.md")) + sorted(ROOT.glob("*/*.md")):
        rel = path.relative_to(ROOT).as_posix()
        if rel in SKIP:
            print(f"SKIP   {rel}")
            skipped += 1
            continue
        if rel not in AGENT_PROFILE:
            print(f"WARN   {rel}: no profile mapping")
            missing.append(rel)
            continue
        new_tools = AGENT_PROFILE[rel]
        ok, msg = rewrite_tools_line(path, new_tools)
        if ok:
            tier_size = len([t for t in new_tools.split(",")])
            print(f"OK  [{tier_size:>2}t] {rel}")
            changed += 1
        else:
            print(f"ERROR  {rel}: {msg}")
            errors += 1

    print()
    print(f"=== SUMMARY ===")
    print(f"Changed:         {changed}")
    print(f"Skipped:         {skipped}")
    print(f"Errors:          {errors}")
    print(f"Missing mapping: {len(missing)}")
    if missing:
        for r in missing:
            print(f"  - {r}")
    return 0 if errors == 0 and not missing else 1


if __name__ == "__main__":
    sys.exit(main())
