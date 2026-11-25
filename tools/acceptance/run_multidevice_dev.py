#!/usr/bin/env python3
"""Real Chrome + Linux protocol integration; NEVER physical-device qualification."""
import argparse, datetime, hashlib, json, os
from pathlib import Path
import shutil, sys
from run_task import ROOT, run, test_count
from run_local_video import skipped

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report',type=Path,required=True)
    args=parser.parse_args()
    flutter=shutil.which('flutter')
    if not flutter: parser.error('pinned Flutter SDK required on PATH')
    env=os.environ.copy(); records=[]
    # CHROME_EXECUTABLE must point to an installed browser; no download/paid/API fallback.
    for command, cwd in [
        ([flutter,'test','--platform','chrome','test','--reporter=json'],ROOT/'apps/studio_web'),
        ([flutter,'build','web','--release','--no-pub'],ROOT/'apps/studio_web'),
        ([flutter,'--version','--machine'],ROOT),
        ([env.get('CHROME_EXECUTABLE','google-chrome'),'--version'],ROOT),
    ]:
        value=run(command,cwd=cwd,environment=env,timeout=240);records.append(value)
        print('exit='+str(value['exitCode'])+' '+' '.join(command[:5]),flush=True)
    test_records=[r for r in records if '--reporter=json' in r['command']]
    count=sum(test_count(r['output']) for r in test_records)
    omitted=sum(skipped(r['output']) for r in test_records)
    ok=all(r['exitCode']==0 for r in records) and count>=3 and omitted==0
    names=[p for p in (ROOT/'apps/studio_web').rglob('*') if p.is_file() and not any(x in p.parts for x in ['build','.dart_tool'])]
    value={'schemaVersion':'1.0.0','checkedAt':datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(),'timezone':'Asia/Shanghai','scopeStatus':'passed' if ok else 'failed','fullTaskComplete':False,'physicalDeviceQualification':False,'testsExecuted':count,'skippedTests':omitted,'scope':'One Linux physical host: actual Chrome persistent RTCCertificate/IndexedDB Harness/consent+receipt UI and direct-only preflight, editable Flutter Web and release JS build; NOT positive encrypted peer-network or physical-device qualification','sourceHashes':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(names)},'checks':records,'notValidated':['positive WebRTC DTLS/SCTP pair/revocation network qualification (managed host ICE suppressed)' ,'resumable media transfer','two physical devices','browser-native live network session','models or paid jobs','macOS/Windows/iOS/Android','browser media rendering/SQLite WASM and background execution']}
    args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
    print(f"scope={value['scopeStatus']} tests={count} skipped={omitted} physicalDevices=false")
    return 0 if ok else 1
if __name__=='__main__': sys.exit(main())
