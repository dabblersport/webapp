// KAN-1058: Manage Sports copy comes from l10n in English and Arabic.

import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/repositories/sport_profiles_repository.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/profile/presentation/controllers/profile_controller.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/sport_profiles_providers.dart';
import 'package:dabbler/features/profile/presentation/widgets/manage_sports_sheet.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../sports/my_sports_provider_test.dart' show catalogue;

class _Profile extends StateNotifier<ProfileState>
    implements ProfileController {
  _Profile(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements SportProfilesRepository {
  @override
  Future<Result<List<String>, Failure>> getSportIdsForProfile(
    String id,
  ) async => const Ok(['gym']);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final profile = UserProfile(
    id: 'p1',
    userId: 'u1',
    displayName: 'P',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    interests: const ['fb'],
    profileType: 'player',
  );

  Future<void> pump(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileControllerProvider.overrideWith(
            (ref) => _Profile(ProfileState(profile: profile)),
          ),
          sportProfilesRepositoryProvider.overrideWithValue(_Repo()),
          sportsProvider.overrideWith((ref) async => catalogue),
          activeSportsByProfileCountryProvider.overrideWith(
            (ref) async => catalogue,
          ),
        ],
        child: MaterialApp(
          locale: locale,
          theme: DabblerDesignSystemTheme.withTokens(ThemeData()),
          builder: (context, child) => DabblerToastProvider(child: child!),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ManageSportsSheet(saving: ValueNotifier<bool>(false)),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  for (final entry in {
    'en': (
      'Tap a sport to add or remove it from your profile.',
      'Search sports',
    ),
    'ar': (
      'اضغط على رياضة لإضافتها إلى ملفك الشخصي أو إزالتها منه.',
      'ابحث عن رياضة',
    ),
  }.entries) {
    testWidgets('sheet copy in ${entry.key}', (tester) async {
      await pump(tester, Locale(entry.key));
      expect(find.text(entry.value.$1), findsOneWidget);
      expect(find.text(entry.value.$2), findsOneWidget);
      expect(find.text('Manage Sports'), findsNothing);
    });
  }

  test('title and messages exist in en and ar', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final ar = lookupAppLocalizations(const Locale('ar'));
    expect(en.manage_sports_title, 'Manage Sports');
    expect(ar.manage_sports_title, 'إدارة الرياضات');
    expect(ar.manage_sports_no_match, isNot(en.manage_sports_no_match));
    expect(ar.manage_sports_load_failed, isNot(en.manage_sports_load_failed));
    expect(ar.manage_sports_last_sport, isNot(en.manage_sports_last_sport));
  });
}
