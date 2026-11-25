"""Qualification-only stdin driver; production uses C ABI directly, never Python."""
import json,sys
from pulse_smoke import native,call
l=native(sys.argv[1]);h=l.sm_create(b'test')
try:
 for line in sys.stdin:
  try:print(json.dumps({'ok':True,'value':call(l,h,json.loads(line))}),flush=True)
  except Exception as e:print(json.dumps({'ok':False,'error':str(e)}),flush=True)
finally:l.sm_close(h,b'test')
