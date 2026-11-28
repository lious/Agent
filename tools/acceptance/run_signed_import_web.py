#!/usr/bin/env python3
"""Loopback-only real Chrome qualification: production bridge then compiled importer.
No fake backend fallback, VM/native runtime test, production UI/deployment or API.
"""
import argparse
import base64
import hashlib
import http.server
import json
import os
import signal
from pathlib import Path
import subprocess
import tempfile
import threading
from urllib.parse import urlsplit

ROOT=Path(__file__).resolve().parents[2]
ASSETS=ROOT/'packages/studio_assets'
TEST=ASSETS/'test/skills/signed_import_web'
LOCK=json.loads((ROOT/'docs/implementation/evidence/web-signed-import-plan-v1/backend-candidate.json').read_text())

def sri(b):return 'sha384-'+base64.b64encode(hashlib.sha384(b).digest()).decode()
def run(args):
 artifact=(ASSETS/'web'/LOCK['appAssetPath'].lstrip('/')).read_bytes()
 assert len(artifact)==LOCK['sourceBytes'] and hashlib.sha256(artifact).hexdigest()==LOCK['sourceSha256']
 assert sri(artifact)==LOCK['sri'],'DO NOT execute unverified vendor source'
 args.output.mkdir(parents=True,exist_ok=True)
 compiled=args.output/'browser_test.js'
 subprocess.run([args.dart,'compile','js','-O2',str(TEST/'browser_test.dart'),'-o',str(compiled)],cwd=ROOT,check=True)
 compiled_bytes=compiled.read_bytes()
 bootstrap=(ASSETS/'web/signed_import_bootstrap.js').read_bytes()
 harness=(TEST/'harness.js').read_bytes()
 reports=[]
 modes=['crypto','aliasing','bad-string','bad-shared','bad-resizable','importer','fail-before-ready','fail-symbol','fail-version','fail-truthy','fail-preexisting','fail-foreign','fail-csprng','fail-sri','fail-csp','fail-deadline','fail-late','replacement','truthy','exception','teardown']
 for mode in modes:
  result={};event=threading.Event();requests=[]
  resources={'/bootstrap.js':bootstrap,'/harness.js':harness,'/browser_test.js':compiled_bytes,
   '/fixtures.json':(TEST/'fixtures.json').read_bytes(),'/vectors.json':(ASSETS/'test/skills/signed_import/vectors/ed25519_test.json').read_bytes(),LOCK['appAssetPath']:artifact}
  # CSP failure excludes ONLY vendor; every App/test script is separately hashed.
  policy="default-src 'none'; script-src "+(' '.join("'"+sri(b)+"'" for b in (bootstrap,harness,compiled_bytes)) if mode=='fail-csp' else "'self' '"+LOCK['sri']+"' 'wasm-unsafe-eval'")+"; connect-src 'self'; object-src 'none'; base-uri 'none'"
  class Handler(http.server.BaseHTTPRequestHandler):
   def do_GET(self):
    path=urlsplit(self.path).path;requests.append({'path':path,'method':'GET'})
    if path=='/index.html':body=b'<!doctype html><meta charset="utf-8"><script src="/harness.js" integrity="'+sri(harness).encode()+b'"></script><script src="/bootstrap.js" integrity="'+sri(bootstrap).encode()+b'"></script><script defer src="/browser_test.js" integrity="'+sri(compiled_bytes).encode()+b'"></script><body>Signed import Web qualification</body>';mime='text/html'
    elif path in resources:
     body=resources[path];mime='application/json' if path.endswith('.json') else 'text/javascript'
     if mode=='fail-sri' and path==LOCK['appAssetPath']:body+=b'\nwindow.vendorTamperExecuted=true;\n'
    else:self.send_response(404);self.end_headers();return
    self.send_response(200);self.send_header('Content-Type',mime);self.send_header('Content-Security-Policy',policy);self.send_header('Cross-Origin-Opener-Policy','same-origin');self.send_header('Cross-Origin-Embedder-Policy','require-corp');self.send_header('Cache-Control','no-store');self.end_headers();self.wfile.write(body)
   def do_POST(self):
    requests.append({'path':self.path,'method':'POST'})
    if self.path!='/result':self.send_response(404);self.end_headers();return
    result.update(json.loads(self.rfile.read(int(self.headers['Content-Length']))));self.send_response(200);self.end_headers();event.set()
   def log_message(self,*a):pass
  server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
  threading.Thread(target=server.serve_forever,daemon=True).start()
  try:
   with tempfile.TemporaryDirectory(prefix='signed-import-web-chrome-',ignore_cleanup_errors=True) as profile:
    with (args.output/(mode+'.chrome.log')).open('w') as err:
     process=subprocess.Popen([args.chrome,'--headless=new','--no-sandbox','--user-data-dir='+profile,'--no-first-run','--no-default-browser-check','--disable-background-networking','--disable-component-update','--disable-sync',f'http://127.0.0.1:{server.server_port}/index.html?mode={mode}'],stdout=subprocess.DEVNULL,stderr=err,start_new_session=True)
     try:
      if not event.wait(35):result.update(ok=False,error='real browser result timeout')
     finally:os.killpg(process.pid,signal.SIGTERM);process.wait(timeout=10)
  finally:server.shutdown();server.server_close()
  unexpected=[r for r in requests if not (r['method']=='GET' and (r['path'] in resources or r['path'] in ['/index.html','/favicon.ico'])) and not(r['method']=='POST' and r['path']=='/result')]
  if unexpected or result.get('vendorTamperExecuted'):result['ok']=False
  if mode=='fail-csp':
   if not result.get('violations'):result['ok']=False
  elif result.get('violations'):result['ok']=False
  result.update(mode=mode,requests=requests,unexpectedRequests=unexpected,csp=policy)
  reports.append(result)
  (args.output/(mode+'.json')).write_text(json.dumps(result,indent=2)+'\n')
  print(mode, 'PASS' if result.get('ok') else 'FAIL',result.get('error',''),len(result.get('cases',[])),flush=True)
  # Crypto qualification MUST succeed before importer is executed; no skips.
  if not result.get('ok'):break
 summary=dict(ok=len(reports)==len(modes) and all(r.get('ok') for r in reports),base='462b0a25a02c14be6fb9019c6ddeec0a50525629',dart=subprocess.check_output([args.dart,'--version'],text=True).strip(),chrome=subprocess.check_output([args.chrome,'--version'],text=True).strip(),compiler='dart compile js -O2; main browser realm',artifactSha256=LOCK['sourceSha256'],sri=LOCK['sri'],coreVersion='1.0.22 checked by startup self-test',bootstrapSha256=hashlib.sha256(bootstrap).hexdigest(),compiledImporterSha256=hashlib.sha256(compiled_bytes).hexdigest(),modes=reports)
 (args.output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
 return 0 if summary['ok'] else 1
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--dart',default='/workspace/toolchains/flutter/bin/dart');p.add_argument('--chrome',default='/usr/bin/google-chrome');p.add_argument('--output',type=Path,default=Path('/workspace/signed-import-web-348'));raise SystemExit(run(p.parse_args()))
