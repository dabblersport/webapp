import 'package:flutter/material.dart';
import 'package:dabbler/data/models/core/game_creation_model.dart';
import 'package:dabbler/core/viewmodels/game_creation_viewmodel.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/widgets/input_field.dart';

class ParticipationPaymentStep extends StatefulWidget {
  final GameCreationViewModel viewModel;

  const ParticipationPaymentStep({super.key, required this.viewModel});

  @override
  State<ParticipationPaymentStep> createState() =>
      _ParticipationPaymentStepState();
}

class _ParticipationPaymentStepState extends State<ParticipationPaymentStep> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _waitlistSizeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _descriptionController.text = widget.viewModel.state.gameDescription ?? '';
    _waitlistSizeController.text =
        widget.viewModel.state.maxWaitlistSize?.toString() ?? '5';
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _waitlistSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Payment settings',
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure payment split and game details',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Payment Split
          _buildPaymentSplit(context),
          const SizedBox(height: 32),

          // Game Description
          _buildGameDescription(context),
          const SizedBox(height: 32),

          // Waitlist Settings
          _buildWaitlistSettings(context),
          const SizedBox(height: 32),

          // Spectator Settings
          _buildSpectatorSettings(context),
        ],
      ),
    );
  }

  Widget _buildPaymentSplit(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment split',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.viewModel.state.totalCost != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.attach_money,
                  size: 16,
                  color: context.colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Total cost: AED ${widget.viewModel.state.totalCost!.toStringAsFixed(0)}',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        ...PaymentSplit.values.map((split) {
          final isSelected = widget.viewModel.state.paymentSplit == split;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildPaymentSplitOption(
              context,
              split: split,
              isSelected: isSelected,
              onTap: () => widget.viewModel.selectPaymentSplit(split),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPaymentSplitOption(
    BuildContext context, {
    required PaymentSplit split,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final splitData = _getPaymentSplitData(split);
    final costPerPlayer = _calculateCostPerPlayer(split);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colors.primary.withValues(alpha: 0.1)
              : context.violetWidgetBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? context.colors.primary
                : context.colors.outline.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.colors.primary.withValues(alpha: 0.1)
                    : context.colors.outline.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                splitData['icon'] as IconData,
                size: 20,
                color: isSelected
                    ? context.colors.primary
                    : context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        splitData['title'] as String,
                        style: context.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? context.colors.primary
                              : context.colors.onSurface,
                        ),
                      ),
                      if (costPerPlayer != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.colors.primary
                                : context.colors.outline.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'AED ${costPerPlayer.toStringAsFixed(0)}/player',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: isSelected
                                  ? context.colors.onPrimary
                                  : context.colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    splitData['description'] as String,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check, size: 20, color: context.colors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildGameDescription(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Game description',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tell players what to expect from your game',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        CustomInputField(
          controller: _descriptionController,
          label: 'Description (optional)',
          hintText:
              'e.g., Friendly ${widget.viewModel.state.selectedSport} match for ${widget.viewModel.state.skillLevel?.toLowerCase()} players...',
          maxLines: 4,
          onChanged: (value) => widget.viewModel.updateGameDescription(value),
        ),
      ],
    );
  }

  Widget _buildWaitlistSettings(BuildContext context) {
    final allowWaitlist = widget.viewModel.state.allowWaitlist ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Waitlist settings',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 16),

        // Allow Waitlist Toggle
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.violetWidgetBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.colors.outline.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: allowWaitlist
                      ? context.colors.primary.withValues(alpha: 0.1)
                      : context.colors.outline.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.group,
                  size: 20,
                  color: allowWaitlist
                      ? context.colors.primary
                      : context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Allow waitlist',
                      style: context.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Players can join a waitlist if the game is full',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: allowWaitlist,
                onChanged: (value) => widget.viewModel.toggleWaitlist(value),
                activeThumbColor: context.colors.primary,
              ),
            ],
          ),
        ),

        // Waitlist Size
        if (allowWaitlist) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CustomInputField(
                  controller: _waitlistSizeController,
                  label: 'Max waitlist size',
                  hintText: '5',
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final size = int.tryParse(value);
                    if (size != null && size > 0) {
                      widget.viewModel.updateMaxWaitlistSize(size);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: context.colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Recommended: 3-5 players for better backup options',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Map<String, dynamic> _getPaymentSplitData(PaymentSplit split) {
    switch (split) {
      case PaymentSplit.organizer:
        return {
          'title': 'I\'ll pay',
          'description': 'You cover the full cost',
          'icon': Icons.credit_card,
        };
      case PaymentSplit.equal:
        return {
          'title': 'Split equally',
          'description': 'Cost divided among all players including you',
          'icon': Icons.horizontal_rule,
        };
      case PaymentSplit.perPlayer:
        return {
          'title': 'Players pay',
          'description': 'Each player pays their share (you play for free)',
          'icon': Icons.group,
        };
      case PaymentSplit.custom:
        return {
          'title': 'Custom split',
          'description': 'Set custom payment amounts',
          'icon': Icons.settings,
        };
    }
  }

  double? _calculateCostPerPlayer(PaymentSplit split) {
    final totalCost = widget.viewModel.state.totalCost;
    final maxPlayers = widget.viewModel.state.maxPlayers;

    if (totalCost == null || maxPlayers == null) return null;

    switch (split) {
      case PaymentSplit.organizer:
        return 0.0;
      case PaymentSplit.equal:
        return totalCost / maxPlayers;
      case PaymentSplit.perPlayer:
        return totalCost / (maxPlayers - 1);
      case PaymentSplit.custom:
        return null; // Custom split varies
    }
  }

  Widget _buildSpectatorSettings(BuildContext context) {
    final allowSpectators = widget.viewModel.state.allowSpectators ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Spectator settings',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.violetWidgetBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.colors.outline.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: allowSpectators
                      ? context.colors.primary.withValues(alpha: 0.1)
                      : context.colors.outline.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.visibility,
                  size: 20,
                  color: allowSpectators
                      ? context.colors.primary
                      : context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Allow spectators',
                      style: context.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Allow non-players to watch the game',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: allowSpectators,
                onChanged: (value) =>
                    widget.viewModel.toggleAllowSpectators(value),
                activeThumbColor: context.colors.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
