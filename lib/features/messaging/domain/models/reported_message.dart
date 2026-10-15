/// The text of ONE reported message, as the audited Worker route
/// (`GET /v1/moderation/reports/{reportId}/message`, KAN-513) returns it to an
/// admin. It carries the text and nothing else of the message.
///
/// The text is held in memory for the lifetime of the panel that shows it. It
/// is never written to disk, logs, trackers or the clipboard, and
/// [toString] and equality deliberately leave it out so it cannot reach a
/// logger or an error report through string interpolation.
class ReportedMessage {
  const ReportedMessage({required this.reportId, required this.text});

  final String reportId;
  final String text;

  @override
  String toString() => 'ReportedMessage($reportId)';

  @override
  bool operator ==(Object other) =>
      other is ReportedMessage && other.reportId == reportId;

  @override
  int get hashCode => reportId.hashCode;
}
