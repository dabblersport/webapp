import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Per-day availability, as a paged month grid. No design frame (PLAN §2c):
/// DS surfaces and status roles at their defaults.
///
/// [DabblerCalendar] is not used: it selects dates, while this grid paints a
/// four-way status per day, which the DS calendar has no slot for (DS gap).
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

/// The status roles, labels and fills both views share.
abstract final class _Availability {
  static DabblerStatusColor? statusOf(
    DabblerColors colors,
    AvailabilityStatus status,
  ) {
    switch (status) {
      case AvailabilityStatus.available:
        return colors.success;
      case AvailabilityStatus.maybe:
        return colors.warning;
      case AvailabilityStatus.busy:
        return colors.error;
      case AvailabilityStatus.notSet:
        return null;
    }
  }

  static Color dot(DabblerColors colors, AvailabilityStatus s) =>
      statusOf(colors, s)?.base ?? colors.borderStrong;

  static Color fill(DabblerColors colors, AvailabilityStatus s) =>
      statusOf(colors, s)?.surface ?? colors.surfaceGrey;

  static Color ink(DabblerColors colors, AvailabilityStatus s) =>
      statusOf(colors, s)?.strong ?? colors.textPrimary;

  static String label(AvailabilityStatus status, {bool short = false}) {
    switch (status) {
      case AvailabilityStatus.available:
        return 'Available';
      case AvailabilityStatus.maybe:
        return short ? 'Maybe' : 'Maybe Available';
      case AvailabilityStatus.busy:
        return 'Busy';
      case AvailabilityStatus.notSet:
        return 'Not Set';
    }
  }

