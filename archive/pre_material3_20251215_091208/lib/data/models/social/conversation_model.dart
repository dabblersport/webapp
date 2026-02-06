import 'package:dabbler/data/models/social/conversation.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'chat_message_model.dart';

/// Data model for conversations with participant and message information
class ConversationModel extends Conversation {
  final List<ConversationParticipant> participants;
  final ChatMessageModel? lastMessage;
  final int unreadCount;
  final Map<String, ParticipantRole> participantRoles;
  final GroupChatMetadata? groupMetadata;
  final ConversationSettings settings;
  final Map<String, dynamic>? metadata;

  const ConversationModel({
    required super.id,
    required super.type,
    required super.createdAt,
    required super.updatedAt,
    super.name,
    super.description,
    super.avatarUrl,
    super.isActive,
    this.participants = const [],
    this.lastMessage,
    this.unreadCount = 0,
    this.participantRoles = const {},
    this.groupMetadata,
    this.settings = const ConversationSettings(),
    this.metadata,
  });

  /// Create ConversationModel from Supabase JSON response
  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    // Parse conversation type
    ConversationType type = ConversationType.direct;
    final typeStr = json['type']?.toString().toLowerCase() ?? 'direct';
    switch (typeStr) {
      case 'direct':
      case 'dm':
        type = ConversationType.direct;
        break;
      case 'group':
        type = ConversationType.group;
        break;
      case 'game':
        type = ConversationType.game;
        break;
      case 'support':
        type = ConversationType.support;
        break;
    }

    // Parse participants array
    List<ConversationParticipant> participants = [];
    if (json['participants'] != null && json['participants'] is List) {
      participants = (json['participants'] as List)
          .map((participant) => ConversationParticipant.fromJson(participant))
          .toList();
    } else if (json['conversation_participants'] != null) {
      // Alternative nested format
      participants = (json['conversation_participants'] as List)
          .map((cp) => ConversationParticipant.fromJson(cp['profile'] ?? cp))
          .toList();
    }

    // Parse last message
    ChatMessageModel? lastMessage;
    if (json['last_message'] != null) {
      lastMessage = ChatMessageModel.fromJson(json['last_message']);
    } else if (json['latest_message'] != null) {
      lastMessage = ChatMessageModel.fromJson(json['latest_message']);
    }

    // Parse participant roles
    Map<String, ParticipantRole> participantRoles = {};
    if (json['participant_roles'] != null && json['participant_roles'] is Map) {
      final rolesMap = json['participant_roles'] as Map<String, dynamic>;
      participantRoles = rolesMap.map((userId, roleStr) {
        ParticipantRole role = ParticipantRole.member;
        switch (roleStr.toString().toLowerCase()) {
          case 'owner':
            role = ParticipantRole.owner;
            break;
          case 'admin':
            role = ParticipantRole.admin;
            break;
          case 'moderator':
            role = ParticipantRole.moderator;
            break;
          case 'member':
          default:
            role = ParticipantRole.member;
            break;
        }
        return MapEntry(userId, role);
      });
    }

    // Parse group metadata for group chats
    GroupChatMetadata? groupMetadata;
    if (type == ConversationType.group && json['group_metadata'] != null) {
      groupMetadata = GroupChatMetadata.fromJson(json['group_metadata']);
    }

    // Parse conversation settings
    ConversationSettings settings = ConversationSettings.fromJson(
      json['settings'] ?? {},
    );

    return ConversationModel(
      id: json['id'] ?? '',
      type: type,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at'] ?? json['last_activity']),
      name: json['name'] ?? json['title'],
      description: json['description'],
      avatarUrl: json['avatar_url'] ?? json['image_url'],
      isActive: json['is_active'] ?? json['active'] ?? true,
      participants: participants,
      lastMessage: lastMessage,
      unreadCount: json['unread_count'] ?? 0,
      participantRoles: participantRoles,
      groupMetadata: groupMetadata,
      settings: settings,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'type': _conversationTypeToString(type),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_active': isActive,
      'unread_count': unreadCount,
    };

    if (name != null) json['name'] = name;
    if (description != null) json['description'] = description;
    if (avatarUrl != null) json['avatar_url'] = avatarUrl;

    // Add participants
    json['participants'] = participants.map((p) => p.toJson()).toList();

