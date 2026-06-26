import 'package:flutter/material.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/data/models/core/game_creation_model.dart';
import '../services/storage_service.dart';
import '../../services/moderation_service.dart';
import '../../routes/route_arguments.dart';

class GameCreationViewModel extends ChangeNotifier {
  GameCreationModel _state = GameCreationModel.initial();
  final StorageService _storageService = StorageService();

  // DB-loaded sports and variants
  List<Map<String, dynamic>> _dbSports = [];
  List<Map<String, dynamic>> _dbVariants = [];
  bool _sportsLoading = false;
  String? _sportsError;

  // Available venues loaded from venue_spaces
  List<VenueSlot> _availableVenues = [];
  List<String> _recentTeammates = [];

  GameCreationViewModel() {
    loadDbSports();
  }

  GameCreationModel get state => _state;
  List<Map<String, dynamic>> get dbSports => List.unmodifiable(_dbSports);
  List<Map<String, dynamic>> get dbVariants => List.unmodifiable(_dbVariants);
  bool get sportsLoading => _sportsLoading;
  String? get sportsError => _sportsError;
  List<VenueSlot> get availableVenues => List.unmodifiable(_availableVenues);
  List<String> get recentTeammates => List.unmodifiable(_recentTeammates);

  // Step navigation
  void nextStep() {
    if (_state.canProceedToNextStep && _state.nextStep != null) {
      _state = _state.copyWith(currentStep: _state.nextStep);

      // Load data for next step
      _loadDataForCurrentStep();
      notifyListeners();
    }
  }

  void previousStep() {
    if (_state.previousStep != null) {
      _state = _state.copyWith(currentStep: _state.previousStep);
      notifyListeners();
    }
  }

  void goToStep(GameCreationStep step) {
    _state = _state.copyWith(currentStep: step);
    _loadDataForCurrentStep();
    notifyListeners();
  }

