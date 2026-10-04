import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/features/profile/utils/persona_label.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// The Profiles design's identity block: the brand-tint band holding the
/// avatar, display-face name, handle, persona and city badges, bio and the
/// counters row. It owns no data and no navigation.
class OwnProfileHeader extends StatelessWidget {
  const OwnProfileHeader({
    super.key,
    required this.profile,
    required this.posts,
    required this.following,
    required this.followers,
    this.onFollowing,
    this.onFollowers,
    this.onPosts,
    this.location,
    this.actions,
  });

  final UserProfile? profile;
  final int posts;
  final int following;
  final int followers;
  final VoidCallback? onFollowing;
  final VoidCallback? onFollowers;
  final VoidCallback? onPosts;

  /// Overrides the city badge's label (city, country).
  final String? location;

  /// The action row under the counters (Follow / Message on another user's
  /// profile); null on the own profile, which the design draws without one.
  final Widget? actions;

  static String personaIcon(String? persona) =>
      switch (persona?.toLowerCase()) {
        'player' => 'activity',
        'organiser' => 'calendar',
        'host' => 'location',
        _ => 'people',
      };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final UserProfile? p = profile;
    final String name = p?.getDisplayName() ?? '';
    final String? username = p?.username;
    final String? persona = p?.personaType;
    final String? city = location ?? p?.city;
    final String? bio = p?.bio;

    return DabblerSurface.brandTintBleed(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space6,
          DabblerSpacing.space6,
          DabblerSpacing.space6,
          DabblerSpacing.space7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                DabblerAvatar(
                  seed: name.isNotEmpty ? name : 'User',
                  imageUrl: p?.avatarUrl,
                  size: DabblerAvatarSize.lg,
                ),
                const DabblerGap.h(DabblerSpacing.space5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      DabblerText(
                        name.isNotEmpty
                            ? name
                            : l10n.profile_complete_your_profile,
                        style: DabblerType.title2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (username != null && username.isNotEmpty)
                        DabblerText(
                          '\u200E@$username',
                          style: DabblerType.subheadline,
                          tone: DabblerTextTone.secondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const DabblerGap.v(DabblerSpacing.space5),
            Wrap(
              spacing: DabblerSpacing.space2,
              runSpacing: DabblerSpacing.space2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (persona != null && persona.isNotEmpty)
                  DabblerBadge(
                    label: personaLabel(context, persona),
                    icon: DabblerIcon(
                      personaIcon(persona),
                      weight: DabblerIconWeight.bold,
                      size: DabblerSizing.iconXs,
                    ),
                  ),
                if (city != null && city.isNotEmpty)
                  DabblerChip(
                    label: city,
                    leadingIcon: const DabblerIcon(
                      'location',
                      size: DabblerSizing.iconSm,
                    ),
                  ),
              ],
            ),
            const DabblerGap.v(DabblerSpacing.space5),
            DabblerText(
              bio != null && bio.isNotEmpty
                  ? bio
                  : l10n.profile_bio_placeholder,
              style: DabblerType.subheadline,
              tone: DabblerTextTone.secondary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const DabblerGap.v(DabblerSpacing.space5),
            Wrap(
              spacing: DabblerSpacing.space6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                DabblerCounterLink(
                  value: '$followers',
                  label: l10n.profile_follower_count(followers),
                  onTap: onFollowers,
                ),
                DabblerCounterLink(
                  value: '$following',
                  label: l10n.profile_following_label,
                  onTap: onFollowing,
                ),
                DabblerCounterLink(
                  value: '$posts',
                  label: l10n.profile_post_count(posts),
                  onTap: onPosts,
                ),
              ],
            ),
            if (actions != null) ...<Widget>[
              const DabblerGap.v(DabblerSpacing.space5),
              actions!,
            ],
          ],
        ),
      ),
    );
  }
}
