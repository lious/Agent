// TEST ONLY public fixture injection at the real Chrome File boundary (not manual OS dialog).
const fs=require('fs'),assert=require('assert/strict'),{execFileSync}=require('child_process');
(async()=>{
const [portFile,url,fixtures,out]=process.argv.slice(2);let port;
for(let i=0;i<100;i++){try{port=+fs.readFileSync(portFile,'utf8').split('\n')[0];break;}catch{}await new Promise(r=>setTimeout(r,50));}
if(!port)throw Error('Chrome startup timeout');
const targets=await(await fetch(`http://127.0.0.1:${port}/json/list`)).json(),ws=new WebSocket(targets.find(t=>t.type==='page').webSocketDebuggerUrl);
await new Promise((r,j)=>{ws.onopen=r;ws.onerror=j;});let seq=0;const pending=new Map(),choosers=[],requests=[],exceptions=[],cases=[];
ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(Error(JSON.stringify(m.error))):p.resolve(m.result);}if(m.method==='Page.fileChooserOpened')choosers.push(m.params);if(m.method==='Network.requestWillBeSent')requests.push(m.params.request.url);if(m.method==='Runtime.exceptionThrown')exceptions.push(m.params.exceptionDetails);};
const call=(method,params={})=>new Promise((resolve,reject)=>{const id=++seq;pending.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params}));});
const ev=async expression=>{const r=await call('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
const wait=async fn=>{for(let i=0;i<200;i++){const v=await fn();if(v)return v;await new Promise(r=>setTimeout(r,25));}throw Error('browser test condition timeout');};
const status=()=>ev('JSON.parse(document.querySelector("#status").textContent)');
async function click(id){const p=await ev(`(()=>{let r=document.querySelector('#${id}').getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2}})()`);await call('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',clickCount:1,...p});await call('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',clickCount:1,...p});}
await call('Page.enable');await call('Runtime.enable');await call('Network.enable');await call('Page.setInterceptFileChooserDialog',{enabled:true});
await call('Page.addScriptToEvaluateOnNewDocument',{source:`window.slices=[];window.violations=[];document.addEventListener('securitypolicyviolation',e=>violations.push(e.violatedDirective));const sl=Blob.prototype.slice;Blob.prototype.slice=function(a,b){slices.push([a,b]);return sl.call(this,a,b);};`});
async function fresh(){await call('Page.navigate',{url});await wait(async()=>await ev('document.querySelector("#status")?.textContent.includes("ready")'));}
async function open(){const n=choosers.length;await click('choose');await wait(()=>choosers.length>n);assert.equal(choosers.at(-1).mode,'selectSingle');return choosers.at(-1).backendNodeId;}
async function inject(id,path){await call('DOM.setFileInputFiles',{files:path?[path]:[],backendNodeId:id});}
await fresh();
for(const size of [0,1,65535,65536,65537,4194303,4194304,4194305]){
 const path=`${fixtures}/${size}.bin`;fs.writeFileSync(path,Buffer.alloc(size,42));await ev('slices=[]');await inject(await open(),path);
 const r=await wait(async()=>{const v=await status();return v.done?v:null;});assert.equal(r.busy,false);
 const slices=await ev('slices');assert(slices.every(([a,b])=>b>a&&b-a<=65536));
 if(size>4194304){assert.equal(r.error,'limit');assert.equal(slices.length,0);}else{assert.equal(r.length,size);assert.equal(r.sum,size*42);if(size)assert.equal(r.immutable,true);assert.equal(slices.at(-1)[0],size);}
 assert.equal(await ev('document.querySelectorAll("input[type=file]").length'),0);cases.push(`File capture ${size}`);
}
// SAME browser File reselected with fresh private input.
await inject(await open(),`${fixtures}/1.bin`);assert.equal((await wait(async()=>{const r=await status();return r.done?r:null;})).length,1);cases.push('same file reselection');
// Synthetic DOM events do not settle a chooser or read bytes. Ordinary App cancellation
// invalidates immediately but keeps one pending operation until trusted late completion.
let id=await open();await ev(`document.querySelector('input').dispatchEvent(new Event('change'));document.querySelector('input').dispatchEvent(new Event('cancel'));slices=[]`);
assert.equal((await status()).pending,true);assert.equal((await status()).busy,true);await click('cancel');await wait(async()=>(await status()).done);assert.equal((await status()).length,null);assert.equal((await status()).busy,true);
await click('choose');assert.equal((await status()).error,'busy');assert.equal(choosers.at(-1).backendNodeId,id);
await inject(id,`${fixtures}/1.bin`);await wait(async()=>await ev('document.querySelectorAll("input").length===0'));
// Controller quiescence occurs after the trusted event's microtasks; query a new
// operation, whose successful result proves the old one did not retain busy.
await inject(await open(),`${fixtures}/1.bin`);assert.equal((await wait(async()=>{const r=await status();return r.done?r:null;})).length,1);assert.equal((await ev('slices')).length,2);cases.push('untrusted events ignored; cancel/busy/late completion drains without read');
// CDP empty injection does not dispatch a cancel event in this Chrome profile.
// Verify fail-closed pending state; DO NOT forge isTrusted or claim OS cancellation.
id=await open();await inject(id,null);assert.equal((await status()).pending,true);assert.equal((await status()).busy,true);await click('cancel');await inject(id,`${fixtures}/1.bin`);await wait(async()=>await ev('document.querySelectorAll("input").length===0'));cases.push('empty CDP injection remains pending; App cancellation drains trusted late result');
// Separate real Chrome/GTK cancellation on this isolated BOX display. Unlike
// empty CDP injection, Escape from the native chooser emits trusted cancel.
await call('Page.setInterceptFileChooserDialog',{enabled:false});await click('choose');execFileSync('python3',[process.argv[6],'cancel',''],{timeout:25000});
const cancelled=await wait(async()=>{const r=await status();return r.done?r:null;});assert.equal(cancelled.length,null);assert.equal(cancelled.busy,false);assert.equal(await ev('document.querySelectorAll("input").length'),0);cases.push('actual Chrome GTK chooser Escape emits trusted cancel and resets');
await call('Page.setInterceptFileChooserDialog',{enabled:true});
// Terminal disposal detaches listeners but DOES NOT pretend the OS dialog settled.
id=await open();await click('dispose');await wait(async()=>(await status()).done);assert.equal(await ev('document.querySelectorAll("input").length'),0);assert.equal((await status()).busy,true);await click('choose');assert.equal((await status()).error,'disposed');cases.push('terminal unresolved chooser is retired, not replaced');
assert.deepEqual(await ev('violations'),[]);assert.deepEqual(exceptions,[]);assert(requests.every(u=>u===url||u===new URL('/probe.js',url).href||u===new URL('/favicon.ico',url).href));assert.equal(await ev('localStorage.length+sessionStorage.length'),0);
const result={passed:true,cases,requests,exceptions,violations:await ev('violations'),browser:await call('Browser.getVersion'),scope:'CDP trusted File boundary plus automated actual Chrome GTK cancellation on isolated box Xvfb; no manual OS dialog, App CSP, importer, crypto, consent or device claim'};fs.writeFileSync(out,JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));ws.close();
})().catch(e=>{console.error(e);process.exit(1);});
