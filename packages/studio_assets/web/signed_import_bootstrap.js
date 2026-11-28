// App-owned opt-in bootstrap. Serve unchanged under the CSP/SRI profile in W1/W2.
// Trusted origin, not an XSS defense. Never load this from a pack-selected URL.
(() => {
  'use strict';
  const name = 'studioSignedImportV1';
  if (name in window) {
    // Separate terminal marker prevents adopting a foreign pre-existing bridge.
    Object.defineProperty(window, 'studioSignedImportBootstrapRejected', {value: true});
    throw new Error('SKILL_IMPORT_POLICY/backend/preexistingBridge');
  }
  let state = 'uninitialized', promise, rejectPending, timer, sodium;
  let point, verify, version, deadline;
  const fail = () => {
    state = 'failed';
    clearTimeout(timer);
    if (rejectPending) rejectPending(new Error('SKILL_IMPORT_POLICY/backend'));
    rejectPending = undefined;
  };
  const assertReady = () => {
    if (state !== 'ready' || window[name] !== bridge || window.sodium !== sodium ||
        sodium.crypto_core_ed25519_is_valid_point !== point ||
        sodium.crypto_sign_verify_detached !== verify ||
        sodium.sodium_version_string !== version ||
        !window.isSecureContext || !window.crypto ||
        typeof window.crypto.getRandomValues !== 'function') {
      fail(); throw new Error('SKILL_IMPORT_POLICY/backend');
    }
  };
  const copy = value => {
    if (!(value instanceof Uint8Array) || (typeof SharedArrayBuffer !== 'undefined' && value.buffer instanceof SharedArrayBuffer) ||
        value.buffer.resizable === true) throw new TypeError('byte array required');
    // Never retain/forward a view, even when Dart has already copied it.
    return new Uint8Array(value);
  };
  const boolean = value => {
    if (typeof value !== 'boolean') throw new TypeError('boolean required');
    return value === true;
  };
  const validPoint = value => boolean(point.call(sodium, new Uint8Array(value)));
  const check = (message, signature, key) => {
    if (key.length !== 32 || signature.length !== 64) return false;
    return validPoint(key) && validPoint(signature.slice(0, 32)) &&
      boolean(verify.call(sodium, new Uint8Array(signature), new Uint8Array(message), new Uint8Array(key)));
  };
  const hex = s => new Uint8Array(s.match(/../g).map(x => parseInt(x, 16)));
  const initialize = () => {
    if (promise) return promise;
    promise = new Promise((resolve, reject) => {
      rejectPending = reject;
      if (state !== 'uninitialized' || 'sodium' in window || !isSecureContext ||
          !window.crypto || typeof window.crypto.getRandomValues !== 'function') {
        fail(); return;
      }
      state = 'loading'; deadline = performance.now() + 10000;
      timer = setTimeout(fail, 10000);
      window.sodium = {onload: value => {
        if (state !== 'loading') return; // A late callback cannot revive failure.
        try {
          if (performance.now() >= deadline || window[name] !== bridge || window.sodium !== value) throw new Error('generation');
          sodium = value;
          point = sodium.crypto_core_ed25519_is_valid_point;
          verify = sodium.crypto_sign_verify_detached;
          version = sodium.sodium_version_string;
          if (typeof point !== 'function' || typeof verify !== 'function' ||
              typeof version !== 'function' || version.call(sodium) !== '1.0.22' ||
              sodium.crypto_sign_PUBLICKEYBYTES !== 32 || sodium.crypto_sign_BYTES !== 64) throw new Error('API/version');
          const key = hex('d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a');
          const sig = hex('e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b');
          const highS = new Uint8Array(sig); highS.fill(255, 32);
          const order = new Uint8Array(32); order[0] = 1;
          if (!check(new Uint8Array(), sig, key) || check(new Uint8Array(), highS, key) ||
              validPoint(order) || check(new Uint8Array(), sig, order)) throw new Error('self-test');
          const smallR = new Uint8Array(sig); smallR.set(order);
          if (check(new Uint8Array(), smallR, key)) throw new Error('small-order R');
          window.crypto.getRandomValues(new Uint8Array(16));
          // Include self-tests in the monotonic readiness deadline.
          if (performance.now() >= deadline) throw new Error('deadline');
          state = 'ready'; clearTimeout(timer); rejectPending = undefined; resolve(true);
        } catch (_) { fail(); }
      }};
      const script = document.createElement('script');
      script.src = '/vendor/studio-signed-import/sodium-0.8.4-sumo.js';
      script.integrity = 'sha384-mMeApJgV3qm7BJusi9ualkYZcdoTJBRsmYEZdzYa+yNWz+UH12DXh6SwImc6IO2V';
      script.crossOrigin = 'anonymous';
      script.onerror = fail;
      try { document.head.appendChild(script); } catch (_) { fail(); }
    });
    return promise;
  };
  const guarded = f => (...args) => {
    try { assertReady(); return f(...args); } catch (_) { fail(); throw new Error('SKILL_IMPORT_POLICY/backend'); }
  };
  const bridge = Object.freeze({
    initialize,
    healthy: guarded(() => true),
    validPublicKey: guarded(key => {const k = copy(key); return k.length === 32 && validPoint(k);}),
    verify: guarded((message, signature, key) => check(copy(message), copy(signature), copy(key))),
  });
  Object.defineProperty(window, name, {value: bridge});
  addEventListener('pagehide', fail, {once: true});
})();
