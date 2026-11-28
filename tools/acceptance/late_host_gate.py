"""Harness-only bounded vendor-body gate; never an App endpoint/readiness source."""
import json
from pathlib import Path
import threading
import time

class VendorResponseGate:
    def __init__(self, folder: Path, case_id: str, seconds: float = 8.0):
        self.folder, self.case_id, self.seconds = folder, case_id, seconds

    def wait_for_release(self):
        start=time.monotonic()
        (self.folder/'held.json').write_text(json.dumps({'caseId':self.case_id,'held':True}))
        pause=threading.Event()
        while True:
            elapsed=time.monotonic()-start
            # Check the bound BEFORE accepting any signal; late release cannot pass.
            if elapsed >= self.seconds:
                return dict(released=False,watchdogFired=True,elapsedSeconds=elapsed)
            signal=self.folder/'release.json'
            if signal.exists():
                try:
                    value=json.loads(signal.read_text())
                    valid=value=={'caseId':self.case_id,'retired':True}
                except (OSError,ValueError):valid=False
                return dict(released=valid,watchdogFired=False,invalidSignal=not valid,elapsedSeconds=elapsed)
            pause.wait(min(0.01,self.seconds-elapsed))
