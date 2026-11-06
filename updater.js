/* Remote Godot game code and resources. The engine and payment bridge remain local. */
(() => {
  'use strict';
  const ABI = 'godot-4.7.2-web-nothreads-bridge1-save2';
  const KEY = 'iskra-updater-v1';
  const CACHE = 'iskra-releases-v1';
  const MAX = 80 * 1024 * 1024;
  let state = read(), selected = null;
  function read() { try { return JSON.parse(localStorage.getItem(KEY)) || {}; } catch (_) { return {}; } }
  function write() { try { localStorage.setItem(KEY, JSON.stringify(state)); } catch (_) {} }
  function cloud(value) {
    const u = new URL(value);
    if (u.protocol !== 'https:' || u.hostname !== 'storage.yandexcloud.net' || u.port || u.username || u.password || u.hash) throw Error('Invalid update host');
    return u.href;
  }
  function validate(m, manifestUrl) {
    if (!m || m.schema !== 1 || m.abi !== ABI || !/^[a-zA-Z0-9._-]{1,64}$/.test(m.version) || !Number.isSafeInteger(m.bytes) || m.bytes < 4 || m.bytes > MAX || !/^[a-f0-9]{64}$/.test(m.sha256)) throw Error('Incompatible update');
    return {schema: 1, abi: ABI, version: m.version, bytes: m.bytes, sha256: m.sha256, pack: cloud(new URL(m.pack, manifestUrl).href)};
  }
  async function request(url, limit, ms, progress) {
    const controller = new AbortController(), timer = setTimeout(() => controller.abort(), ms);
    try {
      const response = await fetch(url, {signal: controller.signal, credentials: 'omit', cache: 'no-store', redirect: 'error'});
      if (!response.ok) throw Error('HTTP ' + response.status);
      const reader = response.body.getReader(), chunks = []; let n = 0;
      for (;;) { const r = await reader.read(); if (r.done) break; n += r.value.length; if (n > limit) { await reader.cancel(); throw Error('Update too large'); } chunks.push(r.value); progress?.(n); }
      const bytes = new Uint8Array(n); let offset = 0;
      for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
      return bytes;
    } finally { clearTimeout(timer); }
  }
  async function verify(bytes, m) {
    if (bytes.byteLength !== m.bytes || bytes[0] !== 71 || bytes[1] !== 68 || bytes[2] !== 80 || bytes[3] !== 67) throw Error('Invalid game pack');
    const digest = await crypto.subtle.digest('SHA-256', bytes);
    const hash = Array.from(new Uint8Array(digest), b => b.toString(16).padStart(2, '0')).join('');
    if (hash !== m.sha256) throw Error('Update checksum mismatch');
    return bytes;
  }
  function cacheKey(m) { return new URL('/__iskra_pack_' + m.sha256, location.href).href; }
  async function cacheGet(m) {
    try { const c = await caches.open(CACHE), r = await c.match(cacheKey(m)); if (r) return await verify(new Uint8Array(await r.arrayBuffer()), m); } catch (_) {}
    return null;
  }
  async function cachePut(m, bytes) {
    try { const c = await caches.open(CACHE); await c.put(cacheKey(m), new Response(bytes)); } catch (_) { /* Quota/private mode: play from memory. */ }
  }
  function failPending() {
    if (!state.pending) return;
    state.blocked = [...new Set([...(state.blocked || []), state.pending.sha256])].slice(-10);
    if (state.backup !== undefined) {
      try { if (state.backup === null) localStorage.removeItem('iskra-idle-v2'); else localStorage.setItem('iskra-idle-v2', state.backup); } catch (_) {}
    }
    delete state.pending; delete state.backup; write();
  }
  async function previous(update) {
    if (!state.good) return null;
    try { const m = validate(state.good, state.good.pack); if ((state.blocked || []).includes(m.sha256)) return null; const bytes = await cacheGet(m); if (bytes) { update(20, 'Запускаем сохранённую версию…'); return {manifest: m, bytes}; } } catch (_) {}
    return null;
  }
  window.IskraUpdater = {
    ABI,
    async prepare(update) {
      failPending();
      try { if (sessionStorage.getItem('iskra-force-base')) { sessionStorage.removeItem('iskra-force-base'); return null; } } catch (_) {}
      const configured = window.ISKRA_UPDATE_CONFIG?.manifestUrl || '';
      let url = configured;
      try { const f = await window.IskraPlatform.getUpdateFlags({update_manifest: configured, updates_enabled: 'true'}); if (f.updates_enabled === 'false') return null; url = f.update_manifest || configured; } catch (_) {}
      if (!url) return null;
      try {
        url = cloud(url); update(4, 'Проверяем обновления…');
        const m = validate(JSON.parse(new TextDecoder().decode(await request(url, 16384, 5000))), url);
        if ((state.blocked || []).includes(m.sha256)) return await previous(update);
        update(6, 'Загружаем обновление ' + m.version + '…');
        let bytes = await cacheGet(m);
        if (!bytes) { bytes = await verify(await request(m.pack, m.bytes, 120000, n => update(6 + 40 * n / m.bytes, 'Загружаем обновление ' + m.version + '…')), m); await cachePut(m, bytes); }
        selected = {manifest: m, bytes}; return selected;
      } catch (e) { console.warn('Iskra update unavailable:', e.message); return await previous(update); }
    },
    begin(release) {
      selected = release;
      if (!release) return;
      try { state.backup = localStorage.getItem('iskra-idle-v2'); } catch (_) { state.backup = undefined; }
      state.pending = release.manifest; write();
    },
    async ready() {
      if (!selected) return;
      state.good = selected.manifest; delete state.pending; delete state.backup; write();
      try { const c = await caches.open(CACHE); for (const key of await c.keys()) if (key.url !== cacheKey(state.good)) await c.delete(key); } catch (_) {}
      selected = null;
    },
    failed() { if (!selected) return false; failPending(); selected = null; return true; },
    useBase() { try { sessionStorage.setItem('iskra-force-base', '1'); } catch (_) {} location.reload(); }
  };
})();