    // Add last message
    if (lastMessage != null) {
      json['last_message'] = lastMessage!.toJson();
    }

    // Add participant roles
    if (participantRoles.isNotEmpty) {
      json['participant_roles'] = participantRoles.map(
        (userId, role) => MapEntry(userId, _participantRoleToString(role)),
      );
    }

    // Add group metadata
    if (groupMetadata != null) {
      json['group_metadata'] = groupMetadata!.toJson();
    }

    // Add settings
    json['settings'] = settings.toJson();

    if (metadata != null) json['metadata'] = metadata;

    return json;
  }

  /// Create JSON for creating new conversation
  Map<String, dynamic> toCreateJson() {
    final json = <String, dynamic>{'type': _conversationTypeToString(type)};

    if (name != null) json['name'] = name;
    if (description != null) json['description'] = description;
    if (avatarUrl != null) json['avatar_url'] = avatarUrl;

    // Add participant IDs for creation
    if (participants.isNotEmpty) {
      json['participant_ids'] = participants.map((p) => p.id).toList();
    }

    // Add group metadata for group chats
    if (type == ConversationType.group && groupMetadata != null) {
      json['group_metadata'] = groupMetadata!.toJson();
    }

    // Add settings
    json['settings'] = settings.toJson();

    if (metadata != null) json['metadata'] = metadata;

    return json;
  }

  /// Create JSON for updating conversation
  Map<String, dynamic> toUpdateJson() {
    final json = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (name != null) json['name'] = name;
    if (description != null) json['description'] = description;
    if (avatarUrl != null) json['avatar_url'] = avatarUrl;

    // Update group metadata if changed
    if (groupMetadata != null) {
      json['group_metadata'] = groupMetadata!.toJson();
    }

    // Update settings
    json['settings'] = settings.toJson();

    if (metadata != null) json['metadata'] = metadata;

    return json;
  }

  /// Create a copy with updated fields
  ConversationModel copyWith({
    String? id,
    ConversationType? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    String? description,
    String? avatarUrl,
    bool? isActive,
    List<ConversationParticipant>? participants,
    ChatMessageModel? lastMessage,
    int? unreadCount,
    Map<String, ParticipantRole>? participantRoles,
    GroupChatMetadata? groupMetadata,
    ConversationSettings? settings,
    Map<String, dynamic>? metadata,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive ?? this.isActive,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      participantRoles: participantRoles ?? this.participantRoles,
      groupMetadata: groupMetadata ?? this.groupMetadata,
      settings: settings ?? this.settings,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Update last message and unread count
  ConversationModel updateLastMessage(
    ChatMessageModel message, {
    int? newUnreadCount,
  }) {
    return copyWith(
      lastMessage: message,
      updatedAt: message.sentAt,
      unreadCount: newUnreadCount ?? unreadCount + 1,
    );
  }

  /// Mark conversation as read for current user
  ConversationModel markAsRead() {
    return copyWith(unreadCount: 0);
  }

  /// Add participant to conversation
  ConversationModel addParticipant(
    ConversationParticipant participant, {
    ParticipantRole role = ParticipantRole.member,
  }) {
    final newParticipants = [...participants, participant];
    final newRoles = Map<String, ParticipantRole>.from(participantRoles);
    newRoles[participant.id] = role;

    return copyWith(
      participants: newParticipants,
      participantRoles: newRoles,
      updatedAt: DateTime.now(),
    );
  }

  /// Remove participant from conversation
  ConversationModel removeParticipant(String participantId) {
    final newParticipants = participants
        .where((p) => p.id != participantId)
        .toList();
    final newRoles = Map<String, ParticipantRole>.from(participantRoles);
    newRoles.remove(participantId);

    return copyWith(
      participants: newParticipants,
      participantRoles: newRoles,
      updatedAt: DateTime.now(),
    );
  }

  /// Update participant role
  ConversationModel updateParticipantRole(
    String participantId,
    ParticipantRole role,
  ) {
    final newRoles = Map<String, ParticipantRole>.from(participantRoles);
    newRoles[participantId] = role;

    return copyWith(participantRoles: newRoles, updatedAt: DateTime.now());
  }

  /// Check if user is participant
  bool isParticipant(String userId) {
    return participants.any((p) => p.id == userId);
  }

  /// Get participant by ID
  ConversationParticipant? getParticipant(String userId) {
    try {
      return participants.firstWhere((p) => p.id == userId);
    } catch (e) {
      return null;
    }
  }

  /// Get participant role
  ParticipantRole getParticipantRole(String userId) {
    return participantRoles[userId] ?? ParticipantRole.member;
  }

  /// Check if user can send messages
  bool canUserSendMessages(String userId) {
    if (!isParticipant(userId)) return false;
    if (!isActive) return false;

    final role = getParticipantRole(userId);
    return role != ParticipantRole.member ||
        !settings.membersCannotSendMessages;
  }

  /// Check if user can add participants
  bool canUserAddParticipants(String userId) {
    final role = getParticipantRole(userId);
    return role == ParticipantRole.owner ||
        role == ParticipantRole.admin ||
        (!settings.onlyAdminsCanAddParticipants &&
            role == ParticipantRole.member);
  }

  /// Check if user can remove participants
  bool canUserRemoveParticipants(String userId) {
    final role = getParticipantRole(userId);
    return role == ParticipantRole.owner || role == ParticipantRole.admin;
  }

  /// Get conversation display name
  String getDisplayName({String? currentUserId}) {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }

    if (type == ConversationType.direct && participants.length == 2) {
      // For direct messages, show the other participant's name
      if (currentUserId != null) {
        final otherParticipant = participants.firstWhere(
          (p) => p.id != currentUserId,
          orElse: () => participants.first,
        );
        return otherParticipant.name;
      }
    }

    if (participants.isNotEmpty) {
      if (participants.length <= 3) {
        return participants.map((p) => p.name).join(', ');
      } else {
        final firstTwo = participants.take(2).map((p) => p.name).join(', ');
        return '$firstTwo and ${participants.length - 2} others';
      }
    }

    return 'Conversation';
  }

  /// Get conversation avatar URL
  String? getAvatarUrl({String? currentUserId}) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return avatarUrl;
    }

    if (type == ConversationType.direct && participants.length == 2) {
      // For direct messages, use the other participant's avatar
      if (currentUserId != null) {
        final otherParticipant = participants.firstWhere(
          (p) => p.id != currentUserId,
          orElse: () => participants.first,
        );
        return otherParticipant.avatar.isNotEmpty
            ? otherParticipant.avatar
            : null;
      }
    }

    return null;
  }

  /// Get last message preview
  String get lastMessagePreview {
    if (lastMessage == null) return 'No messages yet';
    return lastMessage!.previewText;
  }

  /// Check if conversation is group chat
  bool get isGroup => type == ConversationType.group;

  /// Check if conversation is direct message
  bool get isDirect => type == ConversationType.direct;

  /// Check if conversation is pinned
  bool get isPinned => metadata?['is_pinned'] == true;

  /// Check if conversation is archived
  bool get isArchived => metadata?['is_archived'] == true;

  /// Get online participants count
  int get onlineParticipantsCount {
    return participants.where((p) => p.isOnline).length;
  }

  // Helper methods
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  static String _conversationTypeToString(ConversationType type) {
    switch (type) {
      case ConversationType.direct:
        return 'direct';
      case ConversationType.group:
        return 'group';
      case ConversationType.game:
        return 'game';
      case ConversationType.support:
        return 'support';
    }
  }

  static String _participantRoleToString(ParticipantRole role) {
    switch (role) {
      case ParticipantRole.owner:
        return 'owner';
      case ParticipantRole.admin:
        return 'admin';
      case ParticipantRole.moderator:
        return 'moderator';
      case ParticipantRole.member:
        return 'member';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ConversationModel{id: $id, type: $type, participants: ${participants.length}, unread: $unreadCount}';
  }
}

