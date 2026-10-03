import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'profile_edit_models.dart';

/// "Weekly Availability": the slots, each removable, and an Add action that
/// opens [ProfileEditAddAvailabilitySheet]. No design frame (PLAN §2c).
class ProfileEditAvailabilitySection extends StatelessWidget {
  const ProfileEditAvailabilitySection({
    super.key,
    required this.slots,
    required this.onAdd,
    required this.onRemove,
  });

  final List<ProfileEditTimeSlot> slots;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return DabblerSection(
      title: 'Weekly Availability',
      subtitle: 'Set your available times for games and activities.',
      action: DabblerButton(
        label: 'Add',
        icon: 'add',
        tone: DabblerButtonTone.text,
        size: DabblerButtonSize.small,
        onPressed: onAdd,
      ),
      children: [
        if (slots.isEmpty)
          const DabblerEmptyState(
            icon: 'calendar-add',
            text: 'No availability set. Add times when you\'re free to play.',
          )
        else
          for (var i = 0; i < slots.length; i++) _slotRow(slots[i], i),
      ],
    );
  }

  Widget _slotRow(ProfileEditTimeSlot slot, int index) {
    final dayName = ProfileEditSports.dayName(slot.dayOfWeek);
    return DabblerInputRow(
      leading: DabblerIconTile(Text(dayName.substring(0, 2))),
      title: dayName,
      subtitle:
          '${ProfileEditSports.formatHour(slot.startHour)} - ${ProfileEditSports.formatHour(slot.endHour)}',
      trailing: DabblerButton.icon(
        icon: 'trash',
        semanticLabel: 'Remove $dayName availability',
        onPressed: () => onRemove(index),
      ),
    );
  }
}

/// The body of the "Add Availability" sheet: a day, a start and an end hour.
/// An end at or before the start is refused with a toast, as before; a valid
/// slot is handed to [onAdd] and the sheet closes.
class ProfileEditAddAvailabilitySheet extends StatefulWidget {
  const ProfileEditAddAvailabilitySheet({super.key, required this.onAdd});

  final ValueChanged<ProfileEditTimeSlot> onAdd;

  @override
  State<ProfileEditAddAvailabilitySheet> createState() =>
      _ProfileEditAddAvailabilitySheetState();
}

class _ProfileEditAddAvailabilitySheetState
    extends State<ProfileEditAddAvailabilitySheet> {
  int _selectedDay = 1; // Monday
  int _startHour = 9;
  int _endHour = 17;

  static final List<DabblerSelectOption<int>> _hours =
      <DabblerSelectOption<int>>[
        for (var h = 0; h < 24; h++)
          DabblerSelectOption<int>(
            value: h,
            label: ProfileEditSports.formatHour(h),
          ),
      ];

  void _submit() {
    if (_startHour >= _endHour) {
      DabblerToastProvider.of(context).show(
        const DabblerToastSpec(
          message: 'End time must be after start time',
          tone: DabblerToastTone.error,
        ),
      );
      return;
    }
    widget.onAdd(
      ProfileEditTimeSlot(
        dayOfWeek: _selectedDay,
        startHour: _startHour,
        endHour: _endHour,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final labelStyle = DabblerType.subheadline
        .resolveForDirection(Directionality.of(context))
        .copyWith(color: colors.textPrimary, fontWeight: DabblerType.semibold);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        DabblerSpacing.space6,
        0,
        DabblerSpacing.space6,
        DabblerSpacing.space8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Day', style: labelStyle),
          const SizedBox(height: DabblerSpacing.space3),
          Wrap(
            spacing: DabblerSpacing.space3,
            runSpacing: DabblerSpacing.space3,
            children: [
              for (var day = 1; day <= 7; day++)
                DabblerChip(
                  label: ProfileEditSports.dayName(day).substring(0, 3),
                  selected: _selectedDay == day,
                  onTap: () => setState(() => _selectedDay = day),
                ),
            ],
          ),
          const SizedBox(height: DabblerSpacing.space7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DabblerSelect<int>(
                  label: 'Start Time',
                  value: _startHour,
                  options: _hours,
                  searchable: true,
                  onChanged: (h) => setState(() => _startHour = h),
                ),
              ),
              const SizedBox(width: DabblerSpacing.space5),
              Expanded(
                child: DabblerSelect<int>(
                  label: 'End Time',
                  value: _endHour,
                  options: _hours,
                  searchable: true,
                  onChanged: (h) => setState(() => _endHour = h),
                ),
              ),
            ],
          ),
          const SizedBox(height: DabblerSpacing.space8),
          DabblerButton(
            label: 'Add Availability',
            fullWidth: true,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
