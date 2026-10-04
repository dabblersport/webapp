import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:dabbler/core/utils/avatar_url_resolver.dart';
import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// The sections of Game details (D01), each one a composition of design-system
/// parts drawn from `Details.dc.html:79-174`. The screen
/// ([GameDetailScreen]) wires the controller; nothing here owns state.

/// `ds:<seed>` references and storage paths resolve the way the profile screen
/// resolves them, so the picture always matches.
String _seedFor(String? avatarUrl, String name) =>
    extractDsAvatarSeed(avatarUrl) ?? name;

String? _photoFor(String? avatarUrl) => resolveAvatarUrl(avatarUrl);

void _openProfile(BuildContext context, String userId, String profileId) =>
    context.push('${RoutePaths.userProfile}/$userId?profileId=$profileId');

/// What the entry costs, in words: `Free` or the cost-cover rule.
String gameEntryLabel(GameView game) => game.isFree
    ? 'Free'
    : _capitalize(game.costCover.replaceAll('_', ' '));

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// `1h 30m` for a length in minutes.
String _duration(int m) {
  if (m <= 0) return '—';
  if (m < 60) return '${m}m';
  final h = m ~/ 60;
  final r = m % 60;
  return r == 0 ? '${h}h' : '${h}h ${r}m';
}

/// Who is in, the headline count and the fill bar (`:79-91`).
Widget gameHeadcount(GameViewState state) {
  final game = state.game!;
  final shown = state.roster.take(5).toList();
  final extra = game.rosterCount - shown.length;
  return DabblerHeadcount(
    avatars: shown.isEmpty && extra <= 0
        ? null
        : DabblerAvatarGroup(
            people: [
              for (final p in shown) _seedFor(p.avatarUrl, p.displayName),
            ],
            imageUrls: [for (final p in shown) _photoFor(p.avatarUrl)],
            overflow: extra > 0 ? extra : 0,
          ),
    headline: '${game.rosterCount} of ${game.capacity} players in',
    caption: game.isFull
        ? 'Full'
        : '${game.spotsLeft} ${game.spotsLeft == 1 ? 'spot' : 'spots'} left',
    progress: game.capacity > 0 ? game.rosterCount / game.capacity : 0,
    critical: game.isFull,
  );
}

/// The four fact tiles (`:93-110`): when, how long, what it costs, the level.
Widget gameFactTiles(BuildContext context, GameView game) {
  final l = AppLocalizations.of(context);
  final tier = gamesSkillTierFor(game.minSkill, game.maxSkill);
  final mins = game.endAt.difference(game.startAt).inMinutes;
  final hasSkill = game.minSkill != null && game.maxSkill != null;
  Widget glyph(String name) =>
      DabblerIcon(name, size: DabblerSizing.iconSm);
  return DabblerStatGrid(
    rowExtent: DabblerStatGrid.detailsRowHeight,
    children: [
      DabblerStatTile(
        size: DabblerStatTileSize.detail,
        tone: DabblerStatTileTone.amber,
        icon: glyph('clock'),
        value: DateFormat('h:mm a').format(game.startAt),
        label: DateFormat('EEEE, d MMM').format(game.startAt),
        fitValue: true,
      ),
      DabblerStatTile(
        size: DabblerStatTileSize.detail,
        tone: DabblerStatTileTone.info,
        icon: glyph('timer'),
        value: _duration(mins),
        label: 'Until ${DateFormat('h:mm a').format(game.endAt)}',
        fitValue: true,
      ),
      DabblerStatTile(
        size: DabblerStatTileSize.detail,
        tone: DabblerStatTileTone.ink,
        icon: glyph('ticket-2'),
        value: gameEntryLabel(game),
        label: game.isFree ? 'Entry · No fees' : 'Entry',
        span: hasSkill ? 3 : 6,
        fitValue: true,
      ),
      if (hasSkill)
        DabblerStatTile(
          size: DabblerStatTileSize.detail,
          tone: DabblerStatTileTone.accent,
          icon: glyph('cup'),
          value: tier == null
              ? '${game.minSkill}–${game.maxSkill}'
              : gamesSkillTierLabel(l, tier),
          label: 'Skill level',
          fitValue: true,
        ),
    ],
  );
}