/// Model for conversation participants
class ConversationParticipant {
  final String id;
  final String name;
  final String avatar;
  final bool verified;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime joinedAt;
  final Map<String, dynamic>? profile;

  const ConversationParticipant({
    required this.id,
    required this.name,
    this.avatar = '',
    this.verified = false,
    this.isOnline = false,
    this.lastSeen,
    required this.joinedAt,
    this.profile,
  });

  factory ConversationParticipant.fromJson(Map<String, dynamic> json) {
    return ConversationParticipant(
      id: json['id'] ?? json['user_id'] ?? '',
      name:
          json['name'] ??
          json['full_name'] ??
          json['username'] ??
          'Unknown User',
      avatar:
          json['avatar'] ?? json['avatar_url'] ?? json['profile_picture'] ?? '',
      verified: json['verified'] == true || json['is_verified'] == true,
      isOnline: json['is_online'] == true || json['online'] == true,
      lastSeen: json['last_seen'] != null
          ? _parseDateTime(json['last_seen'])
          : null,
      joinedAt: _parseDateTime(json['joined_at'] ?? json['created_at']),
      profile: json['profile'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'name': name,
      'verified': verified,
      'is_online': isOnline,
      'joined_at': joinedAt.toIso8601String(),
    };

    if (avatar.isNotEmpty) json['avatar'] = avatar;
    if (lastSeen != null) json['last_seen'] = lastSeen!.toIso8601String();
    if (profile != null) json['profile'] = profile;

    return json;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }
}

/// Model for group chat metadata
class GroupChatMetadata {
  final int maxParticipants;
  final bool inviteLinksEnabled;
  final String? inviteCode;
  final DateTime? inviteCodeExpiry;
  final List<String> tags;
  final Map<String, dynamic>? gameData;

