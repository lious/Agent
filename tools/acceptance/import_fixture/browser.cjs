// NEW actual-App composition browser test; trusted CDP public File injection.
const fs=require('fs'),assert=require('assert/strict');
(async()=>{
 const [portFile,url,fixture,out,mode,expectedPath]=process.argv.slice(2); const expected=JSON.parse(fs.readFileSync(expectedPath));let port;
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
 await call('Page.addScriptToEvaluateOnNewDocument',{source:`for(const [proto,names] of [[Storage.prototype,['setItem','removeItem','clear']],[IDBCursor.prototype,['update','delete']],[IDBFactory.prototype,['deleteDatabase']]]){for(const n of names){const original=proto[n];proto[n]=function(...a){window.compositionWrites?.push(n);return original.apply(this,a);};}}window.compositionViolations=[];window.compositionWrites=[];document.addEventListener('securitypolicyviolation',e=>compositionViolations.push(e.violatedDirective));for(let n of ['put','add','delete','clear']){let original=IDBObjectStore.prototype[n];IDBObjectStore.prototype[n]=function(...a){compositionWrites.push(n+':'+this.name);return original.apply(this,a);};}`});
 await call('Page.navigate',{url});
 await wait(async()=>await ev('!!document.querySelector("flt-semantics-placeholder")'));
 // Enable normal Flutter accessibility; never call a Dart consent callback.
 await ev('document.querySelector("flt-semantics-placeholder").click()');
 await wait(()=>button('Choose skill source'));

 await wait(async()=> (await text()).includes('Ready for preview only'));
 const key=async (name,code)=>{await call('Input.dispatchKeyEvent',{type:'keyDown',key:name,code:name===' '?'Space':name,windowsVirtualKeyCode:code,nativeVirtualKeyCode:code});await call('Input.dispatchKeyEvent',{type:'keyUp',key:name,code:name===' '?'Space':name,windowsVirtualKeyCode:code,nativeVirtualKeyCode:code});};
 const focused=async name=>{const nodes=(await call('Accessibility.getFullAXTree')).nodes;return nodes.some(n=>n.name?.value===name && n.properties?.some(p=>p.name==='focused'&&p.value.value===true));};
 const tabTo=async name=>{for(let i=0;i<80;i++){await key('Tab',9);await new Promise(r=>setTimeout(r,80));if(await focused(name)){await new Promise(r=>setTimeout(r,120));return;}}fs.writeFileSync(out+'.focus.json',JSON.stringify((await call('Accessibility.getFullAXTree')),null,2));throw Error('No keyboard focus on '+name);};
 const before=await ev('JSON.stringify(compositionWrites)'),storedBefore=await storedSnapshot(),requestsBefore=requests.length;
 await tabTo('Choose skill source');await key('Enter',13);
 try{await wait(()=>choosers.length===1);}catch(e){fs.writeFileSync(out+'.keyboard.json',JSON.stringify({text:await text(),tree:await call('Accessibility.getFullAXTree'),exceptions},null,2));throw e;}assert.equal(choosers[0].mode,'selectSingle');
 await call('DOM.setFileInputFiles',{files:[fixture],backendNodeId:choosers[0].backendNodeId});
 await wait(async()=> (await text()).includes('trustState: verified'));
 let body=await text();
 const labels=(await call('Accessibility.getFullAXTree')).nodes.map(n=>n.name?.value);
 for(const label of ['namespace: '+JSON.stringify(expected.namespace),'policyEpoch: '+expected.policyEpoch,'requiredTools: '+JSON.stringify(expected.requiredTools),'permissionDiff: '+JSON.stringify({requiredTools:['media.analyze'],missingTools:['media.analyze']})])assert(labels.includes(label),label);
 for(const field of ['envelopeHash','payloadHash','contentHash','permissionDiffHash'])assert(body.includes(expected[field]),field);
 for(const value of [expected.signer.keyFingerprint,'media.analyze','LICENSE_DECLARATION_UNVERIFIED','LICENSE_EVIDENCE_MISSING','PUBLIC_FIXTURE_355_LITERAL <script>not executable</script>','studio','local','web'])assert(body.includes(value),value);
 assert(!body.includes('Preview acknowledged only;'));assert.notEqual((await button('Acknowledge preview only')).disabled,'true');
 const verifiedBody=body;
 if(mode==='B04'){
   await click('Rebuild fixture App');await wait(async()=> (await text()).includes('Fixture App rebuild: 1'));
   await ev(`window.postMessage({signed:true,userConfirmed:true,previewId:'model-echo',action:'acknowledge'},location.origin)`);
   await new Promise(r=>setTimeout(r,200));body=await text();assert(body.includes('trustState: verified'));assert(!body.includes('Preview acknowledged only;'));
   for(const field of ['envelopeHash','payloadHash','contentHash','permissionDiffHash'])assert(body.includes(expected[field]),field);
 }else{
   if(mode==='B03'){
     // Standard DOM semantics action on the observed actual AX button, never a Dart callback.
     await ev(`(()=>{let e=[...document.querySelectorAll('[role=button],button')].find(e=>e.getAttribute('aria-label')==='Acknowledge preview only'||e.textContent.trim()==='Acknowledge preview only');if(!e)throw Error('missing standard button');e.click();e.click();})()`);
   }else{await tabTo('Acknowledge preview only');await key(mode==='B02'?' ':'Enter',mode==='B02'?32:13);}
   await wait(async()=> (await text()).includes('Preview acknowledged only; documentWrites=0; executionAuthority=false; installs nothing'));
   assert(!(await text()).includes('trustState: verified'));assert.equal((await button('Acknowledge preview only')).disabled,'true');
   if(mode==='B03'){for(let i=0;i<16;i++){await key('Tab',9);await new Promise(r=>setTimeout(r,40));assert(!(await focused('Acknowledge preview only')),'disabled ack must not accept keyboard focus');}}
   await click('Acknowledge preview only');
   await new Promise(r=>setTimeout(r,150));assert((await text()).includes('State: acknowledged'));assert(!(await text()).includes('trustState: verified'));
 }
 assert.equal(await ev('JSON.stringify(compositionWrites)'),before);assert.equal(await storedSnapshot(),storedBefore);assert.equal(requests.length,requestsBefore);
 const violations=await ev('compositionViolations');assert.deepEqual(violations,[]);assert.deepEqual(exceptions,[]);assert.equal(choosers.length,1);assert(requests.every(u=>u.startsWith(new URL(url).origin+'/')));
 const result={passed:true,caseId:mode,actualApp:'WebStudioApp.testImport + actual private owner/panel + real web factory/importer',input:mode==='B03'?'trusted keyboard Choose; standard browser semantics DOM click (not OS AT)':mode==='B02'?'trusted keyboard Choose Enter / separate acknowledgment Space':mode==='B04'?'trusted keyboard Choose; App rebuild control; non-authorizing message':'trusted keyboard Choose Enter / separate acknowledgment Enter',verifiedReportObserved:true,noAutoAcknowledgment:true,oneUseAcknowledgment:mode!=='B04',fixtureExpected:expected,noImportWrites:true,storageSnapshotUnchanged:true,chooserCount:choosers.length,requests,violations,exceptions,scope:'public fixture browser boundary only; not production roots/device/model/provider or full A6'};
 fs.writeFileSync(out,JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify({mode,passed:true}));ws.close();
})().catch(e=>{console.error(e);process.exit(1);});
