#!/usr/bin/env python3
"""Update all agent definition files with extended tool list."""
import re
import os
import sys

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "agents")

NEW_TOOLS = (
    "Read, Write, Edit, Glob, Grep, Bash, Agent, TodoWrite, WebFetch, WebSearch, "
    "mcp__plugin_gitnexus_gitnexus__impact, mcp__plugin_gitnexus_gitnexus__query, "
    "mcp__plugin_gitnexus_gitnexus__context, mcp__plugin_gitnexus_gitnexus__detect_changes, "
    "mcp__plugin_serena_serena__check_onboarding_performed, mcp__plugin_serena_serena__find_symbol, "
    "mcp__plugin_serena_serena__find_referencing_symbols, mcp__plugin_serena_serena__get_symbols_overview, "
    "mcp__plugin_serena_serena__find_declaration, mcp__plugin_serena_serena__find_implementations, "
    "mcp__plugin_serena_serena__search_for_pattern, mcp__plugin_serena_serena__read_file, "
    "mcp__plugin_serena_serena__list_dir, mcp__plugin_serena_serena__replace_content, "
    "mcp__plugin_serena_serena__replace_symbol_body, mcp__plugin_serena_serena__insert_before_symbol, "
    "mcp__plugin_serena_serena__insert_after_symbol, mcp__plugin_serena_serena__rename_symbol, "
    "mcp__plugin_serena_serena__safe_delete_symbol, mcp__plugin_serena_serena__get_diagnostics_for_file, "
    "mcp__plugin_serena_serena__initial_instructions, mcp__plugin_serena_serena__create_text_file, "
    "mcp__plugin_serena_serena__write_memory, mcp__plugin_serena_serena__read_memory, "
    "mcp__plugin_serena_serena__list_memories, mcp__plugin_serena_serena__edit_memory, "
    "mcp__plugin_serena_serena__delete_memory, mcp__plugin_serena_serena__rename_memory, "
    "mcp__plugin_serena_serena__activate_project, mcp__plugin_serena_serena__execute_shell_command, "
    "mcp__plugin_serena_serena__onboarding, mcp__plugin_serena_serena__get_current_config, "
    "mcp__serena__check_onboarding_performed, mcp__serena__find_symbol, "
    "mcp__serena__find_referencing_symbols, mcp__serena__get_symbols_overview, "
    "mcp__serena__replace_content, mcp__serena__replace_symbol_body, "
    "mcp__serena__insert_before_symbol, mcp__serena__insert_after_symbol, "
    "mcp__serena__rename_symbol, mcp__serena__safe_delete_symbol, "
    "mcp__serena__write_memory, mcp__serena__read_memory, mcp__serena__list_memories, "
    "mcp__serena__edit_memory, mcp__serena__delete_memory, mcp__serena__rename_memory, "
    "mcp__serena__onboarding, mcp__serena__initial_instructions, "
    "mcp__plugin_playwright_playwright__browser_navigate, mcp__plugin_playwright_playwright__browser_snapshot, "
    "mcp__plugin_playwright_playwright__browser_take_screenshot, mcp__plugin_playwright_playwright__browser_console_messages, "
    "mcp__plugin_playwright_playwright__browser_network_requests, mcp__plugin_playwright_playwright__browser_network_request, "
    "mcp__plugin_playwright_playwright__browser_click, mcp__plugin_playwright_playwright__browser_type, "
    "mcp__plugin_playwright_playwright__browser_fill_form, mcp__plugin_playwright_playwright__browser_select_option, "
    "mcp__plugin_playwright_playwright__browser_hover, mcp__plugin_playwright_playwright__browser_drag, "
    "mcp__plugin_playwright_playwright__browser_drop, mcp__plugin_playwright_playwright__browser_press_key, "
    "mcp__plugin_playwright_playwright__browser_wait_for, mcp__plugin_playwright_playwright__browser_tabs, "
    "mcp__plugin_playwright_playwright__browser_close, mcp__plugin_playwright_playwright__browser_resize, "
    "mcp__plugin_playwright_playwright__browser_evaluate, mcp__plugin_playwright_playwright__browser_file_upload, "
    "mcp__plugin_playwright_playwright__browser_handle_dialog, mcp__plugin_playwright_playwright__browser_navigate_back, "
    "mcp__plugin_playwright_playwright__browser_run_code_unsafe, "
    "mcp__plugin_context7_context7__resolve-library-id, mcp__plugin_context7_context7__query-docs, "
    "ListMcpResourcesTool, ReadMcpResourceTool"
)

def find_agent_files(base_dir):
    """Find all agent .md files excluding spec, procedures, and README."""
    agents = []
    for team in ["business", "engineering", "design", "testing", "review"]:
        team_dir = os.path.join(base_dir, team)
        if not os.path.isdir(team_dir):
            continue
        for f in sorted(os.listdir(team_dir)):
            if f.endswith(".md") and f != "README.md":
                agents.append(os.path.join(team_dir, f))
    # Add orchestrator
    orch = os.path.join(base_dir, "orchestrator.md")
    if os.path.exists(orch):
        agents.append(orch)
    return agents


def update_file(filepath):
    """Update the tools line in a single agent file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    new_content = re.sub(
        r'^tools:.*$',
        f'tools: {NEW_TOOLS}',
        content,
        count=1,
        flags=re.MULTILINE
    )

    if new_content == content:
        return False, "NO MATCH"

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)
    return True, "OK"


def main():
    base = os.path.normpath(BASE)
    if not os.path.isdir(base):
        print(f"ERROR: directory not found: {base}")
        sys.exit(1)

    agent_files = find_agent_files(base)
    print(f"Found {len(agent_files)} agent files")

    updated = 0
    errors = []
    skipped_spec = 0

    for filepath in agent_files:
        # Skip spec directory
        if os.path.sep + "spec" + os.path.sep in filepath:
            skipped_spec += 1
            continue

        ok, msg = update_file(filepath)
        if ok:
            rel = os.path.relpath(filepath, base)
            print(f"  UPDATED: {rel}")
            updated += 1
        else:
            errors.append((filepath, msg))

    print(f"\n--- Summary ---")
    print(f"Updated: {updated}")
    print(f"Skipped (spec): {skipped_spec}")
    if errors:
        print(f"Errors ({len(errors)}):")
        for fp, msg in errors:
            print(f"  {msg}: {os.path.relpath(fp, base)}")

if __name__ == "__main__":
    main()
