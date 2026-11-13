/// Domain durations used by the profile data export. These are data (look-back
/// windows), not design: the only place a `Duration` literal is allowed is this
/// directory.
library;

/// Timing constants for the profile data-export collectors.
abstract final class ExportTiming {
  const ExportTiming._();

  /// 180 days: how far back the login-history export reaches.
  static const Duration loginHistoryExportWindow = Duration(days: 180);

  /// 730 days: how far back the consent and audit-log export reaches.
  static const Duration consentAuditExportWindow = Duration(days: 730);
}
