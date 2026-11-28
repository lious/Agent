"""TEST ONLY: drive the real GTK dialog on the runner's isolated Xvfb display."""
import subprocess
import sys
import time

mode, path = sys.argv[1:]
def x(*args):
    return subprocess.run(['xdotool', *args], text=True, capture_output=True)
window = None
for _ in range(400):
    found = x('search', '--onlyvisible', '--name', '^Open File$')
    if found.returncode == 0:
        window = found.stdout.splitlines()[-1]
        break
    time.sleep(.05)
if window is None:
    raise SystemExit('Actual GTK Open File dialog never appeared')
x('windowfocus', '--sync', window)
time.sleep(.2)
if mode == 'cancel':
    result = x('key', 'Escape')
else:
    x('key', 'ctrl+l')
    time.sleep(.4)
    x('key', 'ctrl+a')
    time.sleep(.1)
    x('type', '--clearmodifiers', '--delay', '5', path)
    time.sleep(.5)
    for _ in range(30):
        result = x('key', '--window', window, 'Return')
        time.sleep(.3)
        if window not in x('search', '--onlyvisible', '--name', '^Open File$').stdout.splitlines():
            break
    else:
        raise SystemExit('GTK dialog did not accept the public fixture')
if result.returncode:
    raise SystemExit(result.stderr)
print('Actual GTK chooser', mode, 'completed')
