/// Lightweight model for a meetup returned by the unified search RPC.
class MeetupSearchResult {
  final String id;
  final String title;
  final String? description;
  final DateTime? startAt;

  const MeetupSearchResult({
    required this.id,
    required this.title,
    this.description,
    this.startAt,
  });

  factory MeetupSearchResult.fromJson(Map<String, dynamic> json) {
    return MeetupSearchResult(
      id: (json['entity_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['subtitle'] ?? json['description'])?.toString(),
      startAt: json['start_at'] != null
          ? DateTime.tryParse(json['start_at'].toString())
          : null,
    );
  }
}
