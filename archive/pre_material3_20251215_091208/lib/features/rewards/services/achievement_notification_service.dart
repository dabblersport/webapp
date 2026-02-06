import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:dabbler/data/models/rewards/achievement.dart';
import 'package:dabbler/data/models/rewards/badge_tier.dart';
import '../presentation/widgets/celebrations/achievement_notification.dart';
import '../presentation/widgets/celebrations/confetti_animation.dart';

/// Notification priority levels
enum NotificationPriority { low, normal, high, critical }

/// Sound effect types
enum SoundEffectType {
  achievement,
  tierUp,
  pointsEarned,
  badge,
  milestone,
  celebration,
  fanfare,
  chime,
}

/// Vibration pattern types
enum VibrationPattern {
  light,
  medium,
  heavy,
  success,
  celebration,
  fanfare,
  custom,
}

/// Notification queue item
class NotificationQueueItem {
  final String id;
  final NotificationPriority priority;
  final NotificationType type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime? scheduledFor;
  final Duration? delay;
  final SoundEffectType? soundEffect;
  final VibrationPattern? vibrationPattern;
  final bool enableConfetti;
  final ConfettiConfig? confettiConfig;

  NotificationQueueItem({
    required this.id,
    required this.priority,
    required this.type,
    required this.data,
    required this.createdAt,
    this.scheduledFor,
    this.delay,
    this.soundEffect,
    this.vibrationPattern,
    this.enableConfetti = false,
    this.confettiConfig,
  });

  bool get isReady {
    final now = DateTime.now();
    if (scheduledFor != null) {
      return now.isAfter(scheduledFor!);
    }
    if (delay != null) {
      return now.difference(createdAt) >= delay!;
    }
    return true;
  }

  int get priorityScore {
    switch (priority) {
      case NotificationPriority.low:
        return 1;
      case NotificationPriority.normal:
        return 2;
      case NotificationPriority.high:
        return 3;
      case NotificationPriority.critical:
        return 4;
    }
  }
}

/// Notification types
enum NotificationType {
  achievement,
  tierUpgrade,
  pointsEarned,
  badgeAwarded,
  milestone,
  dailyReward,
  custom,
}

/// Share content data
class ShareContent {
  final String title;
  final String description;
  final String imageUrl;
  final Map<String, String> deepLinks;
  final Map<String, dynamic> metadata;

  const ShareContent({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.deepLinks,
    required this.metadata,
  });
}

/// Achievement notification service
class AchievementNotificationService extends ChangeNotifier {
  final AudioPlayer _audioPlayer;

  // Queue management
  final List<NotificationQueueItem> _notificationQueue = [];
  final List<String> _activeNotifications = [];
  Timer? _processingTimer;
  bool _isProcessing = false;

  // Settings
  bool _soundEnabled = true;
  bool _vibrationsEnabled = true;
  bool _notificationsEnabled = true;
  double _soundVolume = 0.7;
  int _maxConcurrentNotifications = 3;
  Duration _notificationDisplayDuration = const Duration(seconds: 5);

  // Analytics tracking
  final Map<String, int> _notificationCounts = {};
  final Map<String, DateTime> _lastNotificationTimes = {};

  // Initialization state
  bool _isInitialized = false;
  String? _currentUserId;

  AchievementNotificationService() : _audioPlayer = AudioPlayer();

  // Getters
  bool get isInitialized => _isInitialized;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationsEnabled => _vibrationsEnabled;
  bool get notificationsEnabled => _notificationsEnabled;
  double get soundVolume => _soundVolume;
  int get queueLength => _notificationQueue.length;
  int get activeNotificationCount => _activeNotifications.length;

