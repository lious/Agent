#!/usr/bin/env python3
"""NEW B09-B11 late-state/time variants only; no historical suite rerun."""
import shutil
import sys,base64,hashlib,http.server,json,os,secrets,signal,subprocess,tempfile,threading
from pathlib import Path
from urllib.parse import unquote,urlsplit
ROOT=Path(__file__).resolve().parents[2];OUT=Path('/workspace/skill-import-app-357');OUT.mkdir(exist_ok=True);WEB=OUT/'late-state-app'
lock=json.loads((ROOT/'packages/studio_assets/third_party/sodium_web/backend-lock.json').read_text())
def sri(b):return 'sha384-'+base64.b64encode(hashlib.sha384(b).digest()).decode()
vendor=(ROOT/'packages/studio_assets/web'/lock['appAssetPath'].lstrip('/')).read_bytes()
assert hashlib.sha256(vendor).hexdigest()==lock['sourceSha256'] and sri(vendor)==lock['sri'] and len(vendor)==lock['sourceBytes']
inputs=[*sorted((ROOT/'apps/studio_web/lib').glob('*.dart')), ROOT/'apps/studio_web/test/import_late_state_entrypoint.dart',ROOT/'pubspec.lock']
source_hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
assert all('/test/' not in line and 'import_fixture_entrypoint' not in line for p in (ROOT/'apps/studio_web/lib').glob('*.dart') for line in p.read_text().splitlines() if line.startswith('import '))
entry=(ROOT/'apps/studio_web/test/import_late_state_entrypoint.dart').read_text()
assert 'nowSeconds: 1000' in entry and 'clockConfident: true' in entry
assert 'importFixture = null' in (ROOT/'apps/studio_web/lib/main.dart').read_text()
reuse='--reuse-verified-artifacts' in sys.argv
previous=json.loads((OUT/'artifacts.json').read_text()) if reuse else None
if reuse:assert previous['sourceSha256']==source_hashes
# Flutter can retain a stale incremental result after an interrupted/source-changing
# development build. A full qualification starts from a fresh disposable cache.
cache=ROOT/'apps/studio_web/.dart_tool/flutter_build'
assert not cache.is_symlink()
if not reuse and cache.exists():shutil.rmtree(cache)
builds={}
for name,target,optin in [('default','lib/main.dart',False),('opt-in','lib/main.dart',True),('late-state','test/import_late_state_entrypoint.dart',True)]:
 dest=OUT/(name+'-app')
 command=['/workspace/toolchains/flutter/bin/flutter','build','web','--release','--csp','--source-maps','--no-web-resources-cdn','--no-wasm-dry-run','--target='+target,'--output='+str(dest)]
 if optin:command+=['--dart-define=STUDIO_SIGNED_IMPORT_PREVIEW=true']
 if not reuse:subprocess.run(command,cwd=ROOT/'apps/studio_web',check=True)
 js=(dest/'main.dart.js').read_text();source_map=(dest/'main.dart.js.map').read_text()
 if reuse:
  assert hashlib.sha256(js.encode()).hexdigest()==previous['builds'][name]['mainSha256']
  assert hashlib.sha256(source_map.encode()).hexdigest()==previous['builds'][name]['sourceMapSha256']
 sentinels=['ebVWLo/mVPlAeLES6KmLp5AfhTrmlb7X4OORC60ElmQ=','sha256:65b60673d6ed884bf01c2c222d82ada0740f29ac3355d6a925c81f17f47a27b8','Fixture transition:','Apply fixture transition ','Fixture owner facts:','profileChanged=']
 fixture=name == 'late-state'
 assert all((x in js)==fixture for x in sentinels)
 assert ('import_late_state_entrypoint.dart' in source_map)==fixture
 assert 'data-signed-import-fixture-reader' not in js
 builds[name]={'target':target,'optIn':optin,'sourceMapSha256':hashlib.sha256(source_map.encode()).hexdigest(),'mainSha256':hashlib.sha256(js.encode()).hexdigest(),'fixtureSentinelsPresent':fixture,'testEntrypointInSourceMap':fixture,'heldReaderSentinelPresent':False}
