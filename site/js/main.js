// main.js - ナビゲーションの初期化
//
// 問い合わせフォームの送信処理は contact.html 専用の contact-form.js、
// FAQウィジェットは全ページ共通の chat-widget.js に分離した(それぞれ別のCGI/APIと
// 連携するため)。このファイルはページ内アンカーリンクのスムーズスクロールのみを担う。

document.addEventListener('DOMContentLoaded', () => {
    initializeNavLinks();
});

function initializeNavLinks() {
    document.querySelectorAll('.nav-link').forEach((link) => {
        const href = link.getAttribute('href');
        // ページ内アンカー("#..."で始まるもの)のみスムーズスクロールで処理する。
        // contact.html・cgi-bin/news.cgi等の別ページへのリンクは通常の遷移に任せる。
        if (!href || !href.startsWith('#')) {
            return;
        }
        link.addEventListener('click', (e) => {
            e.preventDefault();
            scrollToSection(href);
        });
    });
}
