"""
Sandboxed C++ compiler service.

Compiles and runs C++ code using g++ with strict resource limits.
"""

import asyncio
import os
import platform
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


async def compile_and_run(code: str, stdin_data: str = "") -> CompileRunResult:
    """
    Compile C++ source code and run the resulting binary.

    Steps:
      1. Write code to a temp file
      2. Compile with g++ -std=c++17
      3. Run the binary with optional stdin
      4. Return structured result

    All operations have strict timeouts to prevent abuse.
    """
    with tempfile.TemporaryDirectory(prefix="codequest_") as tmp_dir:
        src_path = os.path.join(tmp_dir, "solution.cpp")
        # On Windows the exe needs .exe extension
        ext = ".exe" if platform.system() == "Windows" else ""
        exe_path = os.path.join(tmp_dir, f"solution{ext}")

        # Write source file
        with open(src_path, "w", encoding="utf-8") as f:
            f.write(code)

        # ── Step 1: Compile ──────────────────────────────────────
        try:
            comp_proc = await asyncio.create_subprocess_exec(
                _get_gpp_command(), "-std=c++17", "-O1",
                "-o", exe_path, src_path,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            comp_stdout, comp_stderr = await asyncio.wait_for(
                comp_proc.communicate(), timeout=COMPILE_TIMEOUT
            )
        except asyncio.TimeoutError:
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

        if comp_proc.returncode != 0:
            return CompileRunResult(
                compiled=False,
                compiler_output=comp_stderr.decode("utf-8", errors="replace")[:MAX_OUTPUT],
            )

        # ── Step 2: Run ──────────────────────────────────────────
        try:
            run_proc = await asyncio.create_subprocess_exec(
                exe_path,
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            run_stdout, run_stderr = await asyncio.wait_for(
                run_proc.communicate(input=stdin_data.encode("utf-8")),
                timeout=RUN_TIMEOUT,
            )
        except asyncio.TimeoutError:
            return CompileRunResult(
                compiled=True,
                compiler_output="",
                stdout="",
                stderr="Runtime timed out (limit: {}s).".format(RUN_TIMEOUT),
                returncode=-1,
                timed_out=True,
            )

        return CompileRunResult(
            compiled=True,
            compiler_output="",
            stdout=run_stdout.decode("utf-8", errors="replace")[:MAX_OUTPUT],
            stderr=run_stderr.decode("utf-8", errors="replace")[:MAX_OUTPUT],
            returncode=run_proc.returncode,
        )
