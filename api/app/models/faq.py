from typing import Literal

from pydantic import BaseModel, Field, field_validator

FaqCategory = Literal["書籍について", "仕事の相談", "会社について"]
CATEGORY_ORDER: list[FaqCategory] = ["書籍について", "仕事の相談", "会社について"]


# --- ファイル(api/app/data/faq.json)側のスキーマ。internal-spec-datamodel.md 2章と完全一致 ---
class FaqFileItem(BaseModel):
    id: str = Field(pattern=r"^faq-\d{4}$")
    category: FaqCategory
    question: str = Field(min_length=1, max_length=100)
    answer: str = Field(min_length=1, max_length=1000)
    display_order: int = Field(gt=0)

    @field_validator("question", "answer")
    @classmethod
    def no_html_tags(cls, v: str) -> str:
        if "<" in v or ">" in v:
            raise ValueError("HTML tags are not allowed")
        return v


class FaqFile(BaseModel):
    faq_schema_version: int
    items: list[FaqFileItem]

    @field_validator("items")
    @classmethod
    def unique_display_order_per_category(cls, items: list[FaqFileItem]) -> list[FaqFileItem]:
        seen: dict[str, set[int]] = {}
        for item in items:
            bucket = seen.setdefault(item.category, set())
            if item.display_order in bucket:
                raise ValueError(
                    f"duplicate display_order {item.display_order} in category {item.category}"
                )
            bucket.add(item.display_order)
        return items


# --- API応答側のスキーマ。internal-spec-integration.md 3.2章と完全一致 ---
class FaqApiItem(BaseModel):
    id: str
    category: FaqCategory
    question: str
    answer: str


class FaqApiResponse(BaseModel):
    faqs: list[FaqApiItem]
    updated_at: str | None = None
