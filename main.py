
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers.submit import router as submit_router

app = FastAPI(
    title="CodeQuest API",
    description="Backend for the CodeQuest RPG educational game. "
                "Compiles C++ code, evaluates test cases, and returns battle results.",
    version="1.0.0",
)

# ── CORS — allow Godot client and local dev tools ────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],          # Restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Register routers ────────────────────────────────────────────
app.include_router(submit_router, tags=["Game"])


# ── Health check ─────────────────────────────────────────────────
@app.get("/", tags=["Health"])
async def health():
    return {"status": "ok", "game": "CodeQuest", "version": "1.0.0"}
