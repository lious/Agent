import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_editor_ui/workbench_visual_language.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

void main() {
  const auditor = WorkbenchVisualAuditor();

  test('12D constants and the four collaboration zones are the constraint contract', () {
    expect(minTouchLogicalPx, 48);
    expect(maxTypeScale, 2);
    expect(minTextContrast, 4.5);
    expect(workbenchZones, [
      'sessionSidebar',
      'briefScript',
      'storyboardCandidates',
      'timelineCanvas',
      'exportArchive',
    ]);
  });

  test('WCAG contrast accepts 4.5:1 text and refuses a weaker pair', () {
    expect(WorkbenchVisualAuditor.contrastRatio(0x000000, 0xFFFFFF), 21);
    // Official audit pairing used by the command-workbench catalog.
    expect(
      WorkbenchVisualAuditor.contrastRatio(0x1A1A1A, 0xF5F5F5),
      greaterThanOrEqualTo(minTextContrast),
    );
    expect(
      () => auditor.audit(
        const [
          ChromeSurface(
            id: 'weak-text',
            role: ChromeRole.command,
            zone: 'timelineCanvas',
            minWidth: 48,
            minHeight: 48,
            foreground: 0x888888,
            background: 0xFFFFFF,
          ),
        ],
        reducedMotion: false,
      ),
      code(contrastTooLow),
    );
  });

  test('errors cannot be conveyed by color alone', () {
    expect(
      () => auditor.audit(
        const [
          ChromeSurface(
            id: 'color-only',
            role: ChromeRole.error,
            zone: 'timelineCanvas',
            colorOnly: true,
            errorCode: 'X',
            foreground: 0xFF8B0000,
            background: 0xFFF5F5F5,
          ),
        ],
        reducedMotion: false,
      ),
      code(colorOnlyError),
    );
    auditor.audit(
      const [
        ChromeSurface(
          id: 'error',
          role: ChromeRole.error,
          zone: 'timelineCanvas',
          errorCode: 'GC_EXPLICIT_CONSENT_REQUIRED',
          messageKey: 'workbench.error',
          colorOnly: false,
          foreground: 0xFF8B0000,
          background: 0xFFF5F5F5,
        ),
      ],
      reducedMotion: false,
    );
  });

  test('command chrome below 48 logical pixels is refused', () {
    expect(
      () => auditor.audit(
        const [
          ChromeSurface(
            id: 'tiny',
            role: ChromeRole.command,
            zone: 'timelineCanvas',
            minWidth: 40,
            minHeight: 40,
          ),
        ],
        reducedMotion: false,
      ),
      code(touchTargetTooSmall),
    );
  });

  test('confirm and cancel stay hittable at 200% type scale and fail when the surface is too narrow', () {
    expect(
      WorkbenchVisualAuditor.confirmCancelFit(
        surfaceWidth: 320,
        confirmLabelWidthAt100: 72,
        cancelLabelWidthAt100: 56,
        typeScale: maxTypeScale,
      ),
      isTrue,
    );
    expect(
      () => auditor.audit(
        const [
          ChromeSurface(
            id: 'confirm',
            role: ChromeRole.confirm,
            zone: 'exportArchive',
            minWidth: 48,
            minHeight: 48,
            labelWidthAt100: 120,
          ),
          ChromeSurface(
            id: 'cancel',
            role: ChromeRole.cancel,
            zone: 'exportArchive',
            minWidth: 48,
            minHeight: 48,
            labelWidthAt100: 120,
          ),
        ],
        reducedMotion: false,
        typeScale: maxTypeScale,
        actionSurfaceWidth: 200,
      ),
      code(typeScaleBlocksActions),
    );
  });

  test('reduced motion stops autoplay and flicker preview but keeps program motion', () {
    expect(
      () => auditor.audit(
        const [
          ChromeSurface(
            id: 'flash',
            role: ChromeRole.preview,
            zone: 'timelineCanvas',
            flickerPreview: true,
          ),
        ],
        reducedMotion: true,
      ),
      code(flickerPreviewNotStopped),
    );
    expect(
      () => auditor.audit(
        const [
          ChromeSurface(
            id: 'play',
            role: ChromeRole.preview,
            zone: 'timelineCanvas',
            autoplay: true,
          ),
        ],
        reducedMotion: true,
      ),
      code(autoplayNotStopped),
    );
    expect(
      () => auditor.audit(
        const [
          ChromeSurface(
            id: 'stripped-keyframes',
            role: ChromeRole.programMotion,
            zone: 'timelineCanvas',
            programMotion: false,
          ),
        ],
        reducedMotion: true,
      ),
      code(programMotionMustRemain),
    );
    auditor.audit(
      officialCommandWorkbenchChrome(reducedMotion: true),
      reducedMotion: true,
      typeScale: maxTypeScale,
    );
  });

  test('progress is announced by phase, not per token, and a late result must not steal focus', () {
    expect(
      () => auditor.audit(
        const [
          ChromeSurface(
            id: 'tokens',
            role: ChromeRole.progress,
            zone: 'sessionSidebar',
            announcePerToken: true,
          ),
        ],
        reducedMotion: false,
      ),
      code(tokenProgressForbidden),
    );
    expect(
      () => auditor.audit(
        const [
          ChromeSurface(
            id: 'agent-toast',
            role: ChromeRole.command,
            zone: 'sessionSidebar',
            minWidth: 48,
            minHeight: 48,
            stealsFocusOnLateResult: true,
          ),
        ],
        reducedMotion: false,
      ),
      code(lateResultStoleFocus),
    );
  });

  test('the official command-workbench catalog audits clean at 200% with reduced motion', () {
    final chrome = officialCommandWorkbenchChrome(reducedMotion: true);
    expect(chrome.map((c) => c.zone).toSet(), isNot(contains('invented')));
    expect(
      chrome.any((c) => c.id == 'error' && c.errorCode != null && !c.colorOnly),
      isTrue,
    );
    expect(
      chrome.any((c) => c.role == ChromeRole.programMotion && c.programMotion),
      isTrue,
    );
    auditor.audit(chrome, reducedMotion: true, typeScale: maxTypeScale);
  });
}
