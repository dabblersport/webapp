// KAN-1057 / KAN-1061: a legacy profile's sport_profiles card that is not in
// interests shows ticked under My sports; its interest under Following.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/repositories/sport_profiles_repository.dart';
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
    displayName: 'Legacy',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    interests: const ['fb'],
    profileType: 'player',
  );

  testWidgets('card-only sport shows ticked', (tester) async {
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
    final ticked = find.byWidgetPredicate(
      (w) => w is DabblerChip && w.selected,
    );
    // Gym under My sports (card), Football under Following (interest).
    expect(ticked, findsNWidgets(2));
  });
}
