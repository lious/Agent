import collections,datetime,hashlib,json
from pathlib import Path
root=Path('/workspace/agent-foundation-20261125');art=root/'artifacts/snap-move';dst=root/'docs/implementation/evidence/snap-move'
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
for f,h in freeze['sourceSha256'].items():assert sha((root/f).read_bytes())==h,f
for f,h in freeze['nativeLibrarySha256'].items():assert sha(Path(f).read_bytes())==h,f
runs=json.loads((art/'commands.json').read_text());assert all('exitCode' in r for r in runs['runs'])
dst.mkdir(parents=True,exist_ok=True);results={};finals={}
for r in runs['runs']:
 name=r['name'];ext='.jsonl' if name in ['native','ui','chrome','pulse'] else '.log'
 proof=copy(root/r['log'],'final-'+name+ext);proof.update(exitCode=r['exitCode'],elapsedSeconds=r['elapsedSeconds']);finals[name]=proof
 if name in ['native','ui','chrome','pulse']:results[name]={**parsed(root/r['log']),**proof}
commands=copy(art/'commands.json');copy(art/'run_selected.py');copy(art/'write_evidence.py');copy(art/'source-freeze.json')
aux=[]
for p in sorted(art.iterdir()):
 if p.name in ['final-actual-legacy.json','final-undo-redo-kill.json','preliminary-events.json','pub-get-offline.log'] or (p.suffix in ['.jsonl','.log'] and not p.name.startswith('final-')):aux.append(copy(p))
copy(root/'docs/implementation/evidence/audio-event-pump/toolchain-reused.json','toolchain-reused.json')
original=json.loads((root/'docs/implementation/task-status.json').read_text());xd=json.loads((root/'docs/implementation/multidevice-status.json').read_text())
def counts(d):
 c=collections.Counter(t['status'] for t in d['tasks']);return {k:c[k] for k in ['complete','partial','planned','blocked']}
