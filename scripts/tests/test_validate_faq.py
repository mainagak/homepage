"""scripts/validate_faq.py の単体テスト。

docs/specs/internal-spec-datamodel.md 2.3節(フィールド定義)・2.4節
(バリデーションルール)に定義された各ルールを個別に検証する。最後に、実際に
リポジトリへ配置した `api/app/data/faq.json` が検証を通過することも確認する
(データファイル自体の回帰テスト)。
"""

from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

import pytest

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = SCRIPTS_DIR.parent
sys.path.insert(0, str(SCRIPTS_DIR))

from validate_faq import (  # noqa: E402
    FaqValidationError,
    main,
    validate_faq_data,
    validate_faq_file,
)


def make_item(**overrides):
    item = {
        "id": "faq-0001",
        "category": "書籍について",
        "question": "電子書籍はどこで購入できますか?",
        "answer": "Amazon Kindleストアにて販売しています。",
        "display_order": 1,
    }
    item.update(overrides)
    return item


def make_data(items=None, **overrides):
    data = {"faq_schema_version": 1, "items": items if items is not None else []}
    data.update(overrides)
    return data


# --- 正常系 ---------------------------------------------------------------


def test_valid_empty_items_passes():
    validate_faq_data(make_data(items=[]))


def test_valid_single_item_passes():
    validate_faq_data(make_data(items=[make_item()]))


def test_answer_allows_newline():
    item = make_item(answer="1行目\n2行目")
    validate_faq_data(make_data(items=[item]))


def test_same_display_order_allowed_across_different_categories():
    items = [
        make_item(id="faq-0001", category="書籍について", display_order=1),
        make_item(id="faq-0002", category="仕事の相談", display_order=1),
    ]
    validate_faq_data(make_data(items=items))


def test_all_three_categories_accepted():
    for index, category in enumerate(
        ["書籍について", "仕事の相談", "会社について"], start=1
    ):
        item = make_item(id=f"faq-{index:04d}", category=category)
        validate_faq_data(make_data(items=[item]))


# --- トップレベル構造 -------------------------------------------------------


def test_top_level_not_object_raises():
    with pytest.raises(FaqValidationError):
        validate_faq_data([])


@pytest.mark.parametrize("missing_key", ["faq_schema_version", "items"])
def test_missing_top_level_key_raises(missing_key):
    data = make_data(items=[])
    del data[missing_key]
    with pytest.raises(FaqValidationError):
        validate_faq_data(data)


def test_wrong_schema_version_raises():
    with pytest.raises(FaqValidationError):
        validate_faq_data(make_data(items=[], faq_schema_version=2))


def test_items_not_array_raises():
    with pytest.raises(FaqValidationError):
        validate_faq_data(make_data(items="not-an-array"))


# --- items[] 個別フィールド ---------------------------------------------------


def test_item_not_object_raises():
    with pytest.raises(FaqValidationError):
        validate_faq_data(make_data(items=["not-an-object"]))


@pytest.mark.parametrize(
    "missing_key", ["id", "category", "question", "answer", "display_order"]
)
def test_item_missing_required_key_raises(missing_key):
    item = make_item()
    del item[missing_key]
    with pytest.raises(FaqValidationError):
        validate_faq_data(make_data(items=[item]))


@pytest.mark.parametrize(
    "bad_id", ["faq-1", "faq-001", "faq-00001", "FAQ-0001", "faq_0001", "0001"]
)
def test_invalid_id_format_raises(bad_id):
    with pytest.raises(FaqValidationError):
        validate_faq_data(make_data(items=[make_item(id=bad_id)]))


def test_valid_id_format_passes():
    validate_faq_data(make_data(items=[make_item(id="faq-9999")]))


def test_invalid_category_raises():
    with pytest.raises(FaqValidationError):
        validate_faq_data(make_data(items=[make_item(category="よくある質問")]))


def test_question_empty_raises():
    with pytest.raises(FaqValidationError):
        validate_faq_data(make_data(items=[make_item(question="")]))


def test_question_too_long_raises():
    with pytest.raises(FaqValidationError):
        validate_faq_data(make_data(items=[make_item(question="a" * 101)]))


