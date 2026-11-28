#!/usr/bin/env python3
"""TEST ONLY xdotool/Flutter keyboard focus canary, not N01 acceptance."""
import json,os,subprocess,sys,tempfile,time
from pathlib import Path

def x(env,*args):
    return subprocess.run(['xdotool',*args],env=env,text=True,capture_output=True)

def main(root, flutter, out):
    root=Path(root)
    with tempfile.TemporaryDirectory(prefix='kbd-canary-') as tmp:
        tmp=Path(tmp)
        marker=tmp/'activated'
        display=subprocess.Popen(['Xvfb','-displayfd','1','-screen','0','1280x720x24','-nolisten','tcp'],stdout=subprocess.PIPE,text=True,stderr=subprocess.DEVNULL)
        try:
            number=display.stdout.readline().strip()
            if not number: raise SystemExit('Xvfb failed')
            env=dict(os.environ,DISPLAY=':'+number,GTK_USE_PORTAL='0',
                     XDG_CONFIG_HOME=str(tmp/'config'),XDG_DATA_HOME=str(tmp/'data'),
                     XDG_CACHE_HOME=str(tmp/'cache'),STUDIO_KEYBOARD_CANARY_OUT=str(marker))
            app=subprocess.Popen([flutter,'run','-d','linux','-t','test/keyboard_focus_canary.dart','--no-pub'],cwd=str(root/'apps/studio_demo'),env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
            window=None
            deadline=time.time()+90
            while time.time()<deadline:
                found=x(env,'search','--onlyvisible','--name','studio_demo')
                if found.returncode==0 and found.stdout.strip():
                    window=found.stdout.splitlines()[-1]
                    break
                if app.poll() is not None:
                    output=app.stdout.read() if app.stdout else ''
                    raise SystemExit('canary app exited early: '+output[-2000:])
                time.sleep(0.25)
            if window is None:
                app.terminate(); raise SystemExit('Flutter canary window never appeared')
            if marker.exists():
                app.terminate(); raise SystemExit('activation occurred before trusted input')
            x(env,'windowfocus','--sync',window)
            time.sleep(0.3)
            focused=x(env,'getwindowfocus').stdout.strip()
            x(env,'key','--window',window,'Tab')
            time.sleep(0.3)
            x(env,'key','--window',window,'Return')
            for _ in range(50):
                if marker.exists():
                    break
                time.sleep(0.1)
            app.terminate()
            try: app.wait(timeout=10)
            except subprocess.TimeoutExpired:
                app.kill(); app.wait(timeout=5)
            passed=marker.exists() and marker.read_text()=='activated' and focused==window
            Path(out).write_text(json.dumps({
                'passed':passed,
                'window':window,
                'focusedWindow':focused,
                'activated':marker.exists(),
                'inputMethod':'xdotool Tab then Return on actual Flutter Linux window',
                'scope':'transport canary only, not N01',
            },indent=2)+'\n')
            if not passed:
                raise SystemExit('keyboard canary failed')
        finally:
            display.terminate(); display.wait(timeout=10)

if __name__=='__main__':
    main(sys.argv[1],sys.argv[2],sys.argv[3])
