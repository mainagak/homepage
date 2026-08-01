/**
 * FroEduX - Fullscreen Slider (Vanilla JS / 外部ライブラリ不使用)
 * Ken Burns風のゆっくりズームをかけながら、フェードで画像を切り替える軽量スライダー
 *
 * 画像は仮のフリー素材（Unsplash）を使用しています。
 * 差し替える場合は SLIDE_IMAGES の配列を書き換えてください。
 */

const SLIDE_IMAGES = [
  'https://images.unsplash.com/photo-1523240795612-9a054b0db644?auto=format&fit=crop&w=1920&q=80', // 自習する学生
  'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?auto=format&fit=crop&w=1920&q=80', // ノートPCで学習
  'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?auto=format&fit=crop&w=1920&q=80', // 図書館で勉強する若手社会人
];

const SLIDE_INTERVAL = 3000; // ms（3秒ごとに切り替え）
const KENBURNS_DURATION = SLIDE_INTERVAL + 800; // フェードと重なっても違和感が出ないよう少し長め

export function initSlider(selector = '#slider') {
  const container = document.querySelector(selector);
  if (!container) return;

  const slides = SLIDE_IMAGES.map((url) => {
    const el = document.createElement('div');
    el.className = 'slider__slide';
    el.style.backgroundImage = `url(${url})`;
    el.style.animationDuration = `${KENBURNS_DURATION}ms`;
    container.appendChild(el);
    return el;
  });

  if (slides.length === 0) return;

  let current = 0;
  slides[current].classList.add('is-active');

  if (slides.length === 1) return; // 画像が1枚のみなら切り替え不要

  setInterval(() => {
    const prev = slides[current];
    current = (current + 1) % slides.length;
    const next = slides[current];

    // Ken Burnsアニメーションを毎回リスタートさせるため、
    // 一旦クラスを外して reflow を発生させてから付け直す
    next.classList.remove('is-active');
    void next.offsetWidth; // force reflow
    next.classList.add('is-active');

    prev.classList.remove('is-active');
  }, SLIDE_INTERVAL);
}
