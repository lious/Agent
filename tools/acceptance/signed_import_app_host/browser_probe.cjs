// Loopback TEST ONLY: instrument a fresh real browser before navigating App.
const fs=require('fs');
(async()=>{
 const [portFile,url,out]=process.argv.slice(2);
 let port;
 for(let i=0;i<100;i++){
  try{port=Number(fs.readFileSync(portFile,'utf8').split('\n')[0]);break;}catch(_){}
  await new Promise(r=>setTimeout(r,50));
 }
 if(!port)throw Error('Chrome DevTools startup timeout');
 const targets=await(await fetch(`http://127.0.0.1:${port}/json/list`)).json();
 const ws=new WebSocket(targets.find(t=>t.type==='page').webSocketDebuggerUrl);
 await new Promise((r,j)=>{ws.onopen=r;ws.onerror=j;});
 let seq=0;const pending=new Map(),requests=[],failures=[],exceptions=[];
 ws.onmessage=event=>{
  const m=JSON.parse(event.data);
  if(m.id){const p=pending.get(m.id);pending.delete(m.id);if(m.error)p.reject(Error(JSON.stringify(m.error)));else p.resolve(m.result);}
  if(m.method==='Network.requestWillBeSent')requests.push({url:m.params.request.url,type:m.params.type});
  if(m.method==='Network.loadingFailed')failures.push(m.params);
  if(m.method==='Runtime.exceptionThrown')exceptions.push(m.params.exceptionDetails);
 };
 const call=(method,params={})=>new Promise((resolve,reject)=>{const id=++seq;pending.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params}));});
 await call('Network.enable');await call('Runtime.enable');await call('Page.enable');
 await call('Page.navigate',{url});
 let result;
 for(let i=0;i<300;i++){
  await new Promise(r=>setTimeout(r,100));
  const v=await call('Runtime.evaluate',{expression:'window.appHostProbeResult || null',returnByValue:true});
  if(v.result.value){result=v.result.value;break;}
 }
 if(!result)result={ok:false,error:'App did not publish probe within 30 seconds'};
 const shot=await call('Page.captureScreenshot',{format:'png'});
 fs.writeFileSync(out.replace(/\.json$/,'.png'),Buffer.from(shot.data,'base64'));
 Object.assign(result,{requests,failures,exceptions});
 fs.writeFileSync(out,JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify({mode:result.mode,firstFrame:result.firstFrame,backendState:result.backendState,violations:result.violations,errors:result.errors}));ws.close();
})().catch(e=>{console.error(e);process.exitCode=1;});