cancels=[r for r in runs['runs'] if '100cancel' in r['name']]
d={**freeze,'asOf':datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(),'timezone':'Asia/Shanghai',
 'freezeIdentity':'Containing LOCAL commit matches all38 source/test/package hashes. Final selected runs freshly executed on these exact bytes; maintenance/evidence only afterward. Not all repository/all87 acceptance; no borrowed261/248/233/182.',
 'commands':commands,'results':results,'totalPassed':sum(r['passed'] for r in results.values()),'totalFailed':sum(r['failed'] for r in results.values()),'totalSkipped':sum(r['skipped'] for r in results.values()),'additionalRuns':finals,'auxiliaryPreFreezeEvidence':aux,
 'snapMoveScope':{
 'originalContract':'Original s3 row25 nearest8 logical pixels, playhead/cut/marker/ID ties, snap before quantization; linked atomic MoveClips/undo/fence requirements unchanged. Pure marker ranking only; marker-bearing projects still refuse editing, never stripped.',
 'algorithm':'Exact Q logical viewport pan/zoom/origin, no physical DPR/wall clock/double in time. All moved media start/end edges, exclude complete link closure from stationary media-cut targets. Derived Gap edges not self-targets. Sorted/compressed target-time binary nearest search, not all-pairs/frame iteration. Both excluded/nonexcluded input streams bounded.',
 'clock':'Earliest moved video START reference -> snap -> absolute project-frame ties-even quantization. Audio-only uses48k sample lattice. One delta for all; mixed29.97/48k fractional-sample result refuses rather than independently rounding. Target/residual after quantization explicitly shown; no hidden nearest-valid collision fallback.',
 'authority':'Immutable base hash including project/revision, SDK metadata guard, existing gesture target/base/writer fence. Stale/foreign plan UPDATE invalidates older candidate. Existing ordinary edit transaction/receipt/journal/definitions/pins/events/outbox; no new schema or registry.',
 'UI':'Real native checkbox linked selection, exact numeric zoom/pan/pointer-x/editing-playhead inputs,8px target/ruler/Q/raw/snapped/final/residual/participating-track readout, shared native ghost, cancel/one commit/undo-redo/archive fork/AAC MP4. Numeric preview+button confirmation, NOT full physical pointer-drag. Editing playhead is viewport-only, NOT AudioSink clock. Expansion survives virtualization; ruler exact-time-clipped before drawing-only double.',
 'failure':'Invalid decimal/scale plan errors also hide old ghost and forbid old commit; no raw-delta fallback. Existing lock/negative/collision/transition/grid failures reject entire group, no skip. Real SQL late abort/manual same candidate retry, duplicate commit refusal, revision/fence, transition handles and saved root restoration.',
 'audio':'Actual post-move MP4 AAC decoded with FFmpeg to48k stereo float PCM;0-0.8s quiet and1.1-1.2s signal windows checked (codec-safe), NOT sample-exact AAC edge/physical DAC/latency qualification.',
 'limits':'Same original native admitted profile only; marker editing/full pointer snapping/clipboard/group/insert-overwrite/cross-track/field-aware inverse/balanced index/O(n) history performance and all-NLE random1000 remain incomplete.'},
 'threeReviews':'../../REVIEW.md increment1.23 / ADR0030: original contract/bounded exact targets; frozen plan invalidation and real AV/SQL/time grids; actual UI virtualization/invalid input and bounded ruler plus selected regressions. Preliminary failures retained, not final counts.',
 'priorUnresolved':[{'commit':'e23a559c7178c5ee9a127780d199d098e60927c5','summary':'../raster-effects/summary.json','failure':'raster_clock first-play underrun presented2877 still not proven solved'},{'commit':'00c2e5d4b6e93d71ff3b19d8ddf5d30f95fdd77d','summary':'../dissolve/summary.json','failure':'opacity_clock Pulse timeout/underrun still not proven solved'}],
 'cancelQualification':{'iterationsFinalOnlyVerified':sum(100 for r in cancels if r['exitCode']==0),'scope':'Four active-video modes regular/ASan100 each, app-owned AVFrame/FD. Not real Pulse ASan/TSan/full codec/GPU internals.'},
 'notRun':['Full repository/original87 hard-dependency closure/full I-005 each-operation random1000 NLE matrix','Physical pointer snapping/marker editor/clipboard/groups/insert-overwrite/cross-track/field-aware inverse','Large/million-entry history realtime performance, balanced index (O(n) history unchanged)','Fresh release App/window build, GPU/stable fps/human hearing/actual DAC/physical AV sync/non-Linux/mobile/physical multi-device','Statistical elimination of startup/resume underrun; old failures retained','New independent60s/VFR/HDR/full P0/whole v4-v8 old-executable qualification; selected current migrations/actual legacy/SQL/SIGKILL only','Unselected Harness/security/peer suites unchanged','Positive RTC managed-network policy block unchanged, no retry/bypass/relay','Remote reads/diagnosis/push/rule/branch/identity/protocol/permission changes'],
 'statusCounts':{'original87':counts(original),'XD10':counts(xd)},
 'publication':'Ordinary LOCAL commit only; five unpublished ancestors e23a559/c8c12d8/c948c56/a52002f/6b30f77 preserved, result ahead6 relative last-known local tracking. No new GitHub URL, no push/remote diagnosis. commit_refs_rules cause unknown; no compliant recovery evidence.',
 'toolchain':'Reused Flutter3.50.1/Dart3.14.0; strict approved SQLite3.54.1 unchanged (DEV3.46.1 not accepted); FFmpeg7.1.5/Pulse17/clang19/CMake3.31.6/Chrome156. Native hashes unchanged; no new package/model/install/paid calls.'}
if (dst/'toolchain-current.json').exists():d['toolchainCurrent']={'log':'toolchain-current.json','sha256':sha((dst/'toolchain-current.json').read_bytes())}
(dst/'summary.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'passed':d['totalPassed'],'failed':d['totalFailed'],'skipped':d['totalSkipped'],'groups':{k:v['exitCode'] for k,v in finals.items()},'cancelIterations':d['cancelQualification']['iterationsFinalOnlyVerified']},indent=2))
