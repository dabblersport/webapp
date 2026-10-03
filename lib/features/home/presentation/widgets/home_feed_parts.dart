import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Small building blocks shared by the Home feed rows. Everything visible is a
/// design-system part; nothing here declares a colour or a text style of its
/// own.

/// A [DabblerType] step resolved for the ambient direction, in [color].
TextStyle homeType(
  BuildContext context,
  DabblerTypeStyle step,
  Color color, {
  FontWeight? weight,
}) => step
    .resolveForDirection(Directionality.of(context))
    .copyWith(color: color, fontWeight: weight);

/// `3s`, `5m`, `2h`, `4d`, then `Oct 3` — the format the feed has always used.
String homeRelativeTime(DateTime createdAt) {
  final diff = DateTime.now().difference(createdAt);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return DateFormat.MMMd().format(createdAt);
}

/// `1.2K` / `3.4M` counts.
String homeCompactCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}
