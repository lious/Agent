// NEW B09–B11 actual-App composition only; standard keyboard and public File injection.
const fs=require('fs'),assert=require('assert/strict');
(async()=>{
 const [portFile,url,fixture,out,mode,expectedPath,gtkHelper]=process.argv.slice(2); const expected=JSON.parse(fs.readFileSync(expectedPath));let port;
 for(let i=0;i<100;i++){try{port=+fs.readFileSync(portFile,'utf8').split('\n')[0];break;}catch{}await new Promise(r=>setTimeout(r,50));}if(!port)throw Error('Chrome startup timeout');
 const targets=await(await fetch(`http://127.0.0.1:${port}/json/list`)).json(),ws=new WebSocket(targets.find(t=>t.type==='page').webSocketDebuggerUrl);await new Promise((r,j)=>{ws.onopen=r;ws.onerror=j;});let seq=0;const pending=new Map(),requests=[],exceptions=[],choosers=[],traces=[],navigations=[],nativeEvents=[];let nativeComplete=null,nativeCollected=false;
 ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(Error(JSON.stringify(m.error))):p.resolve(m.result);}if(m.method==='Tracing.dataCollected')nativeEvents.push(...m.params.value);if(m.method==='Tracing.tracingComplete')nativeComplete=m.params;if(m.method==='Page.frameNavigated'&&!m.params.frame.parentId)navigations.push(m.params);if(m.method==='Runtime.consoleAPICalled'){const v=m.params.args?.[0]?.value;if(typeof v==='string'&&v.startsWith('__signedImportTrace__'))traces.push(JSON.parse(v.slice('__signedImportTrace__'.length)));}if(m.method==='Page.fileChooserOpened')choosers.push(m.params);if(m.method==='Network.requestWillBeSent')requests.push(m.params.request.url);if(m.method==='Runtime.exceptionThrown')exceptions.push(m.params.exceptionDetails);};
 const call=(method,params={})=>new Promise((resolve,reject)=>{const id=++seq;pending.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params}));});
 const ev=async expression=>{const r=await call('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
 const wait=async fn=>{for(let i=0;i<400;i++){const v=await fn();if(v)return v;await new Promise(r=>setTimeout(r,50));}throw Error('App composition condition timeout');};
 const button=name=>ev(`(()=>{let e=[...document.querySelectorAll('[role=button],button')].find(e=>e.getAttribute('aria-label')===${JSON.stringify(name)}||e.textContent.trim()===${JSON.stringify(name)});if(!e)return null;let r=e.getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2,disabled:e.getAttribute('aria-disabled'),label:e.getAttribute('aria-label')||e.textContent};})()`);
 const click=async name=>{const b=await button(name);assert(b,'button '+name);await call('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',clickCount:1,x:b.x,y:b.y});await call('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',clickCount:1,x:b.x,y:b.y});};
 const text=async()=>JSON.stringify((await call('Accessibility.getFullAXTree')).nodes.map(n=>[n.name?.value,n.value?.value]))+await ev('JSON.stringify([...document.querySelectorAll("[aria-label]")].map(e=>e.getAttribute("aria-label")))+JSON.stringify([...document.querySelectorAll("input,textarea")].map(e=>e.value))+document.body.textContent');
 const storedSnapshot=()=>ev(`(async()=>{let result=[];for(const item of (await indexedDB.databases()).sort((a,b)=>a.name.localeCompare(b.name))){const db=await new Promise((r,j)=>{let q=indexedDB.open(item.name);q.onsuccess=()=>r(q.result);q.onerror=()=>j(Error('test DB snapshot'));});let stores=[];for(const name of [...db.objectStoreNames].sort()){let records=await new Promise((r,j)=>{const t=db.transaction(name,'readonly');let keys,values;const s=t.objectStore(name),k=s.getAllKeys(),v=s.getAll();k.onsuccess=()=>keys=k.result;v.onsuccess=()=>values=v.result;t.oncomplete=()=>r([keys,values]);t.onerror=()=>j(Error('test readonly transaction'));});stores.push([name,records]);}result.push([item.name,item.version,stores]);db.close();}return JSON.stringify([result,Object.entries(localStorage).sort(),Object.entries(sessionStorage).sort()],(_,v)=>v instanceof ArrayBuffer?Array.from(new Uint8Array(v)):ArrayBuffer.isView(v)?Array.from(new Uint8Array(v.buffer,v.byteOffset,v.byteLength)):v);})()`);

 await call('Page.enable');await call('Accessibility.enable');await call('Runtime.enable');await call('Network.enable');await call('Tracing.start',{traceConfig:{recordMode:'recordAsMuchAsPossible',includedCategories:['blink.user_timing'],excludedCategories:['*']},transferMode:'ReportEvents'});await call('Page.setInterceptFileChooserDialog',{enabled:true});

 await call('Page.addScriptToEvaluateOnNewDocument',{source:`
 window.lifecycleRealm=crypto.randomUUID();window.compositionViolations=[];window.compositionWrites=[];
 const observedRealm=window.lifecycleRealm,observedWrites=window.compositionWrites,nativeDebug=console.debug.bind(console),nativeMark=performance.mark.bind(performance);let observedReader=null;
 const emit=value=>{const label='__signedImportTrace__'+JSON.stringify(value);nativeMark(label);nativeDebug(label);};
 const trace=(event,extra={})=>emit({event,realm:window.lifecycleRealm,visibility:document.visibilityState,focus:document.hasFocus(),writes:compositionWrites.length,...extra});
 window.addEventListener('pagehide',e=>emit({event:'pagehide',transport:'capture-console',realm:observedRealm,writes:observedWrites.length,isTrusted:e.isTrusted,persisted:e.persisted,reader:observedReader}),{capture:true});
 window.addEventListener('pageshow',e=>trace('pageshow',{isTrusted:e.isTrusted,persisted:e.persisted}),{capture:true});
 document.addEventListener('visibilitychange',e=>trace('visibilitychange',{isTrusted:e.isTrusted}));
 window.addEventListener('blur',e=>trace('blur',{isTrusted:e.isTrusted}));window.addEventListener('focus',e=>trace('focus',{isTrusted:e.isTrusted}));
 for(const event of ['cancel','change'])document.addEventListener(event,e=>{if(e.target?.type==='file')trace('file-'+event,{isTrusted:e.isTrusted,count:e.target.files?.length});},true);
 document.addEventListener('DOMContentLoaded',()=>new MutationObserver(()=>{observedReader=document.documentElement.getAttribute('data-signed-import-fixture-reader');trace('reader',{reader:observedReader});}).observe(document.documentElement,{attributes:true,attributeFilter:['data-signed-import-fixture-reader']}));
 document.addEventListener('securitypolicyviolation',e=>{compositionViolations.push(e.violatedDirective);trace('violation',{directive:e.violatedDirective});});
 for(const [proto,names] of [[Storage.prototype,['setItem','removeItem','clear']],[IDBCursor.prototype,['update','delete']],[IDBFactory.prototype,['deleteDatabase']],[IDBObjectStore.prototype,['put','add','delete','clear']]])for(const n of names){const original=proto[n];proto[n]=function(...a){compositionWrites.push(n);return original.apply(this,a);};}
 `});
 const collectNative=async()=>{
   if(nativeCollected)return;await call('Tracing.end');await wait(()=>nativeComplete);assert.equal(nativeComplete.dataLossOccurred,false);
   for(const event of nativeEvents){const value=event.name??event.args?.data?.name;if(typeof value==='string'&&value.startsWith('__signedImportTrace__')){const t=JSON.parse(value.slice('__signedImportTrace__'.length));if(t.event==='pagehide')traces.push({...t,transport:'chrome-user-timing'});}}
   nativeCollected=true;
 };
 const enable=async()=>{if(await ev('!!document.querySelector("flt-semantics-placeholder")'))await ev('document.querySelector("flt-semantics-placeholder").click()');};
 const ready=async()=>{await wait(()=>ev('!!document.querySelector("flt-semantics-placeholder") || !!document.querySelector("[role=button]")'));await enable();await wait(async()=> (await text()).includes('Ready for preview only'));};
 const key=async(name,code)=>{await call('Input.dispatchKeyEvent',{type:'keyDown',key:name,code:name,windowsVirtualKeyCode:code,nativeVirtualKeyCode:code});await call('Input.dispatchKeyEvent',{type:'keyUp',key:name,code:name,windowsVirtualKeyCode:code,nativeVirtualKeyCode:code});};
 const focused=async name=>(await call('Accessibility.getFullAXTree')).nodes.some(n=>n.name?.value===name&&n.properties?.some(p=>p.name==='focused'&&p.value.value===true));
 const activate=async name=>{for(let i=0;i<100;i++){await key('Tab',9);await new Promise(r=>setTimeout(r,70));if(await focused(name)){await new Promise(r=>setTimeout(r,100));if(name.startsWith('Apply fixture transition '))await report();await key('Enter',13);return;}}throw Error('No standard keyboard focus '+name);};
 const noAck=async()=>assert(!(await text()).includes('Preview acknowledged only;'));
 const report=async()=>{await wait(async()=> (await text()).includes('trustState: verified'));const body=await text();for(const f of ['envelopeHash','payloadHash','contentHash','permissionDiffHash'])assert(body.includes(expected[f]),f);await noAck();};
 const select=async()=>{const count=choosers.length;await activate('Choose skill source');await wait(()=>choosers.length===count+1);await wait(async()=> (await button('Choose skill source')).disabled==='true');await call('DOM.setFileInputFiles',{files:[fixture],backendNodeId:choosers.at(-1).backendNodeId});await report();};
 await call('Page.navigate',{url});await ready();
 const initialRealm=await ev('lifecycleRealm'),initialSnapshot=await storedSnapshot(),initialWrites=await ev('compositionWrites.length');
 let beforeRequests=requests.length,details={};
 const checkFlow=async()=>{assert.equal(await ev('compositionWrites.length'),initialWrites);assert.equal(await storedSnapshot(),initialSnapshot);assert.equal(requests.length,beforeRequests);await noAck();};
 const invalidated=async()=>{await wait(async()=> (await text()).includes('State: invalidated'));assert(!(await text()).includes('trustState: verified'));assert.equal((await button('Choose skill source')).disabled,'true');assert.equal((await button('Acknowledge preview only')).disabled,'true');await noAck();};
 const transition=async name=>{await activate('Apply fixture transition '+name);await wait(async()=> (await text()).includes('Fixture transition: '+name));};
 await select();await checkFlow();
 if(mode==='B10'){
   const original=await text();
   await transition('forward-valid');await report();
   assert.notEqual((await button('Acknowledge preview only')).disabled,'true');
   await transition('forward-expired');await report();
   assert.notEqual((await button('Acknowledge preview only')).disabled,'true');
   await activate('Acknowledge preview only');
   await wait(async()=> (await text()).includes('Preview stale or refused; select again'));
   assert(!(await text()).includes('trustState: verified'));await noAck();
   assert.notEqual((await button('Choose skill source')).disabled,'true');
   assert.equal((await button('Acknowledge preview only')).disabled,'true');
   // Expired target cannot be reused; a new real File selection is required.
   const count=choosers.length;await activate('Choose skill source');await wait(()=>choosers.length===count+1);
   await call('DOM.setFileInputFiles',{files:[fixture],backendNodeId:choosers.at(-1).backendNodeId});
   await wait(async()=> (await text()).includes('SKILL_IMPORT_SIGNATURE'));
   assert(!(await text()).includes('trustState: verified'));await checkFlow();
   details={forwardValid:1001,exclusiveSignerExpiry:10000,actualRepositoryRefused:true,freshSelectionRequired:true,freshFileSelectionObserved:true,freshSelectionRefusal:'SKILL_IMPORT_SIGNATURE'};
 }else{
   const name=mode.replace(/^B(?:09|11)-/,'');await transition(name);await invalidated();
   await activate('Rebuild fixture App');await invalidated();await checkFlow();
   const facts=await text();
   const expect={profile:'profileChanged=true',epoch:'epoch=2','key-removal':'keys=0',installed:'installed=[media.analyze]',session:'session=[media.analyze]',branch:'branch=[media.analyze]',owner:'owner=fixture-other-project',aba:'session=[]',backward:'now=999',confidence:'confidence=false',rollback:'rollback=true'};
   if(!facts.includes(expect[name]))fs.writeFileSync(out+'.facts-diagnostic.json',JSON.stringify({facts,html:await ev('document.body.innerText'),mode},null,2));assert(facts.includes(expect[name]),expect[name]);
   details={transition:name,terminalRetirement:true,rebuildDidNotRevive:true,actualOwnerAndRepository:true,observedFact:expect[name]};
 }
 await collectNative();assert.deepEqual(exceptions,[]);assert.deepEqual(await ev('compositionViolations'),[]);assert(!traces.some(t=>t.event==='violation'));assert(requests.every(u=>u.startsWith(new URL(url).origin+'/')));
 const result={passed:true,caseId:mode,details,chooserCount:choosers.length,actualApp:'WebStudioApp.testImport + actual owner/panel/store + real web factory',noAcknowledgmentAccepted:true,storageSnapshotUnchanged:true,noComponentWrites:true,traces,navigations,nativeTraceDataLoss:nativeComplete.dataLossOccurred,requests,exceptions,violations:[],scope:'B09–B11 box compiled App only; no OS device/AT/model/provider/full A6'};
 fs.writeFileSync(out,JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify({mode,passed:true,details}));ws.close();
})().catch(e=>{console.error(e);process.exit(1);});
