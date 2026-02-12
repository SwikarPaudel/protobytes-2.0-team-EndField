"""
Router: /submit and /challenges endpoints.

Handles code submission, challenge listing, and individual challenge retrieval.
"""

import json
import os
from typing import List

from fastapi import APIRouter, HTTPException

from models.schemas import Challenge, SubmitRequest, SubmitResponse
from services.evaluator import evaluate_submission

router = APIRouter()

# ── Load challenges at module import time ────────────────────────
CHALLENGES_PATH = os.path.join(
    os.path.dirname(os.path.dirname(__file__)),
    "challenges",
    "challenges.json",
)

_challenges_cache: List[Challenge] = []


def _load_challenges() -> List[Challenge]:
    global _challenges_cache
    if not _challenges_cache:
        with open(CHALLENGES_PATH, "r", encoding="utf-8") as f:
            raw = json.load(f)
        _challenges_cache = [Challenge(**c) for c in raw]
    return _challenges_cache


def _find_challenge(challenge_id: str) -> Challenge:
    for c in _load_challenges():
        if c.id == challenge_id:
            return c
    raise HTTPException(status_code=404, detail=f"Challenge '{challenge_id}' not found")


# ── Endpoints ────────────────────────────────────────────────────

@router.post("/submit", response_model=SubmitResponse)
async def submit_code(req: SubmitRequest):
    """
    Submit C++ code for evaluation against a challenge's test cases.

    Returns compilation status, per-test results, damage dealt, and XP earned.
    """
    challenge = _find_challenge(req.challenge_id)

    # ── Basic code safety filter (hackathon-grade) ───────────────
    dangerous_patterns = [
        "system(", "popen(", "fork(", "exec(",
        "#include <fstream>", "remove(", "rename(",
    ]
    code_lower = req.code.lower()
    for pattern in dangerous_patterns:
        if pattern.lower() in code_lower:
            return SubmitResponse(
                success=False,
                compiled=False,
                compiler_output=f"Forbidden pattern detected: {pattern}",
                passed_count=0,
                total_count=len(challenge.test_cases),
                damage=0,
                xp_earned=0,
                hint="Some system calls are restricted for safety.",
            )

    result = await evaluate_submission(req.code, challenge)
    return SubmitResponse(**result)


@router.get("/challenges", response_model=List[Challenge])
async def list_challenges():
    """Return all available challenges."""
    return _load_challenges()


@router.get("/challenge/{challenge_id}", response_model=Challenge)
async def get_challenge(challenge_id: str):
    """Return a single challenge by ID."""
    return _find_challenge(challenge_id)
