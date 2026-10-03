import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/data/models/venue_submission_model.dart';

/// Submission status as a DS badge. No design frame: the status maps onto the
/// DS badge tones (draft neutral, pending warning, approved success,
/// returned/rejected error).
class VenueSubmissionStatusBadge extends StatelessWidget {
  final VenueSubmissionStatus status;

  const VenueSubmissionStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      VenueSubmissionStatus.draft => DabblerBadgeTone.defaultTone,
      VenueSubmissionStatus.pending => DabblerBadgeTone.warning,
      VenueSubmissionStatus.approved => DabblerBadgeTone.success,
      VenueSubmissionStatus.returned => DabblerBadgeTone.error,
      VenueSubmissionStatus.rejected => DabblerBadgeTone.error,
    };

    return DabblerBadge(label: status.name.toUpperCase(), tone: tone);
  }
}
