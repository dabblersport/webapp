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

/// The user's real photo when there is one, the design-system seed avatar
/// otherwise.
///
/// DS GAP: [DabblerAvatar] has no image-URL form. Until it gains one, a photo
/// URL is drawn here (clipped to the avatar's own circle and size) so people do
/// not lose their pictures; the seed avatar is used only when there is no photo.
class HomeAvatar extends StatelessWidget {
  const HomeAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = DabblerAvatarSize.sm,
  });

  final String name;
  final String? imageUrl;
  final DabblerAvatarSize size;

  @override
  Widget build(BuildContext context) {
    final String? url = imageUrl;
    final Widget seed = DabblerAvatar(seed: name, size: size);
    if (url == null || url.isEmpty) return seed;
    final double dimension = size.diameter;
    return SizedBox(
      width: dimension,
      height: dimension,
      child: ClipOval(
        child: Image.network(
          url,
          width: dimension,
          height: dimension,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => seed,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : seed,
        ),
      ),
    );
  }
}

/// An icon and a count, as the action bar shows them.
class HomeActionItem extends StatelessWidget {
  const HomeActionItem({
    super.key,
    required this.icon,
    required this.count,
    required this.color,
    this.weight = DabblerIconWeight.linear,
    this.semanticLabel,
  });

  final String icon;
  final int count;
  final Color color;
  final DabblerIconWeight weight;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DabblerIcon(
          icon,
          weight: weight,
          size: 20,
          color: color,
          semanticLabel: semanticLabel,
        ),
        if (count > 0) ...[
          const SizedBox(width: DabblerSpacing.space2),
          Text(
            homeCompactCount(count),
            style: homeType(context, DabblerType.caption1, color),
          ),
        ],
      ],
    );
  }
}

/// A tappable region with the design system's press feedback and a 45px minimum
/// target, for the action-bar icons.
class HomeTap extends StatelessWidget {
  const HomeTap({super.key, required this.onTap, required this.child, this.label});

  final VoidCallback? onTap;
  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Align(alignment: AlignmentDirectional.centerStart, widthFactor: 1, child: child),
        ),
      ),
    );
  }
}
