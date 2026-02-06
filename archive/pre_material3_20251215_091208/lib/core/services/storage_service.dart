import 'dart:convert';
import 'dart:async';

class StorageService {
  static const String _draftPrefix = 'game_draft_';
  static const String _draftsListKey = 'saved_drafts';

  // Simulate shared preferences storage with an in-memory map for demo
  static final Map<String, String> _storage = {};

  Future<void> saveDraft(String draftId, Map<String, dynamic> draftData) async {
    try {
      final key = '$_draftPrefix$draftId';
      _storage[key] = jsonEncode(draftData);

      // Update drafts list
      final drafts = await getSavedDrafts();
      final existingIndex = drafts.indexWhere(
        (draft) => draft['draftId'] == draftId,
      );

      final draftInfo = {
        'draftId': draftId,
        'selectedSport': draftData['selectedSport'],
        'lastSaved': draftData['lastSaved'],
        'gameTitle': draftData['gameTitle'] ?? 'Untitled Game',
      };

      if (existingIndex >= 0) {
        drafts[existingIndex] = draftInfo;
      } else {
        drafts.add(draftInfo);
      }

      _storage[_draftsListKey] = jsonEncode(drafts);

      // Simulate async operation
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      throw Exception('Failed to save draft: $e');
    }
  }

  Future<Map<String, dynamic>?> loadDraft(String draftId) async {
    try {
      final key = '$_draftPrefix$draftId';
      final data = _storage[key];

      if (data != null) {
        return jsonDecode(data) as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      throw Exception('Failed to load draft: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSavedDrafts() async {
    try {
      final data = _storage[_draftsListKey];

      if (data != null) {
        final List<dynamic> drafts = jsonDecode(data);
        return drafts.cast<Map<String, dynamic>>();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> deleteDraft(String draftId) async {
    try {
      final key = '$_draftPrefix$draftId';
      _storage.remove(key);

      // Update drafts list
      final drafts = await getSavedDrafts();
      drafts.removeWhere((draft) => draft['draftId'] == draftId);
      _storage[_draftsListKey] = jsonEncode(drafts);

      // Simulate async operation
      await Future.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      throw Exception('Failed to delete draft: $e');
    }
  }

  Future<void> clearAllDrafts() async {
    try {
      // Remove all draft entries
      final keysToRemove = _storage.keys
          .where((key) => key.startsWith(_draftPrefix))
          .toList();
      for (final key in keysToRemove) {
        _storage.remove(key);
      }

      // Clear drafts list
      _storage.remove(_draftsListKey);

      // Simulate async operation
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      throw Exception('Failed to clear drafts: $e');
    }
  }
}
