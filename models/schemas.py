"""
Pydantic models for CodeQuest backend API.
"""

from pydantic import BaseModel, Field
from typing import List, Optional


#  Request Models 

class SubmitRequest(BaseModel):
    challenge_id: str = Field(..., description="ID of the challenge being attempted")
    code: str = Field(..., max_length=10_000, description="C++ source code")


#  Response Models

class TestResult(BaseModel):
    name: str
    passed: bool
    expected: str
    actual: str
    error: Optional[str] = None


class SubmitResponse(BaseModel):
    success: bool
    compiled: bool
    compiler_output: str = ""
    test_results: List[TestResult] = []
    passed_count: int = 0
    total_count: int = 0
    damage: int = 0
    xp_earned: int = 0
    hint: Optional[str] = None


# Challenge Models (mirrors challenges.json)

class TestCase(BaseModel):
    input: str = ""
    expected_output: str
    name: str


class EnemyInfo(BaseModel):
    name: str
    hp: int
    sprite: str


class Challenge(BaseModel):
    id: str
    area: str
    title: str
    difficulty: int = Field(..., ge=1, le=10)
    description: str
    starter_code: str
    test_cases: List[TestCase]
    hints: List[str] = []
    xp_reward: int = 100
    enemy: EnemyInfo
