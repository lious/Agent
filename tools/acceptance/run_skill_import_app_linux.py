#!/usr/bin/env python3
"""New actual App composition test, no old qualification runtimes."""
from pathlib import Path
import json,os,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2];OUT=Path('/workspace/skill-import-app-353');OUT.mkdir(exist_ok=True)
lock=json.loads((ROOT/'packages/studio_assets/third_party/sodium/backend-lock.json').read_text())
with tempfile.TemporaryDirectory(prefix='skill-app-353-') as fixture:
 display=subprocess.Popen(['Xvfb','-displayfd','1','-screen','0','1920x1200x24','-nolisten','tcp'],stdout=subprocess.PIPE,text=True,stderr=subprocess.DEVNULL)
 try:
  number=display.stdout.readline().strip()
  if not number:raise RuntimeError('Xvfb failed')
  # Use the already-approved store dependency; its default runtime guard stays enabled.
  env=dict(os.environ,LD_LIBRARY_PATH='/workspace/toolchains/sqlite-3.54.1'+(':'+os.environ['LD_LIBRARY_PATH'] if os.environ.get('LD_LIBRARY_PATH') else ''),DISPLAY=':'+number,GTK_USE_PORTAL='0',XDG_CONFIG_HOME=fixture+'/config',XDG_DATA_HOME=fixture+'/data',XDG_CACHE_HOME=fixture+'/cache',STUDIO_COMPOSITION_FIXTURES=fixture+'/app',STUDIO_COMPOSITION_GTK_HELPER=str(ROOT/'tools/acceptance/skill_source/gtk_choose.py'),STUDIO_COMPOSITION_LINUX_RESULT=str(OUT/'linux.json'))
  Path(fixture+'/app').mkdir()
  subprocess.run(['/workspace/toolchains/flutter/bin/flutter','test','integration_test/skill_import_app_test.dart','-d','linux','--dart-define=STUDIO_SIGNED_IMPORT_SODIUM_PATH='+lock['devBinary'],'--dart-define=STUDIO_SIGNED_IMPORT_SODIUM_SHA256='+lock['devBinarySha256']],cwd=ROOT/'apps/studio_demo',env=env,check=True,timeout=150)
 finally:display.terminate();display.wait(timeout=10)
print((OUT/'linux.json').read_text())