  /// Initialize the service
  Future<void> initialize(String userId) async {
    if (_isInitialized && _currentUserId == userId) return;

    try {
      _currentUserId = userId;

      // Load user preferences
      await _loadUserPreferences();

      // Setup audio player
      await _setupAudioPlayer();

      // Start processing timer
      _startProcessingTimer();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Dispose of the service
  @override
  void dispose() {
    _processingTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Queue an achievement notification
  Future<void> queueAchievementNotification({
    required String userId,
    required Achievement achievement,
    ProgressData? nextProgress,
    NotificationPriority priority = NotificationPriority.high,
    Duration? delay,
    SoundEffectType? soundEffect,
    VibrationPattern? vibrationPattern,
    bool enableConfetti = true,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_notificationsEnabled || userId != _currentUserId) return;

    final notificationId = _generateNotificationId();

    final item = NotificationQueueItem(
      id: notificationId,
      priority: priority,
      type: NotificationType.achievement,
      data: {
        'achievement': achievement,
        'nextProgress': nextProgress,
        'metadata': metadata,
      },
      createdAt: DateTime.now(),
      delay: delay,
      soundEffect: soundEffect ?? SoundEffectType.achievement,
      vibrationPattern: vibrationPattern ?? VibrationPattern.success,
      enableConfetti: enableConfetti,
      confettiConfig: _getConfettiConfigForAchievement(achievement),
    );

    _addToQueue(item);

    // Track analytics
    _trackNotificationQueued(NotificationType.achievement, achievement.id);
  }

  /// Queue tier upgrade notification
  Future<void> queueTierUpgradeNotification({
    required String userId,
    required BadgeTier oldTier,
    required BadgeTier newTier,
    String? achievementName,
    List<String>? benefitsUnlocked,
    NotificationPriority priority = NotificationPriority.critical,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_notificationsEnabled || userId != _currentUserId) return;

    final notificationId = _generateNotificationId();

    final item = NotificationQueueItem(
      id: notificationId,
      priority: priority,
      type: NotificationType.tierUpgrade,
      data: {
        'oldTier': oldTier,
        'newTier': newTier,
        'achievementName': achievementName ?? 'Tier Upgrade',
        'benefitsUnlocked': benefitsUnlocked ?? [],
        'metadata': metadata,
      },
      createdAt: DateTime.now(),
      soundEffect: SoundEffectType.fanfare,
      vibrationPattern: VibrationPattern.celebration,
      enableConfetti: true,
      confettiConfig: ConfettiPresets.celebration,
    );

    _addToQueue(item);

    // Track analytics
    _trackNotificationQueued(
      NotificationType.tierUpgrade,
      '${oldTier.name}_to_${newTier.name}',
    );
  }

  /// Queue points earned notification
  Future<void> queuePointsNotification({
    required String userId,
    required int points,
    required String reason,
    NotificationPriority priority = NotificationPriority.normal,
    Duration? delay,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_notificationsEnabled || userId != _currentUserId || points <= 0) {
      return;
    }

    // Don't spam notifications for small point amounts
    if (points < 10) return;

    final notificationId = _generateNotificationId();

    final item = NotificationQueueItem(
      id: notificationId,
      priority: priority,
      type: NotificationType.pointsEarned,
      data: {'points': points, 'reason': reason, 'metadata': metadata},
      createdAt: DateTime.now(),
      delay: delay,
      soundEffect: SoundEffectType.pointsEarned,
      vibrationPattern: VibrationPattern.light,
      enableConfetti: points >= 100,
      confettiConfig: points >= 100 ? ConfettiPresets.gentle : null,
    );

    _addToQueue(item);

    // Track analytics
    _trackNotificationQueued(NotificationType.pointsEarned, reason);
  }

  /// Queue milestone notification
  Future<void> queueMilestoneNotification({
    required String userId,
    required String milestone,
    required String description,
    int? pointsRewarded,
    NotificationPriority priority = NotificationPriority.high,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_notificationsEnabled || userId != _currentUserId) return;

    final notificationId = _generateNotificationId();

    final item = NotificationQueueItem(
      id: notificationId,
      priority: priority,
      type: NotificationType.milestone,
      data: {
        'milestone': milestone,
        'description': description,
        'pointsRewarded': pointsRewarded,
        'metadata': metadata,
      },
      createdAt: DateTime.now(),
      soundEffect: SoundEffectType.milestone,
      vibrationPattern: VibrationPattern.success,
      enableConfetti: true,
      confettiConfig: ConfettiPresets.goldRush,
    );

    _addToQueue(item);

    // Track analytics
    _trackNotificationQueued(NotificationType.milestone, milestone);
  }

  /// Queue custom notification
  Future<void> queueCustomNotification({
    required String userId,
    required String title,
    required String message,
    NotificationPriority priority = NotificationPriority.normal,
    SoundEffectType? soundEffect,
    VibrationPattern? vibrationPattern,
    bool enableConfetti = false,
    ConfettiConfig? confettiConfig,
    Duration? delay,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_notificationsEnabled || userId != _currentUserId) return;

    final notificationId = _generateNotificationId();

    final item = NotificationQueueItem(
      id: notificationId,
      priority: priority,
      type: NotificationType.custom,
      data: {'title': title, 'message': message, 'metadata': metadata},
      createdAt: DateTime.now(),
      delay: delay,
      soundEffect: soundEffect,
      vibrationPattern: vibrationPattern,
      enableConfetti: enableConfetti,
      confettiConfig: confettiConfig,
    );

    _addToQueue(item);

    // Track analytics
    _trackNotificationQueued(NotificationType.custom, title);
  }

  /// Clear notification queue
  void clearQueue() {
    _notificationQueue.clear();
    notifyListeners();
  }

  /// Clear specific notification type from queue
  void clearQueueByType(NotificationType type) {
    _notificationQueue.removeWhere((item) => item.type == type);
    notifyListeners();
  }

  /// Update settings
  Future<void> updateSettings({
    bool? soundEnabled,
    bool? vibrationsEnabled,
    bool? notificationsEnabled,
    double? soundVolume,
    int? maxConcurrentNotifications,
    Duration? notificationDisplayDuration,
  }) async {
    bool changed = false;

    if (soundEnabled != null && soundEnabled != _soundEnabled) {
      _soundEnabled = soundEnabled;
      changed = true;
    }

    if (vibrationsEnabled != null && vibrationsEnabled != _vibrationsEnabled) {
      _vibrationsEnabled = vibrationsEnabled;
      changed = true;
    }

    if (notificationsEnabled != null &&
        notificationsEnabled != _notificationsEnabled) {
      _notificationsEnabled = notificationsEnabled;
      changed = true;
    }

    if (soundVolume != null && soundVolume != _soundVolume) {
      _soundVolume = soundVolume.clamp(0.0, 1.0);
      await _audioPlayer.setVolume(_soundVolume);
      changed = true;
    }

    if (maxConcurrentNotifications != null &&
        maxConcurrentNotifications != _maxConcurrentNotifications) {
      _maxConcurrentNotifications = maxConcurrentNotifications.clamp(1, 10);
      changed = true;
    }

    if (notificationDisplayDuration != null &&
        notificationDisplayDuration != _notificationDisplayDuration) {
      _notificationDisplayDuration = notificationDisplayDuration;
      changed = true;
    }

    if (changed) {
      await _saveUserPreferences();
      notifyListeners();
    }
  }

  /// Generate share content for achievement
  ShareContent generateAchievementShareContent(Achievement achievement) {
    return ShareContent(
      title: 'Achievement Unlocked!',
      description:
          'I just unlocked "${achievement.name}" in Dabbler! ${achievement.description}',
      imageUrl: '', // No iconUrl property available
      deepLinks: {
        'twitter': _generateTwitterShare(achievement),
        'facebook': _generateFacebookShare(achievement),
        'whatsapp': _generateWhatsAppShare(achievement),
      },
      metadata: {
        'achievementId': achievement.id,
        'achievementName': achievement.name,
        'pointsEarned': achievement.points,
        'tier': achievement.tier.name,
      },
    );
  }

  /// Get notification statistics
  Map<String, dynamic> getNotificationStatistics() {
    return {
      'totalNotifications': _notificationCounts.values.fold<int>(
        0,
        (sum, count) => sum + count,
      ),
      'notificationsByType': Map<String, int>.from(_notificationCounts),
      'queueLength': _notificationQueue.length,
      'activeNotifications': _activeNotifications.length,
      'lastNotificationTimes': Map<String, String>.from(
        _lastNotificationTimes.map(
          (key, value) => MapEntry(key, value.toIso8601String()),
        ),
      ),
    };
  }

  // Private methods

  void _addToQueue(NotificationQueueItem item) {
    _notificationQueue.add(item);
    _notificationQueue.sort((a, b) {
      // Sort by priority first, then by creation time
      final priorityComparison = b.priorityScore.compareTo(a.priorityScore);
      if (priorityComparison != 0) return priorityComparison;
      return a.createdAt.compareTo(b.createdAt);
    });
    notifyListeners();
  }

  void _startProcessingTimer() {
    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _processQueue();
    });
  }

  void _processQueue() {
    if (_isProcessing || _notificationQueue.isEmpty) return;
    if (_activeNotifications.length >= _maxConcurrentNotifications) return;

    _isProcessing = true;

    try {
      final readyNotifications = _notificationQueue
          .where((item) => item.isReady)
          .toList();

      for (final item in readyNotifications) {
        if (_activeNotifications.length >= _maxConcurrentNotifications) break;

        _notificationQueue.remove(item);
        _showNotification(item);
      }
    } finally {
      _isProcessing = false;
    }
  }

  void _showNotification(NotificationQueueItem item) {
    _activeNotifications.add(item.id);

    // Play sound effect
    if (_soundEnabled && item.soundEffect != null) {
      _playSoundEffect(item.soundEffect!);
    }

    // Trigger vibration
    if (_vibrationsEnabled && item.vibrationPattern != null) {
      _triggerVibration(item.vibrationPattern!);
    }

    // Show notification UI (this would be handled by the UI layer)
    // For now, we just track it
    _trackNotificationShown(item.type, item.id);

    // Auto-dismiss after duration
    Timer(_notificationDisplayDuration, () {
      _dismissNotification(item.id);
    });
  }

  void _dismissNotification(String notificationId) {
    _activeNotifications.remove(notificationId);
    notifyListeners();
  }

  Future<void> _playSoundEffect(SoundEffectType type) async {
    if (!_soundEnabled) return;

    try {
      String soundFile;

      switch (type) {
        case SoundEffectType.achievement:
          soundFile = 'sounds/achievement.mp3';
          break;
        case SoundEffectType.tierUp:
          soundFile = 'sounds/tier_up.mp3';
          break;
        case SoundEffectType.pointsEarned:
          soundFile = 'sounds/points.mp3';
          break;
        case SoundEffectType.badge:
          soundFile = 'sounds/badge.mp3';
          break;
        case SoundEffectType.milestone:
          soundFile = 'sounds/milestone.mp3';
          break;
        case SoundEffectType.celebration:
          soundFile = 'sounds/celebration.mp3';
          break;
        case SoundEffectType.fanfare:
          soundFile = 'sounds/fanfare.mp3';
          break;
        case SoundEffectType.chime:
          soundFile = 'sounds/chime.mp3';
          break;
      }

      await _audioPlayer.play(AssetSource(soundFile));
    } catch (e) {}
  }

  Future<void> _triggerVibration(VibrationPattern pattern) async {
    if (!_vibrationsEnabled) return;

    try {
      switch (pattern) {
        case VibrationPattern.light:
          await HapticFeedback.lightImpact();
          break;
        case VibrationPattern.medium:
          await HapticFeedback.mediumImpact();
          break;
        case VibrationPattern.heavy:
          await HapticFeedback.heavyImpact();
          break;
        case VibrationPattern.success:
          await HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.lightImpact();
          break;
        case VibrationPattern.celebration:
          for (int i = 0; i < 3; i++) {
            await HapticFeedback.heavyImpact();
            await Future.delayed(const Duration(milliseconds: 150));
          }
          break;
        case VibrationPattern.fanfare:
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 200));
          await HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.lightImpact();
          break;
        case VibrationPattern.custom:
          // Custom patterns would be defined elsewhere
          await HapticFeedback.mediumImpact();
          break;
      }
    } catch (e) {}
  }

  ConfettiConfig _getConfettiConfigForAchievement(Achievement achievement) {
    switch (achievement.tier) {
      case BadgeTier.bronze:
        return ConfettiPresets.gentle;
      case BadgeTier.silver:
        return ConfettiPresets.celebration;
      case BadgeTier.gold:
        return ConfettiPresets.goldRush;
      case BadgeTier.platinum:
        return ConfettiPresets.explosion;
      case BadgeTier.diamond:
        return ConfettiPresets.explosion.copyWith(
          colors: [
            const Color(0xFFB9F2FF),
            const Color(0xFF87CEEB),
            const Color(0xFFE0FFFF),
          ],
        );
    }
  }

  String _generateNotificationId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}';
  }

  void _trackNotificationQueued(NotificationType type, String identifier) {
    final key = '${type.name}_queued';
    _notificationCounts[key] = (_notificationCounts[key] ?? 0) + 1;
    _lastNotificationTimes[identifier] = DateTime.now();
  }

  void _trackNotificationShown(NotificationType type, String notificationId) {
    final key = '${type.name}_shown';
    _notificationCounts[key] = (_notificationCounts[key] ?? 0) + 1;
  }

  Future<void> _loadUserPreferences() async {
    // This would load from shared preferences or user settings
    // For now, using defaults
  }

  Future<void> _saveUserPreferences() async {
    // This would save to shared preferences or user settings
  }

  Future<void> _setupAudioPlayer() async {
    await _audioPlayer.setVolume(_soundVolume);
  }

  String _generateTwitterShare(Achievement achievement) {
    final text = Uri.encodeComponent(
      'Just unlocked "${achievement.name}" in Dabbler! 🏆 ${achievement.description}',
    );
    return 'https://twitter.com/intent/tweet?text=$text&hashtags=Dabbler,Achievement';
  }

  String _generateFacebookShare(Achievement achievement) {
    final quote = Uri.encodeComponent(
      'Just unlocked "${achievement.name}" in Dabbler!',
    );
    return 'https://www.facebook.com/sharer/sharer.php?quote=$quote';
  }

  String _generateWhatsAppShare(Achievement achievement) {
    final text = Uri.encodeComponent(
      'Just unlocked "${achievement.name}" in Dabbler! 🏆 ${achievement.description}',
    );
    return 'https://wa.me/?text=$text';
  }
}
