#!/usr/bin/env python3
"""Actual private PulseAudio software sink; NOT physical DAC/human hearing."""
import array,ctypes,json,math,os,signal,subprocess,tempfile,time,sys,select
from pathlib import Path
LIB=os.environ.get('STUDIO_MEDIA_LIBRARY','/workspace/agent-media-native-peer/libstudio_media.so')

def native(lib=LIB):
 l=ctypes.CDLL(lib);l.sm_create.argtypes=[ctypes.c_char_p];l.sm_create.restype=ctypes.c_uint64
 l.sm_playback.argtypes=[ctypes.c_uint64,ctypes.c_char_p,ctypes.c_char_p];l.sm_playback.restype=ctypes.c_void_p
 l.sm_string_free.argtypes=[ctypes.c_void_p];l.sm_close.argtypes=[ctypes.c_uint64,ctypes.c_char_p];return l

def call(l,h,r,ns=b'test'):
 p=l.sm_playback(h,ns,json.dumps(r).encode())
 try:x=json.loads(ctypes.string_at(p))
 finally:l.sm_string_free(p)
 if not x['ok']:raise RuntimeError(x['code'])
 return x['value']

def wait(fn,predicate,timeout=6):
 end=time.monotonic()+timeout;last=None
 while time.monotonic()<end:
  last=fn()
  if predicate(last):return last
  time.sleep(.02)
 raise AssertionError(last)

