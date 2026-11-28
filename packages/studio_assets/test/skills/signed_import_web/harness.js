// TEST ONLY fault-injection and reporting. Never shipped as App crypto code.
'use strict';
window.signedImportTestMode = new URL(location.href).searchParams.get('mode');
const mode = window.signedImportTestMode, violations = [], errors = [];
let faultActive = false;
const started = performance.now(), storageCalls=[];
for(const key of ['setItem','removeItem','clear']){
  Storage.prototype[key]=function(){storageCalls.push(key);throw Error('storage forbidden');};
}
for(const key of ['open','deleteDatabase']){
  indexedDB[key]=function(){storageCalls.push('indexedDB.'+key);throw Error('storage forbidden');};
}

addEventListener('securitypolicyviolation', e => violations.push({directive:e.violatedDirective, blocked:e.blockedURI}));
addEventListener('error', e => errors.push(String(e.message)));
window.signedImportTestData = async () => {
  const [fixtures,vectors]=await Promise.all(['/fixtures.json','/vectors.json'].map(p=>fetch(p).then(r=>r.json())));
  return JSON.stringify({fixtures,vectors});
};
window.signedImportTestReport = text => {
  const report=JSON.parse(text);report.elapsedMs=performance.now()-started;
  report.violations=violations;report.browserErrors=errors;
  report.secureContext=isSecureContext;report.userAgent=navigator.userAgent;
  report.observedArtifact='libsodium.js 0.8.4 combined JS/WebAssembly; path not individually instrumented';
  report.vendorTamperExecuted=window.vendorTamperExecuted===true;
  report.persistenceCalls=storageCalls; if(storageCalls.length)report.ok=false;
  if (mode==='fail-late' || mode==='fail-deadline') {
    if(report.elapsedMs<10000 || report.elapsedMs>18000){report.ok=false;report.deadlineFailure=true;}
  }
  fetch('/result',{method:'POST',body:JSON.stringify(report)});
};
if(mode==='fail-preexisting')window.sodium={onload(){throw Error('must not adopt');}};
if(mode==='fail-foreign')window.studioSignedImportV1=Object.freeze({initialize(){return Promise.resolve(true);},healthy(){return true;}});
if(mode==='fail-csprng')Object.defineProperty(window.crypto,'getRandomValues',{value:undefined});
const append=document.head.appendChild.bind(document.head);
document.head.appendChild=function(script){
  if(!script.src.includes('/vendor/studio-signed-import/'))return append(script);
  const ready=window.sodium.onload;
  window.sodium.onload=function(s){
    if(mode==='fail-symbol')s.crypto_core_ed25519_is_valid_point=undefined;
    if(mode==='fail-version')s.sodium_version_string=()=> '1.0.21';
    if(mode==='fail-truthy')s.crypto_sign_verify_detached=()=>1;
    if(mode==='aliasing'){
      const p=s.crypto_core_ed25519_is_valid_point,v=s.crypto_sign_verify_detached;
      s.crypto_core_ed25519_is_valid_point=function(k){const b=p.call(s,k);k.fill(0);return b;};
      s.crypto_sign_verify_detached=function(sig,msg,pk){const b=v.call(s,sig,msg,pk);sig.fill(0);msg.fill(0);pk.fill(0);return b;};
    }
    if(mode==='truthy'||mode==='exception'){
      const v=s.crypto_sign_verify_detached;
      s.crypto_sign_verify_detached=function(...args){if(faultActive){if(mode==='truthy')return 1;throw Error('test-only upstream failure');}return v.apply(s,args);};
    }
    ready(s);
  };
  if(mode==='fail-deadline')return script;
  if(mode==='fail-late'){setTimeout(()=>append(script),11000);return script;}
  if(mode==='fail-before-ready'){queueMicrotask(()=>{try{window.studioSignedImportV1.healthy();}catch(_){}});}
  return append(script);
};
window.signedImportTestAction=function(action){
  if(action==='replacement'){window.sodium={};return true;}
  if(action==='truthy'||action==='exception'){faultActive=true;return true;}
  if(action==='teardown'){dispatchEvent(new PageTransitionEvent('pagehide'));return true;}
  if(action.startsWith('bad-')) {
    let value;
    if(action==='bad-string')value='a'.repeat(32);
    if(action==='bad-shared'){
      if(typeof SharedArrayBuffer!=='function')throw Error('shared-memory test requires COOP/COEP, no skip');
      value=new Uint8Array(new SharedArrayBuffer(32));
    }
    if(action==='bad-resizable'){
      const buffer=new ArrayBuffer(32,{maxByteLength:64});
      if(buffer.resizable!==true)throw Error('resizable test unsupported, no skip');
      value=new Uint8Array(buffer);
    }
    try {window.studioSignedImportV1.validPublicKey(value);return false;}catch(_){return true;}
  }
  if(action==='byteBoundary'){
    const bridge=window.studioSignedImportV1;
    if(!Object.isFrozen(bridge))return false;
    let replaced=false;try{window.studioSignedImportV1={};}catch(_){replaced=true;}
    if(!replaced||window.studioSignedImportV1!==bridge)return false;
    const hex=s=>new Uint8Array(s.match(/../g).map(x=>parseInt(x,16)));
    const pk=hex('3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c');
    const sig=hex('92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00');
    const msg=hex('72'),before=[...msg,...sig,...pk].join(',');
    if(bridge.verify(msg,sig,pk)!==true)return false;
    return [...msg,...sig,...pk].join(',')===before;
  }
  throw Error('unknown TEST action');
};
