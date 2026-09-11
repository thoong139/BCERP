#!/usr/bin/env python3
"""stack_detector — Detect tech stack(s) cua target project.

Phase B cua wf-fix-bugs Coverage Improvement v8.

Strategy:
1. Scan target directory for known config files (package.json, *.csproj, etc.)
2. Parse each config to extract framework hints
3. Rank stacks by confidence + presence in source dir
4. Output: stack-info-v1 JSON

Registry role: NONE.
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional

__version__ = "1.0.0"

# Stack identifier mapping — chuan hoa cho coverage_estimator + lane_dispatch.
KNOWN_STACKS = {
    "csharp-dotnet",
    "typescript-react",
    "typescript-nextjs",
    "javascript-react",
    "vue",
    "python-fastapi",
    "python-django",
    "go",
    "java-spring",
    "rust",
    "unknown",
}

# Limit search depth de tranh quet sau qua nested.
DEFAULT_MAX_DEPTH = 4
# Khi count files in stack, gioi han de tranh slowdown.
MAX_FILES_PER_STACK = 200


@dataclass
class StackEvidence:
    """Bang chung detection cho 1 stack."""
    config_files: List[str] = field(default_factory=list)
    frameworks: List[str] = field(default_factory=list)
    file_count: int = 0


@dataclass
class StackDetectionResult:
    """Output cua stack detection."""
    schema: str = "stack-info-v1"
    primary_stack: str = "unknown"
    secondary_stacks: List[str] = field(default_factory=list)
    frameworks: List[str] = field(default_factory=list)
    confidence: str = "low"  # high | medium | low
    evidence: Dict[str, StackEvidence] = field(default_factory=dict)
    target_dir: str = ""
    version: str = __version__

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        # Convert evidence dataclasses to dict
        d["evidence"] = {k: asdict(v) for k, v in self.evidence.items()}
        return d


def _safe_read_text(path: Path, max_bytes: int = 256_000) -> str:
    """Read text safely, gioi han kich thuoc."""
    try:
        if path.stat().st_size > max_bytes:
            return path.read_text(encoding="utf-8", errors="ignore")[:max_bytes]
        return path.read_text(encoding="utf-8", errors="ignore")
    except (OSError, UnicodeDecodeError):
        return ""


def _find_package_jsons(target: Path, max_depth: int = 3) -> List[Path]:
    """Find all package.json files within max_depth levels (excluding node_modules).

    Monorepo support: e.g., apps/web/package.json, apps/api/package.json.
    """
    skip_dirs = {"node_modules", ".git", "dist", "build", ".next", ".nuxt", ".cache"}
    found: List[Path] = []

    def walk(p: Path, depth: int) -> None:
        if depth > max_depth:
            return
        for child in p.iterdir():
            if child.name in skip_dirs:
                continue
            if child.is_file() and child.name == "package.json":
                found.append(child)
            elif child.is_dir():
                walk(child, depth + 1)

    try:
        walk(target, 0)
    except (OSError, PermissionError):
        pass
    return found


def _detect_typescript_javascript(target: Path, evidence: Dict[str, StackEvidence]) -> List[str]:
    """Detect TS/JS stacks via package.json (recursive for monorepos). Return list of stack ids."""
    pkg_jsons = _find_package_jsons(target)
    if not pkg_jsons:
        return []

    # Aggregate deps + tsconfig presence across all package.json files.
    deps: Dict[str, str] = {}
    has_ts = False
    config_files_found: List[str] = []
    for pkg_json in pkg_jsons:
        text = _safe_read_text(pkg_json)
        if not text:
            continue
        try:
            data = json.loads(text)
        except json.JSONDecodeError:
            continue
        for key in ("dependencies", "devDependencies", "peerDependencies"):
            if isinstance(data.get(key), dict):
                deps.update(data[key])
        config_files_found.append(str(pkg_json.relative_to(target)))
        # Check for tsconfig.json in same dir
        if (pkg_json.parent / "tsconfig.json").is_file():
            has_ts = True

    # Also check root tsconfig.json
    if (target / "tsconfig.json").is_file():
        has_ts = True
    if "typescript" in deps:
        has_ts = True

    detected: List[str] = []
    frameworks: List[str] = []

    if "next" in deps:
        stack = "typescript-nextjs" if has_ts else "javascript-react"
        detected.append(stack)
        frameworks.append("nextjs")
        if "react" in deps:
            frameworks.append("react")
    elif "react" in deps:
        stack = "typescript-react" if has_ts else "javascript-react"
        detected.append(stack)
        frameworks.append("react")
    elif any(k in deps for k in ("vue", "@vue/cli-service", "nuxt")):
        detected.append("vue")
        if "vue" in deps:
            frameworks.append("vue")
        if "nuxt" in deps:
            frameworks.append("nuxt")

    # NestJS or Express on TS = typescript-react fallback (no specific id).
    # Can mark "typescript-node" in future. For now, classify as best fit.
    if not detected and has_ts:
        if "@nestjs/core" in deps:
            frameworks.append("nestjs")
        if "express" in deps:
            frameworks.append("express")

    # Additional framework hints
    if "@tanstack/react-query" in deps or "react-query" in deps:
        frameworks.append("tanstack-query")
    if "next-intl" in deps:
        frameworks.append("next-intl")
    if "zod" in deps:
        frameworks.append("zod")
    if "react-hook-form" in deps:
        frameworks.append("react-hook-form")

    # Record evidence
    if detected:
        for stack in detected:
            ev = evidence.setdefault(stack, StackEvidence())
            ev.config_files.extend(config_files_found)
            ev.frameworks.extend(frameworks)
            # Dedup
            ev.config_files = sorted(set(ev.config_files))
            ev.frameworks = sorted(set(ev.frameworks))
    return detected


def _detect_csharp(target: Path, evidence: Dict[str, StackEvidence]) -> List[str]:
    """Detect C# .NET via *.csproj or *.sln. Return [csharp-dotnet] if found."""
    csproj_files = list(target.rglob("*.csproj"))[:5]
    sln_files = list(target.rglob("*.sln"))[:3]

    if not csproj_files and not sln_files:
        return []

    ev = evidence.setdefault("csharp-dotnet", StackEvidence())
    for p in csproj_files:
        ev.config_files.append(str(p.relative_to(target)))
        text = _safe_read_text(p)
        if "Microsoft.AspNetCore" in text:
            ev.frameworks.append("aspnetcore")
        if "MediatR" in text:
            ev.frameworks.append("mediatr")
        if "EntityFramework" in text or "Microsoft.EntityFrameworkCore" in text:
            ev.frameworks.append("ef-core")
        if "FluentValidation" in text:
            ev.frameworks.append("fluentvalidation")
    for p in sln_files:
        ev.config_files.append(str(p.relative_to(target)))
    # Dedup frameworks
    ev.frameworks = sorted(set(ev.frameworks))
    return ["csharp-dotnet"]


