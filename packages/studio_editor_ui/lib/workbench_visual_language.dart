import 'dart:math' as math;

import 'package:studio_contracts/studio_contracts.dart';

/// 12D workbench visual-language constraints. This is an audit contract,
/// not a UI token or component API, not I-055, and not finished product chrome.
const minTouchLogicalPx = 48.0;
const maxTypeScale = 2.0;
const minTextContrast = 4.5;
const largeTextContrast = 3.0;
const largeTextPx = 18.0;

const touchTargetTooSmall = 'TOUCH_TARGET_TOO_SMALL';
const contrastTooLow = 'CONTRAST_TOO_LOW';
const colorOnlyError = 'COLOR_ONLY_ERROR';
const typeScaleBlocksActions = 'TYPE_SCALE_BLOCKS_ACTIONS';
const flickerPreviewNotStopped = 'FLICKER_PREVIEW_NOT_STOPPED';
const autoplayNotStopped = 'AUTOPLAY_NOT_STOPPED';
const tokenProgressForbidden = 'TOKEN_PROGRESS_FORBIDDEN';
const lateResultStoleFocus = 'LATE_RESULT_STOLE_FOCUS';
const programMotionMustRemain = 'PROGRAM_MOTION_MUST_REMAIN';

/// Four collaboration zones from §1, plus the persistent session sidebar.
const workbenchZones = <String>[
  'sessionSidebar',
  'briefScript',
  'storyboardCandidates',
  'timelineCanvas',
  'exportArchive',
];

enum ChromeRole {
  command,
  confirm,
  cancel,
  field,
  error,
  preview,
  progress,
  programMotion,
}

/// Declared workbench chrome used by the auditor. Values are obligations
/// or measured presentation facts, not a widget tree and not a token API.
final class ChromeSurface {
  const ChromeSurface({
    required this.id,
    required this.role,
    required this.zone,
    this.messageKey,
    this.errorCode,
    this.minWidth = 0,
    this.minHeight = 0,
    this.foreground,
    this.background,
    this.colorOnly = false,
    this.autoplay = false,
    this.flickerPreview = false,
    this.announcePerToken = false,
    this.stealsFocusOnLateResult = false,
    this.programMotion = false,
    this.labelWidthAt100 = 0,
  });

  final String id, zone;
  final ChromeRole role;
  final String? messageKey, errorCode;
  final double minWidth, minHeight, labelWidthAt100;
  final int? foreground, background;
  final bool colorOnly,
      autoplay,
      flickerPreview,
      announcePerToken,
      stealsFocusOnLateResult,
      programMotion;
}

final class WorkbenchVisualAuditor {
  const WorkbenchVisualAuditor();

  /// WCAG 2 relative-luminance contrast of two 0xRRGGBB colors.
  static double contrastRatio(int foreground, int background) {
    final a = _luminance(foreground);
    final b = _luminance(background);
    final hi = math.max(a, b);
    final lo = math.min(a, b);
    return (hi + 0.05) / (lo + 0.05);
  }

