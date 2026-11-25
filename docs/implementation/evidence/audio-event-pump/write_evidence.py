import collections,datetime,hashlib,json
from pathlib import Path
root=Path('/workspace/agent-foundation-20261125');art=root/'artifacts/audio-startup';dst=root/'docs/implementation/evidence/audio-event-pump';dst.mkdir(parents=True,exist_ok=True)
sha=lambda b:hashlib.sha256(b).hexdigest()
def copy(src,name=None):
 raw=src.read_bytes();name=name or src.name
 data=raw if name.endswith(('.json','.jsonl','.py')) else ('\n'.join(l.rstrip() for l in raw.decode().splitlines())+'\n').encode()
 (dst/name).write_bytes(data);r={'log':name,'sha256':sha(data)}
 if raw!=data:r['rawSha256']=sha(raw)
 return r
def parsed(path):
 tests={};done=None
 for line in path.read_text().splitlines():
  try:r=json.loads(line)
  except ValueError:continue
  if r.get('type')=='testStart':tests[r['test']['id']]={'name':r['test']['name']}
  if r.get('type')=='testDone' and not r.get('hidden'):tests.setdefault(r['testID'],{}).update(result='skipped' if r.get('skipped') else r['result'])
  if r.get('type')=='done':done=r
 cases=[v for v in tests.values() if 'result' in v];c=collections.Counter(v['result'] for v in cases)
 return {'passed':c['success'],'failed':c['failure']+c['error'],'skipped':c['skipped'],'runnerDone':done,'cases':cases}
freeze=json.loads((art/'source-freeze.json').read_text())
for f,h in freeze['sourceSha256'].items():assert sha((root/f).read_bytes())==h,f
for f,h in freeze['nativeLibrarySha256'].items():assert sha(Path(f).read_bytes())==h,f
runs=json.loads((art/'commands.json').read_text());assert all('exitCode' in r for r in runs['runs'])
results={};finals={}
for r in runs['runs']:
 name=r['name'];ext='.jsonl' if name in ['native','ui','chrome','pulse'] else '.log'
 proof=copy(root/r['log'],'final-'+name+ext);proof.update(exitCode=r['exitCode'],elapsedSeconds=r['elapsedSeconds']);finals[name]=proof
 if name in ['native','ui','chrome','pulse']:results[name]={**parsed(root/r['log']),**proof}
commands=copy(art/'commands.json');copy(art/'run_selected.py');copy(art/'write_evidence.py')
aux=[copy(art/f) for f in ['final-actual-legacy.json','diagnostic-build.log','event-build.log','asan-build.log','diagnostic-clock.jsonl','diagnostic-smoke.log','event-clock.jsonl','remote-branch-rules.json','remote-rulesets.json','remote-branch.json','remote-diagnosis.json']]
copy(root/'artifacts/local-video/raster-push-attempt.log','prior-push-rejection.log');copy(root/'docs/implementation/evidence/raster-effects/toolchain-reused.json','toolchain-reused.json')
probe=None
for l in (root/'artifacts/audio-startup/final-real-monitor-and-faults.log').read_text().splitlines():
 try:r=json.loads(l)
 except ValueError:continue
 if r.get('status')=='passed':probe=r
