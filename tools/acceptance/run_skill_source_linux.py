#!/usr/bin/env python3
"""Independent actual GTK adapter test; no previous importer/crypto/runtime suite."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[2]
OUT=Path('/workspace/skill-source-351');OUT.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='gtk-source-fixtures-') as fixture:
    display=subprocess.Popen(['Xvfb','-displayfd','1','-screen','0','1920x1200x24','-nolisten','tcp'],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True)
    try:
        number=display.stdout.readline().strip()
        if not number:raise RuntimeError('Xvfb failed to initialize')
        env=dict(os.environ,DISPLAY=':'+number,GTK_USE_PORTAL='0',XDG_CONFIG_HOME=fixture+'/config',XDG_DATA_HOME=fixture+'/data',XDG_CACHE_HOME=fixture+'/cache',
            STUDIO_SOURCE_FIXTURES=fixture,STUDIO_SOURCE_GTK_HELPER=str(ROOT/'tools/acceptance/skill_source/gtk_choose.py'),STUDIO_SOURCE_LINUX_RESULT=str(OUT/'linux.json'))
        subprocess.run(['/workspace/toolchains/flutter/bin/flutter','test','integration_test/skill_source_adapter_test.dart','-d','linux'],cwd=ROOT/'apps/studio_demo',env=env,check=True)
    finally:
        display.terminate();display.wait(timeout=10)
result=json.loads((OUT/'linux.json').read_text());result['gtkVersion']=subprocess.check_output(['pkg-config','--modversion','gtk+-3.0'],text=True).strip();(OUT/'linux.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
