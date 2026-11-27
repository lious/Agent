import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';

import 'context_codes.dart';
import 'grants.dart';
import 'hashing.dart';
import 'locators.dart';

enum MediaKind { text, document, image, video, audio, unsupported }

enum AttachmentState {
  staged,
  probing,
  ready,
  unsupported,
  denied,
  failed,
  revoked,
  purged,
}

final class IngestLimits {
  const IngestLimits({
    this.maxBytes = 1024 * 1024,
    this.maxPages = 500,
    this.maxChars = 200000,
    this.charsPerPage = 1024,
  });

  final int maxBytes, maxPages, maxChars, charsPerPage;
}

final class Attachment {
  Attachment({
    required this.id,
    required this.mediaKind,
    required this.blobHash,
    required this.sizeBytes,
    required this.displayName,
    required this.state,
    required this.sourceVersion,
    this.mime,
    this.body,
    this.pages = const [],
    this.errorCode,
  });

  final String id, blobHash, displayName;
  final MediaKind mediaKind;
  final int sizeBytes, sourceVersion;
  final String? mime, body, errorCode;
  AttachmentState state;
  final List<EvidenceLocator> pages;
}

/// Fake network port. Official tests assert it is not invoked without
/// an uploadSubset grant and an explicit plan.
final class FakeUploadClient {
  int networkRequestCount = 0;

  void post(List<int> bytes) {
    networkRequestCount++;
  }
}

final class UploadPlan {
  UploadPlan({required this.id, required this.attachmentId}) {
    requireId(id);
    requireId(attachmentId);
  }

  final String id, attachmentId;
}

/// Stages local attachments, paginates text, and refuses over-limit
/// inputs instead of silently truncating them. Upload is a separate
/// consent path and is not implied by analyze permission.
final class AttachmentIngestor {
  AttachmentIngestor({
    this.limits = const IngestLimits(),
    FakeUploadClient? uploader,
  }) : uploader = uploader ?? FakeUploadClient();

  final IngestLimits limits;
  final FakeUploadClient uploader;
  final Map<String, Attachment> attachments = {};
  int get networkRequestCount => uploader.networkRequestCount;

  Attachment stageText({
    required String id,
    required String text,
    required String displayName,
    int sourceVersion = 1,
  }) {
    requireId(id);
    final units = utf8.encode(text);
    if (units.length > limits.maxBytes || text.runes.length > limits.maxChars) {
      throw StudioException(overLimit, id);
    }
    final pages = _paginate(id, sourceVersion, units);
    if (pages.length > limits.maxPages) {
      throw StudioException(overLimit, 'pages');
    }
    final attachment = Attachment(
      id: id,
      mediaKind: MediaKind.text,
      blobHash: fingerprint(units),
      sizeBytes: units.length,
      displayName: displayName,
      state: AttachmentState.ready,
      sourceVersion: sourceVersion,
      mime: 'text/plain',
      body: text,
      pages: pages,
    );
    attachments[id] = attachment;
    return attachment;
  }

  Attachment stageBytes({
    required String id,
    required MediaKind kind,
    required List<int> bytes,
    required String displayName,
    String? mime,
    int sourceVersion = 1,
  }) {
    requireId(id);
    if (kind == MediaKind.unsupported) {
      final denied = Attachment(
        id: id,
        mediaKind: kind,
        blobHash: fingerprint(bytes),
        sizeBytes: bytes.length,
        displayName: displayName,
        state: AttachmentState.unsupported,
        sourceVersion: sourceVersion,
        mime: mime,
        errorCode: formatUnsupported,
      );
      attachments[id] = denied;
      return denied;
    }
    if (bytes.length > limits.maxBytes) {
      throw StudioException(overLimit, id);
    }
    if (kind == MediaKind.text) {
      return stageText(
        id: id,
        text: utf8.decode(bytes),
        displayName: displayName,
        sourceVersion: sourceVersion,
      );
    }
    final attachment = Attachment(
      id: id,
      mediaKind: kind,
      blobHash: fingerprint(bytes),
      sizeBytes: bytes.length,
      displayName: displayName,
      state: AttachmentState.ready,
      sourceVersion: sourceVersion,
      mime: mime,
    );
    attachments[id] = attachment;
    return attachment;
  }

  /// Upload requires an active uploadSubset grant and an explicit plan.
  /// A license warning or an analyze-only grant cannot exempt this.
  void upload({
    required String attachmentId,
    required SourceUseGrant grant,
    required UploadPlan plan,
    required DateTime now,
    bool licenseWarning = false,
  }) {
    final attachment = attachments[attachmentId];
    if (attachment == null) {
      throw StudioException('INVALID_ID', attachmentId);
    }
    if (plan.attachmentId != attachmentId) {
      throw StudioException('INVALID_ID', 'plan');
    }
    if (licenseWarning) {
      // A warning never bypasses missing upload consent.
      if (!grant.permitted.contains('uploadSubset') || grant.revoked) {
        throw const StudioException(warningDoesNotExempt, 'upload');
      }
    }
    grant.requireActive('uploadSubset', now: now);
    if (grant.sourceId != attachmentId) {
      throw StudioException(grantRequired, 'source');
    }
    uploader.post(utf8.encode(attachment.body ?? attachment.blobHash));
  }

  List<EvidenceLocator> _paginate(String sourceId, int version, List<int> units) {
    final pages = <EvidenceLocator>[];
    final per = limits.charsPerPage;
    var page = 1;
    var offset = 0;
    while (offset < units.length) {
      final end = (offset + per) < units.length ? offset + per : units.length;
      pages.add(
        EvidenceLocator(
          kind: LocatorKind.page,
          sourceId: sourceId,
          version: version,
          page: page,
          startByte: offset,
          endByte: end,
        ),
      );
      page++;
      offset = end;
    }
    return pages;
  }
}
