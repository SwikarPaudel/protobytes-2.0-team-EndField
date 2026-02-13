"""
Test case evaluator for CodeQuest.

Takes compiler output and compares it against expected test case results.
Calculates damage and XP based on pass rate.
"""

from typing import List, Optional

from models.schemas import Challenge, TestResult
from services.compiler import CompileRunResult, compile_and_run


async def evaluate_submission(
    code: str,
    challenge: Challenge,
) -> dict:
    """
    Evaluate a code submission against all test cases in a challenge.

    Returns a dict matching the SubmitResponse schema.

    Flow:
      1. For each test case, compile & run the code with test input
      2. Compare stdout (stripped) against expected output
      3. Calculate damage & XP proportional to pass rate
      4. Optionally include a hint for partial passes
    """
    test_results: List[TestResult] = []
    passed_count = 0
    total_count = len(challenge.test_cases)

    # We compile once to check for compile errors before running all tests.
    first_result = await compile_and_run(code, challenge.test_cases[0].input if challenge.test_cases else "")

    if not first_result.compiled:
        return {
            "success": False,
            "compiled": False,
            "compiler_output": first_result.compiler_output,
            "test_results": [],
            "passed_count": 0,
            "total_count": total_count,
            "damage": 0,
            "xp_earned": 0,
            "hint": "Fix the compilation errors first!",
        }

    # First test case result
    first_tc = challenge.test_cases[0]
    actual_0 = first_result.stdout.strip()
    expected_0 = first_tc.expected_output.strip()
    passed_0 = actual_0 == expected_0

    if passed_0:
        passed_count += 1

    test_results.append(TestResult(
        name=first_tc.name,
        passed=passed_0,
        expected=expected_0,
        actual=actual_0,
        error=first_result.stderr if first_result.returncode != 0 else None,
    ))

    # Run remaining test cases
    for tc in challenge.test_cases[1:]:
        result = await compile_and_run(code, tc.input)

        if not result.compiled:
            # Shouldn't happen since first compiled ok, but be safe
            test_results.append(TestResult(
                name=tc.name,
                passed=False,
                expected=tc.expected_output.strip(),
                actual="",
                error=result.compiler_output,
            ))
            continue

        actual = result.stdout.strip()
        expected = tc.expected_output.strip()
        passed = actual == expected

        if passed:
            passed_count += 1

        test_results.append(TestResult(
            name=tc.name,
            passed=passed,
            expected=expected,
            actual=actual,
            error=result.stderr if result.returncode != 0 else None,
        ))

    # ── Calculate damage & XP ────────────────────────────────────
    pass_ratio = passed_count / total_count if total_count > 0 else 0
    enemy_hp = challenge.enemy.hp
    damage = int(enemy_hp * pass_ratio)

    difficulty_multiplier = 1.0 + (challenge.difficulty - 1) * 0.15
    xp_earned = int(challenge.xp_reward * pass_ratio * difficulty_multiplier)

    # Provide a hint if partial pass
    hint: Optional[str] = None
    if 0 < passed_count < total_count and challenge.hints:
        hint_index = min(passed_count, len(challenge.hints)) - 1
        hint = challenge.hints[hint_index]
    elif passed_count == 0 and challenge.hints:
        hint = challenge.hints[0]

    success = passed_count == total_count

    return {
        "success": success,
        "compiled": True,
        "compiler_output": "",
        "test_results": test_results,
        "passed_count": passed_count,
        "total_count": total_count,
        "damage": damage,
        "xp_earned": xp_earned,
        "hint": hint,
    }
