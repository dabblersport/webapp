import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../models/joinability_rule.dart';
import 'joinability_repository.dart';

final joinabilityRepositoryProvider = Provider<JoinabilityRepository>((ref) {
  return JoinabilityRepositoryImpl();
});

class JoinabilityRepositoryImpl implements JoinabilityRepository {
  @override
  Result<JoinabilityDecision, Failure> evaluate(JoinabilityInputs inputs) {
    // 1) Viewer presence
    if (inputs.viewerId == null || inputs.viewerId!.isEmpty) {
      return Ok(_deny(reason: JoinabilityReason.notLoggedIn));
    }

    // 2) Already joined → no join/request/waitlist; allow leave
    if (inputs.alreadyJoined) {
      return Ok(
        JoinabilityDecision(
          canJoin: false,
          canRequest: false,
          canWaitlist: false,
          canLeave: true,
          reason: JoinabilityReason.alreadyJoined,
        ),
      );
    }

    // 3) Already requested → no direct join; keep "cancel request" at feature layer
    if (inputs.alreadyRequested) {
      return Ok(_deny(reason: JoinabilityReason.alreadyRequested));
    }

    // 4) Admin/Owner short-circuit (UI may still hide buttons contextually)
    if (inputs.viewerIsOwner) {
      // Owner typically doesn't "join" their own game; treat as deny with a specific reason.
      return Ok(_deny(reason: JoinabilityReason.viewerIsOwner));
    }
    if (inputs.viewerIsAdmin) {
      // Admin override: let UI show join (or management UI) as appropriate
      return Ok(
        JoinabilityDecision(
          canJoin: true,
          canRequest: false,
          canWaitlist: false,
          canLeave: false,
          reason: JoinabilityReason.adminOverride,
        ),
      );
    }

    // 5) Visibility gates (mirror server model)
    switch (inputs.visibility) {
      case 'public':
        // ok
        break;
      case 'circle':
        if (!inputs.areSyncedWithOwner) {
          return Ok(_deny(reason: JoinabilityReason.circleNotSynced));
        }
        break;
      case 'hidden':
        return Ok(_deny(reason: JoinabilityReason.hiddenToViewer));
      default:
        return Ok(_deny(reason: JoinabilityReason.unknownVisibility));
    }

    // 6) Time window
    if (!inputs.joinWindowOpen) {
      // Might still allow waitlisting even when window is closed (product choice).
      // Here we deny join but advertise waitlist if available.
      if (inputs.waitlistHasRoom) {
        return Ok(
          JoinabilityDecision(
            canJoin: false,
            canRequest: false,
            canWaitlist: true,
            canLeave: false,
            reason: JoinabilityReason.windowClosed,
          ),
        );
      }
      return Ok(_deny(reason: JoinabilityReason.windowClosed));
    }

    // 7) Invite / approval
    if (inputs.requiresInvite && !inputs.viewerInvited) {
      // You might allow waitlisting even without invite; reflect product policy here.
      if (inputs.waitlistHasRoom) {
        return Ok(
          JoinabilityDecision(
            canJoin: false,
            canRequest: false,
            canWaitlist: true,
            canLeave: false,
            reason: JoinabilityReason.inviteRequired,
          ),
        );
      }
      return Ok(_deny(reason: JoinabilityReason.inviteRequired));
    }

    // Approval flow: prefer "request" over direct join if required.
    if (inputs.requiresApproval) {
      // If roster has room, prefer a join-request; if full, offer waitlist.
      if (inputs.rosterHasRoom) {
        return Ok(
          JoinabilityDecision(
            canJoin: false,
            canRequest: true,
            canWaitlist: false,
            canLeave: false,
            reason: JoinabilityReason.approvalRequired,
          ),
        );
      }
      if (inputs.waitlistHasRoom) {
        return Ok(
          JoinabilityDecision(
            canJoin: false,
            canRequest: false,
            canWaitlist: true,
            canLeave: false,
            reason: JoinabilityReason.rosterFullWaitlistAvailable,
          ),
        );
      }
      return Ok(_deny(reason: JoinabilityReason.rosterFull));
    }

    // 8) Roster capacity
    if (inputs.rosterHasRoom) {
      return Ok(
        const JoinabilityDecision(
          canJoin: true,
          canRequest: false,
          canWaitlist: false,
          canLeave: false,
          reason: JoinabilityReason.ok,
        ),
      );
    }

    // 9) Waitlist path
    if (inputs.waitlistHasRoom) {
      return Ok(
        JoinabilityDecision(
          canJoin: false,
          canRequest: false,
          canWaitlist: true,
          canLeave: false,
          reason: JoinabilityReason.rosterFullWaitlistAvailable,
        ),
      );
    }

    // 10) Full stop
    return Ok(_deny(reason: JoinabilityReason.rosterFull));
  }

  JoinabilityDecision _deny({required JoinabilityReason reason}) {
    return JoinabilityDecision(
      canJoin: false,
      canRequest: false,
      canWaitlist: false,
      canLeave: false,
      reason: reason,
    );
  }
}