/// The host card (`:101-114`): avatar, "Hosted by", name — opens the profile.
Widget gameHostCard(BuildContext context, GameView game) {
  final name = game.creatorDisplayName ?? game.creatorUsername ?? 'Creator';
  final creatorProfileId = game.creatorProfileId;
  return DabblerListGroup(
    tone: DabblerListGroupTone.info,
    children: [
      DabblerListRow(
        leading: DabblerAvatar(
          seed: _seedFor(game.creatorAvatarUrl, name),
          imageUrl: _photoFor(game.creatorAvatarUrl),
          size: DabblerAvatarSize.md,
        ),
        overline: 'Hosted by',
        title: name,
        // The view exposes only creator_profile_id (KAN-87): pass it in both
        // the path slot and the profileId query param so downstream consumers
        // that check profileId first resolve correctly.
        onTap: creatorProfileId == null
            ? null
            : () => _openProfile(context, creatorProfileId, creatorProfileId),
      ),
    ],
  );
}

/// One squad member (`:122-133`).
Widget _playerRow(
  BuildContext context, {
  required String name,
  required String? avatarUrl,
  required String userId,
  required String profileId,
  required bool isHost,
  required bool isMe,
  String? tag,
  String? note,
  VoidCallback? onRemove,
}) {
  return DabblerListRow(
    leading: DabblerAvatar(
      seed: _seedFor(avatarUrl, name),
      imageUrl: _photoFor(avatarUrl),
      size: DabblerAvatarSize.sm,
    ),
    title: name,
    subtitle: note ?? (isHost ? 'Host' : null),
    trailing: (isMe || tag != null || isHost || onRemove != null)
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMe)
                DabblerBadge(
                  label: 'You',
                  status: DabblerColors.of(context).success,
                ),
              if (isMe && (isHost || tag != null))
                const DabblerGap.h(DabblerSpacing.space2),
              if (isHost) const DabblerBadge(label: 'Host'),
              if (!isHost && tag != null)
                DabblerBadge(label: tag, tone: DabblerBadgeTone.withIcon),
              if (onRemove != null) ...[
                const DabblerGap.h(DabblerSpacing.space3),
                DabblerButton.icon(
                  icon: 'trash',
                  semanticLabel: 'Remove $name from game',
                  tone: DabblerButtonTone.neutral,
                  size: DabblerButtonSize.small,
                  onPressed: onRemove,
                ),
              ],
            ],
          )
        : null,
    onTap: () => _openProfile(context, userId, profileId),
  );
}

