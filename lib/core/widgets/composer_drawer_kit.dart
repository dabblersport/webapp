import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

// =============================================================================
// COMPOSER DRAWER KIT
// =============================================================================
//
// Shared drawer-style chrome + glass primitives used by the post composer
// (Pencil `tuZuf` / `IVAqD`) and the game composer (Pencil `j4Sqpn`).
//
// Brand purple comes from `Theme.of(context).colorScheme.primary`. Glass tints,
// borders, dividers, and text levels are resolved through `ComposerPalette` so
// the surface adapts to light/dark with high enough contrast on the
// backdrop-blurred surface (WCAG 1.4.3).
// =============================================================================

// ─── Brand accents (constant across themes) ─────────────────────────────────

/// Vibe / game tertiary accent (#FF86DD).
const Color kComposerPink = Color(0xFFFF86DD);

/// Sport inactive accent (#B49CDB).
const Color kComposerLavender = Color(0xFFB49CDB);

// ─── Palette ────────────────────────────────────────────────────────────────

/// Composer palette — same Pencil structural alphas in both themes; only the
/// base hue flips between dark-glass and light-glass.
class ComposerPalette {
  const ComposerPalette._({
    required this.drawerFill,
    required this.outerBorder,
    required this.handle,
    required this.bgWeak,
    required this.bgGlass,
    required this.bgStrong,
    required this.borderWeak,
    required this.borderGlass,
    required this.borderMid,
    required this.borderStrong,
    required this.divider,
    required this.gradientStart,
    required this.gradientMid,
    required this.textBright,
    required this.textMuted,
    required this.textSubtle,
    required this.textFaint,
    required this.toggleOffBg,
    required this.knobOff,
    required this.tilePlaceholder,
  });

  final Color drawerFill;
  final Color outerBorder;
  final Color handle;
  final Color bgWeak;
  final Color bgGlass;
  final Color bgStrong;
  final Color borderWeak;
  final Color borderGlass;
  final Color borderMid;
  final Color borderStrong;
  final Color divider;
  final double gradientStart;
  final double gradientMid;
  final Color textBright;
  final Color textMuted;
  final Color textSubtle;
  final Color textFaint;
  final Color toggleOffBg;
  final Color knobOff;
  final Color tilePlaceholder;

  static const ComposerPalette dark = ComposerPalette._(
    drawerFill: Color(0x8C141218),
    outerBorder: Color(0x12FFFFFF),
    handle: Color(0x22FFFFFF),
    bgWeak: Color(0x08FFFFFF),
    bgGlass: Color(0x0AFFFFFF),
    bgStrong: Color(0x14FFFFFF),
    borderWeak: Color(0x12FFFFFF),
    borderGlass: Color(0x15FFFFFF),
    borderMid: Color(0x15FFFFFF),
    borderStrong: Color(0x18FFFFFF),
    divider: Color(0x08FFFFFF),
    gradientStart: 0.20,
    gradientMid: 0.08,
    textBright: Color(0xFFE6E0E9),
    textMuted: Color(0xFFCAC4CF),
    textSubtle: Color(0xFF79747E),
    textFaint: Color(0xFF49454F),
    toggleOffBg: Color(0xFF3B3640),
    knobOff: Color(0xFF79747E),
    tilePlaceholder: Color(0xFF1D1B20),
  );

  static const ComposerPalette light = ComposerPalette._(
    drawerFill: Color(0x8CF7F4F8),
    outerBorder: Color(0x12000000),
    handle: Color(0x33000000),
    bgWeak: Color(0x08000000),
    bgGlass: Color(0x0A000000),
    bgStrong: Color(0x14000000),
    borderWeak: Color(0x14000000),
    borderGlass: Color(0x1A000000),
    borderMid: Color(0x1A000000),
    borderStrong: Color(0x1F000000),
    divider: Color(0x0A000000),
    gradientStart: 0.14,
    gradientMid: 0.06,
    // Bumped for WCAG 1.4.3 contrast on glass — the BackdropFilter washes
    // everything underneath toward a mid value, so light-theme text needs to
    // sit substantially darker than a flat white-surface would require.
    textBright: Color(0xFF0A090C),
    textMuted: Color(0xFF2A2632),
    textSubtle: Color(0xFF3F3A48),
    textFaint: Color(0xFF5A5466),
    toggleOffBg: Color(0xFFD5D2DC),
    knobOff: Color(0xFF5E5868),
    tilePlaceholder: Color(0xFFEFEAF1),
  );