  static double _luminance(int rgb) {
    double lin(int channel) {
      final s = channel / 255.0;
      return s <= 0.04045
          ? s / 12.92
          : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = lin((rgb >> 16) & 0xff);
    final g = lin((rgb >> 8) & 0xff);
    final b = lin(rgb & 0xff);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Confirm and Cancel remain independently hittable at [typeScale].
  static bool confirmCancelFit({
    required double surfaceWidth,
    required double confirmLabelWidthAt100,
    required double cancelLabelWidthAt100,
    double typeScale = 1,
    double gap = 8,
  }) {
    if (typeScale > maxTypeScale || typeScale <= 0) {
      throw const StudioException('INVALID_ID', 'typeScale');
    }
    double box(double label) =>
        math.max(minTouchLogicalPx, label * typeScale);
    return box(confirmLabelWidthAt100) + box(cancelLabelWidthAt100) + gap <=
        surfaceWidth;
  }

  void audit(
    List<ChromeSurface> chrome, {
    required bool reducedMotion,
    double typeScale = 1,
    double actionSurfaceWidth = 320,
  }) {
    if (chrome.any((c) => !workbenchZones.contains(c.zone))) {
      throw const StudioException('INVALID_ID', 'zone');
    }
    for (final surface in chrome) {
      if (surface.role == ChromeRole.command ||
          surface.role == ChromeRole.confirm ||
          surface.role == ChromeRole.cancel) {
        if (surface.minWidth < minTouchLogicalPx ||
            surface.minHeight < minTouchLogicalPx) {
          throw StudioException(touchTargetTooSmall, surface.id);
        }
      }
      if (surface.foreground != null && surface.background != null) {
        final ratio = contrastRatio(surface.foreground!, surface.background!);
        final large = surface.labelWidthAt100 >= largeTextPx * 4;
        final floor = large ? largeTextContrast : minTextContrast;
        if (ratio + 1e-9 < floor) {
          throw StudioException(contrastTooLow, surface.id);
        }
      }
      if (surface.role == ChromeRole.error) {
        final hasText =
            (surface.messageKey != null && surface.messageKey!.isNotEmpty) ||
            (surface.errorCode != null && surface.errorCode!.isNotEmpty);
        if (surface.colorOnly || !hasText) {
          throw StudioException(colorOnlyError, surface.id);
        }
      }
      if (reducedMotion && surface.role == ChromeRole.preview) {
        if (surface.flickerPreview) {
          throw StudioException(flickerPreviewNotStopped, surface.id);
        }
        if (surface.autoplay) {
          throw StudioException(autoplayNotStopped, surface.id);
        }
      }
      if (surface.role == ChromeRole.progress && surface.announcePerToken) {
        throw StudioException(tokenProgressForbidden, surface.id);
      }
      if (surface.stealsFocusOnLateResult) {
        throw StudioException(lateResultStoleFocus, surface.id);
      }
      if (reducedMotion &&
          surface.role == ChromeRole.programMotion &&
          !surface.programMotion) {
        throw StudioException(programMotionMustRemain, surface.id);
      }
    }
    final confirm = chrome.where((c) => c.role == ChromeRole.confirm);
    final cancel = chrome.where((c) => c.role == ChromeRole.cancel);
    if (confirm.isNotEmpty && cancel.isNotEmpty) {
      if (!confirmCancelFit(
        surfaceWidth: actionSurfaceWidth,
        confirmLabelWidthAt100: confirm.first.labelWidthAt100,
        cancelLabelWidthAt100: cancel.first.labelWidthAt100,
        typeScale: typeScale,
      )) {
        throw const StudioException(typeScaleBlocksActions);
      }
    }
  }
}

/// Declared 12D obligations for the Linux command workbench. These are
/// required presentation facts, not a measurement of Material default
/// button sizes in FoundationApp, and not a claim that product UI is done.
List<ChromeSurface> officialCommandWorkbenchChrome({
  required bool reducedMotion,
}) {
  const ink = 0xFF1A1A1A;
  const paper = 0xFFF5F5F5;
  return [
    const ChromeSurface(
      id: 'import-video',
      role: ChromeRole.command,
      zone: 'timelineCanvas',
      messageKey: 'workbench.importVideo',
      minWidth: minTouchLogicalPx,
      minHeight: minTouchLogicalPx,
      foreground: ink,
      background: paper,
    ),
    const ChromeSurface(
      id: 'save-managed',
      role: ChromeRole.command,
      zone: 'exportArchive',
      messageKey: 'workbench.saveManaged',
      minWidth: minTouchLogicalPx,
      minHeight: minTouchLogicalPx,
      foreground: ink,
      background: paper,
    ),
    const ChromeSurface(
      id: 'error',
      role: ChromeRole.error,
      zone: 'timelineCanvas',
      errorCode: 'STUDIO_EXCEPTION_CODE',
      messageKey: 'workbench.error',
      foreground: 0xFF8B0000,
      background: paper,
      colorOnly: false,
    ),
    const ChromeSurface(
      id: 'confirm',
      role: ChromeRole.confirm,
      zone: 'exportArchive',
      messageKey: 'workbench.confirm',
      minWidth: minTouchLogicalPx,
      minHeight: minTouchLogicalPx,
      foreground: ink,
      background: paper,
      labelWidthAt100: 72,
    ),
    const ChromeSurface(
      id: 'cancel',
      role: ChromeRole.cancel,
      zone: 'exportArchive',
      messageKey: 'workbench.cancel',
      minWidth: minTouchLogicalPx,
      minHeight: minTouchLogicalPx,
      foreground: ink,
      background: paper,
      labelWidthAt100: 56,
    ),
    ChromeSurface(
      id: 'timeline-preview',
      role: ChromeRole.preview,
      zone: 'timelineCanvas',
      messageKey: 'workbench.timelinePreview',
      autoplay: !reducedMotion,
      flickerPreview: !reducedMotion,
    ),
    const ChromeSurface(
      id: 'job-progress',
      role: ChromeRole.progress,
      zone: 'sessionSidebar',
      messageKey: 'workbench.progressPhase',
      announcePerToken: false,
    ),
    const ChromeSurface(
      id: 'program-opacity-keyframes',
      role: ChromeRole.programMotion,
      zone: 'timelineCanvas',
      messageKey: 'workbench.programMotion',
      programMotion: true,
    ),
  ];
}
