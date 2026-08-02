// contact-form.js
//
// contact.html専用のスクリプト。3つの役割を持つ:
//   1. contact.cgi がバリデーションエラー時に埋め込む入力値プレースホルダーを
//      各入力欄へ反映する(下記 restoreFieldValues 参照)。
//   2. メールアドレス(確認用)の即時一致チェック(ラウンド1 B12=C、
//      CGI側でも必ず再検証されるためJS側はUX向上のための補助)。
//   3. reCAPTCHA v2完了後にVercelの POST /api/verify-recaptcha を呼び出し、
//      HMAC署名付きトークンをhiddenフィールド(verify_token)に設定する
//      (internal-spec-integration.md 1.4節・2.2節)。
//
// このファイルは X-Smoke-Test-Auth ヘッダーを一切送信しない
// (internal-spec-vercel.md 9.1節: 通常のブラウザからのリクエストには
//  付与されない前提。CI専用ヘッダーはplaywright-smoke.ymlのみが付与する)。
//
// contact.html は本ファイルと js/chat-widget.js の両方を classic <script>として
// 読み込む(唯一の共存ページ)。トップレベルの const/function 宣言はページ内の
// グローバルレキシカル環境を共有してしまい、同名宣言があると構文解析自体が失敗する
// (フェーズ8 E2Eテストで実機確認、docs/PROJECT_STATUS.mdチェックポイント22)。
// そのため本ファイル全体をIIFEで包み、他の<script>タグと名前空間を共有しない。
// reCAPTCHAウィジェットのdata-callback/data-expired-callbackは関数名を
// window上で解決するため、onRecaptchaSuccess/onRecaptchaExpiredのみ明示的に
// windowへ公開する。

(function () {
    'use strict';

    // TODO: 実際にVercelへデプロイしたプロジェクトのURLへ置き換えること
    // (chat-widget.js と同じ値。architecture.md「追加質問6」と同種の未確定値)。
    const VERCEL_API_BASE_URL = 'https://api-seven-steel-73.vercel.app';

    const VERIFY_RECAPTCHA_TIMEOUT_MS = 8000; // internal-spec-integration.md 6.1節

    document.addEventListener('DOMContentLoaded', () => {
        restoreFieldValues();
        initEmailConfirmCheck();
    });

    // contact.cgi は Common::render_template() を使って
    // <!--VALUE:field_name--> というプレースホルダーをHTMLエスケープ済みの値に
    // 置換する(internal-spec-cyberhome.md 2.8節)。一方contact.htmlはGETの場合
    // Apacheが未処理のまま直接配信する(同2.1節)ため、プレースホルダーを
    // そのまま <input value="..."> の中に書いてしまうと、初回アクセス時に
    // 未置換の "<!--VALUE:xxx-->" という文字列がそのまま入力欄に表示されてしまう
    // (contact.cgi・Common.pmの置換ロジック自体は文字列置換のみで、HTMLの
    // 構文的な位置は関知しないため)。
    //
    // これを避けるため、プレースホルダーは各入力欄の外側にある非表示の
    // <span class="value-holder" data-target="フィールドのid" hidden> に
    // 置いておき、ページ読み込み時にJSで対応する入力欄のvalueへ移し替える。
    // 未処理(空)の場合はtextContentが空文字列のため何も起きず、入力欄は
    // 意図通り空のまま表示される。
    function restoreFieldValues() {
        document.querySelectorAll('.value-holder').forEach((holder) => {
            const targetId = holder.dataset.target;
            const target = targetId ? document.getElementById(targetId) : null;
            if (target && holder.textContent) {
                target.value = holder.textContent;
            }
            holder.remove();
        });
    }

    function initEmailConfirmCheck() {
        const email = document.getElementById('email');
        const emailConfirm = document.getElementById('email_confirm');
        const errorEl = document.getElementById('email-mismatch-error');
        if (!email || !emailConfirm || !errorEl) {
            return;
        }

        const check = () => {
            const mismatch = emailConfirm.value !== '' && emailConfirm.value !== email.value;
            errorEl.hidden = !mismatch;
            emailConfirm.setCustomValidity(mismatch ? 'メールアドレスが一致しません' : '');
        };

        email.addEventListener('input', check);
        emailConfirm.addEventListener('input', check);
    }

    // reCAPTCHA v2ウィジェットの data-callback から呼ばれるグローバル関数
    // (internal-spec-integration.md 1.4節フロー(b)(c))。
    // data-callback属性は関数名をwindowプロパティとして解決するため、
    // IIFE内で定義した上でwindowへ明示的に公開する。
    function onRecaptchaSuccess(recaptchaResponse) {
        verifyRecaptcha(recaptchaResponse);
    }
    window.onRecaptchaSuccess = onRecaptchaSuccess;

    // data-expired-callback: 300秒のトークン有効期限切れ等でチェックが自動的に
    // 外れた場合、送信ボタンを再度disabledに戻す。
    function onRecaptchaExpired() {
        const tokenField = document.getElementById('verify_token');
        const submitButton = document.getElementById('contact-submit');
        if (tokenField) tokenField.value = '';
        if (submitButton) submitButton.disabled = true;
    }
    window.onRecaptchaExpired = onRecaptchaExpired;

    async function verifyRecaptcha(recaptchaResponse) {
        const errorEl = document.getElementById('recaptcha-error');
        if (errorEl) errorEl.hidden = true;

        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), VERIFY_RECAPTCHA_TIMEOUT_MS);

        try {
            const response = await fetch(`${VERCEL_API_BASE_URL}/api/verify-recaptcha`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ recaptcha_response: recaptchaResponse }),
                signal: controller.signal,
            });
            clearTimeout(timeoutId);

            let data = null;
            try {
                data = await response.json();
            } catch (parseError) {
                data = null;
            }

            if (response.ok && data && data.verified === true && data.token) {
                const tokenField = document.getElementById('verify_token');
                const submitButton = document.getElementById('contact-submit');
                if (tokenField) tokenField.value = data.token;
                if (submitButton) submitButton.disabled = false;
                return;
            }

            showRecaptchaError();
        } catch (error) {
            clearTimeout(timeoutId);
            console.error('verify-recaptcha request failed:', error);
            showRecaptchaError();
        }
    }

    // internal-spec-integration.md 6.1節の確定文言をそのまま使用する。
    // 自動リトライは行わない(ユーザーが再度チェックボックスを操作する)。
    function showRecaptchaError() {
        const errorEl = document.getElementById('recaptcha-error');
        const tokenField = document.getElementById('verify_token');
        const submitButton = document.getElementById('contact-submit');
        if (tokenField) tokenField.value = '';
        if (submitButton) submitButton.disabled = true;
        if (errorEl) {
            errorEl.textContent =
                '検証に失敗しました。もう一度チェックボックスを操作するか、' +
                '時間をおいて再度お試しください。';
            errorEl.hidden = false;
        }
    }
})();
