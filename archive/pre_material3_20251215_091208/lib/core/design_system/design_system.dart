/// ⚠️ MIGRATION TO NATIVE MATERIAL 3 COMPONENTS ⚠️
///
/// This design system has been migrated to use native Material 3 components.
/// Custom widgets are deprecated and will be removed in future versions.
///
/// Migration Guide: See MATERIAL3_MIGRATION_GUIDE.md
/// Example Usage: See examples/material_components_example.dart
///
/// Quick Reference:
/// - AppButton → FilledButton/OutlinedButton/TextButton
/// - AppCard → Card.filled()/Card.outlined()
/// - AppInputField → TextField/TextFormField
/// - AppChip → FilterChip/ActionChip/InputChip
///
/// Color Tokens:
/// - Access via: Theme.of(context).colorScheme.categoryMain
/// - Or: context.colorTokens (for detailed tokens)
library;

// Design Tokens - PRIMARY EXPORTS
export 'tokens/design_tokens.dart';
export 'tokens/token_based_theme.dart';
export '../../themes/app_theme.dart'; // Includes color extensions

// Colors
export 'colors/app_colors.dart';

// Typography
export 'typography/app_typography.dart';

// Spacing
export 'spacing/app_spacing.dart';

// Layouts
export 'layouts/two_section_layout.dart';
export 'layouts/single_section_layout.dart';

// Specialized Widgets (not directly replaced by Material 3)
export 'widgets/social_feed_widgets.dart';
export 'widgets/app_sport_icon.dart';
export 'widgets/ds_avatar.dart';
export 'widgets/interactive_card_stack.dart';
export 'widgets/upcoming_game_card.dart';
export 'widgets/app_tab.dart';
export 'widgets/app_step.dart';
export 'widgets/app_steps.dart';

// Deprecated Widgets - Use Native Material 3 Instead
@Deprecated('Use FilledButton, OutlinedButton, or TextButton')
export 'widgets/app_button.dart';

@Deprecated('Use Card.filled() or Card.outlined()')
export 'widgets/app_card.dart';

@Deprecated('Use TextField or TextFormField')
export 'widgets/app_input_field.dart';

@Deprecated('Use FilterChip or ActionChip')
export 'widgets/app_chip.dart';

@Deprecated('Use FilterChip')
export 'widgets/app_filter_chip.dart';

// Legacy Widgets (Consider removing)
export 'widgets/app_search_input.dart';
export 'widgets/design_system_button.dart';
export 'widgets/app_progress_indicator.dart';
export 'widgets/app_label.dart';
