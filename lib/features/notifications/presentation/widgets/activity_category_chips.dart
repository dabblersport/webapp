// KAN-990: the Activity log category chips (design A.1: All · You · Games ·
// Social · Rewards). Bookings is not shown: booking and payment are not live
// (F-12). The keys are the ones [filterActivityLog] reads.

import 'package:dabbler/l10n/app_localizations.dart';

import 'notif_chips.dart';

/// The chip keys, in order.
const List<String> kActivityCategoryKeys = <String>[
  'all',
  'me',
  'game',
  'social',
  'reward',
];

/// The Activity log chips, localized.
List<ChipData> activityCategoryChips(AppLocalizations l10n) => <ChipData>[
  ChipData('all', l10n.notif_chip_all, 'activity'),
  ChipData('me', l10n.notif_chip_you, 'edit'),
  ChipData('game', l10n.notif_chip_games, 'game'),
  ChipData('social', l10n.notif_chip_social, 'people'),
  ChipData('reward', l10n.notif_chip_rewards, 'coin'),
];
