import 'package:flutter/material.dart';

class SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? leadingWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;
  final bool isEnabled;
  final Color? backgroundColor;
  final EdgeInsets? contentPadding;

  const SettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.leadingWidget,
    this.trailing,
    this.onTap,
    this.showDivider = true,
    this.isEnabled = true,
    this.backgroundColor,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget tile = Container(
      color: backgroundColor,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        child: Padding(
          padding:
              contentPadding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Leading icon or widget
              if (leadingIcon != null || leadingWidget != null) ...[
                leadingWidget ??
                    Icon(
                      leadingIcon!,
                      color: isEnabled
                          ? theme.iconTheme.color
                          : theme.disabledColor,
                      size: 24,
                    ),
                const SizedBox(width: 16),
              ],

              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: isEnabled
                            ? theme.textTheme.bodyLarge?.color
                            : theme.disabledColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isEnabled
                              ? theme.textTheme.bodyMedium?.color?.withOpacity(
                                  0.7,
                                )
                              : theme.disabledColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Trailing widget
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );

    if (showDivider) {
      tile = Column(
        children: [
          tile,
          Divider(
            height: 1,
            indent: leadingIcon != null || leadingWidget != null ? 56 : 16,
            color: theme.dividerColor.withOpacity(0.3),
          ),
        ],
      );
    }

    return tile;
  }

  // Factory constructors for common tile types
  factory SettingsTile.switchTile({
    required String title,
    String? subtitle,
    IconData? leadingIcon,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isEnabled = true,
    Color? activeColor,
  }) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      leadingIcon: leadingIcon,
      isEnabled: isEnabled,
      onTap: isEnabled ? () => onChanged(!value) : null,
      trailing: Switch(
        value: value,
        onChanged: isEnabled ? onChanged : null,
        activeThumbColor: activeColor,
      ),
    );
  }

  factory SettingsTile.navigation({
    required String title,
    String? subtitle,
    IconData? leadingIcon,
    Widget? leadingWidget,
    required VoidCallback onTap,
    bool showArrow = true,
    bool isEnabled = true,
  }) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      leadingIcon: leadingIcon,
      leadingWidget: leadingWidget,
      onTap: onTap,
      isEnabled: isEnabled,
      trailing: showArrow
          ? Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isEnabled ? Colors.grey[600] : Colors.grey[400],
            )
          : null,
    );
  }

  factory SettingsTile.selection({
    required String title,
    String? subtitle,
    IconData? leadingIcon,
    required String selectedValue,
    required VoidCallback onTap,
    bool isEnabled = true,
    Color? selectedColor,
  }) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      leadingIcon: leadingIcon,
      onTap: onTap,
      isEnabled: isEnabled,
      trailing: _SelectionWidget(
        selectedValue: selectedValue,
        selectedColor: selectedColor,
        isEnabled: isEnabled,
      ),
    );
  }

  factory SettingsTile.action({
    required String title,
    String? subtitle,
    IconData? leadingIcon,
    required VoidCallback onTap,
    Color? textColor,
    bool isDestructive = false,
    bool isEnabled = true,
  }) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      leadingIcon: leadingIcon,
      onTap: onTap,
      isEnabled: isEnabled,
      trailing: _ActionWidget(
        textColor: textColor,
        isDestructive: isDestructive,
        isEnabled: isEnabled,
      ),
    );
  }

  factory SettingsTile.badge({
    required String title,
    String? subtitle,
    IconData? leadingIcon,
    required String badgeText,
    Color? badgeColor,
    VoidCallback? onTap,
    bool isEnabled = true,
  }) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      leadingIcon: leadingIcon,
      onTap: onTap,
      isEnabled: isEnabled,
      trailing: _BadgeWidget(badgeText: badgeText, badgeColor: badgeColor),
    );
  }

  factory SettingsTile.slider({
    required String title,
    String? subtitle,
    IconData? leadingIcon,
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0.0,
    double max = 1.0,
    int? divisions,
    String Function(double)? valueFormatter,
    bool isEnabled = true,
    Color? activeColor,
  }) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      leadingIcon: leadingIcon,
      isEnabled: isEnabled,
      showDivider: false,
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      trailing: _SliderWidget(
        value: value,
        onChanged: onChanged,
        min: min,
        max: max,
        divisions: divisions,
        valueFormatter: valueFormatter,
        isEnabled: isEnabled,
        activeColor: activeColor,
      ),
    );
  }

  factory SettingsTile.custom({
    required String title,
    String? subtitle,
    IconData? leadingIcon,
    required Widget customTrailing,
    VoidCallback? onTap,
    bool showDivider = true,
    bool isEnabled = true,
  }) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      leadingIcon: leadingIcon,
      trailing: customTrailing,
      onTap: onTap,
      showDivider: showDivider,
      isEnabled: isEnabled,
    );
  }
}

// Settings section with grouped tiles
class SettingsSection extends StatelessWidget {
  final String? title;
  final List<SettingsTile> tiles;
  final EdgeInsets? margin;
  final Color? backgroundColor;

  const SettingsSection({
    super.key,
    this.title,
    required this.tiles,
    this.margin,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title?.isNotEmpty == true) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                title!,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
            ),
          ],
          ...tiles.asMap().entries.map((entry) {
            final index = entry.key;
            final tile = entry.value;

            // Don't show divider on the last tile
            if (index == tiles.length - 1) {
              return SettingsTile(
                title: tile.title,
                subtitle: tile.subtitle,
                leadingIcon: tile.leadingIcon,
                leadingWidget: tile.leadingWidget,
                trailing: tile.trailing,
                onTap: tile.onTap,
                showDivider: false,
                isEnabled: tile.isEnabled,
                backgroundColor: tile.backgroundColor,
                contentPadding: tile.contentPadding,
              );
            }

            return tile;
          }),
        ],
      ),
    );
  }
}

// Helper widgets for factory constructors
class _SelectionWidget extends StatelessWidget {
  final String selectedValue;
  final Color? selectedColor;
  final bool isEnabled;

  const _SelectionWidget({
    required this.selectedValue,
    this.selectedColor,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          selectedValue,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isEnabled
                ? (selectedColor ?? Theme.of(context).primaryColor)
                : Theme.of(context).disabledColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: isEnabled ? Colors.grey[600] : Colors.grey[400],
        ),
      ],
    );
  }
}

class _ActionWidget extends StatelessWidget {
  final Color? textColor;
  final bool isDestructive;
  final bool isEnabled;

  const _ActionWidget({
    this.textColor,
    required this.isDestructive,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    Color? finalTextColor = textColor;
    if (isDestructive && finalTextColor == null) {
      finalTextColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        'Action',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isEnabled ? finalTextColor : Theme.of(context).disabledColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _BadgeWidget extends StatelessWidget {
  final String badgeText;
  final Color? badgeColor;

  const _BadgeWidget({required this.badgeText, this.badgeColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor ?? Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        badgeText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SliderWidget extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double)? valueFormatter;
  final bool isEnabled;
  final Color? activeColor;

  const _SliderWidget({
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    this.divisions,
    this.valueFormatter,
    required this.isEnabled,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (valueFormatter != null)
          Text(
            valueFormatter!(value),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isEnabled
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).disabledColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        SizedBox(
          width: 120,
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: isEnabled ? onChanged : null,
            activeColor: activeColor,
          ),
        ),
      ],
    );
  }
}
