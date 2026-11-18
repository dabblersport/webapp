/// A user's show-up rate as the server computes it (KAN-994
/// `rpc_showup_rate`, KAN-1001). The app never derives it: [rate] is the
/// server's integer percent, null until [enough] is true (3 confirmed games
/// or meetups, CEO rule).
class ShowUpRate {
  const ShowUpRate({
    required this.confirmed,
    required this.attended,
    required this.noShows,
    required this.rate,
    required this.enough,
  });

  /// Maps the RPC's jsonb `{user_id, confirmed, attended, no_shows, rate,
  /// enough}`. A missing count reads as zero; [rate] is kept only when the
  /// server says [enough].
  factory ShowUpRate.fromJson(Map<String, dynamic> json) {
    final bool enough = json['enough'] == true;
    final Object? rate = json['rate'];
    return ShowUpRate(
      confirmed: _int(json['confirmed']),
      attended: _int(json['attended']),
      noShows: _int(json['no_shows']),
      rate: enough && rate is num ? rate.round() : null,
      enough: enough && rate is num,
    );
  }

  static int _int(Object? v) => v is num ? v.toInt() : 0;

  /// Settled events counted: attended plus confirmed no-shows.
  final int confirmed;
  final int attended;
  final int noShows;

  /// Percent attended, 0-100; null when not [enough].
  final int? rate;

  /// The server's threshold is met and [rate] is shown.
  final bool enough;
}
