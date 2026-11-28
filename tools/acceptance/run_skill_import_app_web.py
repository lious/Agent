#!/usr/bin/env python3
"""NEW actual-App selection/preview/default-policy composition, not old host suite."""
import base64,hashlib,http.server,json,os,secrets,signal,subprocess,tempfile,threading
from pathlib import Path
from urllib.parse import unquote,urlsplit
ROOT=Path(__file__).resolve().parents[2];OUT=Path('/workspace/skill-import-app-353');OUT.mkdir(exist_ok=True);WEB=OUT/'web-app'
lock=json.loads((ROOT/'packages/studio_assets/third_party/sodium_web/backend-lock.json').read_text())
def sri(b):return 'sha384-'+base64.b64encode(hashlib.sha384(b).digest()).decode()
vendor=(ROOT/'packages/studio_assets/web'/lock['appAssetPath'].lstrip('/')).read_bytes()
assert hashlib.sha256(vendor).hexdigest()==lock['sourceSha256'] and sri(vendor)==lock['sri'] and len(vendor)==lock['sourceBytes']
subprocess.run(['/workspace/toolchains/flutter/bin/flutter','build','web','--release','--no-web-resources-cdn','--no-wasm-dry-run','--dart-define=STUDIO_SIGNED_IMPORT_PREVIEW=true','--output='+str(WEB)],cwd=ROOT/'apps/studio_web',check=True)
subprocess.run(['/workspace/toolchains/flutter/bin/dart','run','tools/acceptance/import_app/create_fixtures.dart',str(OUT/'public')],cwd=ROOT,check=True)
static={'/signed_import_bootstrap.js':(ROOT/'packages/studio_assets/web/signed_import_bootstrap.js').read_bytes(),'/flutter_bootstrap.js':(WEB/'flutter_bootstrap.js').read_bytes(),lock['appAssetPath']:vendor}
for mode in ['normal','missing-backend','csp-backend-block','sri-backend-tamper']:
 nonce=secrets.token_urlsafe(16);index=(WEB/'index.html').read_text().replace('</head>','<meta name="app-style-nonce" content="'+nonce+'"></head>')
 scripts=''.join('<script src="'+p+'" integrity="'+sri(static[p])+'"></script>' for p in ['/signed_import_bootstrap.js','/flutter_bootstrap.js']);index=index.replace('<script src="/flutter_bootstrap.js" async></script>',scripts)
 assert scripts in index and '<base' not in index
 policy="default-src 'none'; script-src 'self' '"+lock['sri']+"' 'wasm-unsafe-eval'; connect-src 'self'; object-src 'none'; base-uri 'none'; font-src 'self'; img-src 'self'; style-src 'self' 'nonce-"+nonce+"'; worker-src 'none'; form-action 'none'; frame-ancestors 'none'"
 hashes={}
 class Host(http.server.BaseHTTPRequestHandler):
  def do_GET(self):
   p=unquote(urlsplit(self.path).path)
   if mode=='missing-backend' and p==lock['appAssetPath']:self.send_response(404);self.end_headers();return
   if p=='/':data,mime=index.encode(),'text/html'
   elif p in static:data,mime=static[p],'text/javascript'
   else:
    f=(WEB/p.lstrip('/')).resolve()
    if not f.is_relative_to(WEB) or not f.is_file():self.send_response(404);self.end_headers();return
    data=f.read_bytes();mime='application/wasm' if f.suffix=='.wasm' else 'text/javascript' if f.suffix=='.js' else 'application/octet-stream'
   if mode=='sri-backend-tamper' and p==lock['appAssetPath']:data+=b'\nwindow.unverifiedCompositionVendorExecuted=true;\n'
   hashes[p]=hashlib.sha256(data).hexdigest();self.send_response(200);self.send_header('Content-Type',mime);self.send_header('Content-Security-Policy',policy)
   if mode=='csp-backend-block':
    origin=f'http://127.0.0.1:{self.server.server_port}'
    self.send_header('Content-Security-Policy',"script-src 'wasm-unsafe-eval' "+' '.join(origin+p for p in ['/signed_import_bootstrap.js','/flutter_bootstrap.js','/main.dart.js','/canvaskit/']))
   self.end_headers();self.wfile.write(data)
  def log_message(self,*_):pass
 server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Host);threading.Thread(target=server.serve_forever,daemon=True).start()
 try:
  with tempfile.TemporaryDirectory(prefix='skill-composition-browser-') as profile:
   chrome=subprocess.Popen(['/usr/bin/google-chrome','--headless=new','--no-sandbox','--disable-background-networking','--no-first-run','--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
   try:subprocess.run(['node',str(ROOT/'tools/acceptance/import_app/browser.cjs'),profile+'/DevToolsActivePort',f'http://127.0.0.1:{server.server_port}/',str(OUT/'public/unsigned.json'),str(OUT/(mode+'.json')),mode],check=True,timeout=90)
   finally:os.killpg(chrome.pid,signal.SIGTERM);chrome.wait(timeout=10)
 finally:server.shutdown();server.server_close()
 result=json.loads((OUT/(mode+'.json')).read_text());result.update(csp=policy,servedAssetSha256=hashes,sri=lock['sri']);(OUT/(mode+'.json')).write_text(json.dumps(result,indent=2)+'\n')
