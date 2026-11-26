import json,os,subprocess,hashlib,time
from pathlib import Path
root=Path('/workspace/agent-foundation-20261125');os.chdir(root)
env=os.environ.copy();env.update(PATH='/workspace/toolchains/flutter/bin:'+env['PATH'], LD_LIBRARY_PATH='/workspace/toolchains/sqlite-3.54.1', STUDIO_MEDIA_LIBRARY='/workspace/agent-media-native-peer/libstudio_media.so',STUDIO_TEST_VIDEO=str(root/'artifacts/local-video/input.mp4'),CHROME_EXECUTABLE='/workspace/toolchains/browser/chrome-test')
p=root/'artifacts/field-invert-audio-mute/commands.json';d=json.loads(p.read_text());freeze=json.loads((root/'artifacts/field-invert-audio-mute/source-freeze.json').read_text())
for f,h in freeze['sourceSha256'].items():assert hashlib.sha256((root/f).read_bytes()).hexdigest()==h,f
failed=[]
for r in d['runs']:
    if r.get('exitCode') is not None:
        print('SKIP',r['name'],r['exitCode'],r.get('elapsedSeconds'),flush=True)
        if r['exitCode']:failed.append(r['name'])
        continue
    print('START',r['name'],flush=True);e=env.copy();e.update(r.get('environment') or {});start=time.monotonic()
    with open(root/r['log'],'w') as out:r['exitCode']=subprocess.run(r['command'],cwd=root/r['cwd'],env=e,stdout=out,stderr=subprocess.STDOUT).returncode
    r['elapsedSeconds']=round(time.monotonic()-start,3);p.write_text(json.dumps(d,indent=2)+'\n');print('END',r['name'],r['exitCode'],r['elapsedSeconds'],flush=True)
    if r['exitCode']:failed.append(r['name'])
print('FAILED',failed,flush=True)
raise SystemExit(bool(failed))
