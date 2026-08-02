// chat-widget.js
//
// FAQ/チャットウィジェット。external-spec.md「2. 問い合わせチャット機能」の確定要件
// (全ページ共通のフローティングウィジェット、右下等に常時表示)を実装する。
// このスクリプトを読み込んだページのbody末尾にウィジェットのDOMを動的に挿入するため、
// 各静的ページ側でウィジェットのHTMLを個別に書く必要はない(ロゴ一元管理と同じ考え方で、
// 変更箇所を1ファイルに集約する)。
//
// API契約: docs/specs/internal-spec-integration.md 3章(GET /api/faq)・6.2節
//         (タイムアウト・失敗時の挙動)。
// レスポンス形式: docs/specs/internal-spec-vercel.md 2章。
//
// contact.html は本ファイルと js/contact-form.js の両方を classic <script>として
// 読み込む(唯一の共存ページ)。トップレベルの const/function 宣言はページ内の
// グローバルレキシカル環境を共有してしまい、同名宣言があると構文解析自体が失敗する
// (フェーズ8 E2Eテストで実機確認、docs/PROJECT_STATUS.mdチェックポイント22)。
// そのため本ファイル全体をIIFEで包み、他の<script>タグと名前空間を共有しない。

(function () {
    'use strict';

    // TODO: 実際にVercelへデプロイしたプロジェクトのURLへ置き換えること。
    // (docs/specs/architecture.md「追加質問6」と同種の、実機確認待ちの非公開情報。
    //  未確定のままではFAQ取得が失敗するが、6.2節の失敗時UI(エラーメッセージ+
    //  問い合わせフォーム導線)により壊れた表示にはならない設計になっている。)
    const VERCEL_API_BASE_URL = 'https://REPLACE-WITH-VERCEL-PROJECT.vercel.app';

    const FAQ_FETCH_TIMEOUT_MS = 5000; // internal-spec-integration.md 6.2節

    document.addEventListener('DOMContentLoaded', () => {
        injectFaqWidgetMarkup();
        initFaqWidgetToggle();
    });

    // このスクリプトはサイト直下のページ(index.html等)と cgi-bin/ 配下から出力される
    // ページ(news.cgi)の両方から読み込まれるため、現在のURLパスに応じて
    // contact.html への相対パスを切り替える。
    function resolveContactPagePath() {
        return window.location.pathname.includes('/cgi-bin/') ? '../contact.html' : 'contact.html';
    }

    function injectFaqWidgetMarkup() {
        const container = document.createElement('div');
        container.id = 'faq-widget';

        const toggle = document.createElement('button');
        toggle.id = 'faq-widget-toggle';
        toggle.type = 'button';
        toggle.className = 'faq-widget-toggle';
        toggle.setAttribute('aria-expanded', 'false');
        toggle.setAttribute('aria-controls', 'faq-widget-panel');
        toggle.textContent = 'FAQ';

        const panel = document.createElement('div');
        panel.id = 'faq-widget-panel';
        panel.className = 'faq-widget-panel';
        panel.hidden = true;

        const header = document.createElement('div');
        header.className = 'faq-widget-header';

        const heading = document.createElement('h3');
        heading.textContent = 'よくある質問';

        const closeButton = document.createElement('button');
        closeButton.id = 'faq-widget-close';
        closeButton.type = 'button';
        closeButton.className = 'faq-widget-close';
        closeButton.setAttribute('aria-label', '閉じる');
        closeButton.textContent = '×';

        header.appendChild(heading);
        header.appendChild(closeButton);

        const body = document.createElement('div');
        body.id = 'faq-widget-body';
        body.className = 'faq-widget-body';
        body.innerHTML = '<p class="faq-widget-loading">読み込み中です…</p>';

        panel.appendChild(header);
        panel.appendChild(body);

        container.appendChild(toggle);
        container.appendChild(panel);
        document.body.appendChild(container);
    }

    function initFaqWidgetToggle() {
        const toggle = document.getElementById('faq-widget-toggle');
        const panel = document.getElementById('faq-widget-panel');
        const closeButton = document.getElementById('faq-widget-close');

        const openPanel = () => {
            panel.hidden = false;
            toggle.setAttribute('aria-expanded', 'true');
            // 再オープンのたびに再取得する(internal-spec-integration.md 6.2節、
            // ブラウザ側でのキャッシュは行わない方針と整合)。
            loadFaq();
        };
        const closePanel = () => {
            panel.hidden = true;
            toggle.setAttribute('aria-expanded', 'false');
        };

        toggle.addEventListener('click', () => {
            if (panel.hidden) {
                openPanel();
            } else {
                closePanel();
            }
        });
        closeButton.addEventListener('click', closePanel);
    }

    async function loadFaq() {
        const body = document.getElementById('faq-widget-body');
        body.innerHTML = '<p class="faq-widget-loading">読み込み中です…</p>';

        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), FAQ_FETCH_TIMEOUT_MS);

        try {
            const response = await fetch(`${VERCEL_API_BASE_URL}/api/faq`, {
                method: 'GET',
                signal: controller.signal,
            });
            clearTimeout(timeoutId);

            if (!response.ok) {
                renderFaqError(body);
                return;
            }

            const data = await response.json();
            renderFaqList(body, Array.isArray(data.faqs) ? data.faqs : []);
        } catch (error) {
            clearTimeout(timeoutId);
            console.error('FAQ fetch failed:', error);
            renderFaqError(body);
        }
    }

    // internal-spec-integration.md 6.2節の確定文言をそのまま使用する。
    function renderFaqError(body) {
        body.innerHTML = '';
        const message = document.createElement('p');
        message.className = 'faq-widget-message';
        message.textContent =
            'FAQを読み込めませんでした。しばらくしてから再度お試しいただくか、' +
            'お問い合わせフォームをご利用ください。';
        body.appendChild(message);
        body.appendChild(buildContactLink());
    }

    // internal-spec-vercel.md 2.2節・phase4-clarification.mdラウンド1A節Q1の確定文言。
    function renderFaqEmpty(body) {
        body.innerHTML = '';
        const message = document.createElement('p');
        message.className = 'faq-widget-message';
        message.textContent = 'まだFAQがありません。お問い合わせフォームをご利用ください。';
        body.appendChild(message);
        body.appendChild(buildContactLink());
    }

    // faqsはサーバー側で既に「カテゴリの固定順→display_order昇順」に整列済み
    // (internal-spec-vercel.md 2.2節)。クライアント側で並び替えは行わない。
    function renderFaqList(body, faqs) {
        if (faqs.length === 0) {
            renderFaqEmpty(body);
            return;
        }

        body.innerHTML = '';
        let currentCategory = null;

        faqs.forEach((item) => {
            if (item.category !== currentCategory) {
                currentCategory = item.category;
                const heading = document.createElement('h4');
                heading.className = 'faq-widget-category';
                heading.textContent = currentCategory;
                body.appendChild(heading);
            }

            const entry = document.createElement('details');
            entry.className = 'faq-widget-entry';

            const question = document.createElement('summary');
            question.textContent = item.question;
            entry.appendChild(question);

            const answer = document.createElement('p');
            answer.textContent = item.answer;
            entry.appendChild(answer);

            body.appendChild(entry);
        });
    }

    // phase4-clarification.md ラウンド2 C節Q21の確定文言「お問い合わせフォームへ」。
    function buildContactLink() {
        const link = document.createElement('a');
        link.href = resolveContactPagePath();
        link.className = 'cta-button faq-widget-cta';
        link.textContent = 'お問い合わせフォームへ';
        return link;
    }
})();