def test_question_max_length_boundary_passes():
    validate_faq_data(make_data(items=[make_item(question="a" * 100)]))


def test_answer_empty_raises():
    with pytest.raises(FaqValidationError):
        validate_faq_data(make_data(items=[make_item(answer="")]))


def test_answer_too_long_raises():
    with pytest.raises(FaqValidationError):
        validate_faq_data(make_data(items=[make_item(answer="a" * 1001)]))


def test_answer_max_length_boundary_passes():
    validate_faq_data(make_data(items=[make_item(answer="a" * 1000)]))


@pytest.mark.parametrize("field", ["question", "answer"])
@pytest.mark.parametrize("bad_char", ["<", ">"])
def test_text_field_containing_angle_bracket_raises(field, bad_char):
    with pytest.raises(FaqValidationError):
        validate_faq_data(make_data(items=[make_item(**{field: f"abc{bad_char}def"})]))


@pytest.mark.parametrize("bad_value", [0, -1, 1.5, True, "1", None])
def test_display_order_invalid_value_raises(bad_value):
    with pytest.raises(FaqValidationError):
        validate_faq_data(make_data(items=[make_item(display_order=bad_value)]))


# --- 一意性制約 --------------------------------------------------------------


def test_duplicate_id_raises():
    items = [
        make_item(id="faq-0001", display_order=1),
        make_item(id="faq-0001", display_order=2),
    ]
    with pytest.raises(FaqValidationError):
        validate_faq_data(make_data(items=items))


def test_duplicate_display_order_within_same_category_raises():
    items = [
        make_item(id="faq-0001", category="書籍について", display_order=1),
        make_item(id="faq-0002", category="書籍について", display_order=1),
    ]
    with pytest.raises(FaqValidationError):
        validate_faq_data(make_data(items=items))


# --- ファイルI/O -------------------------------------------------------------


def test_validate_faq_file_valid(tmp_path: Path):
    path = tmp_path / "faq.json"
    path.write_text(json.dumps(make_data(items=[make_item()]), ensure_ascii=False), encoding="utf-8")
    validate_faq_file(path)


def test_validate_faq_file_missing_file_raises(tmp_path: Path):
    with pytest.raises(FaqValidationError):
        validate_faq_file(tmp_path / "does-not-exist.json")


def test_validate_faq_file_invalid_json_raises(tmp_path: Path):
    path = tmp_path / "faq.json"
    path.write_text("{not valid json", encoding="utf-8")
    with pytest.raises(FaqValidationError):
        validate_faq_file(path)


def test_data_is_not_mutated_by_validation():
    data = make_data(items=[make_item()])
    original = copy.deepcopy(data)
    validate_faq_data(data)
    assert data == original


# --- CLI ---------------------------------------------------------------------


def test_main_returns_zero_for_valid_file(tmp_path: Path, capsys):
    path = tmp_path / "faq.json"
    path.write_text(json.dumps(make_data(items=[make_item()]), ensure_ascii=False), encoding="utf-8")
    exit_code = main([str(path)])
    assert exit_code == 0
    assert "OK" in capsys.readouterr().out


def test_main_returns_one_for_invalid_file(tmp_path: Path, capsys):
    path = tmp_path / "faq.json"
    path.write_text(json.dumps(make_data(items=[make_item(id="bad-id")]), ensure_ascii=False), encoding="utf-8")
    exit_code = main([str(path)])
    assert exit_code == 1
    assert "INVALID" in capsys.readouterr().err


# --- 実データ回帰テスト ---------------------------------------------------------


def test_repo_faq_json_is_valid():
    """MVPで実際に配置した api/app/data/faq.json 自体が検証を通過することを確認する。"""
    faq_path = REPO_ROOT / "api" / "app" / "data" / "faq.json"
    validate_faq_file(faq_path)


def test_repo_faq_json_starts_with_zero_items():
    """external-spec.md確定事項: MVP初期リリースはFAQ 0件で開始する。"""
    faq_path = REPO_ROOT / "api" / "app" / "data" / "faq.json"
    data = json.loads(faq_path.read_text(encoding="utf-8"))
    assert data["faq_schema_version"] == 1
    assert data["items"] == []
