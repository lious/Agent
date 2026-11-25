import collections,datetime,hashlib,json
from pathlib import Path
root=Path('/workspace/agent-foundation-20261125');art=root/'artifacts/multi-move';dst=root/'docs/implementation/evidence/multi-move'
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
 'freezeIdentity':'Containing LOCAL commit matches all32 source/test/package hashes. New selected final runs use this exact source; docs/evidence only afterward. Not all repository/original87 acceptance. No borrowed248/233/209/182.',
 'commands':commands,'results':results,'totalPassed':sum(r['passed'] for r in results.values()),'totalFailed':sum(r['failed'] for r in results.values()),'totalSkipped':sum(r['skipped'] for r in results.values()),'additionalRuns':finals,'auxiliaryPreFreezeEvidence':aux,
 'multiMoveScope':{
 'originalContract':'s3 rows25/36/37/41/45/51/53, original I-005 dependencies/acceptance unchanged. Same-track/reject/includeLinks=true only, explicit viewport checkboxes + exact Q candidate then explicit commit/cancel. Not pointer/snap/copy/insert/overwrite or full I-005.',
 'authority':'Immutable canonical requested IDs; different requested selections refuse gesture coalescing even if a closure could match. Entire admitted AV link closure, exact offsets and source/effect/automation preservation. No silently skipped failed members or stale IDs.',
 'atomicity':'All-member track/start-field locks, negative/frame/sample/collision and transition endpoint checks before one normal repository edit. Existing revision/writer fence, receipt/journal/definitions/pins/events/outbox transaction. Real late SQL rollback/manual same-candidate retry and independent connections exact-one winner.',
 'time':'Absolute captions unchanged; richer caption anchors refuse editing. Caption pixel preview/export explicitly refuse, never silently omit. Exact source ranges/time maps and clip-local effect curves unchanged. Audio fractional sample move refuses; if preserved duration ends mid-video-frame, video tail Gap uses ceil frame.',
 'UI':'Actual four-member AV checkbox selection, native still ghost, one commit undo/redo, invalid-update image disposal/commit refusal, Escape, SQL failure inline/cancel, whole collision refusal, durable save/archive fork/AAC MP4. Widget software-service test, not physical device/window performance.',
 'media':'Real linked four-member AV path plus opacity keyframes/transform/crop/color/proxy; paired dissolve source handles/cut/effect order with native preview==preencoder RGBA, actual MP4 and archive/reopen.100 seeded same-type multi-move/undo/redo roots, not1000 randomized all-NLE matrix.',
 'preservation':'No new schema/tables/registry. Uses existing persistent full-root tip inverse and stored definitions, monotonic revisions; no field-aware concurrent inverse. Existing resource admission/unknown history remains fail-closed.',
 'limits':'O(document+affected sort), existing history cursor O(n), no interval-index/large-history qualification, at-most currently admitted native track/profile slice. Other original48 planned functions not implemented by this increment.'},
 'threeReviews':'../../REVIEW.md increment1.22 / ADR0029: whole-set/locks and sealed exhaustive dispatch; real offset/mixed clocks/transition+SQL/fence; UI invalid ghost/live-binding cleanup+media/resource regressions. Preliminary failures retained, not final counts.',
 'priorUnresolved':[{'commit':'e23a559c7178c5ee9a127780d199d098e60927c5','summary':'../raster-effects/summary.json','failure':'raster_clock first-play underrun presented2877 still not proven solved'},{'commit':'00c2e5d4b6e93d71ff3b19d8ddf5d30f95fdd77d','summary':'../dissolve/summary.json','failure':'opacity_clock Pulse timeout/underrun still not proven solved'}],
 'cancelQualification':{'iterationsFinalOnlyVerified':sum(100 for r in cancels if r['exitCode']==0),'scope':'Four actual active-video cancel modes regular/ASan100 each, app AVFrame/FD; not full codec/GPU/real Pulse ASan/TSan'},
 'notRun':['Full repo/all87 hard-dependency closure or full I-005 operation positive-negative/random1000 NLE matrix','Cross-track/insert-overwrite/snap/clipboard/groups/Alt-unlink/all pointer drag UI or field-aware inverse','Large/million-entry history realtime performance / balanced interval index (O(n) history unchanged)','Fresh release App/window build, GPU/stable fps/human hearing/actual DAC/physical AV synchronization/non-Linux/mobile/physical multi-device','Statistical root-cause elimination of startup/resume underrun; old failures retained','Fresh independent60s/VFR/HDR/full P0/whole v4-v8 old-executable qualification (selected current migration/actual legacy/SQL/SIGKILL only)','Unselected Harness/security/peer suites unchanged','Positive RTC known managed policy blocked unchanged, no retry/bypass/relay','Remote reads/diagnosis/push or rule/branch/identity/protocol/permission change'],
 'statusCounts':{'original87':counts(original),'XD10':counts(xd)},
 'publication':'Ordinary LOCAL commit only; existing unpublished e23a559/c8c12d8/c948c56/a52002f ancestors preserved, resulting ahead5 relative last-known local tracking. No new GitHub commit URL. commit_refs_rules cause remains unknown; no new remote diagnosis/retry or compliant recovery evidence.',
 'toolchain':'Reused Flutter3.50.1/Dart3.14; strict approved SQLite3.54.1 unchanged (system DEV3.46.1 not accepted); FFmpeg7.1.5/Pulse17/clang19/CMake3.31.6/Chrome156. Native hashes unchanged; no package install/large models/paid calls.'}
if (dst/'toolchain-current.json').exists():d['toolchainCurrent']={'log':'toolchain-current.json','sha256':sha((dst/'toolchain-current.json').read_bytes())}
(dst/'summary.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'passed':d['totalPassed'],'failed':d['totalFailed'],'skipped':d['totalSkipped'],'groups':{k:v['exitCode'] for k,v in finals.items()},'cancelIterations':d['cancelQualification']['iterationsFinalOnlyVerified']},indent=2))