  static ComposerPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

// ─── Drawer shell ──────────────────────────────────────────────────────────

/// Top-rounded, backdrop-blurred drawer panel wrapping a scrolling body.
class ComposerDrawerShell extends StatelessWidget {
  const ComposerDrawerShell({
    super.key,
    required this.title,
    required this.ctaLabel,
    required this.onCtaTap,
    required this.canSubmit,
    required this.isSubmitting,
    required this.children,
    this.errorMessage,
    this.bottomSpacer = 24,
  });

  final String title;
  final String ctaLabel;
  final VoidCallback onCtaTap;
  final bool canSubmit;
  final bool isSubmitting;
  final List<Widget> children;
  final String? errorMessage;
  final double bottomSpacer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final palette = ComposerPalette.of(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(42)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: BoxDecoration(
            color: palette.drawerFill,
            border: Border.all(color: palette.outerBorder, width: 1),
          ),
          child: Stack(
            children: [
              // Top-down primary wash — 900h, fades to transparent.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 900,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.40, 0.70],
                        colors: [
                          cs.primary.withValues(alpha: palette.gradientStart),
                          cs.primary.withValues(alpha: palette.gradientMid),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _DrawerHandle(),
                    _DrawerHeader(title: title),
                    if (errorMessage != null)
                      Semantics(
                        liveRegion: true,
                        container: true,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          color: cs.errorContainer.withValues(alpha: 0.85),
                          child: Text(
                            errorMessage!,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onErrorContainer,
                            ),
                          ),
                        ),
                      ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.zero,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...children,
                            SizedBox(height: bottomSpacer),
                            // CTA lives at the end of the scrolling body so
                            // it gets pushed up cleanly when the keyboard
                            // opens instead of layering on top of fields.
                            _DrawerFooter(
                              ctaLabel: ctaLabel,
                              onCtaTap: onCtaTap,
                              canSubmit: canSubmit,
                              isSubmitting: isSubmitting,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerHandle extends StatelessWidget {
  const _DrawerHandle();

  @override
  Widget build(BuildContext context) {
    final palette = ComposerPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: palette.handle,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

/// Header row: title on the left, "Cancel" text button on the right.
/// The submit CTA is pinned to the end of the scrolling body via
/// [_DrawerFooter].
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final palette = ComposerPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: tt.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: palette.textBright,
              ),
            ),
          ),
          // Filled tonal "Cancel" pill — subtle glass fill so it reads as a
          // secondary action and doesn't compete with the bottom primary CTA.
          Semantics(
            label: 'Cancel',
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                height: 36,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: palette.bgStrong,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-pinned CTA footer. Hairline divider on top, full-width primary
/// button below. Handles its own bottom safe-area inset.
class _DrawerFooter extends StatelessWidget {
  const _DrawerFooter({
    required this.ctaLabel,
    required this.canSubmit,
    required this.isSubmitting,
    required this.onCtaTap,
  });

  final String ctaLabel;
  final bool canSubmit;
  final bool isSubmitting;
  final VoidCallback onCtaTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = ComposerPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.borderGlass, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Semantics(
            label: ctaLabel,
            button: true,
            enabled: canSubmit,
            child: GestureDetector(
              onTap: canSubmit ? onCtaTap : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: canSubmit ? cs.primary : palette.bgStrong,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: canSubmit
                      ? [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.40),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        ctaLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: canSubmit ? Colors.white : palette.textSubtle,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Section label ──────────────────────────────────────────────────────────

/// Small-caps section label (11/600 letter-spaced, textSubtle).
class ComposerSectionLabel extends StatelessWidget {
  const ComposerSectionLabel({
    super.key,
    required this.label,
    this.letterSpacing = 1,
  });

  final String label;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: letterSpacing,
        color: ComposerPalette.of(context).textSubtle,
      ),
    );
  }
}

// ─── Settings row (icon · title+subtitle · trailing control) ───────────────

class ComposerSettingsRow extends StatelessWidget {
  const ComposerSettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.showDivider,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final palette = ComposerPalette.of(context);
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: showDivider
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: palette.divider, width: 1),
                ),
              )
            : null,
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(icon, size: 20, color: palette.textMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: palette.textBright,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: palette.textSubtle,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ─── Toggle ────────────────────────────────────────────────────────────────

class ComposerToggle extends StatelessWidget {
  const ComposerToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = ComposerPalette.of(context);
    return Semantics(
      toggled: value,
      button: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 24,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value
                ? cs.primary.withValues(alpha: 0.87)
                : palette.toggleOffBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: value
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.33),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: value ? Colors.white : palette.knobOff,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Select pills ──────────────────────────────────────────────────────────

enum ComposerSelectCaret { down, right }

class ComposerSelectPill extends StatelessWidget {
  const ComposerSelectPill({
    super.key,
    required this.value,
    required this.caret,
    required this.onTap,
  });

  final String value;
  final ComposerSelectCaret caret;

  /// Pass `null` to render a disabled, non-tappable variant (e.g. Format
  /// before a sport is picked).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ComposerPalette.of(context);
    final disabled = onTap == null;
    final textColor = disabled
        ? palette.textFaint
        : (caret == ComposerSelectCaret.down
              ? palette.textMuted
              : palette.textSubtle);
    final caretColor = disabled ? palette.textFaint : palette.textSubtle;

    return Semantics(
      value: value,
      button: !disabled,
      enabled: !disabled,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              // Cap width so long values (e.g. "Venue Name · Space Name")
              // ellipsise inside the pill instead of pushing the row past
              // the screen edge.
              constraints: const BoxConstraints(maxWidth: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: palette.bgWeak,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.borderWeak, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    caret == ComposerSelectCaret.down
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.chevron_right_rounded,
                    size: 14,
                    color: caretColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Smaller select pill for Date / Time / Min / Max selects. No caret —
/// the whole value reads as a tap target. `suffixLabel` adds a tiny "min" or
/// "max" tag (10/regular textSubtle) after the value. When `highlighted` is
/// true, swaps the glass tint for a purple-light accent (Duration row).
class ComposerCompactSelectPill extends StatelessWidget {
  const ComposerCompactSelectPill({
    super.key,
    required this.value,
    required this.onTap,
    this.suffixLabel,
    this.highlighted = false,
  });

  final String value;
  final String? suffixLabel;
  final VoidCallback onTap;
  final bool highlighted;

  static const Color _accentBg = Color(0x22D0BCFF); // #D0BCFF @13%
  static const Color _accentStroke = Color(0x44D0BCFF); // @27%
  static const Color _accentFg = Color(0xFFD0BCFF);

  @override
  Widget build(BuildContext context) {
    final palette = ComposerPalette.of(context);
    final bg = highlighted ? _accentBg : palette.bgWeak;
    final border = highlighted ? _accentStroke : palette.borderWeak;
    final fg = highlighted ? _accentFg : palette.textMuted;
    return Semantics(
      value: '$value${suffixLabel != null ? ' $suffixLabel' : ''}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                  if (suffixLabel != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      suffixLabel!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: palette.textSubtle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Policy chip (Join Policy / Visibility) ────────────────────────────────

class ComposerPolicyChip extends StatelessWidget {
  const ComposerPolicyChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = ComposerPalette.of(context);
    return Semantics(
      label: '$label, tap to select',
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? cs.primary : palette.bgGlass,
            borderRadius: BorderRadius.circular(16),
            border: selected
                ? null
                : Border.all(color: palette.borderGlass, width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : palette.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Glass input (title / notes / similar) ─────────────────────────────────

class ComposerGlassInput extends StatelessWidget {
  const ComposerGlassInput({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final palette = ComposerPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: palette.bgGlass,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.borderStrong, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            minLines: minLines,
            maxLines: maxLines,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: palette.textBright,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: palette.textSubtle,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              filled: false,
            ),
          ),
        ),
      ),
    );
  }
}
