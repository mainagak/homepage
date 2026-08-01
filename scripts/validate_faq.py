"""FAQ JSON データファイルのバリデーションスクリプト。

`docs/specs/internal-spec-datamodel.md` 2.3節・2.4節が定義するフィールド定義・
バリデーションルールを実装する。同ドキュメント2.5節の運用(MVP〜FAQ管理GUI完成までは
Claude Codeが `api/app/data/faq.json` を直接編集する)における、手動編集後の検証用
ツールとして使うことを目的とする。

FastAPI側(api/app/models/faq.py、Vercel側実装タスクの担当領域)のPydanticモデルとは
独立したスタンドアロン実装であり、Python標準ライブラリのみに依存する(外部ライブラリ不要)。
ここでの検証ルールと将来のPydanticモデルの検証ルールは、同じ仕様書(2.3節・2.4節)を
出典とするため一致するはずだが、実装自体は重複させない設計(こちらはデータファイル単体の
妥当性検証、Pydantic側はAPI応答への変換も兼ねる)。

CLIとしての使い方:
    python scripts/validate_faq.py api/app/data/faq.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

FAQ_ID_PATTERN = re.compile(r"^faq-\d{4}$")
ALLOWED_CATEGORIES = ("書籍について", "仕事の相談", "会社について")
DISALLOWED_CHARS = ("<", ">")
QUESTION_MAX_LEN = 100
ANSWER_MAX_LEN = 1000
REQUIRED_TOP_LEVEL_KEYS = ("faq_schema_version", "items")
REQUIRED_ITEM_KEYS = ("id", "category", "question", "answer", "display_order")
SUPPORTED_SCHEMA_VERSION = 1


class FaqValidationError(ValueError):
    """faq.jsonの内容がスキーマ・バリデーションルールに違反する場合に送出する。"""


def validate_faq_data(data: Any) -> None:
    """パース済みのfaq.json内容(dict想定)を検証する。

    違反があれば `FaqValidationError` を送出する。問題なければ何も返さない。
    """
    if not isinstance(data, dict):
        raise FaqValidationError("top-level JSON value must be an object")

    missing = [key for key in REQUIRED_TOP_LEVEL_KEYS if key not in data]
    if missing:
        raise FaqValidationError(f"missing required top-level key(s): {missing}")

    if data["faq_schema_version"] != SUPPORTED_SCHEMA_VERSION:
        raise FaqValidationError(
            "faq_schema_version must be "
            f"{SUPPORTED_SCHEMA_VERSION}, got {data['faq_schema_version']!r}"
        )

    items = data["items"]
    if not isinstance(items, list):
        raise FaqValidationError("items must be an array")

    seen_ids: set[str] = set()
    seen_display_orders: dict[str, set[int]] = {}

    for index, item in enumerate(items):
        _validate_item(item, index)

        item_id = item["id"]
        if item_id in seen_ids:
            raise FaqValidationError(f"duplicate id: {item_id!r}")
        seen_ids.add(item_id)

        category = item["category"]
        display_order = item["display_order"]
        orders_for_category = seen_display_orders.setdefault(category, set())
        if display_order in orders_for_category:
            raise FaqValidationError(
                f"duplicate display_order {display_order!r} within category {category!r}"
            )
        orders_for_category.add(display_order)


def _validate_item(item: Any, index: int) -> None:
    if not isinstance(item, dict):
        raise FaqValidationError(f"items[{index}] must be an object")

    missing = [key for key in REQUIRED_ITEM_KEYS if key not in item]
    if missing:
        raise FaqValidationError(f"items[{index}] missing required key(s): {missing}")

    item_id = item["id"]
    if not isinstance(item_id, str) or not FAQ_ID_PATTERN.match(item_id):
        raise FaqValidationError(
            f"items[{index}].id must match ^faq-\\d{{4}}$, got {item_id!r}"
        )

    category = item["category"]
    if category not in ALLOWED_CATEGORIES:
        raise FaqValidationError(
            f"items[{index}].category must be one of {ALLOWED_CATEGORIES}, got {category!r}"
        )

    _validate_text_field(item["question"], "question", index, QUESTION_MAX_LEN)
    _validate_text_field(item["answer"], "answer", index, ANSWER_MAX_LEN)

    display_order = item["display_order"]
    if (
        isinstance(display_order, bool)
        or not isinstance(display_order, int)
        or display_order <= 0
    ):
        raise FaqValidationError(
            f"items[{index}].display_order must be a positive integer, got {display_order!r}"
        )


def _validate_text_field(value: Any, field_name: str, index: int, max_len: int) -> None:
    if not isinstance(value, str) or not (1 <= len(value) <= max_len):
        raise FaqValidationError(
            f"items[{index}].{field_name} must be a string of length 1..{max_len}"
        )
    if any(char in value for char in DISALLOWED_CHARS):
        raise FaqValidationError(f"items[{index}].{field_name} must not contain '<' or '>'")


def validate_faq_file(path: Path) -> None:
    """指定したパスのfaq.jsonファイルを読み込み、検証する。"""
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise FaqValidationError(f"failed to read {path}: {exc}") from exc

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise FaqValidationError(f"invalid JSON in {path}: {exc}") from exc

    validate_faq_data(data)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate a faq.json file against docs/specs/internal-spec-datamodel.md 2.3/2.4."
    )
    parser.add_argument("path", type=Path, help="path to faq.json")
    args = parser.parse_args(argv)

    try:
        validate_faq_file(args.path)
    except FaqValidationError as exc:
        print(f"INVALID: {exc}", file=sys.stderr)
        return 1

    print(f"OK: {args.path} is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