cancels=[r for r in runs['runs'] if '100cancel' in r['name']]
d={**freeze,'asOf':datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(),'timezone':'Asia/Shanghai','freezeIdentity':'Containing local commit source/test bytes exactly match14 sourceSha256 entries, including retained crop/color12. Final selected commands rerun after last source edit. Docs/evidence only afterward. Not full repository/all87 acceptance. No push attempted this batch.','commands':commands,'results':results,'totalPassed':sum(r['passed'] for r in results.values()),'totalFailed':sum(r['failed'] for r in results.values()),'totalSkipped':sum(r['skipped'] for r in results.values()),'additionalRuns':finals,'auxiliaryEvidence':aux,'realMonitorAndFaultResult':probe,'actualSchedulingFix':'Official readiness-based pa_mainloop_prepare(2000us)/poll/dispatch replaces nonblocking iterate plus unconditional2ms sleep. Requested maximum wait/control cadence unchanged; no project-clock use of wall time. No unconditional delay over already-ready IO/deferred events.','intermittentRootCauseProven':False,'intermittentUnderrunClosed':False,'unchangedPolicy':{'ringFrames':8192,'requestedMaxServerBytes':32768,'requestedTargetBytes':16384,'requestedPrebufBytes':8192,'requestedMinreqBytes':8192,'writeBatchMaxFrames':4096,'clockStaleMilliseconds':500,'ignoreUnderflow':False,'interpolateProjectClock':False,'automaticRetry':False},'newDiagnostics':['serverMinRequestBytes','underflowIndexBytes (diagnostic bytes, NOT clock)','writableBytesAtUnderflow (-1 unknown)','pumpPolicy','eventSourcesDispatched (includes timers/deferred, not only IO)'],'causalLimits':'Diagnostic-only unchanged-scheduling two-case run and old full real probe both passed once before this scheduling change. Therefore final passes do not prove this was sole root of prior intermittent startup/resume failures. No retry-to-green, queue/deadline/assertion relaxation. New trace fields prepare future failures for real diagnosis; issue remains unresolved.','priorFailuresRetained':[{'commit':'e23a559c7178c5ee9a127780d199d098e60927c5','summary':'../raster-effects/summary.json','passed':232,'failed':1,'failure':'raster_clock first play presented2877/submitted5168, before explicit timeline render'},{'commit':'00c2e5d4b6e93d71ff3b19d8ddf5d30f95fdd77d','summary':'../dissolve/summary.json','passed':224,'failed':1,'failure':'opacity_clock real Pulse timeout/underrun'}],'preFreezeRuns':{'diagnosticOnlyTwoCases':parsed(art/'diagnostic-clock.jsonl'),'schedulingTargetedTwoCases':parsed(art/'event-clock.jsonl'),'notBorrowedFinalPasses':True,'diagnosticIntermediateBinaryNotRetained':True},'cancelQualification':{'runs':[{'name':r['name'],'exitCode':r['exitCode'],'iterationsVerified':100 if r['exitCode']==0 else None} for r in cancels],'iterationsFinalOnlyVerified':sum(100 for r in cancels if r['exitCode']==0),'scope':'Four actual video modes regular and ASan/UBSan leak-checking100 each, application-owned AVFrame/FD. Not Pulse worker ASan/TSan nor full codec/GPU internals.'},'remoteDiagnosis':json.loads((art/'remote-diagnosis.json').read_text()),'threeReviews':'../../REVIEW.md increment1.19 / ADR0026: causal evidence vs unknown; official thread/error/clock/queue semantics and signed diagnostic sentinel; controlled real starvation/suspend/server-stall/rebind/EOF and frozen regression.','notRun':['Full repository/all87 release acceptance and full original hard-dependency closure','Long-run or statistically qualified elimination of intermittent startup/resume underrun; root remains open','TSan or ASan-instrumented real Pulse worker/monitor (video cancellation ASan did run)','Fresh release App/window build, physical DAC/human hearing/AV sync/stable fps or performance','Independent new60s/VFR/HDR/P0/GPU matrix; existing selected media/export tests did run','Full independent old-executable v4-v8 matrix; selected migrations/actual old-library SQL-barrier SIGKILL/reopen did run','Unselected Harness/security/peer suites; mechanisms unchanged','Non-Linux/mobile/physical multiple devices/positive RTC; existing managed-policy blocker unchanged, no retry or bypass'],'statusCounts':{'original87':{'complete':0,'partial':26,'planned':48,'blocked':13},'XD10':{'complete':0,'partial':8,'planned':1,'blocked':1}},'toolchain':'Existing official Flutter3.50.1/Dart3.14, approved SQLite3.54.1 strict gate, Debian FFmpeg7.1.5/Pulse17, clang19/CMake3.31.6/Chrome156. No installs/models/paid services. Regular+sanitized native rebuilt.','knownUnresolved':['Intermittent startup/resume underrun root not proven or closed.','Schema9 cannot fence old executable co-writers.','Only last-commit inverse, no multi-level undo/redo/coalescing.','Black-background opaque SDR CPU FP32/RGB8, not full GPU/FP16/alpha.']}
(dst/'summary.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'passed':d['totalPassed'],'failed':d['totalFailed'],'skipped':d['totalSkipped'],'groups':{k:v['exitCode'] for k,v in finals.items()},'cancelIterations':d['cancelQualification']['iterationsFinalOnlyVerified'],'monitorPassed':probe is not None},indent=2))
