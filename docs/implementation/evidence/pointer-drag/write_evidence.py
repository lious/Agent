import collections,datetime,hashlib,json
from pathlib import Path
root=Path('/workspace/agent-foundation-20261125');art=root/'artifacts/pointer-drag';dst=root/'docs/implementation/evidence/pointer-drag'
sha=lambda b:hashlib.sha256(b).hexdigest()
def copy(path,name=None):
 raw=path.read_bytes();name=name or path.name
 data=raw if name.endswith(('.json','.jsonl','.py')) else ('\n'.join(l.rstrip() for l in raw.decode().splitlines())+'\n').encode()
 (dst/name).write_bytes(data)
 return {'log':name,'sha256':sha(data),**({'rawSha256':sha(raw)} if raw!=data else {})}
def parsed(path):
 tests={};done=None
 for line in path.read_text().splitlines():
  try:r=json.loads(line)
  except ValueError:continue
  if r.get('type')=='testStart':tests[r['test']['id']]={'name':r['test']['name']}
  if r.get('type')=='testDone' and not r.get('hidden'):tests.setdefault(r['testID'],{}).update(result='skipped' if r.get('skipped') else r['result'])
  if r.get('type')=='done':done=r
 cases=[t for t in tests.values() if 'result' in t];c=collections.Counter(t['result'] for t in cases)
 return {'passed':c['success'],'failed':c['failure']+c['error'],'skipped':c['skipped'],'runnerDone':done,'cases':cases}
freeze=json.loads((art/'source-freeze.json').read_text())
for f,h in freeze['sourceSha256'].items(): assert sha((root/f).read_bytes())==h,f
freeze['nativeLibrarySha256']={str(p):sha(p.read_bytes()) for p in [Path('/workspace/agent-media-native-peer/libstudio_media.so'),Path('/workspace/agent-media-native-asan-opacity/libstudio_media.so')]}
(art/'source-freeze.json').write_text(json.dumps(freeze,indent=2)+'\n')
runs=json.loads((art/'commands.json').read_text()); assert all('exitCode' in r for r in runs['runs'])
results={}; finals={}
for r in runs['runs']:
 name=r['name']; ext='.jsonl' if name in ['native','ui','chrome','pulse'] else '.log'
 proof=copy(root/r['log'],'final-'+name+ext); proof.update(exitCode=r['exitCode'],elapsedSeconds=r['elapsedSeconds']); finals[name]=proof
 if name in ['native','ui','chrome','pulse']:results[name]={**parsed(root/r['log']),**proof}
for p in ['commands.json','run_selected.py','write_evidence.py','source-freeze.json']: copy(art/p)
aux=[]
for p in sorted(art.iterdir()):
 if p.name.startswith('early-') or p.name in ['final-actual-legacy.json','final-undo-redo-kill.json','toolchain-current.json','runner.log']:aux.append(copy(p))
original=json.loads((root/'docs/implementation/task-status.json').read_text());xd=json.loads((root/'docs/implementation/multidevice-status.json').read_text())
def counts(d):
 c=collections.Counter(t['status'] for t in d['tasks']);return {k:c[k] for k in ['complete','partial','planned','blocked']}
