import 'package:flutter/material.dart';
import 'package:dabbler/data/models/core/game_creation_model.dart';
import 'package:dabbler/core/viewmodels/game_creation_viewmodel.dart';
import 'package:dabbler/themes/app_theme.dart';

class SportFormatStep extends StatefulWidget {
  final GameCreationViewModel viewModel;

  const SportFormatStep({super.key, required this.viewModel});

  @override
  State<SportFormatStep> createState() => _SportFormatStepState();
}

class _SportFormatStepState extends State<SportFormatStep> {
  final ScrollController _mainScrollController = ScrollController();
  final GlobalKey _formatSectionKey = GlobalKey();
  final GlobalKey _gameSettingsKey = GlobalKey();
  final GlobalKey _dateSelectionKey = GlobalKey();
  final GlobalKey _timeSlotSelectionKey = GlobalKey();
  final GlobalKey _skillLevelSelectionKey = GlobalKey();
  final GlobalKey _durationSelectionKey = GlobalKey();

  // Date selection state
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();

    // Restore local state from draft if available
    _restoreLocalState();
  }

  void _restoreLocalState() {
    final state = widget.viewModel.state;
    _selectedDate = state.selectedDate;
    if (state.stepLocalState != null) {
      final localState = state.stepLocalState!;
      if (localState['selectedDate'] != null) {
        _selectedDate = DateTime.parse(localState['selectedDate'] as String);
      }
    }
  }

  void _saveLocalState() {
    final localState = {'selectedDate': _selectedDate?.toIso8601String()};
    widget.viewModel.updateStepLocalState(localState);
    if (_selectedDate != null) {
      widget.viewModel.updateSelectedDate(_selectedDate!);
    }
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    super.dispose();
  }

  void _scrollToNextSection(GlobalKey? nextSectionKey) {
    if (nextSectionKey?.currentContext != null) {
      // Always scroll - remove visibility check as it may be interfering
      Scrollable.ensureVisible(
        nextSectionKey!.currentContext!,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        alignment: 0.1, // Small offset from top for better UX
      );
    }
  }

  void _scrollToFormatSection() {
    if (_formatSectionKey.currentContext != null) {
      Scrollable.ensureVisible(
        _formatSectionKey.currentContext!,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        alignment: 0.1, // Small offset from top for better UX
      );
    }
  }

  void _scrollToRequiredSection() {
    final state = widget.viewModel.state;

    Future.delayed(const Duration(milliseconds: 100), () {
      if (state.selectedSportId == null) {
        return;
      } else if (state.selectedVariantId == null) {
        _scrollToNextSection(_formatSectionKey);
      } else if (_selectedDate == null) {
        _scrollToNextSection(_dateSelectionKey);
      } else if (state.selectedStartTime == null) {
        _scrollToNextSection(_timeSlotSelectionKey);
      } else if (state.skillLevel == null) {
        _scrollToNextSection(_skillLevelSelectionKey);
      } else if (state.gameDuration == null) {
        _scrollToNextSection(_durationSelectionKey);
      }
    });
  }

  Future<void> _selectCustomDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate ??
          DateTime.now().add(
            const Duration(days: 1),
          ), // Default to tomorrow instead of today
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: context.colors.primary,
              onPrimary: context.colors.onPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });

      // Save local state for draft
      _saveLocalState();

      // Scroll to next required section after custom date selection with increased delay
      Future.delayed(const Duration(milliseconds: 200), () {
        _scrollToRequiredSection();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, child) {
        final state = widget.viewModel.state;
        final selectedFormat = state.selectedFormat;
        final selectedSport = state.selectedSport;
        final selectedVariantId = state.selectedVariantId;
        final skillLevel = state.skillLevel;
        final maxPlayers = state.requiredPlayers ?? state.maxPlayers;
        final gameDuration = state.gameDuration;

        return SingleChildScrollView(
          controller: _mainScrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Choose your sport',
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select the sport and format for your game',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Sport Selection
              _buildSportSelection(context, selectedSport),
              const SizedBox(height: 32),

              // Format Selection
              if (selectedSport != null) ...[
                Container(
                  key: _formatSectionKey,
                  child: _buildFormatSelection(
                    context,
                    selectedSport,
                    selectedFormat,
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // Game Type Selection
              if (selectedSport != null && selectedVariantId != null) ...[
                _buildGameTypeSelection(context, state.gameType),
                const SizedBox(height: 32),
              ],

              // Game Settings
              if (selectedSport != null && selectedVariantId != null) ...[
                Container(
                  key: _gameSettingsKey,
                  child: _buildGameSettings(
                    context,
                    skillLevel,
                    maxPlayers,
                    gameDuration,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSportSelection(BuildContext context, String? selectedSport) {
    final dbSports = widget.viewModel.dbSports;
    final isLoading = widget.viewModel.sportsLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sport',
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: dbSports.map((sport) {
                  final isSelected =
                      selectedSport == sport['name_en'] as String?;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildDbSportCard(
                      context,
                      sport: sport,
                      isSelected: isSelected,
                      onTap: () {
                        widget.viewModel.selectDbSport(
                          sport['id'] as String,
                          sport['name_en'] as String,
                          (sport['emoji'] as String?) ?? '',
                        );
                        Future.delayed(const Duration(milliseconds: 200), () {
                          _scrollToFormatSection();
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDbSportCard(
    BuildContext context, {
    required Map<String, dynamic> sport,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final emoji = (sport['emoji'] as String?) ?? '🏅';
    final name = sport['name_en'] as String? ?? '';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colors.primary.withValues(alpha: 0.1)
              : context.violetWidgetBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? context.colors.primary
                : context.colors.outline.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.colors.primary.withValues(alpha: 0.1)
                    : context.colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? context.colors.primary
                    : context.colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatSelection(
    BuildContext context,
    String selectedSport,
    GameFormat? selectedFormat,
  ) {
    final variants = widget.viewModel.dbVariants;
    final selectedVariantId = widget.viewModel.state.selectedVariantId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Match Format',
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose format based on venue capabilities',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (variants.isEmpty)
          Text(
            'No formats available for this sport.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: variants.map((variant) {
                  final isSelected = selectedVariantId == variant['id'];
                  final totalPlayers = variant['required_players'] as int? ?? 0;
                  final perSide = variant['players_per_side'] as int? ?? 0;
                  final description = perSide > 0 ? '${perSide}v$perSide' : '';

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        widget.viewModel.selectDbVariant(variant);
                        Future.delayed(const Duration(milliseconds: 200), () {
                          _scrollToRequiredSection();
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? context.colors.primary.withValues(alpha: 0.1)
                              : context.violetWidgetBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected
                                ? context.colors.primary
                                : context.colors.outline.withValues(alpha: 0.1),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              variant['name_en'] as String? ?? '',
                              style: context.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? context.colors.primary
                                    : context.colors.onSurface,
                              ),
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                description,
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: isSelected
                                      ? context.colors.primary.withValues(
                                          alpha: 0.8,
                                        )
                                      : context.colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? context.colors.primary.withValues(
                                        alpha: 0.2,
                                      )
                                    : context.colors.outline.withValues(
                                        alpha: 0.1,
                                      ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$totalPlayers players',
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: isSelected
                                      ? context.colors.primary
                                      : context.colors.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGameSettings(
    BuildContext context,
    String? skillLevel,
    int? maxPlayers,
    int? gameDuration,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Selection
        Container(key: _dateSelectionKey, child: _buildDateSelection(context)),
        const SizedBox(height: 24),

        // Time Slot Selection
        if (_selectedDate != null) ...[
          Container(
            key: _timeSlotSelectionKey,
            child: _buildTimeSlotSelection(context),
          ),
          const SizedBox(height: 24),
        ],

        // Skill Level Selection
        Container(
          key: _skillLevelSelectionKey,
          child: _buildSkillLevelSelection(context, skillLevel),
        ),

        // Duration Selection
        if (_selectedDate != null &&
            widget.viewModel.state.selectedStartTime != null &&
            maxPlayers != null) ...[
          const SizedBox(height: 24),
          Container(
            key: _durationSelectionKey,
            child: _buildDurationSelection(context, gameDuration),
          ),
        ],

        // Player Count (read-only, locked from variant.required_players)
        if (maxPlayers != null) ...[
          const SizedBox(height: 24),
          _buildPlayerCountDisplay(context, maxPlayers),
        ],
      ],
    );
  }

  Widget _buildDateSelection(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dayAfter = today.add(const Duration(days: 2));

    // Generate next 9 days (excluding today, tomorrow, day after)
    final nextDays = List.generate(
      9,
      (index) => today.add(Duration(days: index + 3)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Date',
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 12),

        // Quick date options
        Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Today
                _buildDateChip(
                  context,
                  date: today,
                  label: 'Today',
                  subtitle: _formatDateShort(today),
                  isSelected:
                      _selectedDate != null &&
                      _isSameDay(_selectedDate!, today),
                ),
                const SizedBox(width: 8),

                // Tomorrow
                _buildDateChip(
                  context,
                  date: tomorrow,
                  label: 'Tomorrow',
                  subtitle: _formatDateShort(tomorrow),
                  isSelected:
                      _selectedDate != null &&
                      _isSameDay(_selectedDate!, tomorrow),
                ),
                const SizedBox(width: 8),

                // Day after tomorrow
                _buildDateChip(
                  context,
                  date: dayAfter,
                  label: _formatDayName(dayAfter),
                  subtitle: _formatDateShort(dayAfter),
                  isSelected:
                      _selectedDate != null &&
                      _isSameDay(_selectedDate!, dayAfter),
                ),
                const SizedBox(width: 8),

                // Next 9 days
                ...nextDays.map(
                  (date) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildDateChip(
                      context,
                      date: date,
                      label: _formatDayName(date),
                      subtitle: _formatDateShort(date),
                      isSelected:
                          _selectedDate != null &&
                          _isSameDay(_selectedDate!, date),
                    ),
                  ),
                ),

                // Custom date picker
                _buildCustomDateChip(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateChip(
    BuildContext context, {
    required DateTime date,
    required String label,
    required String subtitle,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = date;
        });

        // Save local state for draft
        _saveLocalState();

        // Scroll to next required section after date selection with increased delay
        Future.delayed(const Duration(milliseconds: 200), () {
          _scrollToRequiredSection();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colors.primary.withValues(alpha: 0.1)
              : context.violetWidgetBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? context.colors.primary
                : context.colors.outline.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? context.colors.primary
                    : context.colors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: context.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: isSelected
                    ? context.colors.primary.withValues(alpha: 0.8)
                    : context.colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomDateChip(BuildContext context) {
    final isCustomSelected =
        _selectedDate != null && !_isWithinNext12Days(_selectedDate!);

    return GestureDetector(
      onTap: _selectCustomDate,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isCustomSelected
              ? context.colors.primary.withValues(alpha: 0.1)
              : context.violetWidgetBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCustomSelected
                ? context.colors.primary
                : context.colors.outline.withValues(alpha: 0.1),
            width: isCustomSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today,
              size: 16,
              color: isCustomSelected
                  ? context.colors.primary
                  : context.colors.onSurface,
            ),
            const SizedBox(height: 2),
            Text(
              'Custom',
              style: context.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isCustomSelected
                    ? context.colors.primary
                    : context.colors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (isCustomSelected && _selectedDate != null) ...[
              Text(
                _formatDateShort(_selectedDate!),
                style: context.textTheme.bodySmall?.copyWith(
                  fontSize: 9,
                  color: context.colors.primary.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotSelection(BuildContext context) {
    final selectedTime = widget.viewModel.state.selectedStartTime;

    String timeLabel = 'Pick a start time';
    String endLabel = '';
    if (selectedTime != null) {
      final startStr =
          '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
      final endHour = (selectedTime.hour + 1) % 24;
      final endStr =
          '${endHour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
      timeLabel = startStr;
      endLabel = '→ $endStr (+1 h)';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Start Time',
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: selectedTime ?? const TimeOfDay(hour: 18, minute: 0),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: context.colors.primary,
                    onPrimary: context.colors.onPrimary,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              widget.viewModel.updatePreciseStartTime(picked);
              _saveLocalState();
              Future.delayed(const Duration(milliseconds: 200), () {
                _scrollToRequiredSection();
              });
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selectedTime != null
                  ? context.colors.primary.withValues(alpha: 0.1)
                  : context.violetWidgetBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selectedTime != null
                    ? context.colors.primary
                    : context.colors.outline.withValues(alpha: 0.1),
                width: selectedTime != null ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_time,
                  size: 22,
                  color: selectedTime != null
                      ? context.colors.primary
                      : context.colors.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeLabel,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selectedTime != null
                            ? context.colors.primary
                            : context.colors.onSurface,
                      ),
                    ),
                    if (endLabel.isNotEmpty)
                      Text(
                        endLabel,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.primary.withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Helper methods for date formatting
  String _formatDateShort(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  String _formatDayName(DateTime date) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  bool _isWithinNext12Days(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = date.difference(today).inDays;
    return difference >= 0 &&
        difference <= 11; // Today + next 11 days = 12 days total
  }

  Widget _buildSkillLevelSelection(BuildContext context, String? skillLevel) {
    final skillLevels = [
      'Beginner',
      'Intermediate',
      'Advanced',
      'Professional',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Skill Level',
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: skillLevels.map((level) {
                final isSelected = skillLevel == level;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      widget.viewModel.selectSkillLevel(level);
                      // Scroll to next required section after skill level selection with increased delay
                      Future.delayed(const Duration(milliseconds: 200), () {
                        _scrollToRequiredSection();
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.colors.primary.withValues(alpha: 0.1)
                            : context.violetWidgetBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? context.colors.primary
                              : context.colors.outline.withValues(alpha: 0.1),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        level,
                        style: context.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? context.colors.primary
                              : context.colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerCountDisplay(BuildContext context, int? maxPlayers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total Players',
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.colors.outline.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.group, size: 20, color: context.colors.primary),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${maxPlayers ?? 0} Players',
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurface,
                    ),
                  ),
                  Text(
                    'Set by match format',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDurationSelection(BuildContext context, int? gameDuration) {
    final durations = [60, 90, 120, 150, 180]; // Duration options in minutes

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Game Duration',
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: durations.map((duration) {
                final isSelected = gameDuration == duration;
                final hours = duration ~/ 60;
                final minutes = duration % 60;
                String durationText;

                if (hours > 0 && minutes > 0) {
                  durationText = '${hours}h ${minutes}m';
                } else if (hours > 0) {
                  durationText = '${hours}h';
                } else {
                  durationText = '${minutes}m';
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      widget.viewModel.updateGameDuration(duration);
                      // Scroll to next required section after duration selection with increased delay
                      Future.delayed(const Duration(milliseconds: 200), () {
                        _scrollToRequiredSection();
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.colors.primary.withValues(alpha: 0.1)
                            : context.violetWidgetBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? context.colors.primary
                              : context.colors.outline.withValues(alpha: 0.1),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        durationText,
                        style: context.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? context.colors.primary
                              : context.colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameTypeSelection(BuildContext context, String? gameType) {
    final gameTypes = [
      {'value': 'pickup', 'label': 'Pickup', 'icon': Icons.sports_soccer},
      {'value': 'training', 'label': 'Training', 'icon': Icons.fitness_center},
      {'value': 'league', 'label': 'League', 'icon': Icons.emoji_events},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Game Type',
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select the type of game you want to create',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: gameTypes.map((type) {
                final isSelected = gameType == type['value'];

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () {
                      widget.viewModel.selectGameType(type['value'] as String);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.colors.primary.withValues(alpha: 0.1)
                            : context.violetWidgetBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? context.colors.primary
                              : context.colors.outline.withValues(alpha: 0.1),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            type['icon'] as IconData,
                            size: 20,
                            color: isSelected
                                ? context.colors.primary
                                : context.colors.onSurface,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            type['label'] as String,
                            style: context.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? context.colors.primary
                                  : context.colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
