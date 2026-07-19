import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:dabbler/widgets/adaptive_scaffold.dart';
import 'package:dabbler/core/constants/adaptive_destinations.dart';

/// Simple rewards screen for navigation tab
/// This serves as the main entry point for the rewards system
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final content = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Rewards'),
        backgroundColor: colorScheme.surface,
      ),
      body: const Center(child: Text('Rewards Screen - Under Construction')),
    );

    if (MediaQuery.of(context).size.width >= AdaptiveBreakpoints.compact) {
      return AdaptiveScaffold(
        currentIndex: 6,
        destinations: kAdaptiveDestinations,
        onDestinationSelected: (i) =>
            onAdaptiveDestinationSelected(context, i, activeIndex: 6),
        headerWidget: SvgPicture.asset(
          'assets/images/dabbler_text_logo.svg',
          width: 100,
          height: 18,
          colorFilter: ColorFilter.mode(colorScheme.onSurface, BlendMode.srcIn),
        ),
        body: content,
      );
    }
    return content;
  }
}