cancels=[r for r in runs['runs'] if '100cancel' in r['name']]
d={**freeze,'asOf':datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(),'timezone':'Asia/Shanghai',
 'freezeIdentity':'Containing local commit source/test/package bytes match this source SHA256 map and aggregate. Runs freshly executed on these bytes; only documentation/evidence afterward. Parent/base49aa782 is NOT the tested modified tree. Not all repository/all87/full I-005 acceptance and no borrowed276.',
 'results':results,'totalPassed':sum(r['passed'] for r in results.values()),'totalFailed':sum(r['failed'] for r in results.values()),'totalSkipped':sum(r['skipped'] for r in results.values()),'additionalRuns':finals,'earlyEvidence':aux,
 'scope':{'contract':'Original immutable I-005 and s3: drag only ghost; same-track reject, complete link closure, exact8 logical px snap before quantization and original one-command transaction. Marker editor/admission NOT enabled.',
 'actualUI':'Real timeline hit-testing/click+Shift selected clips, horizontal pointer down/move/up/cancel, scaled zoom slider and actual wheel scroll coordinate transforms, snap target line/text and latest native ghost. Identity/Escape/secondary pointer/track or viewport exit/focus/lifecycle/ancestor scroll preempt. Release re-evaluates physical UP and waits for latest native frame. SQL abort/writer fence/concurrent external revision never commit earlier ghost; no automatic retry. Undo-redo/reload/archive fork/AAC MP4 via workbench.',
 'resources':'One native waiter/latest dirty flag, generation/hash/gesture fences, explicit canceled timeout timers and late decoded image disposal; user-visible preview failures cancel release. Other edits and playback gated during capture. Bounded three-screen canvas<=20000px, no auto-scroll/cross-track/mobile long-press/pinch/full-performance claim.',
 'muxDefect':'Measured119/30s AAC duration190368 vs190400 requested samples under default1000Hz MP4 movie clock. Existing verification rejected correctly. Checked FFmpeg movie_timescale=LCM(fps numerator,48000) preserves boundaries; independent91/119-frame exports assert145600/190400 audio samples and identical native ghost/preencoder pixels. No sample padding, verification relaxation or underrun-fix claim.'},
 'reviews':'../../REVIEW.md1.24 and ADR0031: real coordinate/arbitration review; measured AAC/SQL/fence/version semantics review; cancellation timer/late-image/lifecycle review. Early failures retained, excluded from final counts.',
 'cancelQualification':{'iterationsFinalOnlyVerified':sum(100 for r in cancels if r['exitCode']==0),'scope':'Four active-video modes regular+ASan100 each, actual source rebuilt. Not GPU/Pulse internals TSan/physical audio.'},
 'statusCounts':{'original87':counts(original),'XD10':counts(xd)},
 'priorUnresolved':['raster_clock first-play underrun presented2877 and previous opacity_clock/resume failures retained; final single selected service run is not statistical root-cause elimination','O(n) history, field-aware inverse, balanced interval index and original all-operation1000 randomized qualification unfinished','schema9 cannot fence an independently unupgraded old writer','Managed RTC positive path blocked by existing network policy, no retry/bypass/relay','Physical AV/GPU/mobile/other-desktop/multi-device execution not certified'],
 'notRun':['Full repository/original87 task acceptance/hard-dependency closure','Clipboard/group/insert-overwrite/cross-track/marker execution/full mobile gesture matrix','Fresh release App/window/manual human interaction/physical DAC/stableFPS/GPU/all-platform qualification','New60s/VFR/HDR/full original P0 and all history fixture versions; selected current migration/actual legacy and SIGKILL only','Unselected Harness/peer/security suites unchanged, not newly certified','Remote reads/diagnosis/push/rules/identity/branch/protocol/permission changes'],
 'publication':'LOCAL ordinary commit only; six unpublished ancestors e23a559/c8c12d8/c948c56/a52002f/6b30f77/49aa782 preserved. No remote contact/push/diagnosis. commit_refs_rules cause unresolved; no bypass or invented GitHub availability.',
 'toolchain':'Flutter3.50.1/Dart3.14, strict SQLite3.54.1, FFmpeg7.1.5/Pulse17/native CPU. Rebuilt normal+ASan native libraries recorded. Only direct test dependency on existing workspace studio_store added; no model/paid API/OAuth change.'}
(dst/'summary.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'passed':d['totalPassed'],'failed':d['totalFailed'],'skipped':d['totalSkipped'],'groups':{k:v['exitCode'] for k,v in finals.items()},'cancelIterations':d['cancelQualification']['iterationsFinalOnlyVerified']},indent=2))
