/**
 * FroEduX - Main Script (Vanilla JS)
 * - スプリットローディング演出
 * - ヘッダーのスクロール制御（DownMoveトグル）
 * - IntersectionObserverによるスクロールイン演出
 * - 沿革（History）タイムラインの進捗ライン
 * - ハンバーガーメニュー
 */

import { initSlider } from './slider.js';

/* ---------------------------------------------------------
   1. Splash / Loading
--------------------------------------------------------- */
function initSplash() {
  const body = document.body;

  const reveal = () => {
    // ロゴフェードイン + パネルスライドアウトを開始
    body.classList.add('is-loaded');

    // アニメーション完了後にスプラッシュを非表示にしてスクロールを解放
    window.setTimeout(() => {
      body.classList.remove('is-loading');
      body.classList.add('is-ready');
    }, 1500);
  };

  if (document.readyState === 'complete') {
    window.setTimeout(reveal, 300);
  } else {
    window.addEventListener('load', () => window.setTimeout(reveal, 300));
    // 万一loadイベントが遅延・発火しない場合の保険
    window.setTimeout(reveal, 2000);
  }
}

/* ---------------------------------------------------------
   2. Header scroll control (.DownMove)
--------------------------------------------------------- */
function initHeaderScroll() {
  const header = document.getElementById('header');
  if (!header) return;

  let lastY = window.scrollY;
  let ticking = false;
  const headerHeight = header.offsetHeight;

  const update = () => {
    const currentY = window.scrollY;

    if (currentY > lastY && currentY > headerHeight) {
      header.classList.add('DownMove');
    } else {
      header.classList.remove('DownMove');
    }

    lastY = currentY;
    ticking = false;
  };

  window.addEventListener('scroll', () => {
    if (!ticking) {
      window.requestAnimationFrame(update);
      ticking = true;
    }
  });
}

/* ---------------------------------------------------------
   3. Hamburger / Nav Drawer
--------------------------------------------------------- */
function initNavDrawer() {
  const hamburger = document.getElementById('hamburger');
  const drawer = document.getElementById('navDrawer');
  if (!hamburger || !drawer) return;

  const close = () => {
    hamburger.classList.remove('is-active');
    drawer.classList.remove('is-open');
  };

  hamburger.addEventListener('click', () => {
    hamburger.classList.toggle('is-active');
    drawer.classList.toggle('is-open');
  });

  drawer.querySelectorAll('.nav-link').forEach((link) => {
    link.addEventListener('click', close);
  });
}

/* ---------------------------------------------------------
   4. IntersectionObserver - scroll-in animations
--------------------------------------------------------- */
function initScrollAnimations() {
  const targets = document.querySelectorAll('.fadeUp, .fadeRight, .fadeLeft');
  if (targets.length === 0) return;

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('active');
        }
      });
    },
    { threshold: 0.2, rootMargin: '0px 0px -8% 0px' }
  );

  targets.forEach((el) => observer.observe(el));
}

/* ---------------------------------------------------------
   5. History timeline - progress line + item highlight
--------------------------------------------------------- */
function initHistoryTimeline() {
  const timeline = document.querySelector('.history__timeline');
  const progress = document.getElementById('historyProgress');
  const items = document.querySelectorAll('.history__item');
  if (!timeline || !progress) return;

  const itemObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('active');
        }
      });
    },
    { threshold: 0.5 }
  );
  items.forEach((item) => itemObserver.observe(item));

  const updateProgress = () => {
    const rect = timeline.getBoundingClientRect();
    const viewportH = window.innerHeight;

    // タイムライン上端が画面下に到達してから、下端が画面中央に到達するまでの進捗を0〜100%で算出
    const start = viewportH * 0.85;
    const end = viewportH * 0.4;
    const total = rect.height + (start - end);
    const scrolled = start - rect.top;
    const ratio = Math.min(Math.max(scrolled / total, 0), 1);

    progress.style.height = `${ratio * 100}%`;
  };

  window.addEventListener('scroll', updateProgress, { passive: true });
  window.addEventListener('resize', updateProgress);
  updateProgress();
}

/* ---------------------------------------------------------
   Init
--------------------------------------------------------- */
document.addEventListener('DOMContentLoaded', () => {
  initSplash();
  initSlider('#slider');
  initHeaderScroll();
  initNavDrawer();
  initScrollAnimations();
  initHistoryTimeline();
});
