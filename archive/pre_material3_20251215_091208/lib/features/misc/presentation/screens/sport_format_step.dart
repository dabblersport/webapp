import 'package:flutter/material.dart';
import 'package:dabbler/data/models/core/game_creation_model.dart';
import 'package:dabbler/core/viewmodels/game_creation_viewmodel.dart';
import 'package:dabbler/core/utils/sports_config.dart';
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

  // Date and time selection state
  DateTime? _selectedDate;
  String? _selectedTimeSlot;

  @override
  void initState() {
    super.initState();

    // Restore local state from draft if available
    _restoreLocalState();
  }

  void _restoreLocalState() {
    final state = widget.viewModel.state;

    // Restore date and time slot from saved draft
    _selectedDate = state.selectedDate;
    _selectedTimeSlot = state.selectedTimeSlot;

    // Restore any additional local state
    if (state.stepLocalState != null) {
      final localState = state.stepLocalState!;
      if (localState['selectedDate'] != null) {
        _selectedDate = DateTime.parse(localState['selectedDate']);
      }
      if (localState['selectedTimeSlot'] != null) {
        _selectedTimeSlot = localState['selectedTimeSlot'];
      }
    }
  }

  void _saveLocalState() {
    // Save current local state to the view model
    final localState = {
      'selectedDate': _selectedDate?.toIso8601String(),
      'selectedTimeSlot': _selectedTimeSlot,
    };

    widget.viewModel.updateStepLocalState(localState);

    // Also update the main state
    if (_selectedDate != null) {
      widget.viewModel.updateSelectedDate(_selectedDate!);
    }
    if (_selectedTimeSlot != null) {
      widget.viewModel.updateSelectedTimeSlot(_selectedTimeSlot!);
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

    // Add longer delay to ensure widgets are fully rendered
    Future.delayed(const Duration(milliseconds: 100), () {
      // Determine next required action based on current state
      if (state.selectedSport == null) {
        // No scroll needed, sport selection is at top
        return;
      } else if (state.selectedFormat == null) {
        _scrollToNextSection(_formatSectionKey);
      } else if (state.gameType == null) {
        // Game type selection is after format
        return; // Will scroll when game type section is visible
      } else if (_selectedDate == null) {
        _scrollToNextSection(_dateSelectionKey);
      } else if (_selectedTimeSlot == null) {
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
        _selectedTimeSlot = null; // Reset time slot when date changes
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
        final skillLevel = state.skillLevel;
        final maxPlayers = state.maxPlayers;
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
              if (selectedSport != null && selectedFormat != null) ...[
                _buildGameTypeSelection(context, state.gameType),
                const SizedBox(height: 32),
              ],

              // Game Settings
              if (selectedSport != null && selectedFormat != null) ...[
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
        Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: SportsConfig.allSports.map((sport) {
                final isSelected = selectedSport == sport.displayName;

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildSportCard(
                    context,
                    sport: sport,
                    isSelected: isSelected,
                    onTap: () {
                      widget.viewModel.selectSport(sport.displayName);
                      // Always scroll to format section after sport selection with increased delay
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

  Widget _buildSportCard(
    BuildContext context, {
    required Sport sport,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
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
                    : sport.secondaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                sport.icon,
                size: 24,
                color: isSelected ? context.colors.primary : sport.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              sport.displayName,
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
    final availableFormats = SportsConfig.getFormatsForSport(selectedSport);

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
        Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: availableFormats.map((format) {
                final isSelected = selectedFormat?.name == format.name;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildFormatChip(
                    context,
                    format: format,
                    isSelected: isSelected,
                    onTap: () {
                      widget.viewModel.selectGameFormat(format);
                      // Scroll to next required section after format selection with increased delay
                      Future.delayed(const Duration(milliseconds: 200), () {
                        _scrollToRequiredSection();
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

  Widget _buildFormatChip(
    BuildContext context, {
    required GameFormat format,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              format.name,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? context.colors.primary
                    : context.colors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              format.description,
              style: context.textTheme.bodySmall?.copyWith(
                color: isSelected
                    ? context.colors.primary.withValues(alpha: 0.8)
                    : context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.colors.primary.withValues(alpha: 0.2)
                    : context.colors.outline.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${format.totalPlayers} players',
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

        // Duration Selection - moved before player count
        if (_selectedDate != null &&
            _selectedTimeSlot != null &&
            maxPlayers != null) ...[
          const SizedBox(height: 24),
          Container(
            key: _durationSelectionKey,
            child: _buildDurationSelection(context, gameDuration),
          ),
        ],

        // Player Count (read-only, set by format) - only show when format is selected
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
          _selectedTimeSlot = null; // Reset time slot when date changes
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
    final timeSlots = [
      {
        'id': 'morning',
        'label': 'Morning',
        'time': '9:00 - 12:00',
        'icon': Icons.wb_twilight,
      },
      {
        'id': 'day',
        'label': 'Day',
        'time': '13:00 - 16:00',
        'icon': Icons.wb_sunny,
      },
      {
        'id': 'evening',
        'label': 'Evening',
        'time': '17:00 - 20:00',
        'icon': Icons.wb_twilight,
      },
      {
        'id': 'night',
        'label': 'Night',
        'time': '21:00 - 00:00',
        'icon': Icons.nightlight_round,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Time Slot',
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
              children: timeSlots.map((slot) {
                final isSelected = _selectedTimeSlot == slot['id'];

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTimeSlot = slot['id'] as String;
                      });

                      // Save local state for draft
                      _saveLocalState();

                      // Scroll to next required section after time slot selection with increased delay
                      Future.delayed(const Duration(milliseconds: 200), () {
                        _scrollToRequiredSection();
                      });
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            slot['icon'] as IconData,
                            size: 24,
                            color: isSelected
                                ? context.colors.primary
                                : context.colors.onSurface,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            slot['label'] as String,
                            style: context.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? context.colors.primary
                                  : context.colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            slot['time'] as String,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: isSelected
                                  ? context.colors.primary.withValues(
                                      alpha: 0.8,
                                    )
                                  : context.colors.onSurfaceVariant,
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
