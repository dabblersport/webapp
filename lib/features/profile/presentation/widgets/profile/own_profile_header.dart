import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/features/profile/utils/persona_label.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// What a counter knows: a figure, nothing yet, or a failed read. Loading and
/// failed both draw a dash, never a zero (KAN-688); only failed offers retry.
enum ProfileCounterState { data, loading, failed }

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
    this.sportsCount,
    this.sportsLabel,
    this.location,
    this.actions,
    this.showPersonaBadge = true,
    this.postsFailed = false,
    this.onRetryPosts,
    this.followersState = ProfileCounterState.data,
    this.followingState = ProfileCounterState.data,
    this.postsState = ProfileCounterState.data,
    this.onRetryCounts,
    this.onCopyLink,
    this.linkCopied = false,
  });

  final UserProfile? profile;
  final int posts;
  final int following;
  final int followers;
  final VoidCallback? onFollowing;
  final VoidCallback? onFollowers;
  final VoidCallback? onPosts;

  /// When set, the third counter counts sports (the frames' socialiser and
  /// seen-by-another-user rows) instead of posts, captioned [sportsLabel].
  final int? sportsCount;
  final String? sportsLabel;

  /// Overrides the city badge's label (city, country).
  final String? location;

  /// The action row under the counters (Follow / Message on another user's
  /// profile); null on the own profile, which the design draws without one.
  final Widget? actions;

  /// A Contributor shows no persona badge.
  final bool showPersonaBadge;

  /// The posts fetch failed: the counter reads as an error with a retry,
  /// never a zero.
  final bool postsFailed;
  final VoidCallback? onRetryPosts;

  /// The visitor's typed counters (KAN-688). The owner leaves them at
  /// [ProfileCounterState.data] and keeps its own [postsFailed] path.
  final ProfileCounterState followersState;
  final ProfileCounterState followingState;
  final ProfileCounterState postsState;

  /// Re-reads whichever counter failed.
  final VoidCallback? onRetryCounts;

  /// The copy-link pill beside the handle (`Profiles.dc.html` lines 91-98).
  /// Null hides it, as on the owner view.
  final VoidCallback? onCopyLink;

  /// The pill's confirmed state: tick and "Link copied" on the success tint.
  final bool linkCopied;

  static const ValueKey<String> copyLinkKey = ValueKey<String>(
    'profile-copy-link',
  );

  Widget _counter({
    required ProfileCounterState state,
    required String value,
    required String label,
    required String retryLabel,
    VoidCallback? onTap,
  }) => switch (state) {
    ProfileCounterState.data => DabblerCounterLink(
      value: value,
      label: label,
      onTap: onTap,
    ),
    ProfileCounterState.loading => DabblerCounterLink(
      value: '\u2014',
      label: label,
    ),
    ProfileCounterState.failed => DabblerCounterLink(
      value: '\u2014',
      label: retryLabel,
      onTap: onRetryCounts,
    ),
  };

  static String personaIcon(String? persona) =>
      switch (persona?.toLowerCase()) {
        'player' => 'activity',
        'organiser' => 'calendar',
        'host' => 'location',
        _ => 'people',
      };

  /// The persona badge's glyph in the identity block: the Profiles frames
  /// draw the organiser badge with `people`, where the switch sheet uses the
  /// calendar ([personaIcon]).
  static String badgeIcon(String? persona) =>
      persona?.toLowerCase() == 'organiser' ? 'people' : personaIcon(persona);

  /// The name steps down with its length, as the Profiles frame does: up to
  /// 14 characters 22/28, up to 20 characters 19/25, longer 17/22.
  static DabblerTypeStyle nameStyle(String name) => name.length <= 14
      ? DabblerType.title2
      : name.length <= 20
      ? DabblerType.displayNameMid
      : DabblerType.displayNameSmall;

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
        // The counters are 45 tall touch targets (the frame's are 21), so the
        // spacing around them gives up the 12 the target adds each side.
        padding: EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space6,
          DabblerSpacing.space6,
          DabblerSpacing.space6,
          actions == null ? DabblerSpacing.space3 : DabblerSpacing.space7,
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
                        style: nameStyle(name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (username != null && username.isNotEmpty)
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: DabblerText(
                                '\u200E@$username',
                                style: DabblerType.smallTight,
                                tone: DabblerTextTone.tertiary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (onCopyLink != null) ...<Widget>[
                              const DabblerGap.h(DabblerSpacing.space2),
                              _CopyLinkPill(
                                key: copyLinkKey,
                                copied: linkCopied,
                                onTap: onCopyLink!,
                              ),
                            ],
                          ],
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
                if (showPersonaBadge && persona != null && persona.isNotEmpty)
                  DabblerBadge(
                    label: personaLabel(context, persona),
                    comfortable: true,
                    icon: DabblerIcon(
                      badgeIcon(persona),
                      weight: DabblerIconWeight.bold,
                      size: DabblerSizing.iconXs,
                    ),
                  ),
                if (city != null && city.isNotEmpty)
                  DabblerBadge(
                    label: city,
                    outlined: true,
                    comfortable: true,
                    icon: const DabblerIcon(
                      'location',
                      size: DabblerSizing.iconXs,
                    ),
                  ),
              ],
            ),
            const DabblerGap.v(DabblerSpacing.space5),
            // The "Add a short bio" prompt is the owner's; a visitor
            // (the header carries [actions]) sees nothing for an empty bio.
            if ((bio != null && bio.isNotEmpty) || actions == null)
              DabblerText(
                bio != null && bio.isNotEmpty
                    ? bio
                    : l10n.profile_bio_placeholder,
                style: DabblerType.copy,
                tone: DabblerTextTone.secondary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            const DabblerGap.v(DabblerSpacing.space1),
            Wrap(
              spacing: DabblerSpacing.space6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                _counter(
                  state: followersState,
                  value: '$followers',
                  label: l10n.profile_follower_count(followers),
                  retryLabel: l10n.feed_retry,
                  onTap: onFollowers,
                ),
                _counter(
                  state: followingState,
                  value: '$following',
                  label: l10n.profile_following_label,
                  retryLabel: l10n.feed_retry,
                  onTap: onFollowing,
                ),
                if (sportsCount != null)
                  DabblerCounterLink(
                    value: '$sportsCount',
                    label: sportsLabel ?? l10n.profile_section_sports,
                  )
                else if (postsState != ProfileCounterState.data)
                  _counter(
                    state: postsState,
                    value: '$posts',
                    label: l10n.profile_post_count(posts),
                    retryLabel: l10n.feed_retry,
                  )
                else if (postsFailed)
                  DabblerCounterLink(
                    value: '\u2014',
                    label: l10n.feed_retry,
                    onTap: onRetryPosts,
                  )
                else
                  DabblerCounterLink(
                    value: '$posts',
                    label: l10n.profile_post_count(posts),
                    onTap: onPosts,
                  ),
              ],
            ),
            if (actions != null) ...<Widget>[
              const DabblerGap.v(DabblerSpacing.space1),
              actions!,
            ],
          ],
        ),
      ),
    );
  }
}

/// The 26-tall pill beside the handle: a link glyph on the card surface, and
/// after a copy a tick with "Link copied" on the success tint.
class _CopyLinkPill extends StatelessWidget {
  const _CopyLinkPill({super.key, required this.copied, required this.onTap});

  final bool copied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DabblerColors colors = DabblerColors.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color ink = copied ? colors.success.strong : colors.textSecondary;
    return Semantics(
      button: true,
      label: copied ? l10n.sfx_link_copied : l10n.post_detail_copy_link,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DabblerSurface(
          radius: DabblerRadius.pill,
          fill: copied ? colors.success.surface : colors.surfaceCard,
          borderColor: copied ? colors.success.surface : colors.borderDefault,
          padding: const EdgeInsets.symmetric(
            horizontal: DabblerSpacing.space3,
            vertical: DabblerSpacing.space1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DabblerIcon(
                copied ? 'tick-circle' : 'link',
                size: DabblerSizing.iconXs,
                color: ink,
              ),
              if (copied) ...<Widget>[
                const DabblerGap.h(DabblerSpacing.space1),
                DabblerText(
                  l10n.sfx_link_copied,
                  style: DabblerType.tagTight,
                  tone: DabblerTextTone.success,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