  const GroupChatMetadata({
    this.maxParticipants = 100,
    this.inviteLinksEnabled = false,
    this.inviteCode,
    this.inviteCodeExpiry,
    this.tags = const [],
    this.gameData,
  });

  factory GroupChatMetadata.fromJson(Map<String, dynamic> json) {
    List<String> tags = [];
    if (json['tags'] != null && json['tags'] is List) {
      tags = (json['tags'] as List).map((tag) => tag.toString()).toList();
    }

    return GroupChatMetadata(
      maxParticipants: json['max_participants'] ?? 100,
      inviteLinksEnabled: json['invite_links_enabled'] == true,
      inviteCode: json['invite_code'],
      inviteCodeExpiry: json['invite_code_expiry'] != null
          ? ConversationParticipant._parseDateTime(json['invite_code_expiry'])
          : null,
      tags: tags,
      gameData: json['game_data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'max_participants': maxParticipants,
      'invite_links_enabled': inviteLinksEnabled,
      'tags': tags,
    };

    if (inviteCode != null) json['invite_code'] = inviteCode;
    if (inviteCodeExpiry != null) {
      json['invite_code_expiry'] = inviteCodeExpiry!.toIso8601String();
    }
    if (gameData != null) json['game_data'] = gameData;

    return json;
  }
}

/// Model for conversation settings
class ConversationSettings {
  final bool muteNotifications;
  final bool onlyAdminsCanAddParticipants;
  final bool membersCannotSendMessages;
  final bool readReceiptsEnabled;
  final bool typingIndicatorsEnabled;
  final Duration? messageRetention;

  const ConversationSettings({
    this.muteNotifications = false,
    this.onlyAdminsCanAddParticipants = false,
    this.membersCannotSendMessages = false,
    this.readReceiptsEnabled = true,
    this.typingIndicatorsEnabled = true,
    this.messageRetention,
  });

  factory ConversationSettings.fromJson(Map<String, dynamic> json) {
    Duration? messageRetention;
    if (json['message_retention_hours'] != null) {
      messageRetention = Duration(hours: json['message_retention_hours']);
    } else if (json['message_retention_days'] != null) {
      messageRetention = Duration(days: json['message_retention_days']);
    }

    return ConversationSettings(
      muteNotifications: json['mute_notifications'] == true,
      onlyAdminsCanAddParticipants:
          json['only_admins_can_add_participants'] == true,
      membersCannotSendMessages: json['members_cannot_send_messages'] == true,
      readReceiptsEnabled: json['read_receipts_enabled'] ?? true,
      typingIndicatorsEnabled: json['typing_indicators_enabled'] ?? true,
      messageRetention: messageRetention,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'mute_notifications': muteNotifications,
      'only_admins_can_add_participants': onlyAdminsCanAddParticipants,
      'members_cannot_send_messages': membersCannotSendMessages,
      'read_receipts_enabled': readReceiptsEnabled,
      'typing_indicators_enabled': typingIndicatorsEnabled,
    };

    if (messageRetention != null) {
      json['message_retention_hours'] = messageRetention!.inHours;
    }

    return json;
  }
}

/// Enums for conversation types and participant roles
enum ParticipantRole { owner, admin, moderator, member }
