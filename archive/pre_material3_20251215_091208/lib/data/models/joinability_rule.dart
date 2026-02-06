/// Reasons explaining a decision boundary.
/// Keep stable codes for analytics/telemetry.
enum JoinabilityReason {
  ok,
  notLoggedIn,
  viewerIsOwner,
  adminOverride,
  hiddenToViewer,
  circleNotSynced,
  windowClosed,
  inviteRequired,
  approvalRequired,
  rosterFull,
  rosterFullWaitlistAvailable,
  alreadyJoined,
  alreadyRequested,
  unknownVisibility,
}

/// Declarative inputs for the joinability matrix.
/// All fields default to the safest (fail-closed) interpretation if omitted.
class JoinabilityInputs {
  JoinabilityInputs({
    required this.ownerId,
    required this.visibility,
    required this.viewerId,
    this.viewerIsAdmin = false,
    this.areSyncedWithOwner = false,
    this.joinWindowOpen = true,
    this.requiresInvite = false,
    this.viewerInvited = false,
    this.requiresApproval = false,
    this.alreadyJoined = false,
    this.alreadyRequested = false,
    this.rosterCount = 0,
    this.rosterCap = 0,
    this.waitlistEnabled = false,
    this.waitlistCount = 0,
    this.waitlistCap = 0,
  });

  factory JoinabilityInputs.fromJson(Map<String, dynamic> json) {
    return JoinabilityInputs(
      ownerId: json['ownerId'] as String? ?? '',
      visibility: json['visibility'] as String?,
      viewerId: json['viewerId'] as String?,
      viewerIsAdmin: json['viewerIsAdmin'] as bool? ?? false,
      areSyncedWithOwner: json['areSyncedWithOwner'] as bool? ?? false,
      joinWindowOpen: json['joinWindowOpen'] as bool? ?? true,
      requiresInvite: json['requiresInvite'] as bool? ?? false,
      viewerInvited: json['viewerInvited'] as bool? ?? false,
      requiresApproval: json['requiresApproval'] as bool? ?? false,
      alreadyJoined: json['alreadyJoined'] as bool? ?? false,
      alreadyRequested: json['alreadyRequested'] as bool? ?? false,
      rosterCount: (json['rosterCount'] as num?)?.toInt() ?? 0,
      rosterCap: (json['rosterCap'] as num?)?.toInt() ?? 0,
      waitlistEnabled: json['waitlistEnabled'] as bool? ?? false,
      waitlistCount: (json['waitlistCount'] as num?)?.toInt() ?? 0,
      waitlistCap: (json['waitlistCap'] as num?)?.toInt() ?? 0,
    );
  }

  final String ownerId;
  final String? visibility;
  final String? viewerId;

  final bool viewerIsAdmin;
  final bool areSyncedWithOwner;

  final bool joinWindowOpen;

  final bool requiresInvite;
  final bool viewerInvited;
  final bool requiresApproval;

  final bool alreadyJoined;
  final bool alreadyRequested;

  final int rosterCount;
  final int rosterCap;

  final bool waitlistEnabled;
  final int waitlistCount;
  final int waitlistCap;

  bool get viewerIsOwner => viewerId != null && viewerId == ownerId;
  bool get rosterHasRoom => rosterCap > 0 && rosterCount < rosterCap;
  bool get waitlistHasRoom =>
      waitlistEnabled && (waitlistCap <= 0 || waitlistCount < waitlistCap);

  JoinabilityInputs copyWith({
    String? ownerId,
    String? visibility,
    String? viewerId,
    bool? viewerIsAdmin,
    bool? areSyncedWithOwner,
    bool? joinWindowOpen,
    bool? requiresInvite,
    bool? viewerInvited,
    bool? requiresApproval,
    bool? alreadyJoined,
    bool? alreadyRequested,
    int? rosterCount,
    int? rosterCap,
    bool? waitlistEnabled,
    int? waitlistCount,
    int? waitlistCap,
  }) {
    return JoinabilityInputs(
      ownerId: ownerId ?? this.ownerId,
      visibility: visibility ?? this.visibility,
      viewerId: viewerId ?? this.viewerId,
      viewerIsAdmin: viewerIsAdmin ?? this.viewerIsAdmin,
      areSyncedWithOwner: areSyncedWithOwner ?? this.areSyncedWithOwner,
      joinWindowOpen: joinWindowOpen ?? this.joinWindowOpen,
      requiresInvite: requiresInvite ?? this.requiresInvite,
      viewerInvited: viewerInvited ?? this.viewerInvited,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      alreadyJoined: alreadyJoined ?? this.alreadyJoined,
      alreadyRequested: alreadyRequested ?? this.alreadyRequested,
      rosterCount: rosterCount ?? this.rosterCount,
      rosterCap: rosterCap ?? this.rosterCap,
      waitlistEnabled: waitlistEnabled ?? this.waitlistEnabled,
      waitlistCount: waitlistCount ?? this.waitlistCount,
      waitlistCap: waitlistCap ?? this.waitlistCap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ownerId': ownerId,
      'visibility': visibility,
      'viewerId': viewerId,
      'viewerIsAdmin': viewerIsAdmin,
      'areSyncedWithOwner': areSyncedWithOwner,
      'joinWindowOpen': joinWindowOpen,
      'requiresInvite': requiresInvite,
      'viewerInvited': viewerInvited,
      'requiresApproval': requiresApproval,
      'alreadyJoined': alreadyJoined,
      'alreadyRequested': alreadyRequested,
      'rosterCount': rosterCount,
      'rosterCap': rosterCap,
      'waitlistEnabled': waitlistEnabled,
      'waitlistCount': waitlistCount,
      'waitlistCap': waitlistCap,
    };
  }
}

/// Decision result for UI branching.
/// `canJoin` implies the button should attempt a direct join action.
/// `canRequest` implies the button should request/pend host approval.
/// `canWaitlist` implies the button should waitlist when roster is full.
/// `canLeave` is true when the viewer is already in the roster.
class JoinabilityDecision {
  const JoinabilityDecision({
    required this.canJoin,
    required this.canRequest,
    required this.canWaitlist,
    required this.canLeave,
    required this.reason,
  });

  factory JoinabilityDecision.fromJson(Map<String, dynamic> json) {
    return JoinabilityDecision(
      canJoin: json['canJoin'] as bool? ?? false,
      canRequest: json['canRequest'] as bool? ?? false,
      canWaitlist: json['canWaitlist'] as bool? ?? false,
      canLeave: json['canLeave'] as bool? ?? false,
      reason: JoinabilityReason.values.firstWhere(
        (value) => value.name == json['reason'],
        orElse: () => JoinabilityReason.unknownVisibility,
      ),
    );
  }

  final bool canJoin;
  final bool canRequest;
  final bool canWaitlist;
  final bool canLeave;
  final JoinabilityReason reason;

  Map<String, dynamic> toJson() {
    return {
      'canJoin': canJoin,
      'canRequest': canRequest,
      'canWaitlist': canWaitlist,
      'canLeave': canLeave,
      'reason': reason.name,
    };
  }

  @override
  String toString() =>
      'JoinabilityDecision(join:$canJoin, req:$canRequest, wait:$canWaitlist, leave:$canLeave, reason:$reason)';
}
