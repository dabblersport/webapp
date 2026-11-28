// KAN-1062: Arabic sport names on the profile, Arabic "Stay Updated" sheet,
// and the Manage Sports list stays mounted while the profile refreshes.

import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/data/repositories/sport_profiles_repository.dart';
import 'package:dabbler/features/home/presentation/widgets/notification_permission_drawer.dart';
import 'package:dabbler/features/profile/presentation/controllers/profile_controller.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/sport_profiles_providers.dart';
import 'package:dabbler/features/profile/presentation/widgets/manage_sports_sheet.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_followed_sports.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_sport_picker.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _football = Sport(id: 'fb', nameEn: 'Football', nameAr: 'كرة القدم');
const _padel = Sport(id: 'pd', nameEn: 'Padel', nameAr: 'بادل');
const _sports = <Sport>[_football, _padel];

class _Profile extends StateNotifier<ProfileState>
    implements ProfileController {
  _Profile(super.state);
  void set(ProfileState s) => state = s;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements SportProfilesRepository {
  @override
  Future<Result<List<String>, Failure>> getSportIdsForProfile(
    String id,
  ) async => const Ok(['fb']);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget child, {Locale locale = const Locale('ar')}) => MaterialApp(
  locale: locale,
  theme: DabblerDesignSystemTheme.withTokens(ThemeData()),
  builder: (context, c) => DabblerToastProvider(child: c!),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('followed-sports chips show Arabic names', (tester) async {
    await tester.pumpWidget(
      _app(const OwnProfileFollowedSports(sports: _sports)),
    );
    expect(find.text('كرة القدم'), findsOneWidget);
    expect(find.text('بادل'), findsOneWidget);
    expect(find.text('Football'), findsNothing);
  });

  testWidgets('sport picker chips show Arabic names', (tester) async {
    await tester.pumpWidget(
      _app(
        OwnProfileSportPicker(
          sports: _sports,
          selectedId: null,
          primaryId: null,
          onSelect: (_) {},
        ),
      ),
    );
    expect(find.text('بادل'), findsOneWidget);
    expect(find.text('Padel'), findsNothing);
  });

  testWidgets('Stay Updated sheet content is Arabic', (tester) async {
    await tester.pumpWidget(
      _app(
        NotificationPermissionDrawer(
          onEnableNotifications: () {},
          onRemindLater: () {},
          onNoThanks: () {},
        ),
      ),
    );
    final ar = lookupAppLocalizations(const Locale('ar'));
    expect(find.text(ar.notif_perm_enable), findsOneWidget);
    expect(find.text(ar.notif_perm_remind_later), findsOneWidget);
    expect(find.text(ar.notif_perm_no_thanks), findsOneWidget);
    expect(find.text(ar.notif_perm_body), findsOneWidget);
    expect(find.text('Enable Notifications'), findsNothing);
    expect(ar.notif_perm_title, 'ابقَ على اطلاع');
  });

  testWidgets('Manage Sports list stays mounted while the profile refreshes', (
    tester,
  ) async {
    UserProfile profile(String name) => UserProfile(
      id: 'p1',
      userId: 'u1',
      displayName: name,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      interests: const ['fb'],
      profileType: 'player',
    );
    final notifier = _Profile(ProfileState(profile: profile('A')));
    final pending = Completer<List<Sport>>();
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileControllerProvider.overrideWith((ref) => notifier),
          sportProfilesRepositoryProvider.overrideWithValue(_Repo()),
          sportsProvider.overrideWith((ref) async => _sports),
          activeSportsByProfileCountryProvider.overrideWith((ref) {
            ref.watch(profileControllerProvider);
            calls++;
            return calls == 1 ? Future.value(_sports) : pending.future;
          }),
        ],
        child: _app(
          ManageSportsSheet(saving: ValueNotifier<bool>(false)),
          locale: const Locale('en'),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Padel'), findsNWidgets(2));

    notifier.set(ProfileState(profile: profile('B')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(calls, greaterThan(1));
    expect(find.text('Padel'), findsNWidgets(2));
    expect(find.byType(DabblerSpinner), findsNothing);
    pending.complete(_sports);
    await tester.pump();
  });
}
