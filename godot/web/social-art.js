// Cosmetic layer: works with both the original and current SDK social UI.
(() => {
  'use strict';
  if (window.IskraSocialArtwork) return;
  function decorate() {
    const root = document.querySelector('#iskra-shop.social-overlay');
    if (!root) return;
    for (const row of root.querySelectorAll('.social-row')) {
      const rank = Number((row.querySelector('.social-rank')?.textContent || '').replace('#', ''));
      row.dataset.medal = rank >= 1 && rank <= 3 ? String(rank) : '';
    }
    for (const [index, card] of [...root.querySelectorAll('.social-stats > div')].entries()) {
      card.dataset.art = ['victory', 'gold', 'avatar', 'relic', 'avatar', 'victory'][index] || 'relic';
    }
    for (const badge of root.querySelectorAll('.social-achievements > span')) {
      if (badge.querySelector('.social-badge-art')) continue;
      const art = document.createElement('i');
      art.className = 'social-badge-art';
      art.setAttribute('aria-hidden', 'true');
      art.dataset.art = /героев|жизнь/.test(badge.textContent) ? 'avatar' : /лес|босс/.test(badge.textContent) ? 'victory' : 'relic';
      badge.prepend(art);
    }
  }
  const observer = new MutationObserver(decorate);
  observer.observe(document.body, {subtree: true, childList: true, characterData: true});
  window.IskraSocialArtwork = {version: '1.0.2', decorate};
  decorate();
})();
