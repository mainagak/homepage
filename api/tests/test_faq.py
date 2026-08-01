import json

import pytest
from pydantic import ValidationError

from app.models.faq import FaqFile, FaqFileItem
from app.services import faq_service

BOOK = "書籍について"
WORK = "仕事の相談"
COMPANY = "会社について"


def _faq_payload(items):
    return {"faq_schema_version": 1, "items": items}


def _item(id_, category, order, question="質問", answer="回答"):
    return {
        "id": id_,
        "category": category,
        "question": question,
        "answer": answer,
        "display_order": order,
    }


# 1: items: [] のとき200かつ{"faqs": [], "updated_at": "..."}
def test_empty_faq_list_returns_200_with_empty_faqs(client, write_faq_file):
    write_faq_file(_faq_payload([]))
    resp = client.get("/api/faq")
    assert resp.status_code == 200
    body = resp.json()
    assert body["faqs"] == []
    assert "updated_at" in body


# 2: 複数件・複数カテゴリのとき、カテゴリ固定順→display_order昇順で返る
def test_multiple_items_sorted_by_category_then_display_order(client, write_faq_file):
    items = [
        _item("faq-0002", WORK, 1),
        _item("faq-0001", BOOK, 2),
        _item("faq-0003", BOOK, 1),
        _item("faq-0004", COMPANY, 1),
    ]
    write_faq_file(_faq_payload(items))
    resp = client.get("/api/faq")
    ids = [f["id"] for f in resp.json()["faqs"]]
    assert ids == ["faq-0003", "faq-0001", "faq-0002", "faq-0004"]


# 3: レスポンスの各項目にid/category/question/answerのみ含まれdisplay_orderが含まれない
def test_response_item_fields_exclude_display_order(client, write_faq_file):
    write_faq_file(_faq_payload([_item("faq-0001", BOOK, 1)]))
    resp = client.get("/api/faq")
    item = resp.json()["faqs"][0]
    assert set(item.keys()) == {"id", "category", "question", "answer"}


# 4: レスポンスヘッダーにCache-Control: no-storeが付与される
def test_cache_control_no_store_header(client, write_faq_file):
    write_faq_file(_faq_payload([]))
    resp = client.get("/api/faq")
    assert resp.headers["cache-control"] == "no-store"


# 5: 許可オリジンからのfetch相当リクエストでAccess-Control-Allow-Originヘッダーが返る
def test_cors_allowed_origin_echoed(client, write_faq_file):
    write_faq_file(_faq_payload([]))
    resp = client.get(
        "/api/faq", headers={"Origin": "https://jyoho1.web.cyberhome.ne.jp"}
    )
    assert (
        resp.headers.get("access-control-allow-origin")
        == "https://jyoho1.web.cyberhome.ne.jp"
    )


# 6: 許可外オリジンではAccess-Control-Allow-Originヘッダーが返らない(または値が一致しない)
def test_cors_disallowed_origin_not_echoed(client, write_faq_file):
    write_faq_file(_faq_payload([]))
    resp = client.get("/api/faq", headers={"Origin": "https://evil.example.com"})
    assert resp.headers.get("access-control-allow-origin") != "https://evil.example.com"


# 7: faq.jsonが存在しない/壊れたJSON/スキーマ不正のとき500+{"error": "faq_unavailable"}
def test_faq_unavailable_returns_500_for_missing_broken_or_invalid_json(
    client, tmp_path, monkeypatch
):
    missing_path = tmp_path / "missing.json"

    broken_path = tmp_path / "broken.json"
    broken_path.write_text("{not valid json", encoding="utf-8")

    invalid_schema_path = tmp_path / "invalid_schema.json"
    invalid_schema_path.write_text(json.dumps({"items": []}), encoding="utf-8")

    for path in (missing_path, broken_path, invalid_schema_path):
        monkeypatch.setattr(faq_service, "FAQ_FILE_PATH", path)
        faq_service._load_faq_file.cache_clear()
        resp = client.get("/api/faq")
        assert resp.status_code == 500
        assert resp.json() == {"error": "faq_unavailable"}


# 8: FaqFileItem単体: idが^faq-\d{4}$に一致しない値はバリデーションエラー
def test_faq_file_item_rejects_invalid_id_format():
    with pytest.raises(ValidationError):
        FaqFileItem(id="faq-1", category=BOOK, question="q", answer="a", display_order=1)


# 9: FaqFileItem単体: categoryが固定3値以外はバリデーションエラー
def test_faq_file_item_rejects_invalid_category():
    with pytest.raises(ValidationError):
        FaqFileItem(
            id="faq-0001", category="不正カテゴリ", question="q", answer="a", display_order=1
        )


# 10: FaqFileItem単体: question/answerに<>を含むとバリデーションエラー
def test_faq_file_item_rejects_html_tags_in_question_or_answer():
    with pytest.raises(ValidationError):
        FaqFileItem(
            id="faq-0001", category=BOOK, question="<script>", answer="a", display_order=1
        )


# 11: FaqFile単体: 同一カテゴリ内でdisplay_orderが重複するとバリデーションエラー
def test_faq_file_rejects_duplicate_display_order_within_category():
    with pytest.raises(ValidationError):
        FaqFile(
            faq_schema_version=1,
            items=[_item("faq-0001", BOOK, 1), _item("faq-0002", BOOK, 1)],
        )


# 12: 短時間に規定回数を超えてアクセスすると429になる
def test_faq_rate_limit_returns_429_after_threshold(client, write_faq_file):
    write_faq_file(_faq_payload([]))
    for _ in range(60):
        resp = client.get("/api/faq")
        assert resp.status_code == 200
    resp = client.get("/api/faq")
    assert resp.status_code == 429