  // Save draft functionality with step-specific state
  Future<void> saveAsDraft({Map<String, dynamic>? stepLocalState}) async {
    if (!_state.canSaveAsDraft) return;

    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    try {
      final draftId = _state.draftId ?? _generateDraftId();
      final draftData = _state.copyWith(
        draftId: draftId,
        lastSaved: DateTime.now(),
        isDraft: true,
        stepLocalState: stepLocalState,
      );

      await _storageService.saveDraft(draftId, draftData.toJson());

      _state = draftData.copyWith(isLoading: false);
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: 'Failed to save draft: $e',
      );
      notifyListeners();
    }
  }

  // Auto-save draft when significant changes are made
  Future<void> autoSaveDraft({Map<String, dynamic>? stepLocalState}) async {
    if (!_state.canSaveAsDraft) return;

    // Auto-save without showing loading state
    try {
      final draftId = _state.draftId ?? _generateDraftId();
      final draftData = _state.copyWith(
        draftId: draftId,
        lastSaved: DateTime.now(),
        isDraft: true,
        stepLocalState: stepLocalState,
      );

      await _storageService.saveDraft(draftId, draftData.toJson());
      _state = draftData;
      // Don't notify listeners for auto-save to avoid UI flicker
    } catch (e) {
      // Silently handle auto-save errors
    }
  }

  Future<List<Map<String, dynamic>>> getSavedDrafts() async {
    try {
      return await _storageService.getSavedDrafts();
    } catch (e) {
      return [];
    }
  }

  Future<void> loadDraft(String draftId) async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    try {
      final draftData = await _storageService.loadDraft(draftId);
      if (draftData != null) {
        // Reconstruct GameFormat from saved data
        GameFormat? reconstructedFormat;
        if (draftData['selectedSport'] != null &&
            draftData['selectedFormat'] != null) {
          reconstructedFormat = _reconstructGameFormat(
            draftData['selectedSport'],
            draftData['selectedFormat'],
          );
        }

        _state = _state.copyWith(
          // Restore current step
          currentStep: draftData['currentStep'] != null
              ? GameCreationStep.values.firstWhere(
                  (e) => e.name == draftData['currentStep'],
                )
              : GameCreationStep.sportAndFormat,

          // Sport & Format Selection
          selectedSport: draftData['selectedSport'],
          selectedFormat: reconstructedFormat,
          skillLevel: draftData['skillLevel'],
          maxPlayers: draftData['maxPlayers'],
          gameDuration: draftData['gameDuration'],
          gameType: draftData['gameType'],

          // Venue & Slot Selection
          selectedVenueSlot: draftData['selectedVenueSlot'] != null
              ? _reconstructVenueSlot(draftData['selectedVenueSlot'])
              : null,
          amenityFilters: draftData['amenityFilters']?.cast<String>(),

          // Participation & Payment
          participationMode: draftData['participationMode'] != null
              ? ParticipationMode.values.firstWhere(
                  (e) => e.name == draftData['participationMode'],
                )
              : null,
          paymentSplit: draftData['paymentSplit'] != null
              ? PaymentSplit.values.firstWhere(
                  (e) => e.name == draftData['paymentSplit'],
                )
              : null,
          gameDescription: draftData['gameDescription'],
          allowWaitlist: draftData['allowWaitlist'],
          maxWaitlistSize: draftData['maxWaitlistSize'],
          allowSpectators: draftData['allowSpectators'],
          totalCost: draftData['totalCost'],

          // Player Invitation
          invitedPlayerIds: draftData['invitedPlayerIds']?.cast<String>(),
          invitedPlayerEmails: draftData['invitedPlayerEmails']?.cast<String>(),
          allowFriendsToInvite: draftData['allowFriendsToInvite'],
          invitationMessage: draftData['invitationMessage'],

          // Review & Confirm
          gameTitle: draftData['gameTitle'],
          agreeToTerms: draftData['agreeToTerms'],
          sendReminders: draftData['sendReminders'],

          // Step-specific local state
          selectedDate: draftData['selectedDate'] != null
              ? DateTime.parse(draftData['selectedDate'])
              : null,
          selectedTimeSlot: draftData['selectedTimeSlot'],
          selectedPlayers: draftData['selectedPlayers']?.cast<String>(),
          stepLocalState: draftData['stepLocalState'],

          // Draft metadata
          draftId: draftId,
          isDraft: true,
          lastSaved: draftData['lastSaved'] != null
              ? DateTime.parse(draftData['lastSaved'])
              : null,
          isLoading: false,
        );

        // Load data for the current step
        _loadDataForCurrentStep();
      }
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: 'Failed to load draft: $e',
      );
    }
    notifyListeners();
  }

  /// Apply initial values based on an existing booking seed.
  void applyBookingSeed(BookingSeedData seed) {
    final slot = _buildSeedVenueSlot(seed);
    final inferredTitle =
        _state.gameTitle ?? '${seed.sport} at ${seed.venueName}';

    _state = _state.copyWith(
      selectedSport: seed.sport,
      selectedDate: seed.date,
      selectedTimeSlot: seed.timeLabel,
      selectedVenueSlot: slot ?? _state.selectedVenueSlot,
      gameTitle: inferredTitle,
    );
    notifyListeners();
  }

  VenueSlot? _buildSeedVenueSlot(BookingSeedData seed) {
    final venueId = seed.venueId;
    if (venueId == null || venueId.isEmpty) {
      return null;
    }

    final timeSlot = _buildSeedTimeSlot(seed.date, seed.timeLabel);
    return VenueSlot(
      venueId: venueId,
      venueName: seed.venueName,
      location: seed.venueLocation ?? '',
      timeSlot: timeSlot,
      amenities: null,
      rating: 0,
      imageUrl: null,
    );
  }

  TimeSlot _buildSeedTimeSlot(DateTime date, String label) {
    final parts = label.split('-').map((value) => value.trim()).toList();
    final startTime = _parseSeedTime(parts.isNotEmpty ? parts.first : label);
    final endTime = parts.length > 1 ? _parseSeedTime(parts[1]) : null;

    final startDateTime = startTime != null
        ? DateTime(
            date.year,
            date.month,
            date.day,
            startTime.hour,
            startTime.minute,
          )
        : DateTime(date.year, date.month, date.day, 9);

    final calculatedEnd = endTime != null
        ? DateTime(
            date.year,
            date.month,
            date.day,
            endTime.hour,
            endTime.minute,
          )
        : startDateTime.add(const Duration(hours: 1));

    final duration = calculatedEnd.isAfter(startDateTime)
        ? calculatedEnd.difference(startDateTime)
        : const Duration(hours: 1);

    return TimeSlot(
      startTime: startDateTime,
      duration: duration,
      price: 0,
      isAvailable: true,
    );
  }

  TimeOfDay? _parseSeedTime(String value) {
    var trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    String? period;
    final lower = trimmed.toLowerCase();
    if (lower.endsWith('am')) {
      period = 'am';
      trimmed = trimmed.substring(0, trimmed.length - 2).trim();
    } else if (lower.endsWith('pm')) {
      period = 'pm';
      trimmed = trimmed.substring(0, trimmed.length - 2).trim();
    }

    final parts = trimmed.split(':');
    final hourPart = parts.isNotEmpty ? parts[0] : trimmed;
    final minutePart = parts.length > 1 ? parts[1] : '0';

    final parsedHour = int.tryParse(hourPart);
    final parsedMinute = int.tryParse(minutePart);
    if (parsedHour == null || parsedMinute == null) {
      return null;
    }

    var hour = parsedHour.clamp(0, 24);
    final minute = parsedMinute.clamp(0, 59);

    if (period == 'pm' && hour < 12) {
      hour += 12;
    } else if (period == 'am' && hour == 12) {
      hour = 0;
    }

    if (hour >= 24) {
      hour = hour % 24;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> deleteDraft(String draftId) async {
    try {
      await _storageService.deleteDraft(draftId);
    } catch (e) {
      // Handle error silently for now
    }
  }

  String _generateDraftId() {
    return 'draft_${DateTime.now().millisecondsSinceEpoch}';
  }

  // ── DB loaders ────────────────────────────────────────────────────────────

  Future<void> loadDbSports() async {
    _sportsLoading = true;
    _sportsError = null;
    notifyListeners();
    try {
      final response = await Supabase.instance.client
          .from(SupabaseConfig.sportsTable)
          .select('id, sport_key, name_en, emoji')
          .eq('is_active', true)
          .eq('is_challenge_sport', true)
          .order('name_en');
      _dbSports = List<Map<String, dynamic>>.from(response as List);
      _sportsError = null;
    } catch (e) {
      _dbSports = [];
      _sportsError = 'Failed to load sports: $e';
    }
    _sportsLoading = false;
    notifyListeners();
  }

  Future<void> loadDbVariants(String sportId) async {
    try {
      final response = await Supabase.instance.client
          .from(SupabaseConfig.sportVariantsTable)
          .select('id, name_en, required_players, players_per_side')
          .eq('sport_id', sportId)
          .eq('is_active', true)
          .order('name_en');
      _dbVariants = List<Map<String, dynamic>>.from(response as List);
    } catch (_) {
      _dbVariants = [];
    }
    notifyListeners();
  }

  // ── Sport / Variant selection ──────────────────────────────────────────────

  void selectDbSport(String sportId, String nameEn, String emoji) {
    _state = _state.clearVariant().copyWith(
      selectedSport: nameEn,
      selectedSportId: sportId,
    );
    _dbVariants = [];
    notifyListeners();
    loadDbVariants(sportId);
    autoSaveDraft();
  }

  void selectDbVariant(Map<String, dynamic> variant) {
    final required = variant['required_players'] as int;
    final perSide = variant['players_per_side'] as int;
    _state = _state.copyWith(
      selectedVariantId: variant['id'] as String,
      requiredPlayers: required,
      playersPerSide: perSide,
      maxPlayers: required,
      gameDuration: 60,
      // Clear venue when variant changes
      selectedVenueSlot: null,
      venueSpaceId: null,
    );
    notifyListeners();
    autoSaveDraft();
  }

  void updatePreciseStartTime(TimeOfDay time) {
    _state = _state.copyWith(selectedStartTime: time);
    notifyListeners();
    autoSaveDraft();
  }

  // ── Legacy helpers (kept for draft restore compat) ─────────────────────────

  // Step 1: Sport & Format Selection
  void selectSport(String sport) {
    _state = _state.copyWith(
      selectedSport: sport,
      selectedFormat: null,
      maxPlayers: null,
      gameDuration: null,
    );
    notifyListeners();
    autoSaveDraft();
  }

  void selectGameFormat(GameFormat format) {
    _state = _state.copyWith(
      selectedFormat: format,
      maxPlayers: format.totalPlayers,
      gameDuration: format.defaultDuration.inMinutes,
    );
    notifyListeners();
    autoSaveDraft();
  }

  void updateGameDuration(int durationMinutes) {
    _state = _state.copyWith(gameDuration: durationMinutes);
    notifyListeners();

    // Auto-save after duration update
    autoSaveDraft();
  }

  void selectSkillLevel(String skillLevel) {
    final (minS, maxS) = switch (skillLevel.toLowerCase()) {
      'beginner'     => (1, 3),
      'intermediate' => (4, 6),
      'advanced'     => (7, 8),
      'professional' => (9, 10),
      _              => (1, 10),
    };
    _state = _state.copyWith(
      skillLevel: skillLevel,
      minSkill: minS,
      maxSkill: maxS,
    );
    notifyListeners();
    autoSaveDraft();
  }

  void selectGameType(String gameType) {
    _state = _state.copyWith(gameType: gameType);
    notifyListeners();

    // Auto-save after game type selection
    autoSaveDraft();
  }

  void updateMaxPlayers(int count) {
    _state = _state.copyWith(maxPlayers: count);
    notifyListeners();
  }

  // Step 2: Venue & Slot Selection
  Future<void> loadAvailableVenues() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    try {
      final variantId = _state.selectedVariantId;
      if (variantId == null) {
        _availableVenues = [];
        _state = _state.copyWith(isLoading: false);
        notifyListeners();
        return;
      }

      final response = await Supabase.instance.client
          .from(SupabaseConfig.venueSpacesTable)
          .select(
            'id, name_en, joining_rule, price_per_hour, venue:venues(id, name_en, address_en, area, rating, lat, lng)',
          )
          .eq('sport_variant_id', variantId)
          .eq('is_active', true);

      final date =
          _state.selectedDate ?? DateTime.now().add(const Duration(days: 1));
      final startHour = _state.selectedStartTime?.hour ?? 18;
      final startMinute = _state.selectedStartTime?.minute ?? 0;

      _availableVenues = (response as List).map((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        final venue = row['venue'] as Map<String, dynamic>? ?? {};
        final startAt = DateTime(
          date.year,
          date.month,
          date.day,
          startHour,
          startMinute,
        );
        final location =
            (venue['address_en'] as String?)?.trim() ??
            (venue['area'] as String?)?.trim() ??
            '';

        return VenueSlot(
          venueId: (venue['id'] as String?) ?? '',
          venueSpaceId: row['id'] as String?,
          venueName: (venue['name_en'] as String?)?.trim() ?? 'Unknown Venue',
          location: location,
          rating: (venue['rating'] as num?)?.toDouble() ?? 0.0,
          timeSlot: TimeSlot(
            startTime: startAt,
            duration: Duration(minutes: _state.gameDuration ?? 60),
            price: (row['price_per_hour'] as num?)?.toDouble() ?? 0.0,
          ),
        );
      }).toList(growable: false);

      _state = _state.copyWith(isLoading: false, error: null);
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: 'Failed to load venues: $e',
      );
      _availableVenues = [];
    }
    notifyListeners();
  }

  void selectVenueSlot(VenueSlot venueSlot) {
    _state = _state.copyWith(
      selectedVenueSlot: venueSlot,
      venueSpaceId: venueSlot.venueSpaceId,
      totalCost: venueSlot.timeSlot.price,
    );
    notifyListeners();
  }

  void updateVenueFilters(List<String> filters) {
    _state = _state.copyWith(venueFilters: filters);
    // Re-filter venues based on new filters
    notifyListeners();
  }

  void updateMaxDistance(double distance) {
    _state = _state.copyWith(maxDistance: distance);
    notifyListeners();
  }

  // Step 3: Participation & Payment
  void selectParticipationMode(ParticipationMode mode) {
    _state = _state.copyWith(participationMode: mode);
    notifyListeners();
  }

  void selectPaymentSplit(PaymentSplit split) {
    _state = _state.copyWith(paymentSplit: split);
    _recalculatePayments();
    notifyListeners();
  }

  void updateGameDescription(String description) {
    _state = _state.copyWith(gameDescription: description);
    notifyListeners();
  }

  void toggleWaitlist(bool allow) {
    _state = _state.copyWith(allowWaitlist: allow);
    notifyListeners();
  }

  void toggleAllowSpectators(bool allow) {
    _state = _state.copyWith(allowSpectators: allow);
    notifyListeners();
  }

  void updateMaxWaitlistSize(int size) {
    _state = _state.copyWith(maxWaitlistSize: size);
    notifyListeners();
  }

  void updateCustomPaymentSplit(Map<String, double> split) {
    _state = _state.copyWith(customPaymentSplit: split);
    notifyListeners();
  }

  // Step 4: Player Invitation
  Future<void> loadRecentTeammates() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    try {
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 500));

      _recentTeammates = [
        'Ahmed Mohamed',
        'Sarah Johnson',
        'Carlos Rodriguez',
        'Fatima Al-Zahra',
        'Mike Wilson',
        'Layla Hassan',
        'David Kim',
        'Nour Abdullah',
      ];

      _state = _state.copyWith(isLoading: false, error: null);
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: 'Failed to load teammates: $e',
      );
    }
    notifyListeners();
  }

  void addInvitedPlayer(String playerId) {
    final currentList = _state.invitedPlayerIds ?? [];
    if (!currentList.contains(playerId)) {
      _state = _state.copyWith(invitedPlayerIds: [...currentList, playerId]);
      notifyListeners();
    }
  }

  void removeInvitedPlayer(String playerId) {
    final currentList = _state.invitedPlayerIds ?? [];
    _state = _state.copyWith(
      invitedPlayerIds: currentList.where((id) => id != playerId).toList(),
    );
    notifyListeners();
  }

  void addInvitedEmail(String email) {
    final currentList = _state.invitedPlayerEmails ?? [];
    if (!currentList.contains(email)) {
      _state = _state.copyWith(invitedPlayerEmails: [...currentList, email]);
      notifyListeners();
    }
  }

  void removeInvitedEmail(String email) {
    final currentList = _state.invitedPlayerEmails ?? [];
    _state = _state.copyWith(
      invitedPlayerEmails: currentList.where((e) => e != email).toList(),
    );
    notifyListeners();
  }

  void updateInvitationMessage(String message) {
    _state = _state.copyWith(invitationMessage: message);
    notifyListeners();
  }

  void toggleAllowFriendsToInvite(bool allow) {
    _state = _state.copyWith(allowFriendsToInvite: allow);
    notifyListeners();
  }

  // Step 5: Review & Confirm
  void updateGameTitle(String title) {
    _state = _state.copyWith(gameTitle: title);
    notifyListeners();
  }

  void updateTermsAgreement(bool agree) {
    _state = _state.copyWith(agreeToTerms: agree);
    notifyListeners();
  }

  void updateGameReminders(bool sendReminders) {
    _state = _state.copyWith(sendReminders: sendReminders);
    notifyListeners();
  }

  void updateReminderTime(DateTime reminderTime) {
    _state = _state.copyWith(reminderTime: reminderTime);
    notifyListeners();
  }

  // Final game creation — calls rpc_create_game
  Future<bool> createGame() async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Validate required fields
      if (_state.selectedSportId == null) {
        throw Exception('Please select a sport');
      }
      if (_state.selectedVariantId == null) {
        throw Exception('Please select a match format');
      }
      if (_state.selectedDate == null || _state.selectedStartTime == null) {
        throw Exception('Please select a date and start time');
      }

      // Rate-limit check
      final moderationService = ModerationService();
      final cooldownResult = await moderationService.checkAndBumpCooldown(
        'game.create',
        windowSeconds: 86400,
        limitCount: 5,
      );
      if (!cooldownResult.allowed) {
        final resetTime = DateFormat('MMM d, HH:mm').format(cooldownResult.resetAt);
        throw Exception(
          'Daily game creation limit reached. Try again at $resetTime.',
        );
      }

      const actorType = 'player';

      // Build timestamps
      final date = _state.selectedDate!;
      final t = _state.selectedStartTime!;
      final startAt = DateTime(date.year, date.month, date.day, t.hour, t.minute);
      final endAt = startAt.add(const Duration(hours: 1));

      if (!endAt.isAfter(startAt)) {
        throw Exception('End time must be after start time.');
      }

      // Build optional rules jsonb
      final rules = <String, dynamic>{};
      if (_state.gameDuration != null) {
        rules['duration_minutes'] = _state.gameDuration;
      }
      if (_state.gameDescription != null && _state.gameDescription!.isNotEmpty) {
        rules['notes'] = _state.gameDescription;
      }

      // Call RPC
      final params = <String, dynamic>{
        'p_actor_type': actorType,
        'p_sport_id': _state.selectedSportId!,
        'p_sport_variant_id': _state.selectedVariantId!,
        'p_start_at': startAt.toIso8601String(),
        'p_end_at': endAt.toIso8601String(),
        'p_bench_slots': 0,
        'p_listing_visibility': _state.listingVisibility ?? 'public',
        'p_join_policy': _state.joinPolicy ?? 'open',
        'p_allow_spectators': _state.allowSpectators ?? false,
        'p_allows_waitlist': _state.allowWaitlist ?? false,
      };
      if (_state.gameTitle != null && _state.gameTitle!.isNotEmpty) {
        params['p_title'] = _state.gameTitle;
      }
      if (_state.venueSpaceId != null) {
        params['p_venue_space_id'] = _state.venueSpaceId;
      }
      if (_state.minSkill != null) params['p_min_skill'] = _state.minSkill;
      if (_state.maxSkill != null) params['p_max_skill'] = _state.maxSkill;
      if (rules.isNotEmpty) params['p_rules'] = rules;

      await supabase.rpc(SupabaseConfig.rpcCreateGameFn, params: params);

      // Delete draft on success
      if (_state.isDraft && _state.draftId != null) {
        await deleteDraft(_state.draftId!);
      }

      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return true;
    } on PostgrestException catch (e) {
      String message;
      if (e.code == 'P0001') {
        message = switch (e.message) {
          'sport_not_challenge_eligible' =>
            'This sport is not available for challenge games.',
          'invalid_sport_variant' =>
            'Invalid match format for this sport.',
          'invalid_time_range' => 'End time must be after start time.',
          'invalid_bench_slots' => 'Invalid bench slots for this format.',
          'creator_profile_not_found' =>
            'Profile not found. Please complete your profile first.',
          _ => e.message,
        };
      } else {
        message = 'Database error: ${e.message}';
      }
      _state = _state.copyWith(isLoading: false, error: message);
      notifyListeners();
      return false;
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      notifyListeners();
      return false;
    }
  }

  // Reset to initial state
  void reset() {
    _state = GameCreationModel.initial();
    _availableVenues = [];
    _recentTeammates = [];
    notifyListeners();
  }

  // Private helper methods
  void _loadDataForCurrentStep() {
    switch (_state.currentStep) {
      case GameCreationStep.venueAndSlot:
        loadAvailableVenues();
        break;
      case GameCreationStep.playerInvitation:
        loadRecentTeammates();
        break;
      default:
        break;
    }
  }

  void _recalculatePayments() {
    if (_state.selectedVenueSlot == null || _state.paymentSplit == null) return;

    final venueCost = _state.selectedVenueSlot!.timeSlot.price;
    final playerCount = _state.maxPlayers ?? 1;

    double totalCost = venueCost;

    switch (_state.paymentSplit!) {
      case PaymentSplit.organizer:
        totalCost = venueCost;
        break;
      case PaymentSplit.equal:
        totalCost = venueCost / playerCount;
        break;
      case PaymentSplit.perPlayer:
        totalCost = venueCost / playerCount;
        break;
      case PaymentSplit.custom:
        // Custom split would be calculated based on customPaymentSplit map
        totalCost = venueCost;
        break;
    }

    _state = _state.copyWith(totalCost: totalCost);
  }

  // Helper method to reconstruct GameFormat from saved data
  GameFormat? _reconstructGameFormat(String sport, String formatName) {
    try {
      switch (sport.toLowerCase()) {
        case 'football':
          return FootballFormat.allFormats.firstWhere(
            (f) => f.name == formatName,
          );
        case 'cricket':
          return CricketFormat.allFormats.firstWhere(
            (f) => f.name == formatName,
          );
        case 'padel':
          return PadelFormat.allFormats.firstWhere((f) => f.name == formatName);
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Helper method to reconstruct VenueSlot from saved data
  VenueSlot? _reconstructVenueSlot(Map<String, dynamic> venueData) {
    try {
      final timeSlotData = venueData['timeSlot'];
      final timeSlot = TimeSlot(
        startTime: DateTime.parse(timeSlotData['startTime']),
        duration: Duration(minutes: timeSlotData['duration']),
        price: timeSlotData['price']?.toDouble() ?? 0.0,
        isAvailable: timeSlotData['isAvailable'] ?? true,
        restrictions: timeSlotData['restrictions']?.cast<String>() ?? [],
      );

      return VenueSlot(
        venueId: venueData['venueId'],
        venueName: venueData['venueName'],
        location: venueData['location'],
        timeSlot: timeSlot,
        amenities: venueData['amenities']?.cast<String>() ?? [],
        rating: venueData['rating']?.toDouble() ?? 0.0,
        imageUrl: venueData['imageUrl'],
      );
    } catch (e) {
      return null;
    }
  }

  // Step-specific state management for draft resume
  void updateStepLocalState(Map<String, dynamic> localState) {
    _state = _state.copyWith(
      stepLocalState: {..._state.stepLocalState ?? {}, ...localState},
    );

    // Auto-save step-specific state
    autoSaveDraft(stepLocalState: _state.stepLocalState);
  }

  void updateSelectedDate(DateTime date) {
    _state = _state.copyWith(selectedDate: date);
    notifyListeners();

    // Auto-save date selection
    autoSaveDraft();
  }

  void updateSelectedTimeSlot(String timeSlot) {
    _state = _state.copyWith(selectedTimeSlot: timeSlot);
    notifyListeners();

    // Auto-save time slot selection
    autoSaveDraft();
  }

  void updateSelectedPlayers(List<String> players) {
    _state = _state.copyWith(selectedPlayers: players);
    notifyListeners();

    // Auto-save player selection
    autoSaveDraft();
  }
}
