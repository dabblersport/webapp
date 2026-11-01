import 'package:dabbler/features/profile/presentation/providers/contributor_profile_provider.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile_message_action.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';

/// Columns `public.v_meetup_list` exposes (read from the live view,
/// 2026-11-01). A unit test has no database, so the select list is pinned
/// against this list: it is the nearest seam to "the query returns 400".
/// Update it, and the migration test, when the view changes.
const Set<String> _vMeetupListColumns = {
  'id',
  'title',
  'description',
  'start_at',
  'end_at',
  'capacity',
  'members_only',
  'listing_visibility',
  'rsvp_policy',
  'is_cancelled',
  'vibe_key',
  'created_at',
  'updated_at',
  'creator_profile_id',
  'creator_display_name',
  'creator_username',
  'creator_avatar_url',
  'sport_id',
  'sport_key',
  'sport_name_en',
  'sport_name_ar',
  'sport_emoji',
  'area_id',
  'area_name',
  'venue_id',
  'venue_name',
  'location_name',
  'geo_location_id',
  'min_skill',
  'max_skill',
  'joining_rule',
  'cost_cover',
  'going_count',
  'interested_count',
  'declined_count',
  'my_rsvp_status',
  'attendee_avatars',
  'venue_is_indoor',
  'favorite_count',
  'favourited_by_me',
  'setting_is_indoor',
};

void main() {
  test('contributor meetup select list only names v_meetup_list columns', () {
    final names = meetupColumns.split(',').map((c) => c.trim()).toList();
    final unknown = names.where((c) => !_vMeetupListColumns.contains(c));
    expect(unknown, isEmpty, reason: 'columns the view does not have');
    expect(names, isNot(contains('creator_user_id')));
  });

  for (final (locale, label) in [
    (const Locale('en'), 'Invite'),
    (const Locale('ar'), 'دعوة'),
  ]) {
    testWidgets(
      'visitor header shows the Invite icon button (${locale.languageCode})',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            theme: DabblerDesignSystemTheme.withTokens(renderThemeBase()),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ProfileActionButtons(
                follow: DabblerButton(
                  label: 'Follow',
                  fullWidth: true,
                  onPressed: () {},
                ),
                message: null,
                invite: const ProfileInviteAction(),
              ),
            ),
          ),
        );
        expect(find.byKey(ProfileInviteAction.buttonKey), findsOneWidget);
        expect(find.bySemanticsLabel(label), findsOneWidget);
        handle.dispose();
      },
    );
  }
}
