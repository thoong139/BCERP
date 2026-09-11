#!/usr/bin/env python3
"""dispatcher.py — Generic lane dispatch cho linear workflow skills.

Vai trò:
    Chạy nhiều "lanes" (đường xử lý song song), mỗi lane là 1 agent task
    với prompt, output path, và context riêng. Dùng Semaphore cho
    concurrency control, import concurrency/token_bucket cho backpressure.

    Khác với lane_dispatch.py gốc (QD-specific, 11 dimensions QD1-QD11),
    module này cho phép lanes theo bất kỳ key nào.

Registry role: NONE.

Tham chiếu:
    - ADR-OPT-01: Generic lane dispatch
    - Refactor từ _shared/lane_dispatch.py (QD-specific)
"""
from __future__ import annotations

import argparse
import asyncio
import json
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

# Concurrency (optional — graceful degrade neu import fail)
try:
    from concurrency.token_bucket import TokenBucket3Tier  # noqa: F401
    _TB_AVAILABLE = True
except ImportError:
    _TB_AVAILABLE = False
    TokenBucket3Tier = None  # type: ignore

try:
    from concurrency.backpressure import AdaptiveBackpressure  # noqa: F401
    _BP_AVAILABLE = True
except ImportError:
    _BP_AVAILABLE = False
    AdaptiveBackpressure = None  # type: ignore

# ──────────────────────────────────────────────────────────────────────
# Data classes
# ──────────────────────────────────────────────────────────────────────


@dataclass
class LaneConfig:
    """Cấu hình 1 lane cần chạy.

    Attributes:
        key: Định danh lane (vd: "department-sales", "system-crm").
        agent_type: Loại agent cần spawn (vd: "business-analyst").
        prompt: Prompt gửi cho agent.
        output_path: Path ghi kết quả.
        context: Context data tùy chọn cho lane.
    """

    key: str
    agent_type: str
    prompt: str
    output_path: Path
    context: dict[str, Any] = field(default_factory=dict)


@dataclass
class LaneResult:
    """Kết quả sau khi chạy 1 lane.

    Attributes:
        key: Định danh lane (match LaneConfig.key).
        status: "success" | "error" | "timeout".
        output_path: Path đã ghi kết quả.
        duration_ms: Thời gian chạy (millisecond).
        error: Thông báo lỗi nếu status != "success".
    """

    key: str
    status: str
    output_path: Path
    duration_ms: int
    error: str | None = None


# ──────────────────────────────────────────────────────────────────────
# Core dispatch
# ──────────────────────────────────────────────────────────────────────


async def _run_single_lane(
    lane_config: LaneConfig,
    semaphore: asyncio.Semaphore,
    timeout_sec: int,
    token_bucket: "TokenBucket3Tier | None" = None,
    backpressure: "AdaptiveBackpressure | None" = None,
) -> LaneResult:
    """Chạy 1 lane với semaphore control và timeout.

    Đây là stub implementation — trong thực tế, lane sẽ spawn Agent
    qua Claude Code Agent tool. Module này chỉ cung cấp framework.

    Args:
        lane_config: Cấu hình lane.
        semaphore: Semaphore cho concurrency control.
        timeout_sec: Timeout cho lane.
        token_bucket: TokenBucket3Tier (tùy chọn, graceful degrade).
        backpressure: AdaptiveBackpressure (tùy chọn, graceful degrade).

    Returns:
        LaneResult với status và duration.
    """
    start = time.monotonic()

    # Acquire token bucket trước khi vào semaphore slot
    tb_ctx = None
    if token_bucket is not None:
        try:
            tb_ctx = token_bucket.acquire(
                lane_id=lane_config.key,
                probe_id=lane_config.key,
                timeout_ms=15_000,
            )
            await tb_ctx.__aenter__()
        except Exception:
            tb_ctx = None  # Graceful degrade

    try:
        if backpressure is not None:
            try:
                await backpressure.pre_wait()
                backpressure.start()
            except Exception:
                pass  # Graceful degrade

        async with semaphore:
            try:
                result = await asyncio.wait_for(
                    _execute_lane(lane_config),
                    timeout=timeout_sec,
                )
            except asyncio.TimeoutError:
                elapsed = int((time.monotonic() - start) * 1000)
                return LaneResult(
                    key=lane_config.key,
                    status="timeout",
                    output_path=lane_config.output_path,
                    duration_ms=elapsed,
                    error=f"Timeout sau {timeout_sec}s",
                )
    except Exception as exc:
        elapsed = int((time.monotonic() - start) * 1000)
        return LaneResult(
            key=lane_config.key,
            status="error",
            output_path=lane_config.output_path,
            duration_ms=elapsed,
            error=str(exc),
        )
    finally:
        if backpressure is not None:
            try:
                backpressure.end()
            except Exception:
                pass
        if tb_ctx is not None:
            try:
                await tb_ctx.__aexit__(None, None, None)
            except Exception:
                pass

    elapsed = int((time.monotonic() - start) * 1000)
    return LaneResult(
        key=lane_config.key,
        status=result,
        output_path=lane_config.output_path,
        duration_ms=elapsed,
    )