def _detect_python(target: Path, evidence: Dict[str, StackEvidence]) -> List[str]:
    """Detect Python via pyproject.toml / requirements.txt. Return list of stack ids."""
    pyproject = target / "pyproject.toml"
    requirements = target / "requirements.txt"

    if not pyproject.is_file() and not requirements.is_file():
        return []

    text = ""
    if pyproject.is_file():
        text += _safe_read_text(pyproject)
    if requirements.is_file():
        text += "\n" + _safe_read_text(requirements)

    if not text.strip():
        return []

    detected: List[str] = []
    frameworks: List[str] = []
    text_lower = text.lower()

    if "fastapi" in text_lower:
        detected.append("python-fastapi")
        frameworks.append("fastapi")
    if "django" in text_lower:
        detected.append("python-django")
        frameworks.append("django")

    # Generic — cover py without specific framework
    if not detected:
        # Check if it's a non-framework Python project
        if any(token in text_lower for token in ("pytest", "setuptools", "poetry", "[tool.poetry]")):
            detected.append("python-fastapi")  # default fallback for Python — neutral

    # Common libs
    if "sqlalchemy" in text_lower:
        frameworks.append("sqlalchemy")
    if "pydantic" in text_lower:
        frameworks.append("pydantic")
    if "celery" in text_lower:
        frameworks.append("celery")

    if detected:
        for stack in detected:
            ev = evidence.setdefault(stack, StackEvidence())
            if pyproject.is_file():
                ev.config_files.append("pyproject.toml")
            if requirements.is_file():
                ev.config_files.append("requirements.txt")
            ev.frameworks.extend(frameworks)
            ev.frameworks = sorted(set(ev.frameworks))
    return detected


