import 'package:dabbler/core/fp/failure.dart';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/sport_profile.dart';

import '../providers/sport_profiles_providers.dart';

TextStyle _text(BuildContext context, DabblerTypeStyle step, Color color) =>
    step.resolveForDirection(Directionality.of(context)).copyWith(color: color);

/// Minimal showcase widget for sport profile providers.
class SportProfilesConsumer extends StatelessWidget {
  const SportProfilesConsumer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);

    return Consumer(
      builder: (context, ref, _) {
        final initialLoad = ref.watch(mySportProfilesProvider);
        final realtime = ref.watch(mySportProfilesStreamProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Initial load',
              style: _text(context, DabblerType.headline, colors.textPrimary),
            ),
            const SizedBox(height: DabblerSpacing.space2),
            _ResultView(value: initialLoad),
            const SizedBox(height: DabblerSpacing.space5),
            Text(
              'Realtime updates',
              style: _text(context, DabblerType.headline, colors.textPrimary),
            ),
            const SizedBox(height: DabblerSpacing.space2),
            _ResultView(value: realtime),
          ],
        );
      },
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.value});

  final AsyncValue<Result<List<SportProfile>, Failure>> value;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    Text line(String message) => Text(
      message,
      style: _text(context, DabblerType.body, colors.textPrimary),
    );

    return value.when(
      data: (result) => result.fold(
        (failure) => line('Error: ${failure.message}'),
        (sports) => sports.isEmpty
            ? line('No sport preferences yet.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final sport in sports)
                    line('${sport.sportKey} · skill ${sport.skillLevel}'),
                ],
              ),
      ),
      loading: () => const Center(child: DabblerSpinner()),
      error: (error, _) => line('Error: $error'),
    );
  }
}
