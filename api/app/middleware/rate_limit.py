from collections import defaultdict
from time import time

from fastapi import HTTPException, Request

from app.core.request_utils import get_client_ip

_WINDOW_SECONDS = 300  # 5分。contact.cgi側の重複送信判定・HMACトークン有効期限と同じ値を
                        # 採用し、保守者が覚える時間定数を1つに揃える(保守性重視)
_buckets: dict[str, list[float]] = defaultdict(list)


def _check(key: str, limit: int) -> None:
    now = time()
    window_start = now - _WINDOW_SECONDS
    bucket = _buckets[key]
    while bucket and bucket[0] < window_start:
        bucket.pop(0)
    if len(bucket) >= limit:
        raise HTTPException(status_code=429, detail={"reason": "rate_limited"})
    bucket.append(now)


def rate_limit_recaptcha(request: Request) -> None:
    ip = get_client_ip(request) or "unknown"
    _check(f"recaptcha:{ip}", limit=10)  # 5分あたり10回まで


def rate_limit_faq(request: Request) -> None:
    ip = get_client_ip(request) or "unknown"
    _check(f"faq:{ip}", limit=60)  # 5分あたり60回まで(通常のウィジェット開閉操作を妨げない値)