/// The squad (`:116-148`): the players, and the open spots after them. For the
/// host, the pending join requests come first.
List<Widget> gameSquadSections(
  BuildContext context, {
  required GameViewState state,
  required GameViewController ctrl,
  required Key sectionKey,
  required Future<void> Function(GameRosterEntry) onRemove,
}) {
  final roster = state.roster;
  final waitlist = state.waitlist;
  final game = state.game!;
  // Pending join requests are host-managed; RLS only returns the full list to
  // the host, but gate on isHost anyway so a requester viewing their own row
  // never sees approve / deny controls.
  final requests = ctrl.isHost
      ? state.pendingRequests
      : const <GameJoinRequestEntry>[];
  // The creator can drop players from upcoming games (never themselves).
  final canManagePlayers =
      ctrl.isHost && !game.isCancelled && game.endAt.isAfter(DateTime.now());

  return [
    if (requests.isNotEmpty)
      DabblerSection(
        style: DabblerSectionStyle.label,
        title:
            '${requests.length} join ${requests.length == 1 ? 'request' : 'requests'}',
        children: [
          DabblerListGroup(
            children: [
              for (final r in requests)
                DabblerListRow(
                  leading: DabblerAvatar(
                    seed: _seedFor(r.avatarUrl, r.displayName),
                    imageUrl: _photoFor(r.avatarUrl),
                    size: DabblerAvatarSize.sm,
                  ),
                  title: r.displayName,
                  subtitle: 'Wants to join',
                  // Avatar + name open the requester's profile so the host
                  // can vet them before deciding.
                  onTap: () => _openProfile(context, r.userId, r.profileId),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DabblerButton.icon(
                        icon: 'tick-circle',
                        semanticLabel: 'Approve ${r.displayName}',
                        tone: DabblerButtonTone.primary,
                        size: DabblerButtonSize.small,
                        disabled: state.isActing,
                        onPressed: state.isActing
                            ? null
                            : () => ctrl.decideJoinRequest(r.id, true),
                      ),
                      const DabblerGap.h(DabblerSpacing.space3),
                      DabblerButton.icon(
                        icon: 'close-circle',
                        semanticLabel: 'Deny ${r.displayName}',
                        tone: DabblerButtonTone.neutral,
                        size: DabblerButtonSize.small,
                        disabled: state.isActing,
                        onPressed: state.isActing
                            ? null
                            : () => ctrl.decideJoinRequest(r.id, false),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    KeyedSubtree(
      key: sectionKey,
      child: DabblerSection(
        style: DabblerSectionStyle.label,
        title: 'Squad',
        children: [
          if (roster.isEmpty && waitlist.isEmpty && game.spotsLeft == 0)
            const DabblerEmptyState(
              title: 'No players yet — be the first to join!',
            )
          else
            DabblerListGroup(
              children: [
                for (final p in roster)
                  _playerRow(
                    context,
                    name: p.displayName,
                    avatarUrl: p.avatarUrl,
                    userId: p.userId,
                    profileId: p.profileId,
                    isHost: p.isHost,
                    isMe: p.userId == ctrl.currentUserId,
                    onRemove: canManagePlayers && !p.isHost && !state.isActing
                        ? () => onRemove(p)
                        : null,
                  ),
                if (game.spotsLeft > 0)
                  DabblerListRow(
                    leading: const DabblerIconTile.named(
                      'add',
                      tone: DabblerIconTileTone.amber,
                      size: DabblerSizing.iconXl,
                    ),
                    title:
                        '${game.spotsLeft} open ${game.spotsLeft == 1 ? 'spot' : 'spots'}',
                  ),
              ],
            ),
        ],
      ),
    ),
    if (waitlist.isNotEmpty)
      DabblerSection(
        style: DabblerSectionStyle.label,
        title: 'Waitlist',
        children: [
          DabblerListGroup(
            children: [
              for (final w in waitlist)
                _playerRow(
                  context,
                  name: w.displayName,
                  avatarUrl: w.avatarUrl,
                  userId: w.userId,
                  profileId: w.profileId,
                  isHost: false,
                  isMe: w.userId == ctrl.currentUserId,
                  tag: '#${w.position}',
                  note: 'Waitlisted',
                ),
            ],
          ),
        ],
      ),
  ];
}

/// Where it is played (`:150-168`): the space and the venue, and the area.
Widget? gameWhereSection(GameView game) {
  final title = [
    game.venueSpaceName,
    game.venueName,
  ].whereType<String>().join(', ');
  if (title.isEmpty && game.areaName == null) return null;
  return DabblerSection(
    style: DabblerSectionStyle.label,
    title: 'Where',
    children: [
      DabblerListGroup(
        children: [
          DabblerListRow(
            title: title.isEmpty ? game.areaName! : title,
            subtitle: title.isEmpty ? null : game.areaName,
          ),
        ],
      ),
    ],
  );
}
