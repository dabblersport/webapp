/// Why a message is reported (`components.schemas.ReportRequest.category`).
/// Proposed categories, to be confirmed with the moderation owner.
enum ReportCategory {
  spam('spam'),
  harassment('harassment'),
  inappropriate('inappropriate'),
  other('other');

  const ReportCategory(this.wireName);
  final String wireName;
}
