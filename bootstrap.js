(() => {
  'use strict';
  const canvas = document.getElementById('canvas');
  const loading = document.getElementById('loading');
  const fill = document.getElementById('fill');
  const status = document.getElementById('status');
  const bar = document.getElementById('loading-progress');
  let progress = 0;
  function update(value, message) {
    progress = Math.max(progress, Math.min(100, value));
    fill.style.width = progress + '%';
    bar.setAttribute('aria-valuenow', String(Math.round(progress)));
    if (message) status.textContent = message;
  }
  function waitForWorld() {
    return new Promise((resolve, reject) => {
      const deadline = performance.now() + 90000;
      function check() {
        if (window.rpgReady) { requestAnimationFrame(() => requestAnimationFrame(resolve)); return; }
        if (performance.now() > deadline) { reject(new Error('World startup timeout')); return; }
        requestAnimationFrame(check);
      }
      check();
    });
  }
  window.startIskra = async config => {
    try {
      // Resolve the SDK language during startup, before the Godot UI is built.
      await window.IskraPlatform.init();
      const text = window.IskraPlatform.text;
      const release = await window.IskraUpdater.prepare(update);
      const engine = new Engine(config);
      update(3, text('loadingStart'));
      const options = { canvas, onProgress: (loaded, total) => {
        if (total > 0) update(50 + loaded / total * 35, text(loaded / total < 0.7 ? 'loadingWorld' : 'loadingHeroes'));
      }};
      if (release) {
        window.IskraUpdater.begin(release);
        await engine.preloadFile(release.bytes.buffer, 'update.pck');
        await engine.init(config.executable);
        await engine.start({...options, args: ['--main-pack', 'update.pck', ...(config.args || [])]});
      } else {
        await engine.startGame(options);
      }
      update(92, text('loadingForest'));
      await waitForWorld();
      await window.IskraUpdater.ready();
      update(100, text('loadingReady'));
      loading.hidden = true;
      window.IskraPlatform.markReady();
      if (!window.IskraPlatform.isPaused()) canvas.focus();
    } catch (error) {
      console.warn('Iskra startup failed:', error?.message || String(error));
      if (window.IskraUpdater.failed()) { location.reload(); return; }
      status.textContent = window.IskraPlatform.text('loadingError');
      document.getElementById('error').hidden = false;
    }
  };
  document.getElementById('base-version').addEventListener('click', () => window.IskraUpdater.useBase());
  document.getElementById('retry').addEventListener('click', () => location.reload());
  document.addEventListener('contextmenu', event => event.preventDefault());
})();
