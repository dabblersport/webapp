import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'package:dabbler/data/models/rewards/achievement.dart';
import 'package:dabbler/data/models/rewards/user_progress.dart';
import 'package:dabbler/data/models/rewards/point_transaction.dart';
import 'package:dabbler/data/models/rewards/badge_tier.dart';

import 'package:dabbler/data/models/rewards/achievement_model.dart';
import 'package:dabbler/data/models/rewards/user_progress_model.dart';
import 'package:dabbler/data/models/rewards/badge_model.dart';
import 'package:dabbler/data/models/rewards/tier_model.dart';

/// Local SQLite data source for rewards system
/// Handles offline storage, caching, and sync status tracking
class AchievementsLocalDataSource {
  static Database? _database;
  static const String _dbName = 'rewards_database.db';
  static const int _dbVersion = 1;

  // Table names
  static const String _achievementsTable = 'achievements';
  static const String _userProgressTable = 'user_progress';
  static const String _pointTransactionsTable = 'point_transactions';
  static const String _userBadgesTable = 'user_badges';
  static const String _userTiersTable = 'user_tiers';
  static const String _eventQueueTable = 'event_queue';
  static const String _syncStatusTable = 'sync_status';
  static const String _cacheMetadataTable = 'cache_metadata';

  /// Get database instance (singleton)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database with tables
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createTables,
      onUpgrade: _upgradeDatabase,
    );
  }

  /// Create all required tables
  Future<void> _createTables(Database db, int version) async {
    // Achievements table
    await db.execute('''
      CREATE TABLE $_achievementsTable (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        rarity TEXT NOT NULL,
        points INTEGER NOT NULL,
        is_hidden INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        criteria TEXT NOT NULL,
        requirements TEXT NOT NULL,
        rewards TEXT NOT NULL,
        icon_url TEXT,
        badge_url TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        expires_at TEXT,
        metadata TEXT,
        cached_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        is_dirty INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // User progress table
    await db.execute('''
      CREATE TABLE $_userProgressTable (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        achievement_id TEXT NOT NULL,
        current_progress TEXT NOT NULL,
        required_progress TEXT NOT NULL,
        status TEXT NOT NULL,
        completed_at TEXT,
        expires_at TEXT,
        started_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        metadata TEXT,
        cached_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        is_dirty INTEGER NOT NULL DEFAULT 0,
        UNIQUE(user_id, achievement_id)
      )
    ''');

    // Point transactions table
    await db.execute('''
      CREATE TABLE $_pointTransactionsTable (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        base_points INTEGER NOT NULL,
        final_points INTEGER NOT NULL,
        running_balance INTEGER NOT NULL,
        type TEXT NOT NULL,
        description TEXT NOT NULL,
        created_at TEXT NOT NULL,
        metadata TEXT,
        cached_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        is_dirty INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // User badges table
    await db.execute('''
      CREATE TABLE $_userBadgesTable (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        badge_id TEXT NOT NULL,
        tier TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        icon_url TEXT,
        rarity TEXT NOT NULL,
        requirements TEXT NOT NULL,
        is_showcased INTEGER NOT NULL DEFAULT 0,
        showcase_order INTEGER,
        earned_at TEXT NOT NULL,
        metadata TEXT,
        cached_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        is_dirty INTEGER NOT NULL DEFAULT 0,
        UNIQUE(user_id, badge_id)
      )
    ''');

    // User tiers table
    await db.execute('''
      CREATE TABLE $_userTiersTable (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL UNIQUE,
        current_tier INTEGER NOT NULL,
        current_points INTEGER NOT NULL,
        points_to_next INTEGER NOT NULL,
        tier_name TEXT NOT NULL,
        tier_color TEXT NOT NULL,
        benefits TEXT NOT NULL,
        multiplier REAL NOT NULL,
        updated_at TEXT NOT NULL,
        cached_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        is_dirty INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Event queue table for offline tracking
    await db.execute('''
      CREATE TABLE $_eventQueueTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        event_data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_retry_at TEXT,
        error_message TEXT
      )
    ''');

    // Sync status table
    await db.execute('''
      CREATE TABLE $_syncStatusTable (
        table_name TEXT PRIMARY KEY,
        last_sync_at TEXT NOT NULL,
        sync_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        last_error_at TEXT
      )
    ''');

    // Cache metadata table
    await db.execute('''
      CREATE TABLE $_cacheMetadataTable (
        cache_key TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        expires_at TEXT,
        size_bytes INTEGER NOT NULL DEFAULT 0,
        access_count INTEGER NOT NULL DEFAULT 0,
        last_accessed_at TEXT NOT NULL
      )
    ''');

    // Create indexes for better performance
    await _createIndexes(db);
  }

  /// Create database indexes
  Future<void> _createIndexes(Database db) async {
    // Achievement indexes
    await db.execute(
      'CREATE INDEX idx_achievements_category ON $_achievementsTable(category)',
    );
    await db.execute(
      'CREATE INDEX idx_achievements_is_hidden ON $_achievementsTable(is_hidden)',
    );
    await db.execute(
      'CREATE INDEX idx_achievements_cached_at ON $_achievementsTable(cached_at)',
    );

    // User progress indexes
    await db.execute(
      'CREATE INDEX idx_user_progress_user_id ON $_userProgressTable(user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_user_progress_achievement_id ON $_userProgressTable(achievement_id)',
    );
    await db.execute(
      'CREATE INDEX idx_user_progress_status ON $_userProgressTable(status)',
    );
    await db.execute(
      'CREATE INDEX idx_user_progress_updated_at ON $_userProgressTable(updated_at)',
    );

    // Point transactions indexes
    await db.execute(
      'CREATE INDEX idx_point_transactions_user_id ON $_pointTransactionsTable(user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_point_transactions_type ON $_pointTransactionsTable(type)',
    );
    await db.execute(
      'CREATE INDEX idx_point_transactions_created_at ON $_pointTransactionsTable(created_at)',
    );

    // Event queue indexes
    await db.execute(
      'CREATE INDEX idx_event_queue_status ON $_eventQueueTable(status)',
    );
    await db.execute(
      'CREATE INDEX idx_event_queue_user_id ON $_eventQueueTable(user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_event_queue_created_at ON $_eventQueueTable(created_at)',
    );
  }

  /// Handle database upgrades
  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Handle migrations between versions
    if (oldVersion < newVersion) {
      // Add migration logic here when needed
      await _createTables(db, newVersion);
    }
  }

  // =============================================================================
  // ACHIEVEMENTS OPERATIONS
  // =============================================================================

  /// Cache achievements from remote source
  Future<void> cacheAchievements(List<AchievementModel> achievements) async {
    final db = await database;
    final batch = db.batch();

    for (final achievement in achievements) {
      batch.insert(
        _achievementsTable,
        _achievementToMap(achievement),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    await _updateCacheMetadata('achievements', achievements.length);
  }

  /// Get cached achievements with filters
  Future<List<AchievementModel>> getCachedAchievements({
    AchievementCategory? category,
    bool includeHidden = false,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (category != null) {
      whereClause += 'category = ?';
      whereArgs.add(category.name);
    }

    if (!includeHidden) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'is_hidden = ?';
      whereArgs.add(0);
    }

    final result = await db.query(
      _achievementsTable,
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at DESC',
    );

    return result.map((map) => _achievementFromMap(map)).toList();
  }

  /// Get single achievement by ID
  Future<AchievementModel?> getAchievementById(String achievementId) async {
    final db = await database;
    final result = await db.query(
      _achievementsTable,
      where: 'id = ?',
      whereArgs: [achievementId],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return _achievementFromMap(result.first);
  }

  /// Cache single achievement
  Future<void> cacheAchievement(AchievementModel achievement) async {
    final db = await database;
    await db.insert(
      _achievementsTable,
      _achievementToMap(achievement),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _updateCacheMetadata('achievement_${achievement.id}', 1);
  }

  /// Search cached achievements
  Future<List<AchievementModel>> searchAchievements(
    String query, {
    AchievementCategory? category,
  }) async {
    final db = await database;
    String whereClause = '(title LIKE ? OR description LIKE ?)';
    List<dynamic> whereArgs = ['%$query%', '%$query%'];

    if (category != null) {
      whereClause += ' AND category = ?';
      whereArgs.add(category.name);
    }

    final result = await db.query(
      _achievementsTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: 20,
    );

    return result.map((map) => _achievementFromMap(map)).toList();
  }

  // =============================================================================
  // USER PROGRESS OPERATIONS
  // =============================================================================

  /// Cache user progress data
  Future<void> cacheUserProgress(
    String userId,
    List<UserProgressModel> progress,
  ) async {
    final db = await database;
    final batch = db.batch();

    for (final prog in progress) {
      batch.insert(
        _userProgressTable,
        _userProgressToMap(prog),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    await _updateCacheMetadata('progress_$userId', progress.length);
  }

  /// Get user progress with filters
  Future<List<UserProgressModel>> getUserProgress(
    String userId, {
    ProgressStatus? status,
    List<String>? achievementIds,
  }) async {
    final db = await database;
    String whereClause = 'user_id = ?';
    List<dynamic> whereArgs = [userId];

    if (status != null) {
      whereClause += ' AND status = ?';
      whereArgs.add(status.name);
    }

    if (achievementIds != null && achievementIds.isNotEmpty) {
      final placeholders = achievementIds.map((_) => '?').join(',');
      whereClause += ' AND achievement_id IN ($placeholders)';
      whereArgs.addAll(achievementIds);
    }

    final result = await db.query(
      _userProgressTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
    );

    return result.map((map) => _userProgressFromMap(map)).toList();
  }

  /// Get progress for specific achievement
  Future<UserProgressModel?> getUserProgressForAchievement(
    String userId,
    String achievementId,
  ) async {
    final db = await database;
    final result = await db.query(
      _userProgressTable,
      where: 'user_id = ? AND achievement_id = ?',
      whereArgs: [userId, achievementId],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return _userProgressFromMap(result.first);
  }

  /// Cache user progress for specific achievement
  Future<void> cacheUserProgressForAchievement(
    String userId,
    String achievementId,
    UserProgressModel progress,
  ) async {
    final db = await database;
    await db.insert(
      _userProgressTable,
      _userProgressToMap(progress),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _updateCacheMetadata('progress_${userId}_$achievementId', 1);
  }

  /// Mark progress as dirty (needs sync)
  Future<void> markProgressAsDirty(String userId, String achievementId) async {
    final db = await database;
    await db.update(
      _userProgressTable,
      {'is_dirty': 1},
      where: 'user_id = ? AND achievement_id = ?',
      whereArgs: [userId, achievementId],
    );
  }

  // =============================================================================
  // POINT TRANSACTIONS OPERATIONS
  // =============================================================================

  /// Cache point transactions
  Future<void> cachePointTransactions(
    String userId,
    List<PointTransaction> transactions,
  ) async {
    final db = await database;
    final batch = db.batch();

    for (final transaction in transactions) {
      batch.insert(
        _pointTransactionsTable,
        _pointTransactionToMap(transaction),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    await _updateCacheMetadata('transactions_$userId', transactions.length);
  }

  /// Get cached point transactions
  Future<List<PointTransaction>> getPointTransactions(
    String userId, {
    TransactionType? type,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    String whereClause = 'user_id = ?';
    List<dynamic> whereArgs = [userId];

    if (type != null) {
      whereClause += ' AND type = ?';
      whereArgs.add(type.name);
    }

    final result = await db.query(
      _pointTransactionsTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    return result.map((map) => _pointTransactionFromMap(map)).toList();
  }

  // =============================================================================
  // BADGE OPERATIONS
  // =============================================================================

  /// Cache user badges
  Future<void> cacheUserBadges(String userId, List<BadgeModel> badges) async {
    final db = await database;
    final batch = db.batch();

    for (final badge in badges) {
      batch.insert(
        _userBadgesTable,
        _badgeToMap(badge, userId),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    await _updateCacheMetadata('badges_$userId', badges.length);
  }

  /// Get cached user badges
  Future<List<BadgeModel>> getUserBadges(
    String userId, {
    BadgeTier? tier,
    bool showcaseOnly = false,
  }) async {
    final db = await database;
    String whereClause = 'user_id = ?';
    List<dynamic> whereArgs = [userId];

    if (tier != null) {
      whereClause += ' AND tier = ?';
      whereArgs.add(tier.name);
    }

    if (showcaseOnly) {
      whereClause += ' AND is_showcased = ?';
      whereArgs.add(1);
    }

    final result = await db.query(
      _userBadgesTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: showcaseOnly
          ? 'showcase_order ASC, earned_at DESC'
          : 'earned_at DESC',
    );

    return result.map((map) => _badgeFromMap(map)).toList();
  }

  /// Update badge showcase status
  Future<void> updateBadgeShowcase(
    String userId,
    String badgeId,
    bool isShowcased, {
    int? showcaseOrder,
  }) async {
    final db = await database;
    await db.update(
      _userBadgesTable,
      {
        'is_showcased': isShowcased ? 1 : 0,
        'showcase_order': showcaseOrder,
        'is_dirty': 1, // Mark as needing sync
      },
      where: 'user_id = ? AND badge_id = ?',
      whereArgs: [userId, badgeId],
    );
  }

  // =============================================================================
  // TIER OPERATIONS
  // =============================================================================

  /// Cache user tier
  Future<void> cacheUserTier(String userId, TierModel tier) async {
    final db = await database;
    await db.insert(
      _userTiersTable,
      _tierToMap(tier, userId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _updateCacheMetadata('tier_$userId', 1);
  }

  /// Get cached user tier
  Future<TierModel?> getUserTier(String userId) async {
    final db = await database;
    final result = await db.query(
      _userTiersTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return _tierFromMap(result.first);
  }

  // =============================================================================
  // EVENT QUEUE OPERATIONS
  // =============================================================================

  /// Queue event for later processing
  Future<void> queueEvent(Map<String, dynamic> event) async {
    final db = await database;
    await db.insert(_eventQueueTable, {
      'user_id': event['userId'],
      'event_type': event['type'],
      'event_data': jsonEncode(event['data']),
      'created_at': event['timestamp'] ?? DateTime.now().toIso8601String(),
      'status': 'pending',
      'retry_count': 0,
    });
  }

  /// Get queued events for processing
  Future<List<Map<String, dynamic>>> getQueuedEvents({int limit = 50}) async {
    final db = await database;
    final result = await db.query(
      _eventQueueTable,
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
      limit: limit,
    );

    return result
        .map(
          (row) => {
            'id': row['id'],
            'userId': row['user_id'],
            'type': row['event_type'],
            'data': jsonDecode(row['event_data'] as String),
            'timestamp': row['created_at'],
            'retryCount': row['retry_count'],
          },
        )
        .toList();
  }

  /// Mark event as processed
  Future<void> markEventAsProcessed(int eventId) async {
    final db = await database;
    await db.update(
      _eventQueueTable,
      {'status': 'processed'},
      where: 'id = ?',
      whereArgs: [eventId],
    );
  }

  /// Mark event as failed
  Future<void> markEventAsFailed(int eventId, String errorMessage) async {
    final db = await database;
    await db.update(
      _eventQueueTable,
      {
        'status': 'failed',
        'error_message': errorMessage,
        'retry_count': 'retry_count + 1',
        'last_retry_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [eventId],
    );
  }

  /// Get count of queued events
  Future<int> getQueuedEventsCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_eventQueueTable WHERE status = ?',
      ['pending'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // =============================================================================
  // SYNC STATUS OPERATIONS
  // =============================================================================

  /// Update sync status for a table
  Future<void> updateSyncStatus(String tableName) async {
    final db = await database;
    await db.insert(_syncStatusTable, {
      'table_name': tableName,
      'last_sync_at': DateTime.now().toIso8601String(),
      'sync_count': 'sync_count + 1',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get sync status for a table
  Future<Map<String, dynamic>?> getSyncStatus(String tableName) async {
    final db = await database;
    final result = await db.query(
      _syncStatusTable,
      where: 'table_name = ?',
      whereArgs: [tableName],
      limit: 1,
    );

    return result.isEmpty ? null : result.first;
  }

  /// Get all sync statuses
  Future<Map<String, dynamic>> getAllSyncStatuses() async {
    final db = await database;
    final result = await db.query(_syncStatusTable);

    final statuses = <String, dynamic>{};
    for (final row in result) {
      statuses[row['table_name'] as String] = {
        'lastSyncAt': row['last_sync_at'],
        'syncCount': row['sync_count'],
        'lastError': row['last_error'],
        'lastErrorAt': row['last_error_at'],
      };
    }

    return statuses;
  }

  // =============================================================================
  // CACHE MANAGEMENT OPERATIONS
  // =============================================================================

  /// Update cache metadata
  Future<void> _updateCacheMetadata(String cacheKey, int itemCount) async {
    final db = await database;
    await db.insert(_cacheMetadataTable, {
      'cache_key': cacheKey,
      'created_at': DateTime.now().toIso8601String(),
      'expires_at': DateTime.now()
          .add(const Duration(hours: 24))
          .toIso8601String(),
      'size_bytes': itemCount * 1024, // Rough estimate
      'access_count': 1,
      'last_accessed_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStatistics() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_items,
        SUM(size_bytes) as total_size,
        MIN(created_at) as oldest_item,
        MAX(created_at) as newest_item
      FROM $_cacheMetadataTable
    ''');

    return result.isEmpty ? {} : result.first;
  }

  /// Clear cache for specific key pattern
  Future<void> clearCacheByPattern(String pattern) async {
    final db = await database;
    await db.delete(
      _cacheMetadataTable,
      where: 'cache_key LIKE ?',
      whereArgs: ['%$pattern%'],
    );
  }

  /// Clear all cache
  Future<void> clearCache() async {
    final db = await database;
    final batch = db.batch();

    batch.delete(_achievementsTable);
    batch.delete(_userProgressTable);
    batch.delete(_pointTransactionsTable);
    batch.delete(_userBadgesTable);
    batch.delete(_userTiersTable);
    batch.delete(_cacheMetadataTable);

    await batch.commit(noResult: true);
  }

  /// Get cache size in bytes
  Future<int> getCacheSize() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(size_bytes) as total_size FROM $_cacheMetadataTable',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Clean expired cache entries
  Future<void> cleanExpiredCache() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // Get expired cache keys
    final expiredKeys = await db.query(
      _cacheMetadataTable,
      columns: ['cache_key'],
      where: 'expires_at < ?',
      whereArgs: [now],
    );

    // Delete expired cache data based on cache key patterns
    final batch = db.batch();
    for (final row in expiredKeys) {
      final cacheKey = row['cache_key'] as String;

      if (cacheKey.startsWith('achievements')) {
        // Could implement more granular cleanup
      } else if (cacheKey.startsWith('progress_')) {
        // Clean specific user progress
      }
    }

    // Delete expired metadata
    batch.delete(
      _cacheMetadataTable,
      where: 'expires_at < ?',
      whereArgs: [now],
    );

    await batch.commit(noResult: true);
  }

  // =============================================================================
  // DATA CONVERSION HELPERS
  // =============================================================================

  Map<String, dynamic> _achievementToMap(AchievementModel achievement) {
    return {
      'id': achievement.id,
      'title': achievement.name,
      'description': achievement.description,
      'category': achievement.category.name,
      'difficulty': achievement.tier.name,
      'rarity': achievement.tier.name,
      'points': achievement.points,
      'is_hidden': false, // Use isActive instead
      'is_active': achievement.isActive ? 1 : 0,
      'criteria': jsonEncode(achievement.criteria),
      'requirements': jsonEncode(achievement.prerequisites),
      'rewards': jsonEncode({'points': achievement.points}),
      'icon_url': null, // Not available in model
      'badge_url': null, // Not available in model
      'created_at': achievement.createdAt.toIso8601String(),
      'updated_at':
          achievement.updatedAt?.toIso8601String() ??
          achievement.createdAt.toIso8601String(),
      'expires_at': achievement.availableUntil?.toIso8601String(),
      'metadata': jsonEncode({}),
      'cached_at': DateTime.now().toIso8601String(),
      'is_dirty': 0,
    };
  }

  AchievementModel _achievementFromMap(Map<String, dynamic> map) {
    return AchievementModel.fromJson({
      'id': map['id'],
      'code': map['id'], // Use id as code
      'name': map['title'],
      'description': map['description'],
      'type': 'standard',
      'category': map['category'],
      'tier': map['difficulty'],
      'criteria': jsonDecode(map['criteria']),
      'points': map['points'],
      'prerequisites': jsonDecode(map['requirements'] ?? '[]'),
      'available_from': null,
      'available_until': map['expires_at'],
      'is_active': map['is_active'] == 1,
      'created_at': map['created_at'],
      'updated_at': map['updated_at'],
    });
  }

  Map<String, dynamic> _userProgressToMap(UserProgressModel progress) {
    return {
      'id': progress.id,
      'user_id': progress.userId,
      'achievement_id': progress.achievementId,
      'current_progress': jsonEncode(progress.currentProgress),
      'required_progress': jsonEncode(progress.requiredProgress),
      'status': progress.status.name,
      'completed_at': progress.completedAt?.toIso8601String(),
      'expires_at': progress.expiresAt?.toIso8601String(),
      'started_at': progress.startedAt.toIso8601String(),
      'updated_at': progress.updatedAt.toIso8601String(),
      'metadata': jsonEncode(progress.metadata ?? {}),
      'cached_at': DateTime.now().toIso8601String(),
      'is_dirty': 0,
    };
  }

  UserProgressModel _userProgressFromMap(Map<String, dynamic> map) {
    return UserProgressModel.fromJson({
      'id': map['id'],
      'user_id': map['user_id'],
      'achievement_id': map['achievement_id'],
      'current_progress': jsonDecode(map['current_progress']),
      'required_progress': jsonDecode(map['required_progress']),
      'status': map['status'],
      'completed_at': map['completed_at'],
      'expires_at': map['expires_at'],
      'started_at': map['started_at'],
      'updated_at': map['updated_at'],
      'metadata': jsonDecode(map['metadata'] ?? '{}'),
    });
  }

  Map<String, dynamic> _pointTransactionToMap(PointTransaction transaction) {
    return {
      'id': transaction.id,
      'user_id': transaction.userId,
      'base_points': transaction.basePoints,
      'final_points': transaction.finalPoints,
      'running_balance': transaction.runningBalance,
      'type': transaction.type.name,
      'description': transaction.description,
      'created_at': transaction.createdAt.toIso8601String(),
      'metadata': jsonEncode(transaction.metadata),
      'cached_at': DateTime.now().toIso8601String(),
      'is_dirty': 0,
    };
  }

  PointTransaction _pointTransactionFromMap(Map<String, dynamic> map) {
    return PointTransaction(
      id: map['id'],
      userId: map['user_id'],
      basePoints: map['base_points'],
      finalPoints: map['final_points'],
      runningBalance: map['running_balance'],
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.achievement,
      ),
      description: map['description'],
      createdAt: DateTime.parse(map['created_at']),
      metadata: jsonDecode(map['metadata'] ?? '{}'),
    );
  }

  Map<String, dynamic> _badgeToMap(BadgeModel badge, String userId) {
    return {
      'id': badge.id,
      'user_id': userId,
      'badge_id': badge.id,
      'tier': badge.tier.name,
      'name': badge.name,
      'description': badge.unlockMessage,
      'icon_url': badge.iconUrl,
      'rarity': badge.tier.name,
      'requirements': jsonEncode({'achievement_id': badge.achievementId}),
      'is_showcased': badge.isShowcased ? 1 : 0,
      'showcase_order': badge.showcaseOrder,
      'earned_at': badge.createdAt.toIso8601String(),
      'metadata': jsonEncode(badge.collectionMetadata),
      'cached_at': DateTime.now().toIso8601String(),
      'is_dirty': 0,
    };
  }

  BadgeModel _badgeFromMap(Map<String, dynamic> map) {
    final requirements = jsonDecode(map['requirements'] ?? '{}');
    return BadgeModel.fromJson({
      'id': map['badge_id'],
      'name': map['name'],
      'tier': map['tier'],
      'icon_url': map['icon_url'],
      'animated_icon_url': null,
      'rarity_score': 1.0,
      'unlock_message': map['description'],
      'achievement_id': requirements['achievement_id'] ?? '',
      'style': 'classic',
      'animation': 'none',
      'design_metadata': {},
      'is_limited_edition': false,
      'max_owners': null,
      'current_owners': 0,
      'created_at': map['earned_at'],
      'updated_at': map['earned_at'],
      'times_earned': 1,
      'first_earned_at': map['earned_at'],
      'last_earned_at': map['earned_at'],
      'is_showcased': map['is_showcased'] == 1,
      'showcase_order': map['showcase_order'] ?? 0,
      'collection_metadata': jsonDecode(map['metadata'] ?? '{}'),
    });
  }

  Map<String, dynamic> _tierToMap(TierModel tier, String userId) {
    return {
      'id': tier.id,
      'user_id': userId,
      'current_tier': tier.level.level,
      'current_points': tier.currentPoints,
      'points_to_next': tier.pointsInTier,
      'tier_name': tier.level.displayName,
      'tier_color': '#6366f1', // Default tier color
      'benefits': jsonEncode(tier.benefits),
      'multiplier': 1.0, // Default multiplier
      'updated_at': tier.updatedAt.toIso8601String(),
      'cached_at': DateTime.now().toIso8601String(),
      'is_dirty': 0,
    };
  }

  TierModel _tierFromMap(Map<String, dynamic> map) {
    return TierModel.fromJson({
      'id': map['id'],
      'user_id': map['user_id'],
      'level': map['current_tier'],
      'current_points': map['current_points'],
      'points_in_tier': map['points_to_next'],
      'benefits': jsonDecode(map['benefits'] ?? '{}'),
      'privileges': {},
      'customization': {},
      'achieved_at': DateTime.now().toIso8601String(),
      'previous_tier_at': null,
      'has_notification_sent': false,
      'created_at': map['cached_at'],
      'updated_at': map['updated_at'],
      'benefits_breakdown': {},
      'privileges_breakdown': {},
      'progress_data': {},
      'comparison_data': {},
    });
  }

  /// Dispose and close database
  Future<void> dispose() async {
    final db = _database;
    _database = null;
    await db?.close();
  }
}
