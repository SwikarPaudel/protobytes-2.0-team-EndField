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


_recent_challenges: dict = {}

@router.get("/challenge/random/{difficulty}", response_model=Challenge)
async def get_random_challenge(difficulty: str):
    """Get a random challenge, avoiding recently used ones."""
    import random

    all_matching = [
        c for c in _load_challenges()
        if c.difficulty.lower() == difficulty.lower()
    ]

    if not all_matching:
        raise HTTPException(404, f"No challenges for {difficulty}")

    # Get recent IDs for this difficulty
    recent = _recent_challenges.get(difficulty, [])

    # Filter out recently used challenges
    available = [c for c in all_matching if c.id not in recent]

    # If all have been used, reset
    if not available:
        available = all_matching
        recent = []

    # Pick random challenge
    chosen = random.choice(available)

    # Track it (keep last 3 per difficulty)
    recent.append(chosen.id)
    if len(recent) > 3:
        recent.pop(0)
    _recent_challenges[difficulty] = recent

    return chosen


@router.get("/challenge/{challenge_id}", response_model=Challenge)
async def get_challenge(challenge_id: str):
    """Return a single challenge by ID."""
    return _find_challenge(challenge_id)