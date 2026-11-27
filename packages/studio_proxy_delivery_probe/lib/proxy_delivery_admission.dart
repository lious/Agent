import 'package:studio_contracts/studio_contracts.dart';

final class ProxyDeliveryRequest {
  const ProxyDeliveryRequest({
    required this.originalPresent,
    required this.proxyPresent,
    required this.exportRequested,
    this.explicitProxyDelivery = false,
    this.degradedMarked = false,
  });

  final bool originalPresent,
      proxyPresent,
      exportRequested,
      explicitProxyDelivery,
      degradedMarked;
}

final class ProxyDeliveryReceipt {
  const ProxyDeliveryReceipt({
    required this.canEdit,
    required this.exported,
    required this.degraded,
  });

  final bool canEdit, exported, degraded;
}

/// DEV-PURE I-004 / s4 admission: a proxy is enough to edit, but a default
/// export without the original is refused. Only an explicit "deliver with
/// proxy" confirmation produces a marked degraded export record. This is
/// not a muxer, not packMode=proxyOnly, and not a re-qualification of
/// Increment 2.72 ExportService or I-013 archive packMode.
final class ProxyDeliveryAdmission {
  bool i024Requalified = false;
  bool i013Requalified = false;
  bool filesTestRequalified = false;
  bool muxerInvented = false;
  bool v003Claimed = false;
  bool packModeProxyOnlyInvented = false;
  bool paidApiCalled = false;

  ProxyDeliveryReceipt admit(ProxyDeliveryRequest request) {
    final canEdit = request.originalPresent || request.proxyPresent;
    if (!request.exportRequested) {
      return ProxyDeliveryReceipt(
        canEdit: canEdit,
        exported: false,
        degraded: false,
      );
    }
    if (request.originalPresent) {
      return ProxyDeliveryReceipt(
        canEdit: canEdit,
        exported: true,
        degraded: false,
      );
    }
    if (!request.explicitProxyDelivery) {
      throw const StudioException('MISSING_ORIGINAL_EXPORT', 'export');
    }
    if (!request.proxyPresent) {
      throw const StudioException('PROXY_UNAVAILABLE', 'export');
    }
    if (!request.degradedMarked) {
      throw const StudioException('DEGRADED_EXPORT_UNMARKED', 'export');
    }
    return ProxyDeliveryReceipt(
      canEdit: canEdit,
      exported: true,
      degraded: true,
    );
  }
}
