// NEW actual-App composition browser test; trusted CDP public File injection.
const fs=require('fs'),assert=require('assert/strict');
(async()=>{
 const [portFile,url,fixture,out,mode]=process.argv.slice(2);let port;
 for(let i=0;i<100;i++){try{port=+fs.readFileSync(portFile,'utf8').split('\n')[0];break;}catch{}await new Promise(r=>setTimeout(r,50));}if(!port)throw Error('Chrome startup timeout');
 const targets=await(await fetch(`http://127.0.0.1:${port}/json/list`)).json(),ws=new WebSocket(targets.find(t=>t.type==='page').webSocketDebuggerUrl);await new Promise((r,j)=>{ws.onopen=r;ws.onerror=j;});let seq=0;const pending=new Map(),requests=[],exceptions=[],choosers=[];
 ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(Error(JSON.stringify(m.error))):p.resolve(m.result);}if(m.method==='Page.fileChooserOpened')choosers.push(m.params);if(m.method==='Network.requestWillBeSent')requests.push(m.params.request.url);if(m.method==='Runtime.exceptionThrown')exceptions.push(m.params.exceptionDetails);};
 const call=(method,params={})=>new Promise((resolve,reject)=>{const id=++seq;pending.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params}));});
 const ev=async expression=>{const r=await call('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
 const wait=async fn=>{for(let i=0;i<400;i++){const v=await fn();if(v)return v;await new Promise(r=>setTimeout(r,50));}throw Error('App composition condition timeout');};
 const button=name=>ev(`(()=>{let e=[...document.querySelectorAll('[role=button],button')].find(e=>e.getAttribute('aria-label')===${JSON.stringify(name)}||e.textContent.trim()===${JSON.stringify(name)});if(!e)return null;let r=e.getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2,disabled:e.getAttribute('aria-disabled'),label:e.getAttribute('aria-label')||e.textContent};})()`);
 const click=async name=>{const b=await button(name);assert(b,'button '+name);await call('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',clickCount:1,x:b.x,y:b.y});await call('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',clickCount:1,x:b.x,y:b.y});};
 const text=async()=>JSON.stringify((await call('Accessibility.getFullAXTree')).nodes.map(n=>[n.name?.value,n.value?.value]))+await ev('JSON.stringify([...document.querySelectorAll("[aria-label]")].map(e=>e.getAttribute("aria-label")))+JSON.stringify([...document.querySelectorAll("input,textarea")].map(e=>e.value))+document.body.textContent');
 const storedSnapshot=()=>ev(`(async()=>{let result=[];for(const item of (await indexedDB.databases()).sort((a,b)=>a.name.localeCompare(b.name))){const db=await new Promise((r,j)=>{let q=indexedDB.open(item.name);q.onsuccess=()=>r(q.result);q.onerror=()=>j(Error('test DB snapshot'));});let stores=[];for(const name of [...db.objectStoreNames].sort()){let records=await new Promise((r,j)=>{const t=db.transaction(name,'readonly');let keys,values;const s=t.objectStore(name),k=s.getAllKeys(),v=s.getAll();k.onsuccess=()=>keys=k.result;v.onsuccess=()=>values=v.result;t.oncomplete=()=>r([keys,values]);t.onerror=()=>j(Error('test readonly transaction'));});stores.push([name,records]);}result.push([item.name,item.version,stores]);db.close();}return JSON.stringify([result,Object.entries(localStorage).sort(),Object.entries(sessionStorage).sort()],(_,v)=>v instanceof ArrayBuffer?Array.from(new Uint8Array(v)):ArrayBuffer.isView(v)?Array.from(new Uint8Array(v.buffer,v.byteOffset,v.byteLength)):v);})()`);
 await call('Page.enable');await call('Accessibility.enable');await call('Runtime.enable');await call('Network.enable');await call('Page.setInterceptFileChooserDialog',{enabled:true});
 await call('Page.addScriptToEvaluateOnNewDocument',{source:`window.compositionViolations=[];window.compositionWrites=[];document.addEventListener('securitypolicyviolation',e=>compositionViolations.push(e.violatedDirective));for(let n of ['put','add','delete','clear']){let original=IDBObjectStore.prototype[n];IDBObjectStore.prototype[n]=function(...a){compositionWrites.push(n+':'+this.name);return original.apply(this,a);};}`});
 await call('Page.navigate',{url});
 await wait(async()=>await ev('!!document.querySelector("flt-semantics-placeholder")'));
 // Enable normal Flutter accessibility; never call a Dart consent callback.
 await ev('document.querySelector("flt-semantics-placeholder").click()');
 await wait(()=>button('Choose skill source'));
 if(mode!=='normal'){
  await wait(async()=> (await text()).includes('Preview backend unavailable'));
  assert.equal((await button('Choose skill source')).disabled,'true');assert.equal(choosers.length,0);
 }else{
  await wait(async()=> (await text()).includes('Ready for preview only'));
  assert.notEqual((await button('Choose skill source')).disabled,'true');
  const before=await ev('JSON.stringify(compositionWrites)');const storedBefore=await storedSnapshot();const requestsBefore=requests.length;
  await click('Choose skill source');await wait(()=>choosers.length===1);assert.equal(choosers[0].mode,'selectSingle');
  await call('DOM.setFileInputFiles',{files:[fixture],backendNodeId:choosers[0].backendNodeId});
  await new Promise(r=>setTimeout(r,400));
  await call('Input.dispatchMouseEvent',{type:'mouseWheel',x:350,y:450,deltaY:200,deltaX:0});
  try{await wait(async()=> (await text()).includes('trustState: needsReview'));}catch(e){fs.writeFileSync(out+'.diagnostic.json',JSON.stringify({labels:await text(),exceptions,requests},null,2));throw e;}
  assert.equal((await button('Acknowledge preview only')).disabled,'true');
  const body=await text();for(const term of ['envelopeHash:','payloadHash:','contentHash:','permissionDiff:','missingTools','executionAuthority=false','Literal <script>not executable</script>'])assert(body.includes(term),term);
  await click('Dismiss preview');await wait(async()=> !(await text()).includes('trustState: needsReview'));
  assert.equal(await ev('JSON.stringify(compositionWrites)'),before);assert.equal(await storedSnapshot(),storedBefore);assert.equal(requests.length,requestsBefore);
 }
 const violations=await ev('compositionViolations');if(mode==='normal')assert.deepEqual(violations,[]);if(mode==='csp-backend-block')assert(violations.length>0);assert.equal(await ev('window.unverifiedCompositionVendorExecuted===true'),false);
 assert(requests.every(u=>u.startsWith(new URL(url).origin+'/')));assert.deepEqual(exceptions,[]);
 const result={passed:true,mode,actualApp:'WebStudioApp opt-in, actual compiled owner/widgets + existing File adapter/backend',chooseDisabled:(await button('Choose skill source')).disabled,chooserCount:choosers.length,requests,violations,exceptions,noImportIdbWrites:mode==='normal',idbAndLocalSessionSnapshotUnchanged:mode==='normal',scope:'recorded default-empty-root/unknown-clock App flow only; CDP public files, no manual dialog/device/provider qualification'};
 fs.writeFileSync(out,JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify({mode,passed:true}));ws.close();
})().catch(e=>{console.error(e);process.exit(1);});
