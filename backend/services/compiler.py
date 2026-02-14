"""
Sandboxed C++ compiler service.

Compiles and runs C++ code using g++ with strict resource limits.

Uses subprocess.run inside asyncio.to_thread so it works on Windows
regardless of the event loop policy (uvicorn forces SelectorEventLoop
which does not support asyncio.create_subprocess_exec).
"""

import asyncio
import os
import platform
import subprocess
import tempfile
from dataclasses import dataclass
from typing import Optional


COMPILE_TIMEOUT = 10  # seconds
RUN_TIMEOUT = 5       # seconds
MAX_OUTPUT = 10_000   # characters


@dataclass
class CompileRunResult:
    compiled: bool
    compiler_output: str = ""
    stdout: str = ""
    stderr: str = ""
    returncode: int = -1
    timed_out: bool = False


def _get_gpp_command() -> str:
    """Return the g++ command appropriate for the platform."""
    return "g++"


def _compile_and_run_sync(code: str, stdin_data: str = "") -> CompileRunResult:
    """Synchronous compile-and-run (runs inside a thread)."""
    with tempfile.TemporaryDirectory(prefix="codequest_") as tmp_dir:
        src_path = os.path.join(tmp_dir, "solution.cpp")
        ext = ".exe" if platform.system() == "Windows" else ""
        exe_path = os.path.join(tmp_dir, f"solution{ext}")

        with open(src_path, "w", encoding="utf-8") as f:
            f.write(code)

        # ── Step 1: Compile ──────────────────────────────────────
        try:
            comp = subprocess.run(
                [_get_gpp_command(), "-std=c++17", "-O1", "-o", exe_path, src_path],
                capture_output=True,
                timeout=COMPILE_TIMEOUT,
            )
        except subprocess.TimeoutExpired:
            return CompileRunResult(
                compiled=False,
                compiler_output="Compilation timed out.",
                timed_out=True,
            )
        except FileNotFoundError:
            return CompileRunResult(
                compiled=False,
                compiler_output="g++ not found. Please install MinGW / g++.",
            )

        if comp.returncode != 0:
            return CompileRunResult(
                compiled=False,
                compiler_output=comp.stderr.decode("utf-8", errors="replace")[:MAX_OUTPUT],
            )

        # ── Step 2: Run ──────────────────────────────────────────
        try:
            run = subprocess.run(
                [exe_path],
                input=stdin_data.encode("utf-8"),
                capture_output=True,
                timeout=RUN_TIMEOUT,
            )
        except subprocess.TimeoutExpired:
            return CompileRunResult(
                compiled=True,
                compiler_output="",
                stdout="",
                stderr=f"Runtime timed out (limit: {RUN_TIMEOUT}s).",
                returncode=-1,
                timed_out=True,
            )

        return CompileRunResult(
            compiled=True,
            compiler_output="",
            stdout=run.stdout.decode("utf-8", errors="replace")[:MAX_OUTPUT],
            stderr=run.stderr.decode("utf-8", errors="replace")[:MAX_OUTPUT],
            returncode=run.returncode,
        )


async def compile_and_run(code: str, stdin_data: str = "") -> CompileRunResult:
    """
    Compile C++ source code and run the resulting binary.

    Delegates to a synchronous helper via asyncio.to_thread so subprocess
    calls work on any event loop (including Windows SelectorEventLoop).
    """
    return await asyncio.to_thread(_compile_and_run_sync, code, stdin_data)
