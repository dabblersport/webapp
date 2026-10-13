/// Why a message is reported (`components.schemas.ReportRequest.reason`).
/// These are the ten values of the existing `report_reason` enum of
/// `moderation_reports`; none is added here.
enum ReportCategory {
  spam('spam'),
  abuse('abuse'),
  hate('hate'),
  harassment('harassment'),
  nudity('nudity'),
  illegal('illegal'),
  danger('danger'),
  scam('scam'),
  impersonation('impersonation'),
  other('other');

  const ReportCategory(this.wireName);
  final String wireName;
}
