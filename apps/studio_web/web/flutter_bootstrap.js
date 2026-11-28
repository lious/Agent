// App-owned main-realm CanvasKit host. No service worker, worker or CDN fallback.
{{flutter_js}}
{{flutter_build_config}}

(() => {
  'use strict';
  // The strict-CSP host supplies a fresh style-only nonce in its HTTP response.
  // A plain static development host has no such profile and is NOT qualified by
  // merely serving this file; it must use the documented headers and SRI as well.
  const meta = document.querySelector('meta[name="app-style-nonce"]');
  const nonce = meta?.content;
  if (meta && !/^[A-Za-z0-9_-]{22,}$/.test(nonce)) {
    throw new Error('APP_HOST_STYLE_NONCE_INVALID');
  }
  _flutter.loader.load({
    config: {
      renderer: 'canvaskit',
      assetBase: '/',
      entrypointBaseUrl: '/',
      canvasKitBaseUrl: '/canvaskit/',
    },
    onEntrypointLoaded: async engine => {
      const app = await engine.initializeEngine({assetBase: '/', nonce});
      await app.runApp();
    },
  });
})();