  static Widget dotWidget(DabblerColors colors, AvailabilityStatus s,
      {double size = 12}) {
    return DabblerSurface(
      width: size,
      height: size,
      radius: DabblerRadius.pill,
      fill: dot(colors, s),
      borderWidth: 0,
    );
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
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

  TextStyle _style(DabblerTypeStyle style) =>
      style.resolveForDirection(Directionality.of(context));

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        const SizedBox(height: DabblerSpacing.space5),
        _buildLegend(),
        const SizedBox(height: DabblerSpacing.space5),
        _buildCalendar(),
        if (widget.selectedDate != null) ...[
          const SizedBox(height: DabblerSpacing.space5),
          _buildSelectedDateInfo(),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    final colors = DabblerColors.of(context);
    final currentMonth = DateTime.now().add(Duration(days: _currentPage * 30));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        DabblerButton.icon(
          icon: 'arrow-left-2',
          semanticLabel: 'Previous month',
          disabled: _currentPage <= 0,
          onPressed: _currentPage > 0 ? _previousMonth : null,
        ),
        Text(
          DateFormat('MMMM yyyy').format(currentMonth),
          style: _style(DabblerType.title3).copyWith(color: colors.textPrimary),
        ),
        DabblerButton.icon(
          icon: 'arrow-right-2',
          semanticLabel: 'Next month',
          disabled: _currentPage >= widget.monthsToShow - 1,
          onPressed:
              _currentPage < widget.monthsToShow - 1 ? _nextMonth : null,
        ),
      ],
    );
  }

  Widget _buildLegend() {
    final colors = DabblerColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final status in AvailabilityStatus.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Availability.dotWidget(colors, status),
              const SizedBox(width: DabblerSpacing.space1),
              Text(
                _Availability.label(status, short: true),
                style: _style(DabblerType.caption1)
                    .copyWith(color: colors.textSecondary),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCalendar() {
    return DabblerSurface.card(
      height: 300,
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
    final colors = DabblerColors.of(context);
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
    final firstDayOfWeek = firstDayOfMonth.weekday % 7;

    // Generate all days for the month view (including padding days)
    final days = <DateTime?>[
      for (int i = 0; i < firstDayOfWeek; i++) null,
      for (int day = 1; day <= lastDayOfMonth.day; day++)
        DateTime(month.year, month.month, day),
    ];

    return Padding(
      padding: const EdgeInsetsDirectional.all(DabblerSpacing.space5),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: [
              for (final day in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: _style(DabblerType.caption1).copyWith(
                        fontWeight: DabblerType.bold,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: DabblerSpacing.space3),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                crossAxisSpacing: DabblerSpacing.space1,
                mainAxisSpacing: DabblerSpacing.space1,
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
    final colors = DabblerColors.of(context);
    final availability = widget.availability[date] ?? AvailabilityStatus.notSet;
    final isSelected =
        widget.selectedDate != null &&
        _Availability.sameDay(date, widget.selectedDate!);
    final isToday = _Availability.sameDay(DateTime.now(), date);

    return GestureDetector(
      onTap: () {
        widget.onDateSelected?.call(date);
        if (widget.isEditable) {
          _showAvailabilitySelector(date, availability);
        }
      },
      child: DabblerSurface(
        radius: DabblerRadius.md,
        fill: _Availability.fill(colors, availability),
        borderColor: isSelected || isToday ? colors.brandPrimary : null,
        borderWidth: isSelected ? 2 : (isToday ? 1 : 0),
        center: true,
        child: Text(
          date.day.toString(),
          style: _style(DabblerType.footnote).copyWith(
            fontWeight: isToday ? DabblerType.bold : DabblerType.regular,
            color: _Availability.ink(colors, availability),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedDateInfo() {
    if (widget.selectedDate == null) return const SizedBox.shrink();
    final colors = DabblerColors.of(context);

    final date = widget.selectedDate!;
    final availability = widget.availability[date] ?? AvailabilityStatus.notSet;
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(date);

    return DabblerSurface.card(
      padding: const EdgeInsetsDirectional.all(DabblerSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            formattedDate,
            style: _style(DabblerType.headline)
                .copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: DabblerSpacing.space3),
          Row(
            children: [
              _Availability.dotWidget(colors, availability, size: 16),
              const SizedBox(width: DabblerSpacing.space3),
              Text(
                _Availability.label(availability),
                style: _style(DabblerType.body)
                    .copyWith(color: colors.textPrimary),
              ),
            ],
          ),
          if (widget.isEditable) ...[
            const SizedBox(height: DabblerSpacing.space4),
            DabblerButton(
              label: 'Change Availability',
              fullWidth: true,
              onPressed: () => _showAvailabilitySelector(date, availability),
            ),
          ],
        ],
      ),
    );
  }

  void _showAvailabilitySelector(DateTime date, AvailabilityStatus current) {
    showDabblerDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colors = DabblerColors.of(dialogContext);
        return DabblerDialog(
          title: 'Set Availability',
          description: DateFormat('EEEE, MMMM d, yyyy').format(date),
          onClose: () => Navigator.of(dialogContext).pop(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final status in AvailabilityStatus.values)
                DabblerInputRow(
                  leading: _Availability.dotWidget(colors, status, size: 16),
                  title: _Availability.label(status),
                  trailing: status == current
                      ? DabblerIcon(
                          'tick-circle',
                          size: DabblerSizing.iconMd,
                          color: colors.brandPrimary,
                        )
                      : null,
                  onTap: () {
                    widget.onAvailabilityChanged?.call(date, status);
                    Navigator.of(dialogContext).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _previousMonth() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: DabblerMotion.base,
        curve: DabblerMotion.easeOut,
      );
    }
  }

  void _nextMonth() {
    if (_currentPage < widget.monthsToShow - 1) {
      _pageController.nextPage(
        duration: DabblerMotion.base,
        curve: DabblerMotion.easeOut,
      );
    }
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

  TextStyle _style(DabblerTypeStyle style) =>
      style.resolveForDirection(Directionality.of(context));

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildWeekHeader(),
        const SizedBox(height: DabblerSpacing.space4),
        _buildWeekDays(),
      ],
    );
  }

  Widget _buildWeekHeader() {
    final colors = DabblerColors.of(context);
    final weekEnd = _currentWeekStart.add(const Duration(days: 6));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        DabblerButton.icon(
          icon: 'arrow-left-2',
          semanticLabel: 'Previous week',
          onPressed: () {
            setState(() {
              _currentWeekStart = _currentWeekStart.subtract(
                const Duration(days: 7),
              );
            });
          },
        ),
        Text(
          '${DateFormat('MMM d').format(_currentWeekStart)} - ${DateFormat('MMM d').format(weekEnd)}',
          style: _style(DabblerType.headline)
              .copyWith(color: colors.textPrimary),
        ),
        DabblerButton.icon(
          icon: 'arrow-right-2',
          semanticLabel: 'Next week',
          onPressed: () {
            setState(() {
              _currentWeekStart = _currentWeekStart.add(
                const Duration(days: 7),
              );
            });
          },
        ),
      ],
    );
  }

  Widget _buildWeekDays() {
    final colors = DabblerColors.of(context);
    return Row(
      children: List.generate(7, (index) {
        final date = _currentWeekStart.add(Duration(days: index));
        final availability =
            widget.availability[date] ?? AvailabilityStatus.notSet;
        final isToday = _Availability.sameDay(DateTime.now(), date);
        final ink = _Availability.ink(colors, availability);

        return Expanded(
          child: GestureDetector(
            onTap: widget.isEditable
                ? () => _showQuickAvailabilitySelector(date, availability)
                : null,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 2),
              child: DabblerSurface(
                radius: DabblerRadius.md,
                fill: _Availability.fill(colors, availability),
                borderColor: isToday ? colors.brandPrimary : null,
                borderWidth: isToday ? 2 : 0,
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: DabblerSpacing.space4,
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('E').format(date),
                      style: _style(DabblerType.caption1)
                          .copyWith(fontWeight: DabblerType.bold, color: ink),
                    ),
                    const SizedBox(height: DabblerSpacing.space1),
                    Text(
                      date.day.toString(),
                      style: _style(DabblerType.headline).copyWith(color: ink),
                    ),
                  ],
                ),
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
    showDabblerSheet<void>(
      context: context,
      title: 'Set availability for ${DateFormat('EEEE, MMM d').format(date)}',
      detent: DabblerSheetDetent.content,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space6,
          0,
          DabblerSpacing.space6,
          DabblerSpacing.space8,
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: DabblerSpacing.space3,
          runSpacing: DabblerSpacing.space3,
          children: [
            for (final status in AvailabilityStatus.values)
              DabblerChip(
                label: _Availability.label(status, short: true),
                selected: current == status,
                onTap: () {
                  widget.onAvailabilityChanged?.call(date, status);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }
}
