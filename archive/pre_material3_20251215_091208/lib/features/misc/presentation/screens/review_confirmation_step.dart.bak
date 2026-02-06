import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dabbler/data/models/core/game_creation_model.dart';
import 'package:dabbler/core/viewmodels/game_creation_viewmodel.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/widgets/input_field.dart';

class ReviewConfirmationStep extends StatefulWidget {
  final GameCreationViewModel viewModel;

  const ReviewConfirmationStep({super.key, required this.viewModel});

  @override
  State<ReviewConfirmationStep> createState() => _ReviewConfirmationStepState();
}

class _ReviewConfirmationStepState extends State<ReviewConfirmationStep> {
  final TextEditingController _gameTitleController = TextEditingController();
  bool _agreeToTerms = false;
  bool _enableReminders = true;

  @override
  void initState() {
    super.initState();
    _gameTitleController.text =
        widget.viewModel.state.gameTitle ?? _generateGameTitle();
  }

  @override
  void dispose() {
    _gameTitleController.dispose();
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
            'Review & confirm',
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Double-check your game details before creating',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Game Title
          _buildGameTitle(context),
          const SizedBox(height: 24),

          // Game Summary
          _buildGameSummary(context),
          const SizedBox(height: 24),

          // Payment Breakdown
          _buildPaymentBreakdown(context),
          const SizedBox(height: 24),

          // Invitations Summary
          if (widget.viewModel.state.participationMode !=
              ParticipationMode.public)
            _buildInvitationsSummary(context),
          if (widget.viewModel.state.participationMode !=
              ParticipationMode.public)
            const SizedBox(height: 24),

          // Settings
          _buildSettings(context),
          const SizedBox(height: 24),

          // Terms Agreement
          _buildTermsAgreement(context),
        ],
      ),
    );
  }

  Widget _buildGameTitle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Game title',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Give your game a catchy title',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        CustomInputField(
          controller: _gameTitleController,
          label: 'Title',
          hintText: 'Enter game title...',
          onChanged: (value) => widget.viewModel.updateGameTitle(value),
        ),
        const SizedBox(height: 12),

        // Quick suggestions
        Text(
          'Suggestions:',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _getGameTitleSuggestions()
              .map(
                (suggestion) => GestureDetector(
                  onTap: () {
                    _gameTitleController.text = suggestion;
                    widget.viewModel.updateGameTitle(suggestion);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.violetWidgetBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.colors.outline.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      suggestion,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildGameSummary(BuildContext context) {
    final state = widget.viewModel.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Game summary',
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
          child: Column(
            children: [
              _buildSummaryRow(
                context,
                icon: _getSportIcon(state.selectedSport),
                label: 'Sport & Format',
                value: '${state.selectedSport} • ${state.selectedFormat?.name}',
              ),
              const SizedBox(height: 16),
              _buildSummaryRow(
                context,
                icon: LucideIcons.mapPin,
                label: 'Venue',
                value: state.selectedVenueSlot?.venueName ?? 'Not selected',
              ),
              const SizedBox(height: 16),
              _buildSummaryRow(
                context,
                icon: LucideIcons.clock,
                label: 'Date & Time',
                value: _formatDateTime(
                  state.selectedVenueSlot?.timeSlot.startTime,
                ),
              ),
              const SizedBox(height: 16),
              _buildSummaryRow(
                context,
                icon: LucideIcons.users,
                label: 'Players',
                value: '${state.maxPlayers} players • ${state.skillLevel}',
              ),
              const SizedBox(height: 16),
              _buildSummaryRow(
                context,
                icon: LucideIcons.clock4,
                label: 'Duration',
                value: '${state.gameDuration} minutes',
              ),
              if (state.participationMode != null) ...[
                const SizedBox(height: 16),
                _buildSummaryRow(
                  context,
                  icon: _getParticipationIcon(state.participationMode!),
                  label: 'Access',
                  value: _getParticipationLabel(state.participationMode!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.colors.primary),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentBreakdown(BuildContext context) {
    final state = widget.viewModel.state;
    final totalCost = state.totalCost ?? 0.0;
    final paymentSplit = state.paymentSplit;
    final maxPlayers = state.maxPlayers ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment breakdown',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.colors.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildPaymentRow(
                context,
                label: 'Venue cost',
                amount: totalCost,
                isTotal: false,
              ),
              const SizedBox(height: 12),
              Divider(color: context.colors.outline.withValues(alpha: 0.2)),
              const SizedBox(height: 12),
              _buildPaymentRow(
                context,
                label: 'Total cost',
                amount: totalCost,
                isTotal: true,
              ),
              if (paymentSplit != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getPaymentSplitDescription(
                          paymentSplit,
                          maxPlayers,
                          totalCost,
                        ),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getPaymentSplitDetails(paymentSplit),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentRow(
    BuildContext context, {
    required String label,
    required double amount,
    required bool isTotal,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colors.onSurface,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          'AED ${amount.toStringAsFixed(0)}',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colors.primary,
            fontWeight: FontWeight.w700,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildInvitationsSummary(BuildContext context) {
    final state = widget.viewModel.state;
    final invitedPlayers =
        (state.invitedPlayerIds?.length ?? 0) +
        (state.invitedPlayerEmails?.length ?? 0);

    if (invitedPlayers == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invitations',
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
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.mail,
                    size: 16,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$invitedPlayers invitation${invitedPlayers != 1 ? 's' : ''} will be sent',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (state.invitationMessage?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '"${state.invitationMessage}"',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettings(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings',
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
                  color: _enableReminders
                      ? context.colors.primary.withValues(alpha: 0.1)
                      : context.colors.outline.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  LucideIcons.bell,
                  size: 20,
                  color: _enableReminders
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
                      'Game reminders',
                      style: context.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Send reminder notifications before the game',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _enableReminders,
                onChanged: (value) {
                  setState(() {
                    _enableReminders = value;
                  });
                  widget.viewModel.updateGameReminders(value);
                },
                activeThumbColor: context.colors.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTermsAgreement(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.error.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _agreeToTerms,
                onChanged: (value) {
                  setState(() {
                    _agreeToTerms = value ?? false;
                  });
                  widget.viewModel.updateTermsAgreement(_agreeToTerms);
                },
                activeColor: context.colors.primary,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'I agree to the ',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.onSurface,
                          ),
                        ),
                        TextSpan(
                          text: 'Terms of Service',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        TextSpan(
                          text: ' and ',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.onSurface,
                          ),
                        ),
                        TextSpan(
                          text: 'Cancellation Policy',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        TextSpan(
                          text:
                              '. I understand that I may be charged cancellation fees for late cancellations.',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!_agreeToTerms) ...[
            const SizedBox(height: 8),
            Text(
              'You must agree to the terms to create the game',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _generateGameTitle() {
    final sport = widget.viewModel.state.selectedSport ?? 'Game';
    final format = widget.viewModel.state.selectedFormat?.name ?? 'Match';
    return '$sport $format';
  }

  List<String> _getGameTitleSuggestions() {
    final sport = widget.viewModel.state.selectedSport ?? 'Game';
    final skillLevel = widget.viewModel.state.skillLevel ?? 'Intermediate';
    final format = widget.viewModel.state.selectedFormat?.name ?? 'Match';

    return [
      '$skillLevel $sport $format',
      'Fun $sport Session',
      '$sport Night Out',
      'Weekly $sport Game',
      '$format & Chill',
    ];
  }

  IconData _getSportIcon(String? sport) {
    switch (sport?.toLowerCase()) {
      case 'football':
        return LucideIcons.target;
      case 'basketball':
        return LucideIcons.circle;
      case 'tennis':
        return LucideIcons.circle;
      case 'cricket':
        return LucideIcons.target;
      case 'padel':
        return LucideIcons.square;
      default:
        return LucideIcons.activity;
    }
  }

  IconData _getParticipationIcon(ParticipationMode mode) {
    switch (mode) {
      case ParticipationMode.public:
        return LucideIcons.globe;
      case ParticipationMode.private:
        return LucideIcons.lock;
      case ParticipationMode.hybrid:
        return LucideIcons.userPlus;
    }
  }

  String _getParticipationLabel(ParticipationMode mode) {
    switch (mode) {
      case ParticipationMode.public:
        return 'Public - Anyone can join';
      case ParticipationMode.private:
        return 'Private - Invite only';
      case ParticipationMode.hybrid:
        return 'Hybrid - Mixed access';
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Not selected';

    final day = dateTime.day;
    final month = _getMonthName(dateTime.month);
    final time = TimeOfDay.fromDateTime(dateTime).format(context);

    return '$day $month, $time';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  String _getPaymentSplitDescription(
    PaymentSplit split,
    int maxPlayers,
    double totalCost,
  ) {
    switch (split) {
      case PaymentSplit.organizer:
        return 'You pay: AED ${totalCost.toStringAsFixed(0)} • Players play for free';
      case PaymentSplit.equal:
        final perPlayer = totalCost / maxPlayers;
        return 'Everyone pays: AED ${perPlayer.toStringAsFixed(0)} per player';
      case PaymentSplit.perPlayer:
        final perPlayer = totalCost / (maxPlayers - 1);
        return 'Players pay: AED ${perPlayer.toStringAsFixed(0)} each • You play for free';
      case PaymentSplit.custom:
        return 'Custom payment arrangement';
    }
  }

  String _getPaymentSplitDetails(PaymentSplit split) {
    switch (split) {
      case PaymentSplit.organizer:
        return 'You cover the full venue cost';
      case PaymentSplit.equal:
        return 'Cost split equally among all players including organizer';
      case PaymentSplit.perPlayer:
        return 'Players cover the cost, organizer plays for free';
      case PaymentSplit.custom:
        return 'Custom payment amounts set';
    }
  }
}