def _detect_go(target: Path, evidence: Dict[str, StackEvidence]) -> List[str]:
    """Detect Go via go.mod."""
    go_mod = target / "go.mod"
    if not go_mod.is_file():
        return []

    text = _safe_read_text(go_mod)
    ev = evidence.setdefault("go", StackEvidence())
    ev.config_files.append("go.mod")

    text_lower = text.lower()
    if "github.com/gin-gonic/gin" in text_lower:
        ev.frameworks.append("gin")
    if "github.com/labstack/echo" in text_lower:
        ev.frameworks.append("echo")
    if "github.com/gofiber/fiber" in text_lower:
        ev.frameworks.append("fiber")
    if "gorm.io/gorm" in text_lower:
        ev.frameworks.append("gorm")
    ev.frameworks = sorted(set(ev.frameworks))
    return ["go"]


def _detect_java(target: Path, evidence: Dict[str, StackEvidence]) -> List[str]:
    """Detect Java via pom.xml (Maven) or build.gradle (Gradle)."""
    pom = target / "pom.xml"
    gradle = target / "build.gradle"
    gradle_kts = target / "build.gradle.kts"

    if not pom.is_file() and not gradle.is_file() and not gradle_kts.is_file():
        return []

    text = ""
    config_files: List[str] = []
    if pom.is_file():
        text += _safe_read_text(pom)
        config_files.append("pom.xml")
    if gradle.is_file():
        text += "\n" + _safe_read_text(gradle)
        config_files.append("build.gradle")
    if gradle_kts.is_file():
        text += "\n" + _safe_read_text(gradle_kts)
        config_files.append("build.gradle.kts")

    text_lower = text.lower()

    ev = evidence.setdefault("java-spring", StackEvidence())
    ev.config_files.extend(config_files)

    if "spring-boot" in text_lower or "springframework" in text_lower:
        ev.frameworks.append("spring-boot")
    if "hibernate" in text_lower:
        ev.frameworks.append("hibernate")
    if "spring-data-jpa" in text_lower:
        ev.frameworks.append("spring-data-jpa")
    ev.frameworks = sorted(set(ev.frameworks))
    return ["java-spring"]


def _detect_rust(target: Path, evidence: Dict[str, StackEvidence]) -> List[str]:
    """Detect Rust via Cargo.toml."""
    cargo = target / "Cargo.toml"
    if not cargo.is_file():
        return []
    ev = evidence.setdefault("rust", StackEvidence())
    ev.config_files.append("Cargo.toml")
    text = _safe_read_text(cargo).lower()
    if "actix-web" in text:
        ev.frameworks.append("actix-web")
    if "axum" in text:
        ev.frameworks.append("axum")
    if "rocket" in text:
        ev.frameworks.append("rocket")
    ev.frameworks = sorted(set(ev.frameworks))
    return ["rust"]


def _count_source_files(target: Path, stacks: List[str]) -> Dict[str, int]:
    """Count source files per stack to disambiguate primary vs secondary."""
    extensions: Dict[str, List[str]] = {
        "csharp-dotnet": [".cs"],
        "typescript-react": [".ts", ".tsx"],
        "typescript-nextjs": [".ts", ".tsx"],
        "javascript-react": [".js", ".jsx"],
        "vue": [".vue"],
        "python-fastapi": [".py"],
        "python-django": [".py"],
        "go": [".go"],
        "java-spring": [".java"],
        "rust": [".rs"],
    }

    counts: Dict[str, int] = {s: 0 for s in stacks}

    skip_dirs = {"node_modules", ".git", "__pycache__", ".venv", "venv", "dist", "build",
                 "target", "bin", "obj", "out", ".next", ".nuxt", ".cache"}

    for stack in stacks:
        exts = extensions.get(stack, [])
        if not exts:
            continue
        count = 0
        for ext in exts:
            for p in target.rglob(f"*{ext}"):
                # Skip if in excluded dir
                if any(part in skip_dirs for part in p.parts):
                    continue
                count += 1
                if count >= MAX_FILES_PER_STACK:
                    break
            if count >= MAX_FILES_PER_STACK:
                break
        counts[stack] = count
    return counts


