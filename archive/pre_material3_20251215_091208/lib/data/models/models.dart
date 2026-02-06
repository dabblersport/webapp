// Barrel file for all data models
// This file exports core model files for convenience
// Note: Some models have naming conflicts and must be imported directly

// Core models - only game_creation to avoid GameFormat conflict
export 'core/game_creation_model.dart';

// Authentication models
export 'authentication/auth_response_model.dart';
export 'authentication/auth_session.dart';
export 'authentication/user.dart';
export 'authentication/user_model.dart';

// Profile models
export 'profile/privacy_settings.dart';
export 'profile/privacy_settings_model.dart';
export 'profile/profile_statistics.dart';
export 'profile/profile_statistics_model.dart';
export 'profile/sport_model.dart';
export 'profile/sports_profile.dart';
export 'profile/sports_profile_model.dart';
export 'profile/user_preferences.dart'
    hide TimeSlot; // TimeSlot also in game_creation_model
export 'profile/user_preferences_model.dart';
export 'profile/user_profile.dart';
export 'profile/user_settings.dart';
export 'profile/user_settings_model.dart';

// Games models
export 'games/booking.dart';
export 'games/booking_model.dart';
export 'games/game.dart';
export 'games/game_model.dart';
export 'games/player.dart';
export 'games/player_model.dart';
export 'games/sport_config.dart';
export 'games/sport_config_model.dart';
export 'games/venue.dart';
export 'games/venue_model.dart';

// Social models
export 'social/block_record_model.dart';
export 'social/chat_message.dart';
export 'social/chat_message_model.dart';
export 'social/comment_model.dart';
export 'social/conversation.dart';
export 'social/conversation_model.dart';
export 'social/friend.dart';
export 'social/friend_model.dart';
export 'social/friend_request.dart';
export 'social/friend_request_model.dart';
export 'social/post.dart';
export 'social/post_model.dart';
export 'social/reaction_model.dart';
export 'social/social_feed_model.dart';

// Rewards models
export 'rewards/achievement.dart';
export 'rewards/achievement_model.dart';
export 'rewards/badge.dart';
export 'rewards/badge_model.dart';
export 'rewards/badge_tier.dart';
export 'rewards/leaderboard_entry.dart' hide RankMovement;
export 'rewards/leaderboard_model.dart' hide TierLevel;
export 'rewards/points_transaction.dart';
export 'rewards/tier.dart' hide TierLevel;
export 'rewards/tier_model.dart';
export 'rewards/user_progress.dart';
export 'rewards/user_progress_model.dart';

// Payments models
export 'payments/payment_method.dart';
export 'payments/payment_method_model.dart';

// Notifications models
export 'notifications/notification.dart';
export 'notifications/notification_model.dart';
