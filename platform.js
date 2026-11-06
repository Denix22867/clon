/* Yandex ads use the platform SDK only. Game assets always remain local. */
(() => {
  'use strict';
  const mode = document.querySelector('meta[name="iskra-platform"]')?.content || 'web';
  const overlay = document.getElementById('ad-break');
  const number = document.getElementById('ad-count');
  const title = document.getElementById('ad-title');
  const reasons = new Set();
  const intervalMs = 180000;
  const countdownMs = 2000; // Yandex requires a two-second warning; three visual steps.
  let sdk = null;
  let ready = false;
  let activeMs = 0;
  let lastAttemptMs = 0;
  let ad = null;
  let nativePause = null;
  let playingReported = null;
  let loadingReported = false;
  let tutorial = false;
  let activityPaused = false;
  let initialization = null;
  let platformLanguage = null;
  let language = 'ru';
  // The game currently ships one translation. Read the SDK language even for
  // a Russian-only game (Yandex requirement 2.14), then select a supported pack.
  const translations = { ru: {
    loadingStart: 'Разжигаем Искру…', loadingWorld: 'Собираем отряд. Загружаем мир…',
    loadingHeroes: 'Пробуждаем героев…', loadingForest: 'Открываем путь в Шепчущий лес…',
    loadingReady: 'Твой поход начинается', loadingError: 'Не удалось открыть путь',
    adCountdown: 'Реклама через', adOpening: 'Открываем рекламу'
  }};
  function selectLanguage(requested) {
    platformLanguage = typeof requested === 'string' ? requested : null;
    const code = (platformLanguage || 'ru').toLowerCase().split(/[-_]/)[0];
    language = Object.prototype.hasOwnProperty.call(translations, code) ? code : 'ru';
    document.documentElement.lang = language;
    window.rpgLanguage = language;
  }
  function text(key) { return translations[language][key]; }

  function isPaused() {
    return !ready || document.hidden || reasons.size > 0 || ad !== null;
  }
  function reportGameplay() {
    if (!sdk || !ready) return;
    const playing = !isPaused() && !tutorial && !activityPaused;
    if (playing === playingReported) return;
    playingReported = playing;
    try { sdk.features?.GameplayAPI?.[playing ? 'start' : 'stop']?.(); }
    catch (_) { /* Platform metrics cannot block gameplay. */ }
  }
  function sync() {
    const paused = isPaused();
    if (window.rpgPaused !== paused) {
      window.rpgPaused = paused;
      nativePause?.(paused);
    }
    document.getElementById('canvas').inert = paused;
    reportGameplay();
  }
  function setReason(name, value) {
    if (value) reasons.add(name); else reasons.delete(name);
    sync();
  }
  function reportLoaded() {
    if (!sdk || !ready || loadingReported) return;
    loadingReported = true;
    try { sdk.features?.LoadingAPI?.ready?.(); } catch (_) {}
    reportGameplay();
  }
  function finish(request) {
    if (ad !== request) return;
    clearInterval(request.timer);
    clearTimeout(request.watchdog);
    overlay.hidden = true;
    ad = null;
    sync();
    if (!isPaused()) document.getElementById('canvas').focus();
  }
  function showAd(request) {
    if (ad !== request) return;
    clearInterval(request.timer);
    request.phase = 'requesting';
    title.textContent = text('adOpening');
    number.textContent = '…';
    // Recover only if the SDK never opens an ad. Never resume over an open ad.
    request.watchdog = setTimeout(() => {
      if (request.phase === 'requesting') finish(request);
    }, 15000);
    try {
      const result = sdk.adv.showFullscreenAdv({ callbacks: {
        onOpen: () => {
          if (ad !== request) return;
          request.phase = 'showing';
          clearTimeout(request.watchdog);
          overlay.hidden = true;
          sync();
        },
        onClose: () => finish(request),
        onError: () => finish(request)
      }});
      if (result?.catch) result.catch(() => finish(request));
    } catch (_) { finish(request); }
  }
  function maybeShowInterstitial() {
    // A timer only makes an ad eligible. Opening a menu is the actual safe break.
    if (!sdk?.adv?.showFullscreenAdv || !ready || isPaused() || tutorial || activeMs - lastAttemptMs < intervalMs) return false;
    lastAttemptMs = activeMs;
    const request = { phase: 'countdown', elapsed: 0, last: performance.now(), timer: null, watchdog: null };
    ad = request;
    title.textContent = text('adCountdown');
    number.textContent = '3';
    overlay.hidden = false;
    sync();
    request.timer = setInterval(() => {
      if (ad !== request) return;
      const now = performance.now();
      if (!document.hidden && reasons.size === 0) request.elapsed += now - request.last;
      request.last = now;
      if (request.elapsed >= countdownMs) { showAd(request); return; }
      number.textContent = String(Math.max(1, 3 - Math.floor(request.elapsed / (countdownMs / 3))));
    }, 40);
    return true;
  }
  async function initSdk() {
    if (mode !== 'yandex') { selectLanguage(null); return; }
    let expired = false;
    let timeout;
    try {
      const initialized = await Promise.race([
        (async () => {
          await new Promise((resolve, reject) => {
            const script = document.createElement('script');
            script.src = '/sdk.js';
            script.async = true;
            script.onload = resolve;
            script.onerror = reject;
            document.head.appendChild(script);
          });
          if (expired) throw new Error('SDK startup timeout');
          return window.YaGames.init();
        })(),
        new Promise((_, reject) => {
          timeout = setTimeout(() => { expired = true; reject(new Error('SDK startup timeout')); }, 15000);
        })
      ]);
      sdk = initialized;
      selectLanguage(sdk.environment?.i18n?.lang);
      sdk.on?.('game_api_pause', () => setReason('sdk', true));
      sdk.on?.('game_api_resume', () => setReason('sdk', false));
      reportLoaded();
    } catch (_) {
      // SDK unavailability never traps the player behind a loading screen.
      sdk = null;
      selectLanguage(null);
    } finally {
      clearTimeout(timeout);
    }
  }
  window.IskraPlatform = {
    init() { return initialization ||= initSdk(); },
    async getUpdateFlags(defaultFlags) {
      if (!sdk?.getFlags) return defaultFlags;
      let timer;
      try { return await Promise.race([sdk.getFlags({defaultFlags}), new Promise(resolve => { timer = setTimeout(() => resolve(defaultFlags), 4000); })]); }
      catch (_) { return defaultFlags; }
      finally { clearTimeout(timer); }
    },
    getLanguage() { return language; },
    getSdk() { return sdk; },
    text,
    setGuardPaused(value) { setReason("guard",Boolean(value)); },
    setActivityPaused(value) { activityPaused=Boolean(value); reportGameplay(); },
    setTutorial(value) { tutorial = Boolean(value); reportGameplay(); },
    bindGodotPause(callback) { nativePause = callback; callback(isPaused()); },
    markReady() { ready = true; sync(); reportLoaded(); window.IskraShop?.init(sdk, mode !== "yandex"); },
    setShopOpen(value) { setReason("shop", Boolean(value)); },
    isPaused,
    tick(delta) {
      if (ready && !isPaused() && !tutorial && !activityPaused) { const dt=Math.min(Math.max(delta, 0), 0.2); activeMs += dt * 1000; window.IskraShop?.tick(dt); }
      sync();
      return isPaused();
    },
    maybeShowInterstitial,
    getState() { return { mode, sdkReady: Boolean(sdk), platformLanguage, language, ready, paused: isPaused(), adPhase: ad?.phase || null, activeMs, lastAttemptMs }; }
  };
  document.addEventListener('visibilitychange', sync);
  window.addEventListener('pagehide', () => setReason('page', true));
  window.addEventListener('pageshow', () => setReason('page', false));
  document.addEventListener('keydown', event => {
    if (!isPaused() || event.target.closest?.("#iskra-shop, #iskra-guard")) return;
    event.preventDefault();
    event.stopImmediatePropagation();
  }, true);
  sync();
})();