async def _execute_lane(lane_config: LaneConfig) -> str:
    """Thực thi 1 lane — ghi stub output.

    Trong thực tế, hàm này sẽ được override bởi SKILL.md inline
    để spawn Agent thực sự. Stub tạo output JSON mẫu.
    """
    lane_config.output_path.parent.mkdir(parents=True, exist_ok=True)

    output_data = {
        "$schema": "lane-signal-v1",
        "lane_key": lane_config.key,
        "lane_type": lane_config.context.get("lane_type", "unknown"),
        "items": [],
        "metadata": {
            "agent_type": lane_config.agent_type,
            "profile": lane_config.context.get("profile", "standard"),
        },
    }

    # CORE-035 atomic + sort_keys=True audit_chain checksum determinism (F06.008).
    lane_config.output_path.write_text(
        json.dumps(output_data, indent=2, ensure_ascii=False, sort_keys=True),
        encoding="utf-8",
    )
    return "success"


def dispatch_lanes(
    lanes: list[LaneConfig],
    max_parallel: int = 3,
    timeout_sec: int = 300,
    enable_concurrency: bool = False,
) -> list[LaneResult]:
    """Chạy nhiều lanes song song với concurrency control.

    Args:
        lanes: Danh sách LaneConfig cần chạy.
        max_parallel: Số lanes tối đa chạy đồng thời.
        timeout_sec: Timeout cho mỗi lane (giây).
        enable_concurrency: Bật TokenBucket3Tier + AdaptiveBackpressure
            (mặc định False = zero behavior change).

    Returns:
        Danh sách LaneResult, cùng thứ tự với lanes input.
    """
    if not lanes:
        return []

    semaphore = asyncio.Semaphore(max_parallel)

    # Concurrency primitives (wired defensively — graceful degrade on failure)
    token_bucket = None
    backpressure = None
    if enable_concurrency and _TB_AVAILABLE:
        try:
            token_bucket = TokenBucket3Tier()
        except Exception:
            pass
    if enable_concurrency and _BP_AVAILABLE:
        try:
            backpressure = AdaptiveBackpressure()
        except Exception:
            pass

    async def _dispatch():
        tasks = [
            _run_single_lane(lane, semaphore, timeout_sec,
                             token_bucket, backpressure)
            for lane in lanes
        ]
        return await asyncio.gather(*tasks)

    # Chạy event loop
    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        loop = None

    if loop and loop.is_running():
        # Đã trong async context — dùng nest_asyncio hoặc chạy thread
        import concurrent.futures

        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            results = pool.submit(
                asyncio.run, _dispatch()
            ).result()
    else:
        results = asyncio.run(_dispatch())

    return list(results)


# ──────────────────────────────────────────────────────────────────────
# Lane signal output helpers
# ──────────────────────────────────────────────────────────────────────


def write_lane_signal(
    output_path: Path,
    lane_key: str,
    lane_type: str,
    items: list[dict[str, Any]],
    metadata: dict[str, Any] | None = None,
) -> None:
    """Ghi lane signal output theo schema lane-signal-v1.

    Args:
        output_path: Path ghi file.
        lane_key: Định danh lane.
        lane_type: "department" | "system" | "feature-group" | "spec-type" | "role".
        items: Danh sách items từ lane.
        metadata: Metadata tùy chọn.
    """
    output_path.parent.mkdir(parents=True, exist_ok=True)

    data = {
        "$schema": "lane-signal-v1",
        "lane_key": lane_key,
        "lane_type": lane_type,
        "items": items,
        "metadata": metadata or {},
    }

    # Atomic write — CORE-035 + sort_keys=True audit_chain checksum determinism (F06.008).
    tmp_path = output_path.with_suffix(".json.tmp")
    tmp_path.write_text(
        json.dumps(data, indent=2, ensure_ascii=False, sort_keys=True),
        encoding="utf-8",
    )
    tmp_path.replace(output_path)


def load_lane_signal(path: Path) -> dict[str, Any]:
    """Đọc lane signal từ file.

    Args:
        path: Path đến lane signal JSON.

    Returns:
        Parsed data.

    Raises:
        FileNotFoundError: file không tồn tại.
        ValueError: JSON parse fail.
    """
    if not path.exists():
        raise FileNotFoundError(f"Lane signal không tồn tại: {path}")

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"Lane signal parse fail: {exc}") from exc

    return data


# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> int:
    """CLI: chạy lane dispatch từ config file."""
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="Generic lane dispatcher")
    parser.add_argument(
        "--config",
        required=True,
        type=Path,
        help="Path đến lane config JSON",
    )
    parser.add_argument(
        "--max-parallel",
        type=int,
        default=3,
        help="Max lanes chạy song song",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=300,
        help="Timeout mỗi lane (giây)",
    )

    args = parser.parse_args(argv)

    try:
        config_data = json.loads(args.config.read_text(encoding="utf-8"))
        lanes_raw = config_data.get("lanes", [])

        lanes = [
            LaneConfig(
                key=l["key"],
                agent_type=l["agent_type"],
                prompt=l["prompt"],
                output_path=Path(l["output_path"]),
                context=l.get("context", {}),
            )
            for l in lanes_raw
        ]

        results = dispatch_lanes(lanes, args.max_parallel, args.timeout)

        for r in results:
            print(f"{r.key}: {r.status} ({r.duration_ms}ms)")
            if r.error:
                print(f"  ERROR: {r.error}")

        if any(r.status == "error" for r in results):
            return 1
        return 0

    except Exception as exc:
        print(f"[lane_dispatch ERROR] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
