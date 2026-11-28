// TEST ONLY. Observe the actual existing App and crypto bootstrap dependency;
// no pack selection, crypto/vector requalification or preview-consent UI here.
'use strict';
const mode = new URL(location.href).searchParams.get('mode');
const violations = [], errors = [], registrations = [];
let firstFrame = false, backendState = 'uninitialized';
addEventListener('securitypolicyviolation', e => violations.push({
  directive: e.violatedDirective, blocked: e.blockedURI, sample: e.sample,
}));
addEventListener('error', e => errors.push(String(e.message)));
addEventListener('unhandledrejection', e => errors.push(String(e.reason)));
if (typeof ServiceWorkerContainer !== 'undefined') {
  ServiceWorkerContainer.prototype.register = function() {
    registrations.push('serviceWorker'); throw Error('service worker forbidden');
  };
}
function report() {
  window.appHostProbeResult = {
    mode, firstFrame, backendState, violations, errors, registrations,
    views: document.querySelectorAll('flutter-view').length,
    nonceStyles: [...document.querySelectorAll('style')].map(s => Boolean(s.nonce)),
    baseElements: document.querySelectorAll('base').length,
    vendorTamperExecuted: window.vendorTamperExecuted === true,
    userAgent: navigator.userAgent, secureContext: isSecureContext,
  };
}
addEventListener('flutter-first-frame', () => {firstFrame = true; setTimeout(report, 3000);});
addEventListener('load', () => {
  // Existing backend startup is a host dependency smoke check, not its old tests.
  window.studioSignedImportV1.initialize()
    .then(() => backendState = 'ready')
    .catch(() => backendState = 'failed');
});
setTimeout(report, 15000);
