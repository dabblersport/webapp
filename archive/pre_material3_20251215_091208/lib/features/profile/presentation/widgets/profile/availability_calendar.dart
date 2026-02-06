import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AvailabilityCalendar extends StatefulWidget {
  final Map<DateTime, AvailabilityStatus> availability;
  final Function(DateTime, AvailabilityStatus)? onAvailabilityChanged;
  final bool isEditable;
  final DateTime? selectedDate;
  final Function(DateTime)? onDateSelected;
  final int monthsToShow;

  const AvailabilityCalendar({
    super.key,
    required this.availability,
    this.onAvailabilityChanged,
    this.isEditable = false,
    this.selectedDate,
    this.onDateSelected,
    this.monthsToShow = 3,
  });

  @override
  State<AvailabilityCalendar> createState() => _AvailabilityCalendarState();
}

class _AvailabilityCalendarState extends State<AvailabilityCalendar> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildLegend(),
        const SizedBox(height: 16),
        _buildCalendar(),
        if (widget.selectedDate != null) ...[
          const SizedBox(height: 16),
          _buildSelectedDateInfo(),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    final currentMonth = DateTime.now().add(Duration(days: _currentPage * 30));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: _currentPage > 0 ? _previousMonth : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          DateFormat('MMMM yyyy').format(currentMonth),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        IconButton(
          onPressed: _currentPage < widget.monthsToShow - 1 ? _nextMonth : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _LegendItem(
          color: Colors.green,
          label: 'Available',
          status: AvailabilityStatus.available,
        ),
        _LegendItem(
          color: Colors.orange,
          label: 'Maybe',
          status: AvailabilityStatus.maybe,
        ),
        _LegendItem(
          color: Colors.red,
          label: 'Busy',
          status: AvailabilityStatus.busy,
        ),
        _LegendItem(
          color: Colors.grey,
          label: 'Not Set',
          status: AvailabilityStatus.notSet,
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
        ),
      ),
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (page) => setState(() => _currentPage = page),
        itemCount: widget.monthsToShow,
        itemBuilder: (context, index) {
          final month = DateTime.now().add(Duration(days: index * 30));
          return _buildMonthView(month);
        },
      ),
    );
  }

  Widget _buildMonthView(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
    final firstDayOfWeek = firstDayOfMonth.weekday % 7;

    // Generate all days for the month view (including padding days)
    final days = <DateTime?>[];

    // Add empty days for padding
    for (int i = 0; i < firstDayOfWeek; i++) {
      days.add(null);
    }

    // Add actual days of the month
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      days.add(DateTime(month.year, month.month, day));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Weekday headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(
                            context,
                          ).textTheme.bodySmall?.color?.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),

          // Calendar grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final date = days[index];
                if (date == null) {
                  return const SizedBox.shrink();
                }

                return _buildDayCell(date);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(DateTime date) {
    final availability = widget.availability[date] ?? AvailabilityStatus.notSet;
    final isSelected =
        widget.selectedDate != null &&
        date.year == widget.selectedDate!.year &&
        date.month == widget.selectedDate!.month &&
        date.day == widget.selectedDate!.day;
    final isToday =
        DateTime.now().year == date.year &&
        DateTime.now().month == date.month &&
        DateTime.now().day == date.day;

    return GestureDetector(
      onTap: () {
        widget.onDateSelected?.call(date);
        if (widget.isEditable) {
          _showAvailabilitySelector(date, availability);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: _getAvailabilityColor(availability).withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : isToday
                ? Theme.of(context).primaryColor.withOpacity(0.5)
                : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            date.day.toString(),
            style: TextStyle(
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              color: _getTextColor(availability),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedDateInfo() {
    if (widget.selectedDate == null) return const SizedBox.shrink();

    final date = widget.selectedDate!;
    final availability = widget.availability[date] ?? AvailabilityStatus.notSet;
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(date);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formattedDate,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _getAvailabilityColor(availability),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getAvailabilityLabel(availability),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          if (widget.isEditable) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showAvailabilitySelector(date, availability),
                child: const Text('Change Availability'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getAvailabilityColor(AvailabilityStatus status) {
    switch (status) {
      case AvailabilityStatus.available:
        return Colors.green;
      case AvailabilityStatus.maybe:
        return Colors.orange;
      case AvailabilityStatus.busy:
        return Colors.red;
      case AvailabilityStatus.notSet:
        return Colors.grey[300]!;
    }
  }

  Color _getTextColor(AvailabilityStatus status) {
    switch (status) {
      case AvailabilityStatus.available:
      case AvailabilityStatus.maybe:
      case AvailabilityStatus.busy:
        return Colors.white;
      case AvailabilityStatus.notSet:
        return Colors.black;
    }
  }

  String _getAvailabilityLabel(AvailabilityStatus status) {
    switch (status) {
      case AvailabilityStatus.available:
        return 'Available';
      case AvailabilityStatus.maybe:
        return 'Maybe Available';
      case AvailabilityStatus.busy:
        return 'Busy';
      case AvailabilityStatus.notSet:
        return 'Not Set';
    }
  }

  void _showAvailabilitySelector(DateTime date, AvailabilityStatus current) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Availability'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(date),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            ...AvailabilityStatus.values.map(
              (status) => RadioListTile(
                title: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _getAvailabilityColor(status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_getAvailabilityLabel(status)),
                  ],
                ),
                value: status,
                groupValue: current,
                onChanged: (value) {
                  if (value != null) {
                    widget.onAvailabilityChanged?.call(date, value);
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _previousMonth() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextMonth() {
    if (_currentPage < widget.monthsToShow - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final AvailabilityStatus status;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

enum AvailabilityStatus { available, maybe, busy, notSet }

// Compact weekly view for smaller spaces
class WeeklyAvailabilityView extends StatefulWidget {
  final Map<DateTime, AvailabilityStatus> availability;
  final Function(DateTime, AvailabilityStatus)? onAvailabilityChanged;
  final bool isEditable;

  const WeeklyAvailabilityView({
    super.key,
    required this.availability,
    this.onAvailabilityChanged,
    this.isEditable = false,
  });

  @override
  State<WeeklyAvailabilityView> createState() => _WeeklyAvailabilityViewState();
}

class _WeeklyAvailabilityViewState extends State<WeeklyAvailabilityView> {
  DateTime _currentWeekStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentWeekStart = _getWeekStart(DateTime.now());
  }

  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday % 7;
    return date.subtract(Duration(days: weekday));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildWeekHeader(),
        const SizedBox(height: 12),
        _buildWeekDays(),
      ],
    );
  }

  Widget _buildWeekHeader() {
    final weekEnd = _currentWeekStart.add(const Duration(days: 6));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _currentWeekStart = _currentWeekStart.subtract(
                const Duration(days: 7),
              );
            });
          },
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          '${DateFormat('MMM d').format(_currentWeekStart)} - ${DateFormat('MMM d').format(weekEnd)}',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _currentWeekStart = _currentWeekStart.add(
                const Duration(days: 7),
              );
            });
          },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildWeekDays() {
    return Row(
      children: List.generate(7, (index) {
        final date = _currentWeekStart.add(Duration(days: index));
        final availability =
            widget.availability[date] ?? AvailabilityStatus.notSet;
        final isToday =
            DateTime.now().year == date.year &&
            DateTime.now().month == date.month &&
            DateTime.now().day == date.day;

        return Expanded(
          child: GestureDetector(
            onTap: widget.isEditable
                ? () => _showQuickAvailabilitySelector(date, availability)
                : null,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _getAvailabilityColor(availability).withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
                border: isToday
                    ? Border.all(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      )
                    : null,
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('E').format(date),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getTextColor(availability),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getTextColor(availability),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  void _showQuickAvailabilitySelector(
    DateTime date,
    AvailabilityStatus current,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Set availability for ${DateFormat('EEEE, MMM d').format(date)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: AvailabilityStatus.values.map((status) {
                return GestureDetector(
                  onTap: () {
                    widget.onAvailabilityChanged?.call(date, status);
                    Navigator.pop(context);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _getAvailabilityColor(status),
                          shape: BoxShape.circle,
                          border: current == status
                              ? Border.all(
                                  color: Theme.of(context).primaryColor,
                                  width: 3,
                                )
                              : null,
                        ),
                        child: current == status
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getAvailabilityLabel(status),
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Color _getAvailabilityColor(AvailabilityStatus status) {
    switch (status) {
      case AvailabilityStatus.available:
        return Colors.green;
      case AvailabilityStatus.maybe:
        return Colors.orange;
      case AvailabilityStatus.busy:
        return Colors.red;
      case AvailabilityStatus.notSet:
        return Colors.grey[300]!;
    }
  }

  Color _getTextColor(AvailabilityStatus status) {
    switch (status) {
      case AvailabilityStatus.available:
      case AvailabilityStatus.maybe:
      case AvailabilityStatus.busy:
        return Colors.white;
      case AvailabilityStatus.notSet:
        return Colors.black;
    }
  }

  String _getAvailabilityLabel(AvailabilityStatus status) {
    switch (status) {
      case AvailabilityStatus.available:
        return 'Available';
      case AvailabilityStatus.maybe:
        return 'Maybe';
      case AvailabilityStatus.busy:
        return 'Busy';
      case AvailabilityStatus.notSet:
        return 'Not Set';
    }
  }
}
