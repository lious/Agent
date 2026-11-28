#!/usr/bin/env python3
"""Compile the actual Web source adapter, independently test real browser Files."""
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
import os
import subprocess
import tempfile
import threading

ROOT=Path(__file__).resolve().parents[2];OUT=Path('/workspace/skill-source-351');OUT.mkdir(exist_ok=True)
class Host(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Content-Security-Policy',"default-src 'none'; script-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'none'; worker-src 'none'; frame-ancestors 'none'; form-action 'none'")
        super().end_headers()
    def log_message(self,*_):pass
with tempfile.TemporaryDirectory(prefix='skill-source-web-') as directory:
    d=Path(directory);(d/'fixtures').mkdir();(d/'site').mkdir();site=d/'site'
    subprocess.run(['/workspace/toolchains/flutter/bin/dart','compile','js','-O2','-o',str(site/'probe.js'),'apps/studio_web/test/skill_source_adapter_web_probe.dart'],cwd=ROOT,check=True)
    (site/'index.html').write_text('<!doctype html><meta charset="utf-8"><button id="choose">Choose</button><button id="cancel">Cancel</button><button id="dispose">Dispose</button><pre id="status"></pre><script src="/probe.js" defer></script>')
    server=ThreadingHTTPServer(('127.0.0.1',0),partial(Host,directory=str(site)));threading.Thread(target=server.serve_forever,daemon=True).start()
    display=subprocess.Popen(['Xvfb','-displayfd','1','-screen','0','1920x1200x24','-nolisten','tcp'],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True)
    number=display.stdout.readline().strip()
    if not number:raise RuntimeError('Xvfb failed to initialize')
    env=dict(os.environ,DISPLAY=':'+number,GTK_USE_PORTAL='0',XDG_CONFIG_HOME=str(d/'config'),XDG_DATA_HOME=str(d/'data'),XDG_CACHE_HOME=str(d/'cache'))
    chrome=subprocess.Popen(['/usr/bin/google-chrome','--ozone-platform=x11','--disable-background-networking','--no-first-run','--no-default-browser-check','--no-sandbox','--disable-dev-shm-usage','--remote-debugging-port=0',f'--user-data-dir={d}/profile','about:blank'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,env=env)
    try:
        subprocess.run(['node',str(ROOT/'tools/acceptance/skill_source/browser_probe.cjs'),str(d/'profile/DevToolsActivePort'),f'http://127.0.0.1:{server.server_port}/index.html',str(d/'fixtures'),str(OUT/'web.json'),str(ROOT/'tools/acceptance/skill_source/gtk_choose.py')],check=True,timeout=90,env=env)
    finally:
        chrome.terminate();chrome.wait(timeout=10);display.terminate();display.wait(timeout=10);server.shutdown();server.server_close()
