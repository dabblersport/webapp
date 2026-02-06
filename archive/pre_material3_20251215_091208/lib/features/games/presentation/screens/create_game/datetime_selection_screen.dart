import 'package:flutter/material.dart';

class DateTimeSelectionScreen extends StatefulWidget {
  final Function(DateTime, TimeOfDay, TimeOfDay) onDateTimeSelected;
  final DateTime? selectedDate;
  final TimeOfDay? selectedStartTime;
  final TimeOfDay? selectedEndTime;
  final String? sport;

  const DateTimeSelectionScreen({
    super.key,
    required this.onDateTimeSelected,
    this.selectedDate,
    this.selectedStartTime,
    this.selectedEndTime,
    this.sport,
  });

  @override
  State<DateTimeSelectionScreen> createState() =>
      _DateTimeSelectionScreenState();
}

class _DateTimeSelectionScreenState extends State<DateTimeSelectionScreen> {
  DateTime? _selectedDay;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int _durationMinutes = 90; // Default duration
  bool _isRecurring = false;

  final Map<DateTime, List<Map<String, dynamic>>> _existingBookings = {
    DateTime(2025, 8, 12): [
      {'time': '14:00', 'title': 'Basketball Game', 'type': 'game'},
      {'time': '16:00', 'title': 'Court Maintenance', 'type': 'blocked'},
    ],
    DateTime(2025, 8, 15): [
      {'time': '18:00', 'title': 'Soccer Match', 'type': 'game'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.selectedDate;
    _startTime = widget.selectedStartTime;
    _endTime = widget.selectedEndTime;

    // Set default duration based on sport
    _setDefaultDurationForSport();
  }

  void _setDefaultDurationForSport() {
    switch (widget.sport?.toLowerCase()) {
      case 'basketball':
        _durationMinutes = 90;
        break;
      case 'soccer':
      case 'football':
        _durationMinutes = 120;
        break;
      case 'tennis':
        _durationMinutes = 60;
        break;
      case 'volleyball':
        _durationMinutes = 60;
        break;
      default:
        _durationMinutes = 90;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'When do you want to play?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose your preferred date and time. We\'ll check for venue availability.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            _buildDateSelection(),
            const SizedBox(height: 24),

            if (_selectedDay != null) ...[
              _buildTimeSelection(),
              const SizedBox(height: 24),
              _buildDurationSelector(),
              const SizedBox(height: 24),
              _buildExistingBookings(),
              const SizedBox(height: 24),
              _buildRecurringOption(),
              const SizedBox(height: 24),
              _buildConflictWarnings(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Select Date',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Date picker button
            GestureDetector(
              onTap: () async {
                final selectedDate = await showDatePicker(
                  context: context,
                  initialDate: _selectedDay ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (selectedDate != null) {
                  setState(() {
                    _selectedDay = selectedDate;
                  });
                  _updateDateTime();
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: _selectedDay != null
                      ? Colors.blue[50]
                      : Colors.grey[50],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month,
                      color: _selectedDay != null
                          ? Colors.blue
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedDay != null
                                ? _formatDate(_selectedDay!)
                                : 'Select a date',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _selectedDay != null
                                  ? Colors.blue
                                  : Colors.grey[600],
                            ),
                          ),
                          if (_selectedDay != null)
                            Text(
                              _getDayOfWeek(_selectedDay!),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Quick date options
            const Text(
              'Quick Select',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              children: [
                _buildDateChip('Today', DateTime.now()),
                _buildDateChip(
                  'Tomorrow',
                  DateTime.now().add(const Duration(days: 1)),
                ),
                _buildDateChip('This Weekend', _getNextWeekend()),
                _buildDateChip(
                  'Next Week',
                  DateTime.now().add(const Duration(days: 7)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.schedule, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Select Time',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildTimeField('Start Time', _startTime, (time) {
                    setState(() {
                      _startTime = time;
                      // Auto-calculate end time based on duration
                      if (time != null) {
                        final startMinutes = time.hour * 60 + time.minute;
                        final endMinutes = startMinutes + _durationMinutes;
                        _endTime = TimeOfDay(
                          hour: (endMinutes ~/ 60) % 24,
                          minute: endMinutes % 60,
                        );
                      }
                    });
                    _updateDateTime();
                  }),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimeField('End Time', _endTime, (time) {
                    setState(() {
                      _endTime = time;
                      // Update duration based on time difference
                      if (_startTime != null && time != null) {
                        final startMinutes =
                            _startTime!.hour * 60 + _startTime!.minute;
                        final endMinutes = time.hour * 60 + time.minute;
                        _durationMinutes = endMinutes - startMinutes;
                        if (_durationMinutes < 0) {
                          _durationMinutes += 24 * 60; // Handle next day
                        }
                      }
                    });
                    _updateDateTime();
                  }),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Quick time suggestions
            const Text(
              'Popular Times',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              children: [
                _buildTimeChip('Morning', const TimeOfDay(hour: 9, minute: 0)),
                _buildTimeChip('Lunch', const TimeOfDay(hour: 12, minute: 0)),
                _buildTimeChip(
                  'Afternoon',
                  const TimeOfDay(hour: 15, minute: 0),
                ),
                _buildTimeChip('Evening', const TimeOfDay(hour: 18, minute: 0)),
                _buildTimeChip('Night', const TimeOfDay(hour: 20, minute: 0)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField(
    String label,
    TimeOfDay? time,
    Function(TimeOfDay?) onChanged,
  ) {
    return GestureDetector(
      onTap: () async {
        final selectedTime = await showTimePicker(
          context: context,
          initialTime: time ?? TimeOfDay.now(),
        );
        if (selectedTime != null) {
          onChanged(selectedTime);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  time?.format(context) ?? 'Select time',
                  style: TextStyle(
                    fontSize: 16,
                    color: time != null ? Colors.black : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeChip(String label, TimeOfDay time) {
    final isSelected = _startTime == time;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _startTime = time;
            final startMinutes = time.hour * 60 + time.minute;
            final endMinutes = startMinutes + _durationMinutes;
            _endTime = TimeOfDay(
              hour: (endMinutes ~/ 60) % 24,
              minute: endMinutes % 60,
            );
          });
          _updateDateTime();
        }
      },
    );
  }

  Widget _buildDurationSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timer, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Game Duration',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Duration: ${_durationMinutes ~/ 60}h ${_durationMinutes % 60}m',
                  ),
                ),
                Text('${(_durationMinutes / 60).toStringAsFixed(1)} hours'),
              ],
            ),
            const SizedBox(height: 8),

            Slider(
              value: _durationMinutes.toDouble(),
              min: 30,
              max: 300,
              divisions: 27, // 30min increments
              label: '${_durationMinutes ~/ 60}h ${_durationMinutes % 60}m',
              onChanged: (value) {
                setState(() {
                  _durationMinutes = value.round();
                  // Update end time if start time is set
                  if (_startTime != null) {
                    final startMinutes =
                        _startTime!.hour * 60 + _startTime!.minute;
                    final endMinutes = startMinutes + _durationMinutes;
                    _endTime = TimeOfDay(
                      hour: (endMinutes ~/ 60) % 24,
                      minute: endMinutes % 60,
                    );
                  }
                });
                _updateDateTime();
              },
            ),

            const SizedBox(height: 8),

            // Duration presets
            Wrap(
              spacing: 8,
              children: [
                _buildDurationChip('30 min', 30),
                _buildDurationChip('1 hour', 60),
                _buildDurationChip('1.5 hours', 90),
                _buildDurationChip('2 hours', 120),
                _buildDurationChip('3 hours', 180),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationChip(String label, int minutes) {
    final isSelected = _durationMinutes == minutes;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _durationMinutes = minutes;
            // Update end time if start time is set
            if (_startTime != null) {
              final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
              final endMinutes = startMinutes + _durationMinutes;
              _endTime = TimeOfDay(
                hour: (endMinutes ~/ 60) % 24,
                minute: endMinutes % 60,
              );
            }
          });
          _updateDateTime();
        }
      },
    );
  }

  Widget _buildExistingBookings() {
    if (_selectedDay == null) return const SizedBox.shrink();

    final dayKey = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
    );
    final bookings = _existingBookings[dayKey] ?? [];

    if (bookings.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600]),
              const SizedBox(width: 12),
              const Text(
                'No conflicts found for this date',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.event_busy, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Existing Bookings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ...bookings.map(
              (booking) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: booking['type'] == 'blocked'
                      ? Colors.red[50]
                      : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: booking['type'] == 'blocked'
                        ? Colors.red[200]!
                        : Colors.orange[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      booking['type'] == 'blocked' ? Icons.block : Icons.sports,
                      color: booking['type'] == 'blocked'
                          ? Colors.red[600]
                          : Colors.orange[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking['title'],
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            booking['time'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringOption() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.repeat, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Recurring Game',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Create a series of games that repeat weekly',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 12),

            SwitchListTile(
              title: const Text('Make this a recurring game'),
              subtitle: const Text('Players can join future occurrences'),
              value: _isRecurring,
              onChanged: (value) {
                setState(() {
                  _isRecurring = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            if (_isRecurring) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coming Soon!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Recurring games feature will be available in a future update.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConflictWarnings() {
    if (_startTime == null || _endTime == null || _selectedDay == null) {
      return const SizedBox.shrink();
    }

    final warnings = _checkForConflicts();
    if (warnings.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Potential Conflicts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ...warnings.map(
              (warning) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(warning),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _checkForConflicts() {
    final warnings = <String>[];

    // Check if selected time is in the past
    if (_selectedDay != null && _startTime != null) {
      final selectedDateTime = DateTime(
        _selectedDay!.year,
        _selectedDay!.month,
        _selectedDay!.day,
        _startTime!.hour,
        _startTime!.minute,
      );

      if (selectedDateTime.isBefore(DateTime.now())) {
        warnings.add('Selected time is in the past');
      }
    }

    // Check for booking conflicts
    if (_selectedDay != null && _startTime != null && _endTime != null) {
      final dayKey = DateTime(
        _selectedDay!.year,
        _selectedDay!.month,
        _selectedDay!.day,
      );
      final bookings = _existingBookings[dayKey] ?? [];

      for (final booking in bookings) {
        // Simple time overlap check (would need more sophisticated logic in real app)
        final bookingTime = booking['time'] as String;
        final bookingHour = int.parse(bookingTime.split(':')[0]);

        if (bookingHour >= _startTime!.hour && bookingHour < _endTime!.hour) {
          warnings.add('Conflicts with existing booking: ${booking['title']}');
        }
      }
    }

    return warnings;
  }

  void _updateDateTime() {
    if (_selectedDay != null && _startTime != null && _endTime != null) {
      widget.onDateTimeSelected(_selectedDay!, _startTime!, _endTime!);
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month]} ${date.day}, ${date.year}';
  }

  String _getDayOfWeek(DateTime date) {
    const days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[date.weekday];
  }

  DateTime _getNextWeekend() {
    final now = DateTime.now();
    final daysUntilSaturday = 6 - now.weekday;
    return now.add(Duration(days: daysUntilSaturday));
  }

  Widget _buildDateChip(String label, DateTime date) {
    final isSelected =
        _selectedDay != null &&
        date.year == _selectedDay!.year &&
        date.month == _selectedDay!.month &&
        date.day == _selectedDay!.day;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedDay = date;
          });
          _updateDateTime();
        }
      },
    );
  }
}
