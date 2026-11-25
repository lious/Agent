#!/usr/bin/env python3
"""Run real service integration in an isolated local Pulse/DBus session.
Test-only software sinks, never production defaults or physical-device evidence.
"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


def main():
    command = sys.argv[1:]
    if not command:
        raise SystemExit('usage: run_private.py COMMAND [ARGS...]')
    if os.environ.get('STUDIO_PRIVATE_PULSE_DBUS') != '1':
        return subprocess.call(['dbus-run-session', '--', sys.executable, __file__, *command],
                               env={**os.environ, 'STUDIO_PRIVATE_PULSE_DBUS': '1'})
    with tempfile.TemporaryDirectory(prefix='studio-pulse-qualification-') as root:
        directory = Path(root)
        (directory / 'runtime').mkdir(mode=0o700)
        (directory / 'state').mkdir(mode=0o700)
        environment = {**os.environ,
                       'XDG_RUNTIME_DIR': str(directory / 'runtime'),
                       'PULSE_RUNTIME_PATH': str(directory / 'runtime'),
                       'PULSE_STATE_PATH': str(directory / 'state'),
                       'XDG_CONFIG_HOME': str(directory / 'config'),
                       'PULSE_SERVER': 'unix:' + str(directory / 'native'),
                       'STUDIO_PULSE_TEST': '1'}
        # Auth anonymous is limited to this 0700 temporary directory's Unix socket.
        # Production uses the user's OS-authenticated service, no network endpoints.
        args = ['pulseaudio', '-n', '--daemonize=no', '--exit-idle-time=-1',
                '--disable-shm=yes', '--log-target=file:' + str(directory / 'pulse.log'),
                '--load=module-null-sink sink_name=studio_test rate=48000 channels=2',
                '--load=module-null-sink sink_name=second rate=48000 channels=2',
                '--load=module-native-protocol-unix socket=' + str(directory / 'native') + ' auth-anonymous=1']
        server = subprocess.Popen(args, env={**environment, 'HOME': root}, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            deadline = time.monotonic() + 6
            while not (directory / 'native').exists():
                if server.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError('Private real Pulse service startup failed')
                time.sleep(.02)
            return subprocess.call(command, env=environment)
        finally:
            server.terminate()
            server.wait(timeout=6)


if __name__ == '__main__':
    sys.exit(main())
