// NEW L02–L03 controlled-reader App profiles ONLY; no L01/B01–B11 execution.
const fs=require('fs'),assert=require('assert/strict');
(async()=>{
 const [portFile,url,out,mode]=process.argv.slice(2);let port;
 for(let i=0;i<100;i++){try{port=+fs.readFileSync(portFile,'utf8').split('\n')[0];break;}catch{}await new Promise(r=>setTimeout(r,50));}if(!port)throw Error('Chrome startup timeout');
 const targets=await(await fetch(`http://127.0.0.1:${port}/json/list`)).json(),ws=new WebSocket(targets.find(t=>t.type==='page').webSocketDebuggerUrl);await new Promise((r,j)=>{ws.onopen=r;ws.onerror=j;});let seq=0;const pending=new Map(),requests=[],exceptions=[],choosers=[],traces=[],navigations=[],nativeEvents=[];let nativeComplete=null,nativeCollected=false;
 ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(Error(JSON.stringify(m.error))):p.resolve(m.result);}if(m.method==='Tracing.dataCollected')nativeEvents.push(...m.params.value);if(m.method==='Tracing.tracingComplete')nativeComplete=m.params;if(m.method==='Page.frameNavigated'&&!m.params.frame.parentId)navigations.push(m.params);if(m.method==='Runtime.consoleAPICalled'){const v=m.params.args?.[0]?.value;if(typeof v==='string'&&v.startsWith('__signedImportTrace__'))traces.push(JSON.parse(v.slice('__signedImportTrace__'.length)));}if(m.method==='Page.fileChooserOpened')choosers.push(m.params);if(m.method==='Network.requestWillBeSent')requests.push(m.params.request.url);if(m.method==='Runtime.exceptionThrown')exceptions.push(m.params.exceptionDetails);};
 const call=(method,params={})=>new Promise((resolve,reject)=>{const id=++seq;pending.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params}));});
 const ev=async expression=>{const r=await call('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
 const wait=async fn=>{for(let i=0;i<400;i++){const v=await fn();if(v)return v;await new Promise(r=>setTimeout(r,50));}throw Error('App composition condition timeout');};
 const button=name=>ev(`(()=>{let e=[...document.querySelectorAll('[role=button],button')].find(e=>e.getAttribute('aria-label')===${JSON.stringify(name)}||e.textContent.trim()===${JSON.stringify(name)});if(!e)return null;let r=e.getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2,disabled:e.getAttribute('aria-disabled'),label:e.getAttribute('aria-label')||e.textContent};})()`);
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
 window.addEventListener('keydown',e=>{if(['Tab','Enter'].includes(e.key))trace('key',{isTrusted:e.isTrusted,key:e.key});},true);
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
 const key=async(name,code)=>{await call('Input.dispatchKeyEvent',{type:'keyDown',key:name,code:name,windowsVirtualKeyCode:code,nativeVirtualKeyCode:code});await call('Input.dispatchKeyEvent',{type:'keyUp',key:name,code:name,windowsVirtualKeyCode:code,nativeVirtualKeyCode:code});};
 const focused=async name=>(await call('Accessibility.getFullAXTree')).nodes.some(n=>n.name?.value===name&&n.properties?.some(p=>p.name==='focused'&&p.value.value===true));
 const activate=async name=>{for(let i=0;i<100;i++){await key('Tab',9);await new Promise(r=>setTimeout(r,70));if(await focused(name)){await new Promise(r=>setTimeout(r,100));await key('Enter',13);return;}}throw Error('No standard keyboard focus '+name);};
 const noAck=async()=>assert(!(await text()).includes('Preview acknowledged only;'));
 const observations=[];
 const reader=()=>ev('(()=>{const s=document.documentElement.getAttribute("data-signed-import-late-reader");return s?JSON.parse(s):null;})()');
 const observe=async phase=>observations.push({phase,reader:await reader(),browserMonotonic:await ev('performance.now()')});
 const invalidated=async()=>{await wait(async()=> (await text()).includes('State: invalidated'));assert(!(await text()).includes('trustState: verified'));assert.equal((await button('Choose skill source')).disabled,'true');assert.equal((await button('Acknowledge preview only')).disabled,'true');await noAck();};
 await call('Page.navigate',{url});await wait(()=>ev('!!document.querySelector("flt-semantics-placeholder") || !!document.querySelector("[role=button]")'));await enable();
 await wait(async()=> (await text()).includes('Ready for preview only'));
 const phase=mode.startsWith('L03-')?'close':mode.split('-')[1],action=mode.startsWith('L03-')?'context':mode.split('-')[2];
 await activate('Arm fixture reader '+phase);await wait(async()=> (await reader())?.boundary===phase);
 const initialSnapshot=await storedSnapshot(),initialWrites=await ev('compositionWrites.length'),beforeRequests=requests.length;
 await activate('Choose skill source');await wait(async()=> (await reader())?.held===true);
 assert.equal((await reader()).busy,true);assert.equal((await button('Choose skill source')).disabled,'true');await observe('held');
 if(phase==='close'){
   assert.equal((await reader()).outcome,'pending');assert.equal((await reader()).counts.eof,1);
   await activate('Cancel source capture');await wait(async()=> (await reader()).outcome==='null');
   assert.equal((await reader()).counts.closeCompleted??0,0);assert((await reader()).busy);await observe('early-null-close-pending');
 }
 if(action==='cancel')await activate('Cancel source capture');
 else if(action==='dispose'){await activate('Unmount fixture import panel');await wait(async()=>!(await button('Choose skill source')));}
 else {await activate('Apply fixture transition session');await invalidated();}
 await wait(async()=> (await reader()).outcome==='null');assert((await reader()).busy);await observe('invalidated-before-release');
 // Arm/release controls are normal UI; rearming cannot replace the busy source.
 await activate('Arm fixture reader '+(phase==='read'?'open':'read'));
 assert.equal((await reader()).boundary,phase);assert.equal((await reader()).counts.armRefusals,1);
 const choose=await button('Choose skill source');
 if(choose){assert.equal(choose.disabled,'true');await call('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',clickCount:1,x:choose.x,y:choose.y});await call('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',clickCount:1,x:choose.x,y:choose.y});}
 assert.equal((await reader()).counts.selections,1);assert.equal((await reader()).counts.closeCompleted??0,0);
 await activate('Release fixture reader');await wait(async()=> (await reader()).counts.quiescent===1);await observe('quiescent');
 await activate('Release fixture reader');await activate('Rebuild fixture App');
 const final=await reader(),c=final.counts;
 for(const key of ['selections','selected','openStarted','openCompleted','lengthStarted','lengthCompleted','closeStarted','closeCompleted','outcomeNull','quiescent','manualReleases'])assert.equal(c[key],1,key);
 assert.equal(c.outcomeBytes??0,0);assert.equal(c.outcomeErrors??0,0);assert.equal(c.disposeHooks??0,action==='dispose'?1:0);
 assert.equal(c.readStarted??0,phase==='read'||phase==='close'?1:0);assert.equal(c.readCompleted??0,phase==='read'||phase==='close'?1:0);assert.equal(c.eof??0,phase==='close'?1:0);
 assert.equal(final.busy,false);assert.equal(final.watchdogFired,false);assert.equal(final.observerFaults,0);assert(final.elapsedSeconds<15);
 if(action==='dispose')assert(!(await button('Choose skill source')));else if(action==='context')await invalidated();else {await wait(async()=> (await text()).includes('Selection cancelled'));assert.notEqual((await button('Choose skill source')).disabled,'true');}
 assert(!(await text()).includes('trustState: verified'));await noAck();assert.equal(choosers.length,0);
 assert.equal(await ev('compositionWrites.length'),initialWrites);assert.equal(await storedSnapshot(),initialSnapshot);assert.equal(requests.length,beforeRequests);
 assert(traces.some(t=>t.event==='key'&&t.key==='Enter'&&t.isTrusted));
 if(phase==='close')assert(final.events.indexOf('outcomeNull')<final.events.indexOf('closeCompleted'));
 const details={controlledNotFile:true,phase,action,naturalNullOutcome:true,oneResourceClosed:true,noReplacementCapacity:true,reader:final};
 await collectNative();assert.deepEqual(exceptions,[]);assert.deepEqual(await ev('compositionViolations'),[]);assert(!traces.some(t=>t.event==='violation'));assert(requests.every(u=>u.startsWith(new URL(url).origin+'/')));
 const result={passed:true,caseId:mode,details,chooserCount:choosers.length,actualApp:'WebStudioApp.testImport + actual owner/panel/store + real web factory',inputMethod:'trusted CDP Tab/Enter on standard App fixture controls',observations,noAcknowledgmentAccepted:true,storageSnapshotUnchanged:true,noComponentWrites:true,traces,navigations,nativeTraceDataLoss:nativeComplete.dataLossOccurred,requests,exceptions,violations:[],scope:'L02–L03 controlled-port box App profile only; no real File/OS/device/AT/model/provider/full A6'};
 fs.writeFileSync(out,JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify({mode,passed:true,details}));ws.close();
})().catch(e=>{console.error(e);process.exit(1);});
