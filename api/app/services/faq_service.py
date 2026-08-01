import json
import logging
from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path

from app.models.faq import CATEGORY_ORDER, FaqApiItem, FaqApiResponse, FaqFile

logger = logging.getLogger(__name__)

FAQ_FILE_PATH = Path(__file__).resolve().parent.parent / "data" / "faq.json"


class FaqLoadError(Exception):
    """faq.json の読み込み・検証に失敗した場合に送出する"""


@lru_cache(maxsize=1)
def _load_faq_file() -> FaqFile:
    try:
        raw = json.loads(FAQ_FILE_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        logger.error("faq_json_read_failed error_type=%s", type(exc).__name__)
        raise FaqLoadError("failed to read faq.json") from exc

    try:
        faq_file = FaqFile.model_validate(raw)
    except Exception as exc:  # pydantic.ValidationError
        logger.error("faq_json_validation_failed error_type=%s", type(exc).__name__)
        raise FaqLoadError("failed to validate faq.json") from exc

    if faq_file.faq_schema_version != 1:
        logger.warning(
            "faq_schema_version_unexpected version=%s", faq_file.faq_schema_version
        )
    return faq_file


def get_faq_response() -> FaqApiResponse:
    faq_file = _load_faq_file()
    sorted_items = sorted(
        faq_file.items,
        key=lambda i: (CATEGORY_ORDER.index(i.category), i.display_order),
    )
    updated_at = datetime.fromtimestamp(
        FAQ_FILE_PATH.stat().st_mtime, tz=timezone.utc
    ).isoformat()
    return FaqApiResponse(
        faqs=[
            FaqApiItem(id=i.id, category=i.category, question=i.question, answer=i.answer)
            for i in sorted_items
        ],
        updated_at=updated_at,
    )