def _determine_confidence(
    stacks: List[str], file_counts: Dict[str, int]
) -> str:
    """Confidence level dua tren so stacks + file counts."""
    if not stacks or stacks == ["unknown"]:
        return "low"
    primary = stacks[0]
    primary_count = file_counts.get(primary, 0)
    if primary_count >= 50:
        return "high"
    if primary_count >= 10:
        return "medium"
    return "low"


def detect_stack(target_dir: str | Path) -> StackDetectionResult:
    """Detect tech stack(s) trong target directory.

    Args:
        target_dir: Path to project root (chua package.json/csproj/etc.).

    Returns:
        StackDetectionResult with primary_stack + secondary_stacks + evidence.
    """
    target = Path(target_dir).resolve()
    result = StackDetectionResult(target_dir=str(target))

    if not target.is_dir():
        return result  # Returns "unknown" defaults

    evidence: Dict[str, StackEvidence] = {}

    # Run all detectors
    all_detected: List[str] = []
    all_detected.extend(_detect_typescript_javascript(target, evidence))
    all_detected.extend(_detect_csharp(target, evidence))
    all_detected.extend(_detect_python(target, evidence))
    all_detected.extend(_detect_go(target, evidence))
    all_detected.extend(_detect_java(target, evidence))
    all_detected.extend(_detect_rust(target, evidence))

    # Dedup
    seen: set[str] = set()
    detected: List[str] = []
    for s in all_detected:
        if s not in seen:
            seen.add(s)
            detected.append(s)

    if not detected:
        return result

    # Count source files to determine primary
    file_counts = _count_source_files(target, detected)
    for stack, count in file_counts.items():
        if stack in evidence:
            evidence[stack].file_count = count

    # Sort by file count desc, then alphabetically for stability
    detected.sort(key=lambda s: (-file_counts.get(s, 0), s))

    result.primary_stack = detected[0]
    result.secondary_stacks = detected[1:]
    result.confidence = _determine_confidence(detected, file_counts)

    # Aggregate frameworks
    all_frameworks: List[str] = []
    for stack_evidence in evidence.values():
        all_frameworks.extend(stack_evidence.frameworks)
    result.frameworks = sorted(set(all_frameworks))
    result.evidence = evidence

    return result


def detect_stack_from_dir(target_dir: str | Path, output_path: Optional[str | Path] = None) -> StackDetectionResult:
    """Detect + (optionally) write stack-info.json."""
    result = detect_stack(target_dir)
    if output_path:
        out = Path(output_path)
        out.parent.mkdir(parents=True, exist_ok=True)
        with out.open("w", encoding="utf-8") as f:
            # CORE-035 atomic + sort_keys=True audit_chain checksum determinism (F06.008).
            json.dump(result.to_dict(), f, indent=2, ensure_ascii=False, sort_keys=True)
    return result


def main(argv: List[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Detect tech stack(s) in target dir.")
    parser.add_argument("--target", required=True, help="Target directory to scan.")
    parser.add_argument("--output", help="Output JSON path (default: $target/stack-info.json).")
    parser.add_argument("--print", action="store_true", help="Print result to stdout.")
    args = parser.parse_args(argv)

    target = Path(args.target)
    if not target.is_dir():
        print(f"ERROR: target dir khong ton tai: {target}", file=sys.stderr)
        return 2

    output_path = Path(args.output) if args.output else target / "stack-info.json"
    result = detect_stack_from_dir(target, output_path)

    if args.print:
        try:
            sys.stdout.reconfigure(encoding="utf-8")
        except (AttributeError, OSError):
            pass
        try:
            print(json.dumps(result.to_dict(), indent=2, ensure_ascii=False))
        except UnicodeEncodeError:
            print(json.dumps(result.to_dict(), indent=2, ensure_ascii=True))
    else:
        print(f"Primary stack: {result.primary_stack} "
              f"({result.confidence} confidence) -> {output_path}")
        if result.secondary_stacks:
            print(f"  Secondary: {', '.join(result.secondary_stacks)}")
        if result.frameworks:
            print(f"  Frameworks: {', '.join(result.frameworks)}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