(OUT/'artifacts.json').write_text(json.dumps({'passed':True,'verifiedArtifactReuse':reuse,'builds':builds,'sourceSha256':source_hashes,'defaultSourceUsesNullFixture': 'importFixture = null' in (ROOT/'apps/studio_web/lib/main.dart').read_text(),'fixtureClockDefinedOnlyInTestEntrypoint':True},indent=2)+'\n')
assert source_hashes=={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
subprocess.run(['/workspace/toolchains/flutter/bin/dart','run','packages/studio_assets/test/skills/import_app_fixture/create_fixtures.dart',str(OUT/'public')],cwd=ROOT,check=True)
cases=['B09-'+x for x in ['profile','epoch','key-removal','installed','session','branch','owner','aba']]+['B10']+['B11-'+x for x in ['backward','confidence','rollback']]
for mode in cases:
 WEB=OUT/'late-state-app'
 static={'/signed_import_bootstrap.js':(ROOT/'packages/studio_assets/web/signed_import_bootstrap.js').read_bytes(),'/flutter_bootstrap.js':(WEB/'flutter_bootstrap.js').read_bytes(),lock['appAssetPath']:vendor}
 nonce=secrets.token_urlsafe(16);index=(WEB/'index.html').read_text().replace('</head>','<meta name="app-style-nonce" content="'+nonce+'"></head>')
 scripts=''.join('<script src="'+p+'" integrity="'+sri(static[p])+'"></script>' for p in ['/signed_import_bootstrap.js','/flutter_bootstrap.js']);index=index.replace('<script src="/flutter_bootstrap.js" async></script>',scripts)
 assert scripts in index and '<base' not in index
 policy="default-src 'none'; script-src 'self' '"+lock['sri']+"' 'wasm-unsafe-eval'; connect-src 'self'; object-src 'none'; base-uri 'none'; font-src 'self'; img-src 'self'; style-src 'self' 'nonce-"+nonce+"'; worker-src 'none'; form-action 'none'; frame-ancestors 'none'"
 hashes={};document_responses=[]
 class Host(http.server.BaseHTTPRequestHandler):
  def do_GET(self):
   p=unquote(urlsplit(self.path).path)
   active_index=index;active_policy=policy
   if p=='/':
    response_nonce=secrets.token_urlsafe(16)
    active_index=index.replace(nonce,response_nonce)
    active_policy=policy.replace(nonce,response_nonce)
    document_responses.append({'nonce':response_nonce,'csp':active_policy,'indexSha256':hashlib.sha256(active_index.encode()).hexdigest()})
   if p=='/away.html':data,mime=b'<!doctype html><title>Fixture navigation destination</title>','text/html'
   elif p=='/':data,mime=active_index.encode(),'text/html'
   elif p in static:data,mime=static[p],'text/javascript'
   else:
    f=(WEB/p.lstrip('/')).resolve()
    if not f.is_relative_to(WEB) or not f.is_file():self.send_response(404);self.end_headers();return
    data=f.read_bytes();mime='application/wasm' if f.suffix=='.wasm' else 'text/javascript' if f.suffix=='.js' else 'application/octet-stream'
   hashes[p]=hashlib.sha256(data).hexdigest();self.send_response(200);self.send_header('Content-Type',mime);self.send_header('Content-Security-Policy',active_policy)
   self.end_headers();self.wfile.write(data)
  def log_message(self,*_):pass
 server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Host);threading.Thread(target=server.serve_forever,daemon=True).start()
 try:
  with tempfile.TemporaryDirectory(prefix='skill-composition-browser-') as profile:
   display=subprocess.Popen(['Xvfb','-displayfd','1','-screen','0','1920x1200x24','-nolisten','tcp'],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True)
   number=display.stdout.readline().strip()
   if not number:raise RuntimeError('Xvfb failed')
   env=dict(os.environ,DISPLAY=':'+number,GTK_USE_PORTAL='0',XDG_CONFIG_HOME=profile+'/config',XDG_DATA_HOME=profile+'/data',XDG_CACHE_HOME=profile+'/cache')
   chrome=subprocess.Popen(['/usr/bin/google-chrome','--ozone-platform=x11','--window-size=1920,1200','--no-sandbox','--disable-background-networking','--disable-dev-shm-usage','--no-first-run','--no-default-browser-check','--remote-debugging-port=0','--user-data-dir='+profile+'/chrome','about:blank'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True,env=env)
   try:subprocess.run(['node',str(ROOT/'tools/acceptance/import_late_state/browser.cjs'),profile+'/chrome/DevToolsActivePort',f'http://127.0.0.1:{server.server_port}/',str(OUT/'public/signed.json'),str(OUT/(mode+'.json')),mode,str(OUT/'public/expected.json'),str(ROOT/'tools/acceptance/skill_source/gtk_choose.py')],check=True,timeout=120,env=env)
   finally:
    os.killpg(chrome.pid,signal.SIGTERM);chrome.wait(timeout=10);display.terminate();display.wait(timeout=10)
 finally:server.shutdown();server.server_close()
 result=json.loads((OUT/(mode+'.json')).read_text());result.update(csp=document_responses[0]['csp'],documentResponses=document_responses,servedAssetSha256=hashes,sri=lock['sri']);(OUT/(mode+'.json')).write_text(json.dumps(result,indent=2)+'\n')
