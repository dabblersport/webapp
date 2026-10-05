import 'package:dabbler/core/utils/avatar_url_resolver.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// A [DabblerTextField] that takes part in the screen's [Form]: the
/// [validator] runs on [Form.validate] against the controller's text and its
/// message is shown as the field's error line — what `TextFormField` did
/// before KAN-418.
class ProfileEditTextField extends StatelessWidget {
  const ProfileEditTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.hintText,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.readOnly = false,
    this.helperText,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool readOnly;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: validator == null ? null : (_) => validator!(controller.text),
      builder: (state) => DabblerTextField(
        variant: maxLines > 1
            ? DabblerTextFieldVariant.multiline
            : DabblerTextFieldVariant.standard,
        rows: maxLines > 1 ? maxLines : DabblerTextField.defaultRows,
        controller: controller,
        label: label,
        placeholder: hintText,
        helperText: helperText,
        errorText: state.errorText,
        keyboardType: keyboardType,
        // Read-only fields (username, age) are not editable here, as before.
        enabled: !readOnly,
        onChanged: (v) => state.didChange(v),
      ),
    );
  }
}

/// An avatar for a stored reference: a `ds:` reference draws the generated
/// portrait for its seed, anything else is loaded as a photo.
class ProfileEditAvatar extends StatelessWidget {
  const ProfileEditAvatar({
    super.key,
    required this.reference,
    required this.fallbackSeed,
    this.size = DabblerAvatarSize.xl,
    this.badge,
    this.ringColor,
    this.onTap,
    this.semanticLabel,
  });

  final VoidCallback? onTap;
  final String? semanticLabel;
  final String? reference;
  final String fallbackSeed;
  final DabblerAvatarSize size;
  final Widget? badge;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final dsSeed = extractDsAvatarSeed(reference);
    final url = isDsAvatarReference(reference) ? null : reference;
    return DabblerAvatar(
      seed: dsSeed ?? fallbackSeed,
      imageUrl: url,
      onTap: onTap,
      semanticLabel: semanticLabel,
      size: size,
      badge: badge,
      ringColor: ringColor,
    );
  }
}

/// The photo at the top of the form, with the camera badge that opens the
/// avatar options. While an upload runs the badge shows a spinner and taps
/// are ignored.
class ProfileEditAvatarHeader extends StatelessWidget {
  const ProfileEditAvatarHeader({
    super.key,
    required this.avatarUrl,
    required this.displayName,
    required this.uploading,
    required this.onTap,
  });

  final String? avatarUrl;
  final String displayName;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ProfileEditAvatar(
        reference: avatarUrl,
        fallbackSeed: displayName,
        semanticLabel: 'Change avatar',
        onTap: uploading ? null : onTap,
        badge: uploading
            ? const DabblerSpinner(
                size: DabblerSpinnerSize.sm,
                tone: DabblerSpinnerTone.onBrand,
              )
            : const DabblerIcon('camera'),
      ),
    );
  }
}

/// Date of birth: [DabblerDateField] whose trailing button opens the picker
/// supplied by the screen; a set date can be cleared again.
class ProfileEditDobField extends StatelessWidget {
  const ProfileEditDobField({
    super.key,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.onOpenPicker,
    required this.onChanged,
  });

  final DateTime? value;
  final DateTime minimum;
  final DateTime maximum;
  final VoidCallback onOpenPicker;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: DabblerDateField(
            key: ValueKey<DateTime?>(value),
            label: AppLocalizations.of(context).onb_dob_label,
            placeholder: 'Select your date of birth',
            value: value,
            minimum: minimum,
            maximum: maximum,
            onChanged: onChanged,
            onOpenPicker: onOpenPicker,
          ),
        ),
        if (value != null) ...[
          const DabblerGap.h(DabblerSpacing.space2),
          DabblerButton.icon(
            icon: 'close-circle',
            tone: DabblerButtonTone.text,
            semanticLabel: 'Clear date of birth',
            onPressed: () => onChanged(null),
          ),
        ],
      ],
    );
  }
}
