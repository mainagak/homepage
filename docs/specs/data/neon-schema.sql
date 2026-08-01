-- ============================================================================
-- 将来のNeon (Postgres) スキーマ定義 — 参照専用ドキュメント
-- ============================================================================
--
-- 出典: docs/specs/internal-spec-datamodel.md 3章「将来のNeon Postgres schema
-- (FAQ管理Web GUI用)」。同章3.2節のテーブル定義をそのままDDL化したもの。
--
-- 重要: このファイルは「将来こう作る」というドキュメント/設計成果物であり、
-- 実行を想定した稼働中のマイグレーションではない。DB導入自体がMVPスコープ外
-- (architecture.md 決定事項5)であるため、現時点でNeonへの接続・提供・実行は
-- 一切行っていない。FAQ管理Web GUI導入時(MVPリリース直後の最初の保守作業)に、
-- このファイルを起点として実際のマイグレーションツール(例: Alembic)で適用する
-- ことを想定する。
--
-- 導入時期・運用方針の詳細は internal-spec-datamodel.md 3.1節(設計方針の要点)・
-- 3.4節(Neon運用設計)を参照。
-- ============================================================================

-- ----------------------------------------------------------------------------
-- gui_accounts: FAQ管理GUIのログインアカウント(複数アカウント対応、権限分離なし)
-- ----------------------------------------------------------------------------
CREATE TABLE gui_accounts (
    id                     SERIAL PRIMARY KEY,
    email                  VARCHAR(255) NOT NULL UNIQUE,
    password_hash          VARCHAR(60)  NOT NULL,
    display_name           VARCHAR(100),
    is_active              BOOLEAN      NOT NULL DEFAULT true,
    failed_login_attempts  SMALLINT     NOT NULL DEFAULT 0,
    locked_until           TIMESTAMPTZ,
    created_at             TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at             TIMESTAMPTZ  NOT NULL DEFAULT now(),
    last_login_at          TIMESTAMPTZ
);
-- email は UNIQUE 制約により自動的にインデックスが張られる。

-- ----------------------------------------------------------------------------
-- faqs: FAQ本体。MVPの faq.json (api/app/data/faq.json) の内容をここへ完全移行する
-- (4章「JSON → DB 移行方針」参照)。
-- ----------------------------------------------------------------------------
CREATE TABLE faqs (
    id               BIGSERIAL PRIMARY KEY,
    legacy_json_id   VARCHAR(20),
    category         VARCHAR(50)  NOT NULL
                       CHECK (category IN ('書籍について', '仕事の相談', '会社について')),
    question         VARCHAR(100) NOT NULL CHECK (char_length(question) > 0),
    answer           VARCHAR(1000) NOT NULL CHECK (char_length(answer) > 0),
    display_order    INTEGER      NOT NULL DEFAULT 0,
    status           VARCHAR(10)  NOT NULL DEFAULT 'draft'
                       CHECK (status IN ('draft', 'published')),
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by       INTEGER      REFERENCES gui_accounts(id) ON DELETE SET NULL,
    updated_by       INTEGER      REFERENCES gui_accounts(id) ON DELETE SET NULL
);

CREATE INDEX idx_faqs_category_status_order
  ON faqs (category, status, display_order);
CREATE INDEX idx_faqs_status ON faqs (status);
-- FAQ公開API(GET /api/faq相当)は status='published' のみをカテゴリ・表示順で
-- 取得するため、上記インデックスが主要クエリと一致する。

-- ----------------------------------------------------------------------------
-- faq_change_log: FAQの変更履歴(誰が何を変更したか)
-- ----------------------------------------------------------------------------
CREATE TABLE faq_change_log (
    id               BIGSERIAL PRIMARY KEY,
    faq_id           BIGINT      NOT NULL REFERENCES faqs(id) ON DELETE CASCADE,
    account_id       INTEGER     REFERENCES gui_accounts(id) ON DELETE SET NULL,
    action           VARCHAR(10) NOT NULL
                       CHECK (action IN ('create', 'update', 'delete', 'publish', 'unpublish')),
    before_snapshot  JSONB,
    after_snapshot   JSONB,
    changed_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_faq_change_log_faq_id_changed_at
  ON faq_change_log (faq_id, changed_at DESC);

-- ----------------------------------------------------------------------------
-- ER概要(テキスト表現、internal-spec-datamodel.md 3.3節と同一)
-- ----------------------------------------------------------------------------
-- gui_accounts (1) ──< faqs.created_by / faqs.updated_by
-- gui_accounts (1) ──< faq_change_log.account_id
-- faqs (1) ──< faq_change_log.faq_id (ON DELETE CASCADE)

-- ----------------------------------------------------------------------------
-- 設計上意図的に持たないもの(internal-spec-datamodel.md 3.1節の根拠を参照)
-- ----------------------------------------------------------------------------
-- - カテゴリマスタテーブル: category は faqs.category に CHECK 制約で直接持たせる
--   (GUIから動的追加はしない運用のため)。
-- - gui_accounts.role: 権限分離は行わない(当面は運営者本人のみの前提)。
-- - セッションテーブル: JWT(有効期限1週間)で代替、DB非保持。
-- - faqs.deleted_at: 物理削除+faq_change_log のスナップショットで代替。
-- - password_reset_token 等のパスワードリセット関連カラム: 2026-08-02の内部仕様
--   追加質問Q1回答により、メールによるリセットを廃止したため不要
--   (パスワード紛失時は運営者の依頼によりClaude CodeがSQLを直接発行してUPDATEする)。

-- ----------------------------------------------------------------------------
-- 移行時シードの参考(4.2節「移行手順」の対応、実際の投入はPhase 6以降で実装)
-- ----------------------------------------------------------------------------
-- INSERT INTO faqs (category, question, answer, display_order, legacy_json_id, status,
--                    created_by, updated_by)
-- VALUES ($1, $2, $3, $4, $5, 'published', NULL, NULL);
-- -- $1..$5 は faq.json の items[].category / question / answer / display_order / id
-- -- に対応する(4.2節参照)。
