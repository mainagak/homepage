from datetime import datetime, timezone

from fastapi import APIRouter

router = APIRouter(tags=["health"])  # プレフィックスなし(internal-spec-vercel.md 0.1節参照)


@router.get("/health")
def get_health():
    return {
        "status": "ok",
        "service": "homepage-api",
        "time": datetime.now(timezone.utc).isoformat(),
    }
