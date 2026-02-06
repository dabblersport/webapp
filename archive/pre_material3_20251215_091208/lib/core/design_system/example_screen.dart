import 'package:flutter/material.dart';
import 'package:dabbler/core/design_system/design_system.dart';

/// Example screen demonstrating the design system usage
/// Copy this template when creating new screens
class ExampleScreen extends StatelessWidget {
  const ExampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TwoSectionLayout(
      // ========== TOP SECTION (Purple) ==========
      topSection: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text('Screen Title', style: AppTypography.displayLarge),
          const SizedBox(height: AppSpacing.md),

          // Subtitle or description
          Text('Screen description goes here', style: AppTypography.bodyLarge),
          const SizedBox(height: AppSpacing.sectionSpacing),

          // Featured card or action in top section
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Featured Item', style: AppTypography.headingMedium),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Details about this featured item',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // ========== BOTTOM SECTION (Dark) ==========
      bottomSection: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Text('Section Title', style: AppTypography.headingLarge),
          const SizedBox(height: AppSpacing.elementSpacing),

          // Button cards in a row
          Row(
            children: [
              Expanded(
                child: AppButtonCard(
                  emoji: '📚',
                  label: 'Option 1',
                  onTap: () {
                    // Handle tap
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButtonCard(
                  emoji: '🏆',
                  label: 'Option 2',
                  onTap: () {
                    // Handle tap
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionSpacing),

          // Action cards in a row
          Row(
            children: [
              Expanded(
                child: AppActionCard(
                  emoji: '➕',
                  title: 'Action 1',
                  subtitle: 'Description of action',
                  onTap: () {
                    // Handle tap
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppActionCard(
                  emoji: '🔍',
                  title: 'Action 2',
                  subtitle: 'Another description',
                  onTap: () {
                    // Handle tap
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionSpacing),

          // List of cards
          Text('List Section', style: AppTypography.headingLarge),
          const SizedBox(height: AppSpacing.elementSpacing),

          ...List.generate(
            3,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppCard(
                onTap: () {
                  // Handle card tap
                },
                child: Row(
                  children: [
                    // Icon or image
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('🎯', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'List Item ${index + 1}',
                            style: AppTypography.bodyLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Subtitle or description',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),

                    // Trailing icon or info
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
