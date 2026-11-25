#!/usr/bin/env python3
"""Actual60s1080p30/Main4/AAC48k offline codec/mux qualification, not AudioSink.
No user material, device access, downloads, model/paid API or deployment.
"""
import argparse
import array
import datetime
from fractions import Fraction
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
from run_task import ROOT, run


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--native-library', type=Path, required=True)
    p.add_argument('--report', type=Path, required=True)
    args = p.parse_args()
    directory = ROOT / 'artifacts/audio-qualification/current'
    directory.mkdir(parents=True, exist_ok=True)
    # Only replace this recipe's synthetic artifacts, never user-selected paths.
    for name in ['input.mp4', 'export.mp4', 'decoded.f32', 'sdk-result.json', 'project.db', 'project.db-wal', 'project.db-shm', 'frames.gray']:
        file = directory / name
        if file.exists():
            file.unlink()
    records = []

    def check(command, **options):
        r = run([str(x) for x in command], environment=os.environ.copy(), timeout=300, **options)
        log = directory / ('command-' + str(len(records) + 1) + '.log')
        log.write_text(r['output'])
        records.append({k: v for k, v in r.items() if k != 'output'} | {'outputSavedTo': str(log.relative_to(ROOT))})
        print('exit=' + str(r['exitCode']) + ' ' + ' '.join(r['command'][:5]), flush=True)
        if r['exitCode']:
            raise RuntimeError('actual command failed')
        return r['output']

    metrics = {}
    status = 'failed'
    try:
        check(['ffmpeg', '-v', 'error', '-f', 'lavfi', '-i', 'color=black:size=1920x1080:rate=30:duration=60',
               '-f', 'lavfi', '-i', "aevalsrc='if(lt(mod(t,1),0.005),0.5,0)':s=48000:d=60",
               '-vf', "drawbox=color=white:t=fill:enable='eq(mod(n,30),0)',setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=limited",
               '-c:v', 'libx264', '-preset', 'veryfast', '-profile:v', 'main', '-level:v', '4.0', '-bf', '0',
               '-c:a', 'aac', '-ar', '48000', '-ac', '2', directory / 'input.mp4'])
        check([shutil.which('dart') or 'dart', 'run', 'packages/studio_sdk/tool/audio_qualification.dart', directory, args.native_library.absolute()])
        sdk = json.loads((directory / 'sdk-result.json').read_text())
        probe = json.loads(check(['ffprobe', '-v', 'error', '-show_streams', '-show_packets', '-of', 'json', directory / 'export.mp4']))
        video = next(s for s in probe['streams'] if s['codec_type'] == 'video')
        audio = next(s for s in probe['streams'] if s['codec_type'] == 'audio')
        assert (video['codec_name'], video['profile'], video['level'], video['width'], video['height'], video['pix_fmt']) == ('h264', 'Main', 40, 1920, 1080, 'yuv420p')
        assert audio['codec_name'] == 'aac' and int(audio['sample_rate']) == 48000 and audio['channels'] == 2
        assert Fraction(video['duration_ts']) * Fraction(video['time_base']) == Fraction(60)
        assert Fraction(audio['duration_ts']) * Fraction(audio['time_base']) == Fraction(60)
        assert int(video['nb_frames']) == 1800
        for stream in [video, audio]:
            packets = [x for x in probe['packets'] if x['stream_index'] == stream['index']]
            dts = [int(x['dts']) for x in packets]
            assert all(a < b for a, b in zip(dts, dts[1:]))
            assert Fraction(int(packets[-1]['pts']) + int(packets[-1]['duration'])) * Fraction(stream['time_base']) == 60
        # Decode independent reference observations with the installed CLI. This
        # is test inspection only; application code does not execute ffmpeg CLI.
        check(['ffmpeg', '-v', 'error', '-i', directory / 'export.mp4', '-map', '0:a:0', '-f', 'f32le', '-ac', '2', '-ar', '48000', directory / 'decoded.f32'])
        check(['ffmpeg', '-v', 'error', '-i', directory / 'export.mp4', '-map', '0:v:0', '-vf', 'scale=1:1:flags=area', '-pix_fmt', 'gray', '-f', 'rawvideo', directory / 'frames.gray'])
        frames = (directory / 'frames.gray').read_bytes()
        white = [i for i, pixel in enumerate(frames) if pixel > 200]
        assert len(frames) == 1800 and white == list(range(0, 1800, 30))
        n = 60 * 48000
        file_samples = (directory / 'decoded.f32').stat().st_size // 8
        # The decoder can expose the last padded AAC frame. Actual packet
        # duration/skip metadata, not an invented priming subtraction, determines
        # the logical content end used for presentation.
        frame_size = sdk['receipt']['audioFrameSize']
        assert n <= file_samples < n + frame_size
        offsets = []
        with (directory / 'decoded.f32').open('rb') as f:
            for second, frame in enumerate(white):
                start = max(0, second * 48000 - 960)
                count = min(n - start, 1920)
                f.seek(start * 8)
                samples = array.array('f')
                samples.frombytes(f.read(count * 8))
                if sys.byteorder != 'little':
                    samples.byteswap()
                onset = next(i for i in range(count) if max(abs(samples[2*i]), abs(samples[2*i+1])) > .1)
                offsets.append(float((Fraction(start + onset, 48000) - Fraction(frame, 30)) * 1000))
        assert max(abs(x) for x in offsets) <= 20
        metrics = {'videoFrames': len(frames), 'videoProfile': video['profile'], 'videoLevel': video['level'],
                   'contentAudioSamples': n, 'independentDecoderRawSamples': file_samples,
                   'actualEncoderFrameSize': frame_size, 'actualInitialPadding': sdk['receipt']['audioInitialPadding'],
                   'firstAudioPacket': next(x for x in probe['packets'] if x['stream_index'] == audio['index']),
                   'lastAudioPacket': [x for x in probe['packets'] if x['stream_index'] == audio['index']][-1],
                   'audioFlashOffsetsMs': offsets, 'maxAbsAVOffsetMs': max(abs(x) for x in offsets),
                   'monotonicDTS': True, 'videoDurationSeconds': 60, 'audioContainerDurationSeconds': 60,
                   'flashFrames': white, 'nativeCodecProfile': sdk['nativeCodecProfile'],
                   'frozenRevision': sdk['frozenRevision'], 'currentRevision': sdk['currentRevision'],
                   'sha256': {name: hashlib.file_digest((directory / name).open('rb'), 'sha256').hexdigest()
                              for name in ['input.mp4', 'export.mp4', 'sdk-result.json', 'frames.gray', 'decoded.f32']}}
        status = 'passed'

    except Exception as e:
        metrics['failure'] = type(e).__name__ + ': ' + str(e)
    names=__import__('subprocess').check_output(['git','ls-files','--cached','--others','--exclude-standard'],cwd=ROOT,text=True).splitlines()
    sources={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in sorted(names) if (name.startswith(('native/','packages/','tools/','apps/')) or name in ['pubspec.yaml','pubspec.lock']) and (ROOT/name).is_file()}
    report = {'sourceHashes':sources,'schemaVersion': '1.0.0', 'scopeStatus': status, 'checkedAt': datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(), 'timezone': 'Asia/Shanghai', 'fullTaskComplete': False, 'physicalDeviceQualification': False, 'scope': 'Linux offline synthetic60s1080p30 H264 Main4 + AAC48k, not device presentation clock or full original task', 'metrics': metrics, 'checks': records, 'notValidated': ['AudioSink presentation/underrun/device switch', 'other platforms/physical devices', 'full RenderGraph/effects/AudioClip link/schema', 'hardware codecs/production redistribution']}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    return 0 if status == 'passed' else 1


if __name__ == '__main__':
    sys.exit(main())
