#!/usr/bin/env python3
"""TEST ONLY loopback strace canary, not App import or N01/N02 acceptance."""
import hashlib, json, os, socket, subprocess, sys, tempfile, time
from pathlib import Path

def digest(path):
    with open(path,'rb') as f: return hashlib.file_digest(f,'sha256').hexdigest()

def main(out):
    tool=Path('/usr/bin/strace')
    version=subprocess.check_output([str(tool),'-V'],text=True).splitlines()[0]
    with tempfile.TemporaryDirectory(prefix='strace-canary-') as tmp:
        tmp=Path(tmp)
        canary=tmp/'canary.py'
        marker=tmp/'created.txt'
        canary.write_text(
            'import socket,pathlib\n'
            f'pathlib.Path({str(marker)!r}).write_text("ok")\n'
            's=socket.socket();s.connect(("127.0.0.1",1))\n'
        )
        trace_prefix=tmp/'trace'
        proc=subprocess.run(
            [str(tool),'-ff','-ttt','-yy','-e','trace=network,file','-o',str(trace_prefix),
             sys.executable,str(canary)],
            text=True,capture_output=True,timeout=15)
        traces=list(tmp.glob('trace*'))
        text='\n'.join(p.read_text(errors='replace') for p in traces)
        loss=('detach: ' in text) or ('??? ' in text and 'exited' not in text)
        saw_open='openat(' in text and 'created.txt' in text
        saw_connect='connect(' in text and '127.0.0.1' in text
        passed=proc.returncode in (0,1) and traces and saw_open and saw_connect and not loss
        result=dict(
            passed=bool(passed),
            tool=str(tool),
            version=version,
            toolSha256=digest(tool),
            returncode=proc.returncode,
            stderr=proc.stderr[-2000:],
            traceFiles=[str(p.name) for p in traces],
            traceBytes=sum(p.stat().st_size for p in traces),
            sawOpenCreate=saw_open,
            sawLoopbackConnect=saw_connect,
            traceDataLoss=loss,
            flags=['-ff','-ttt','-yy','-e','trace=network,file'],
        )
        Path(out).write_text(json.dumps(result,indent=2)+'\n')
        if not passed:
            raise SystemExit('strace canary failed')

if __name__=='__main__':
    main(sys.argv[1])
