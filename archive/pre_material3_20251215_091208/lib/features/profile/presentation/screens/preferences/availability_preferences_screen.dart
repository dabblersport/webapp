import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AvailabilityPreferencesScreen extends ConsumerStatefulWidget {
  const AvailabilityPreferencesScreen({super.key});

  @override
  ConsumerState<AvailabilityPreferencesScreen> createState() =>
      _AvailabilityPreferencesScreenState();
}

class _AvailabilityPreferencesScreenState
    extends ConsumerState<AvailabilityPreferencesScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Weekly schedule
  final Map<String, List<TimeSlot>> _weeklySchedule = {
    'monday': [],
    'tuesday': [],
    'wednesday': [],
    'thursday': [],
    'friday': [],
    'saturday': [],
    'sunday': [],
  };

  // Vacation mode
  bool _vacationMode = false;
  DateTime? _vacationStartDate;
  DateTime? _vacationEndDate;

  // Last-minute availability
  bool _lastMinuteAvailability = true;
  int _lastMinuteHours = 2;

  // Recurring availability templates
  final List<AvailabilityTemplate> _templates = [
    AvailabilityTemplate(
      name: 'Weekday Evenings',
      description: 'Monday to Friday, 6:00 PM - 10:00 PM',
      schedule: {
        'monday': [
          TimeSlot(
            start: TimeOfDay(hour: 18, minute: 0),
            end: TimeOfDay(hour: 22, minute: 0),
          ),
        ],
        'tuesday': [
          TimeSlot(
            start: TimeOfDay(hour: 18, minute: 0),
            end: TimeOfDay(hour: 22, minute: 0),
          ),
        ],
        'wednesday': [
          TimeSlot(
            start: TimeOfDay(hour: 18, minute: 0),
            end: TimeOfDay(hour: 22, minute: 0),
          ),
        ],
        'thursday': [
          TimeSlot(
            start: TimeOfDay(hour: 18, minute: 0),
            end: TimeOfDay(hour: 22, minute: 0),
          ),
        ],
        'friday': [
          TimeSlot(
            start: TimeOfDay(hour: 18, minute: 0),
            end: TimeOfDay(hour: 22, minute: 0),
          ),
        ],
        'saturday': [],
        'sunday': [],
      },
    ),
    AvailabilityTemplate(
      name: 'Weekend Warrior',
      description: 'Saturday and Sunday, 9:00 AM - 6:00 PM',
      schedule: {
        'monday': [],
        'tuesday': [],
        'wednesday': [],
        'thursday': [],
        'friday': [],
        'saturday': [
          TimeSlot(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 18, minute: 0),
          ),
        ],
        'sunday': [
          TimeSlot(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 18, minute: 0),
          ),
        ],
      },
    ),
    AvailabilityTemplate(
      name: 'Morning Person',
      description: 'Every day, 6:00 AM - 10:00 AM',
      schedule: {
        'monday': [
          TimeSlot(
            start: TimeOfDay(hour: 6, minute: 0),
            end: TimeOfDay(hour: 10, minute: 0),
          ),
        ],
        'tuesday': [
          TimeSlot(
            start: TimeOfDay(hour: 6, minute: 0),
            end: TimeOfDay(hour: 10, minute: 0),
          ),
        ],
        'wednesday': [
          TimeSlot(
            start: TimeOfDay(hour: 6, minute: 0),
            end: TimeOfDay(hour: 10, minute: 0),
          ),
        ],
        'thursday': [
          TimeSlot(
            start: TimeOfDay(hour: 6, minute: 0),
            end: TimeOfDay(hour: 10, minute: 0),
          ),
        ],
        'friday': [
          TimeSlot(
            start: TimeOfDay(hour: 6, minute: 0),
            end: TimeOfDay(hour: 10, minute: 0),
          ),
        ],
        'saturday': [
          TimeSlot(
            start: TimeOfDay(hour: 6, minute: 0),
            end: TimeOfDay(hour: 10, minute: 0),
          ),
        ],
        'sunday': [
          TimeSlot(
            start: TimeOfDay(hour: 6, minute: 0),
            end: TimeOfDay(hour: 10, minute: 0),
          ),
        ],
      },
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Initialize with some default availability
    _weeklySchedule['saturday']!.add(
      TimeSlot(
        start: const TimeOfDay(hour: 10, minute: 0),
        end: const TimeOfDay(hour: 16, minute: 0),
      ),
    );
    _weeklySchedule['sunday']!.add(
      TimeSlot(
        start: const TimeOfDay(hour: 14, minute: 0),
        end: const TimeOfDay(hour: 18, minute: 0),
      ),
    );

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(context),
              SliverToBoxAdapter(child: _buildQuickActionsSection(context)),
              SliverToBoxAdapter(child: _buildWeeklyScheduleSection(context)),
              SliverToBoxAdapter(child: _buildVacationModeSection(context)),
              SliverToBoxAdapter(child: _buildLastMinuteSection(context)),
              SliverToBoxAdapter(child: _buildTemplatesSection(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Availability',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
      ),
      actions: [
        TextButton(onPressed: _saveSettings, child: const Text('Save')),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickAction(
              'Clear All',
              'Remove all availability',
              Icons.clear_all,
              Colors.red,
              _clearAllAvailability,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickAction(
              'Full Week',
              'Available all week',
              Icons.calendar_today,
              Colors.green,
              _setFullWeekAvailability,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
            color: color.withOpacity(0.05),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyScheduleSection(BuildContext context) {
    return _buildSection(
      context,
      'Weekly Schedule',
      'Set your regular availability for each day',
      [
        ..._weeklySchedule.entries.map((entry) {
          final day = entry.key;
          final timeSlots = entry.value;
          return _buildDaySchedule(context, day, timeSlots);
        }),
      ],
    );
  }

  Widget _buildDaySchedule(
    BuildContext context,
    String day,
    List<TimeSlot> timeSlots,
  ) {
    final dayName = _getDayName(day);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dayName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () => _addTimeSlot(day),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Time'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (timeSlots.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.grey, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'No availability set',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          else
            ...timeSlots.asMap().entries.map((entry) {
              final index = entry.key;
              final timeSlot = entry.value;
              return _buildTimeSlotCard(context, day, index, timeSlot);
            }),
        ],
      ),
    );
  }

  Widget _buildTimeSlotCard(
    BuildContext context,
    String day,
    int index,
    TimeSlot timeSlot,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.schedule,
              size: 16,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${timeSlot.start.format(context)} - ${timeSlot.end.format(context)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _editTimeSlot(day, index, timeSlot),
            icon: const Icon(Icons.edit, size: 16),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            onPressed: () => _removeTimeSlot(day, index),
            icon: const Icon(Icons.delete, size: 16, color: Colors.red),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildVacationModeSection(BuildContext context) {
    return _buildSection(
      context,
      'Vacation Mode',
      'Pause your availability during vacation or busy periods',
      [
        SwitchListTile(
          title: const Text('Enable Vacation Mode'),
          subtitle: Text(
            _vacationMode
                ? 'Your availability is currently paused'
                : 'Set vacation dates to pause availability',
          ),
          value: _vacationMode,
          onChanged: (value) => setState(() => _vacationMode = value),
          contentPadding: EdgeInsets.zero,
        ),
        if (_vacationMode) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDateSelector(
                  'Start Date',
                  _vacationStartDate,
                  (date) => setState(() => _vacationStartDate = date),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDateSelector(
                  'End Date',
                  _vacationEndDate,
                  (date) => setState(() => _vacationEndDate = date),
                ),
              ),
            ],
          ),
          if (_vacationStartDate != null && _vacationEndDate != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You\'ll be unavailable from ${_formatDate(_vacationStartDate!)} to ${_formatDate(_vacationEndDate!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildLastMinuteSection(BuildContext context) {
    return _buildSection(
      context,
      'Last-Minute Availability',
      'Allow others to invite you to games with short notice',
      [
        SwitchListTile(
          title: const Text('Accept Last-Minute Invites'),
          subtitle: Text(
            _lastMinuteAvailability
                ? 'You can be invited up to $_lastMinuteHours hours before games'
                : 'You won\'t receive last-minute invitations',
          ),
          value: _lastMinuteAvailability,
          onChanged: (value) => setState(() => _lastMinuteAvailability = value),
          contentPadding: EdgeInsets.zero,
        ),
        if (_lastMinuteAvailability) ...[
          const SizedBox(height: 16),
          Text(
            'Minimum notice required: $_lastMinuteHours hours',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _lastMinuteHours.toDouble(),
            min: 1,
            max: 24,
            divisions: 23,
            label: '$_lastMinuteHours hours',
            onChanged: (value) =>
                setState(() => _lastMinuteHours = value.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1 hour',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
              Text(
                '24 hours',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTemplatesSection(BuildContext context) {
    return _buildSection(
      context,
      'Quick Templates',
      'Apply common availability patterns',
      [
        ..._templates.map((template) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _applyTemplate(template),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.schedule,
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              template.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              template.description,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String description,
    List<Widget> children,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(
    String label,
    DateTime? date,
    ValueChanged<DateTime> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: date ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (selectedDate != null) {
                onChanged(selectedDate);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    date != null ? _formatDate(date) : 'Select date',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: date != null ? null : Colors.grey[600],
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getDayName(String day) {
    switch (day) {
      case 'monday':
        return 'Monday';
      case 'tuesday':
        return 'Tuesday';
      case 'wednesday':
        return 'Wednesday';
      case 'thursday':
        return 'Thursday';
      case 'friday':
        return 'Friday';
      case 'saturday':
        return 'Saturday';
      case 'sunday':
        return 'Sunday';
      default:
        return day;
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      '',
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
    return '${months[date.month]} ${date.day}, ${date.year}';
  }

  void _addTimeSlot(String day) async {
    final result = await _showTimeSlotDialog(context);
    if (result != null) {
      setState(() {
        _weeklySchedule[day]!.add(result);
        // Sort time slots by start time
        _weeklySchedule[day]!.sort(
          (a, b) => _compareTimeOfDay(a.start, b.start),
        );
      });
    }
  }

  void _editTimeSlot(String day, int index, TimeSlot currentSlot) async {
    final result = await _showTimeSlotDialog(context, currentSlot: currentSlot);
    if (result != null) {
      setState(() {
        _weeklySchedule[day]![index] = result;
        // Sort time slots by start time
        _weeklySchedule[day]!.sort(
          (a, b) => _compareTimeOfDay(a.start, b.start),
        );
      });
    }
  }

  void _removeTimeSlot(String day, int index) {
    setState(() {
      _weeklySchedule[day]!.removeAt(index);
    });
  }

  void _clearAllAvailability() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Availability'),
        content: const Text(
          'Are you sure you want to remove all your availability? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                for (final day in _weeklySchedule.keys) {
                  _weeklySchedule[day]!.clear();
                }
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All availability cleared'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _setFullWeekAvailability() {
    setState(() {
      for (final day in _weeklySchedule.keys) {
        _weeklySchedule[day]!.clear();
        _weeklySchedule[day]!.add(
          TimeSlot(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 17, minute: 0),
          ),
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Full week availability set (9 AM - 5 PM)'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _applyTemplate(AvailabilityTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apply ${template.name}'),
        content: Text(
          'This will replace your current availability with the ${template.name} template. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _weeklySchedule.clear();
                for (final entry in template.schedule.entries) {
                  _weeklySchedule[entry.key] = List.from(entry.value);
                }
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${template.name} template applied'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<TimeSlot?> _showTimeSlotDialog(
    BuildContext context, {
    TimeSlot? currentSlot,
  }) async {
    TimeOfDay startTime =
        currentSlot?.start ?? const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime =
        currentSlot?.end ?? const TimeOfDay(hour: 17, minute: 0);

    return await showDialog<TimeSlot>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(currentSlot != null ? 'Edit Time Slot' : 'Add Time Slot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Start Time'),
                subtitle: Text(startTime.format(context)),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: startTime,
                  );
                  if (time != null) {
                    setDialogState(() => startTime = time);
                  }
                },
              ),
              ListTile(
                title: const Text('End Time'),
                subtitle: Text(endTime.format(context)),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: endTime,
                  );
                  if (time != null) {
                    setDialogState(() => endTime = time);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (_compareTimeOfDay(startTime, endTime) < 0) {
                  Navigator.of(
                    context,
                  ).pop(TimeSlot(start: startTime, end: endTime));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('End time must be after start time'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(currentSlot != null ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  int _compareTimeOfDay(TimeOfDay a, TimeOfDay b) {
    if (a.hour != b.hour) {
      return a.hour.compareTo(b.hour);
    }
    return a.minute.compareTo(b.minute);
  }

  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Availability settings saved!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class TimeSlot {
  final TimeOfDay start;
  final TimeOfDay end;

  TimeSlot({required this.start, required this.end});
}

class AvailabilityTemplate {
  final String name;
  final String description;
  final Map<String, List<TimeSlot>> schedule;

  AvailabilityTemplate({
    required this.name,
    required this.description,
    required this.schedule,
  });
}
