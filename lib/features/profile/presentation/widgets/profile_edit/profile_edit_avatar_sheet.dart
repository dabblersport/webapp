import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'profile_edit_fields.dart';

/// The body of the "Choose your avatar" sheet: 12 generated avatars that can
/// be shuffled, and the upload sources. Each action closes the sheet first and
/// then runs, exactly as before KAN-418.
class ProfileEditAvatarSheet extends StatefulWidget {
  const ProfileEditAvatarSheet({
    super.key,
    required this.choicesFor,
    required this.currentReference,
    required this.displayName,
    required this.uploading,
    required this.onPickGenerated,
    required this.onFromFile,
    required this.onFromGallery,
    this.onFromCamera,
  });

  /// The 12 references for a shuffle generation.
  final List<String> Function(int generation) choicesFor;
  final String? currentReference;
  final String displayName;
  final bool uploading;
  final Future<void> Function(String reference) onPickGenerated;
  final Future<void> Function() onFromFile;
  final Future<void> Function() onFromGallery;

  /// Null where the platform has no camera; the row is then absent.
  final Future<void> Function()? onFromCamera;

  @override
  State<ProfileEditAvatarSheet> createState() => _ProfileEditAvatarSheetState();
}

class _ProfileEditAvatarSheetState extends State<ProfileEditAvatarSheet> {
  int _generation = 0;

  void _closeThen(Future<void> Function() action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final choices = widget.choicesFor(_generation);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.only(
        start: DabblerSpacing.space6,
        end: DabblerSpacing.space6,
        bottom: DabblerSpacing.space8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DabblerText(
            'Pick one of 12 generated avatars or upload your own photo.',
            style: DabblerType.subheadline,
            tone: DabblerTextTone.secondary,
          ),
          const SizedBox(height: DabblerSpacing.space7),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: DabblerSpacing.space2,
            crossAxisSpacing: DabblerSpacing.space2,
            children: [
              for (final reference in choices)
                Center(
                  child: Semantics(
                    button: true,
                    selected: widget.currentReference == reference,
                    label: 'Avatar option',
                    child: GestureDetector(
                      onTap: widget.uploading
                          ? null
                          : () => _closeThen(
                              () => widget.onPickGenerated(reference),
                            ),
                      child: ProfileEditAvatar(
                        reference: reference,
                        fallbackSeed: widget.displayName,
                        size: DabblerAvatarSize.lg,
                        ringColor: widget.currentReference == reference
                            ? colors.brandPrimary
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: DabblerSpacing.space5),
          DabblerButton(
            label: 'Shuffle avatars',
            icon: 'refresh',
            tone: DabblerButtonTone.outlined,
            fullWidth: true,
            onPressed: () => setState(() => _generation++),
          ),
          const SizedBox(height: DabblerSpacing.space8),
          DabblerSection(
            title: 'Upload options',
            children: [
              _sourceRow(
                icon: 'folder-open',
                title: 'From file',
                subtitle: 'Choose an image file from your device',
                action: widget.onFromFile,
              ),
              _sourceRow(
                icon: 'gallery',
                title: 'From gallery',
                subtitle: 'Pick a photo from your gallery',
                action: widget.onFromGallery,
              ),
              if (widget.onFromCamera != null)
                _sourceRow(
                  icon: 'camera',
                  title: 'Take a photo',
                  subtitle: 'Open the camera and capture a new avatar',
                  action: widget.onFromCamera!,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sourceRow({
    required String icon,
    required String title,
    required String subtitle,
    required Future<void> Function() action,
  }) {
    return DabblerInputRow(
      leading: DabblerIconTile.named(icon),
      title: title,
      subtitle: subtitle,
      trailing: const DabblerChevron(),
      enabled: !widget.uploading,
      onTap: widget.uploading ? null : () => _closeThen(action),
    );
  }
}