def main():
 with tempfile.TemporaryDirectory(prefix='pulse-real-') as root:
  d=Path(root);env={**os.environ,'XDG_RUNTIME_DIR':str(d/'runtime'),'XDG_CONFIG_HOME':str(d/'config'),'HOME':str(d),'PULSE_RUNTIME_PATH':str(d/'runtime'),'PULSE_STATE_PATH':str(d/'state'),'PULSE_SERVER':'unix:'+str(d/'native')};(d/'runtime').mkdir();(d/'state').mkdir();os.environ.update({k:env[k] for k in ['PULSE_RUNTIME_PATH','PULSE_STATE_PATH','PULSE_SERVER','HOME','XDG_RUNTIME_DIR','XDG_CONFIG_HOME']})
  server=subprocess.Popen(['pulseaudio','-n','--daemonize=no','--exit-idle-time=-1','--disable-shm=yes','--log-target=file:'+str(d/'pulse.log'),'--load=module-null-sink sink_name=studio_test rate=48000 channels=2','--load=module-native-protocol-unix socket='+str(d/'native')+' auth-anonymous=1'],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
  worker=capture=None
  try:
   wait(lambda:(d/'native').exists(),bool)
   data=array.array('f',(math.sin(2*math.pi*1000*i/48000)*.1 for i in range(48000*8) for _ in range(2)));pcm=d/'tone.f32';pcm.write_bytes(data.tobytes())
   capture=subprocess.Popen(['parec','--device=studio_test.monitor','--format=float32le','--rate=48000','--channels=2','--raw'],env=env,stdout=(d/'capture.f32').open('wb'),stderr=subprocess.DEVNULL)
   l=native();h=l.sm_create(b'test');status=lambda:call(l,h,{'op':'status'})
   call(l,h,{'op':'open','path':str(pcm),'sampleCount':48000*8,'sink':'studio_test'})
   first=wait(status,lambda s:s['state']=='playing' and s.get('clockValid') and s['presentedSample']>4800)
   for recipe,code in (({'op':'open','path':str(pcm),'sampleCount':48000*8},'PLAYBACK_BUSY'),({'op':'rebind','sink':'not a sink'},'AUDIO_SINK_NAME')):
    try:call(l,h,recipe);raise AssertionError('bad operation accepted')
    except RuntimeError as error:assert str(error)==code
   assert status()['epoch']==first['epoch']
   call(l,h,{'op':'pause'});wait(status,lambda s:s['state']=='paused' and s['clockValid']);time.sleep(.15);a=status();time.sleep(.2);b=status();assert b['presentedSample']==a['presentedSample'],(a,b)
   # Plain resume (without a preceding seek) must not reuse a stale cork queue.
   call(l,h,{'op':'resume'});plain=wait(status,lambda s:s['state']=='playing' and s.get('clockValid') and s['presentedSample']>b['presentedSample']+4800)
   assert plain['epoch']>b['epoch'] and plain['resumeRebuilt'] and plain['resumeDiscardedUnconfirmedFrames']>=0,plain
   call(l,h,{'op':'resume'});assert status()['epoch']==plain['epoch'],'duplicate resume rebuilt an active stream'
   call(l,h,{'op':'pause'});wait(status,lambda s:s['state']=='paused' and s.get('clockValid'))
   try:call(l,h,{'op':'seek','sample':-1});raise AssertionError('invalid accepted')
   except RuntimeError as e:assert str(e)=='PLAYBACK_RANGE'
   call(l,h,{'op':'seek','sample':24000});seek=wait(status,lambda s:s['state']=='paused' and s['clockValid']);assert seek['presentedSample']==24000 and seek['epoch']>b['epoch'],seek
   call(l,h,{'op':'resume'});resumed=wait(status,lambda s:s['presentedSample']>30000 and s['clockValid'])
   subprocess.run(['pactl','load-module','module-null-sink','sink_name=second','rate=48000','channels=2'],env=env,check=True,stdout=subprocess.DEVNULL)
   call(l,h,{'op':'rebind','sink':'second'});rebound=wait(status,lambda s:s.get('sink')=='second' and s.get('clockValid'));assert rebound['epoch']>resumed['epoch']
   try:call(l,h,{'op':'status'},b'foreign');raise AssertionError('namespace accepted')
   except RuntimeError as e:assert str(e)=='NAMESPACE_MISMATCH'
   assert rebound['ringHighWaterFrames']<=8192 and rebound['serverMaxBytes']<=32768,rebound
   call(l,h,{'op':'stop'});assert status()['state']=='stopped';assert l.sm_close(h,b'test')==0
   worker=subprocess.Popen([sys.executable,str(Path(__file__).with_name('worker.py')),LIB],env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
   def rpc(r):
    worker.stdin.write(json.dumps(r)+'\n');worker.stdin.flush();ready,_,_=select.select([worker.stdout],[],[],6);assert ready,'worker timeout';x=json.loads(worker.stdout.readline());assert x['ok'],x;return x['value']
   rpc({'op':'open','path':str(pcm),'sampleCount':48000*8,'sink':'studio_test'})
   wait(lambda:rpc({'op':'status'}),lambda s:s.get('clockValid') and s['presentedSample']>4800)
   # Actual producer process is halted, while independent Pulse daemon keeps
   # consuming its finite queue. No synthetic/mock underflow injection.
   os.kill(worker.pid,signal.SIGSTOP);time.sleep(.3);os.kill(worker.pid,signal.SIGCONT)
   starved=wait(lambda:rpc({'op':'status'}),lambda s:s['state']=='interrupted');assert starved['underruns']>0 and starved['reason']=='underrun',starved
   frozen=starved['presentedSample'];time.sleep(.1);assert rpc({'op':'status'})['presentedSample']==frozen
   rpc({'op':'rebind','sink':'studio_test'});wait(lambda:rpc({'op':'status'}),lambda s:s['state']=='paused' and s.get('clockValid'))
   rpc({'op':'resume'});wait(lambda:rpc({'op':'status'}),lambda s:s['state']=='playing' and s.get('clockValid'))
   subprocess.run(['pactl','suspend-sink','studio_test','1'],env=env,check=True)
   lost=wait(lambda:rpc({'op':'status'}),lambda s:s['state']=='interrupted');assert lost['reason']=='device-lost',lost
   subprocess.run(['pactl','suspend-sink','studio_test','0'],env=env,check=True)
   rpc({'op':'rebind','sink':'studio_test'});wait(lambda:rpc({'op':'status'}),lambda s:s['state']=='paused' and s.get('clockValid'))
   rpc({'op':'resume'});wait(lambda:rpc({'op':'status'}),lambda s:s.get('clockValid') and s['state']=='playing')
   os.kill(server.pid,signal.SIGSTOP)
   try:
    stale=wait(lambda:rpc({'op':'status'}),lambda s:s['state']=='interrupted');assert stale['reason']=='clock-stale',stale
    time.sleep(.1);assert rpc({'op':'status'})['presentedSample']==stale['presentedSample']
   finally:os.kill(server.pid,signal.SIGCONT)
   rpc({'op':'rebind','sink':'studio_test'});wait(lambda:rpc({'op':'status'}),lambda s:s['state']=='paused' and s.get('clockValid'))
   rpc({'op':'stop'});worker.stdin.close();worker.wait(timeout=6);assert worker.returncode==0
   # Exact EOF requires actual server drain acknowledgement, not submission.
   h=l.sm_create(b'test');call(l,h,{'op':'open','path':str(pcm),'sampleCount':48000*8,'startSample':48000*8-12000,'sink':'studio_test'})
   eof=wait(lambda:call(l,h,{'op':'status'}),lambda s:s['state']=='finished');assert eof['presentedSample']==48000*8 and eof['clockValid'],eof
   call(l,h,{'op':'stop'});l.sm_close(h,b'test')
   fd_before=len(list(Path('/proc/self/fd').iterdir()))
   for _ in range(20):
    rejected=l.sm_create(b'test')
    try:call(l,rejected,{'op':'open','path':str(pcm),'sampleCount':48000*8,'paused':'invalid'});raise AssertionError('bad pause type accepted')
    except RuntimeError:pass
    finally:l.sm_close(rejected,b'test')
    h=l.sm_create(b'test');call(l,h,{'op':'open','path':str(pcm),'sampleCount':48000*8,'sink':'studio_test'});call(l,h,{'op':'stop'});l.sm_close(h,b'test')
   fd_after=len(list(Path('/proc/self/fd').iterdir()));assert fd_after<=fd_before+1,(fd_before,fd_after)
   h=l.sm_create(b'test');bad=d/'bad.f32';bad.write_bytes(b'\x00'*7);fifo=d/'fifo';os.mkfifo(fifo);link=d/'symlink';link.symlink_to(pcm)
   for path in (str(bad),str(d/'missing'),str(fifo),str(link)):
    try:call(l,h,{'op':'open','path':path,'sampleCount':1});raise AssertionError('bad PCM accepted')
    except RuntimeError as e:assert str(e)=='PLAYBACK_PCM_FILE'
   bad.write_bytes(array.array('f',[math.nan,0]).tobytes());call(l,h,{'op':'open','path':str(bad),'sampleCount':1,'sink':'studio_test'})
   invalid=wait(lambda:call(l,h,{'op':'status'}),lambda s:s['state']=='interrupted');assert invalid['reason']=='NONFINITE_PCM',invalid
   call(l,h,{'op':'stop'});l.sm_close(h,b'test')
   for remote in ('tcp:127.0.0.1:1','unix:/tmp/unused;tcp:127.0.0.1:1','unix:/tmp/unused tcp:127.0.0.1:1'):
    os.environ['PULSE_SERVER']=remote;h=l.sm_create(b'test')
    try:
     call(l,h,{'op':'open','path':str(pcm),'sampleCount':48000*8})
     refused=wait(lambda:call(l,h,{'op':'status'}),lambda s:s['state']=='interrupted');assert refused['reason']=='LOCAL_AUDIO_SERVICE_REQUIRED',refused
    finally:l.sm_close(h,b'test');os.environ['PULSE_SERVER']=env['PULSE_SERVER']

   capture.terminate();capture.wait(timeout=5);raw=array.array('f');raw.frombytes((d/'capture.f32').read_bytes());rms=math.sqrt(sum(v*v for v in raw)/max(1,len(raw)));assert rms>.005,rms
   print(json.dumps({'status':'passed','first':first,'paused':b,'plainResume':plain,'seek':seek,'rebound':rebound,'monitorRMS':rms,'captureSamples':len(raw)//2,'physicalDAC':False,'humanHearingClaim':False,'actualProducerStarvation':starved,'actualSuspendedDevice':lost,'actualServerStall':stale,'eof':eof,'repeatOpenStop':20,'fdBefore':fd_before,'fdAfter':fd_after,'nonFiniteRefused':invalid,'remoteServerListsRefused':3}))
  except BaseException:
   print('SERVER_LOG', (d/'pulse.log').read_text() if (d/'pulse.log').exists() else 'absent');print('SERVER_EXIT',server.poll());raise
  finally:
   for child in (worker,capture,server):
    if child is not None and child.poll() is None:
     os.kill(child.pid,signal.SIGCONT);child.terminate();child.wait(timeout=5)
if __name__=='__main__':main()
