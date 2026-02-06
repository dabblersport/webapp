import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/data_retention_service.dart';
import 'package:dabbler/core/utils/logger.dart';

/// Data Retention Settings Screen for GDPR compliance
class DataRetentionSettingsScreen extends ConsumerStatefulWidget {
  final String userId;

  const DataRetentionSettingsScreen({super.key, required this.userId});

  @override
  ConsumerState<DataRetentionSettingsScreen> createState() =>
      _DataRetentionSettingsScreenState();
}

class _DataRetentionSettingsScreenState
    extends ConsumerState<DataRetentionSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, Duration> _retentionPolicies = {};
  bool _autoCleanupEnabled = true;
  Duration _gracePeriod = Duration(days: 30);
  List<Map<String, dynamic>> _upcomingCleanups = [];

  @override
  void initState() {
    super.initState();
    _loadRetentionSettings();
  }

  Future<void> _loadRetentionSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dataRetentionService = ref.read(dataRetentionServiceProvider);

      // Load current policy or use defaults
      final policy = await dataRetentionService.getUserRetentionPolicy(
        widget.userId,
      );

      if (policy != null) {
        _retentionPolicies = Map.from(policy.policies);
        _autoCleanupEnabled = policy.autoCleanupEnabled;
        _gracePeriod = policy.gracePeriod;
      } else {
        _retentionPolicies = DataRetentionService.getDefaultRetentionPolicies();
      }

      // Load upcoming cleanups
      _upcomingCleanups = await dataRetentionService.getUpcomingCleanups(
        widget.userId,
      );
    } catch (e) {
      Logger.error('Error loading retention settings', e);
      _showErrorMessage('Failed to load retention settings');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveRetentionSettings() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final dataRetentionService = ref.read(dataRetentionServiceProvider);

      await dataRetentionService.configureRetentionPolicy(
        userId: widget.userId,
        retentionPolicies: _retentionPolicies,
        enableAutoCleanup: _autoCleanupEnabled,
        gracePeriod: _gracePeriod,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Retention settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload to get updated upcoming cleanups
        await _loadRetentionSettings();
      }
    } catch (e) {
      Logger.error('Error saving retention settings', e);
      _showErrorMessage('Failed to save retention settings');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _requestGracePeriod(String dataType) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _GracePeriodDialog(dataType: dataType),
    );

    if (result != null) {
      try {
        final dataRetentionService = ref.read(dataRetentionServiceProvider);
        await dataRetentionService.requestGracePeriod(
          userId: widget.userId,
          dataType: dataType,
          gracePeriod: result['duration'] as Duration,
          reason: result['reason'] as String?,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Grace period requested for ${_getDataTypeDisplayName(dataType)}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }

        await _loadRetentionSettings();
      } catch (e) {
        _showErrorMessage('Failed to request grace period');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Header
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              sliver: SliverToBoxAdapter(child: _buildHeader(context)),
            ),
            // Hero Card
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              sliver: SliverToBoxAdapter(child: _buildHeroCard(context)),
            ),
            // Content
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRetentionPolicyCard(),
                    const SizedBox(height: 20),
                    _buildUpcomingCleanupsCard(),
                    const SizedBox(height: 20),
                    _buildAutomationSettingsCard(),
                    const SizedBox(height: 20),
                    _buildInformationCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _saveRetentionSettings,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            label: const Text('Save Settings'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHigh,
            foregroundColor: colorScheme.onSurface,
            minimumSize: const Size(48, 48),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data Retention',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                'GDPR Compliance',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF4A148C) : const Color(0xFFE0C7FF),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.schedule_outlined,
            size: 48,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          const SizedBox(height: 16),
          Text(
            'Manage data lifecycle',
            style: textTheme.headlineSmall?.copyWith(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Configure how long different types of data are kept before automatic deletion.',
            style: textTheme.bodyMedium?.copyWith(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.85)
                  : Colors.black.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetentionPolicyCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.policy_outlined,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Retention Policies',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ..._retentionPolicies.entries.map(
              (entry) => _buildRetentionPolicyItem(entry.key, entry.value),
            ),

            const SizedBox(height: 12),
            Divider(color: colorScheme.outline.withOpacity(0.2)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade50,
                    Colors.blue.shade100.withOpacity(0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Customizing policies may affect viewing historical data.',
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetentionPolicyItem(String dataType, Duration duration) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getDataTypeColor(dataType).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getDataTypeIcon(dataType),
              size: 20,
              color: _getDataTypeColor(dataType),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getDataTypeDisplayName(dataType),
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getDataTypeDescription(dataType),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: duration.inDays,
            items: _getRetentionOptions(dataType),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _retentionPolicies[dataType] = Duration(days: value);
                });
              }
            },
            underline: const SizedBox(),
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.schedule_send_outlined, size: 20),
            onPressed: () => _requestGracePeriod(dataType),
            tooltip: 'Request grace period',
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primaryContainer.withOpacity(0.3),
              foregroundColor: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<int>> _getRetentionOptions(String dataType) {
    final options = <int>[];

    // Base options for all data types
    options.addAll([30, 90, 180, 365, 365 * 2, 365 * 3, 365 * 5, 365 * 7]);

    // Special options for specific data types
    switch (dataType) {
      case 'audit_logs':
        options.addAll([365 * 10]); // Up to 10 years for security logs
        break;
      case 'profile_data':
        options.addAll([365 * 10]); // Extended for profile data
        break;
    }

    options.sort();

    return options
        .map(
          (days) => DropdownMenuItem<int>(
            value: days,
            child: Text(_formatDuration(Duration(days: days))),
          ),
        )
        .toList();
  }

  Widget _buildUpcomingCleanupsCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.event_outlined,
                    size: 20,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Upcoming Cleanups',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_upcomingCleanups.isEmpty) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.green.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No upcoming cleanups scheduled',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ..._upcomingCleanups.map(
                (cleanup) => _buildUpcomingCleanupItem(cleanup),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingCleanupItem(Map<String, dynamic> cleanup) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dataType = cleanup['data_type'] as String;
    final scheduledDate = DateTime.parse(cleanup['scheduled_cleanup_date']);
    final daysUntilCleanup = scheduledDate.difference(DateTime.now()).inDays;
    final isUrgent = daysUntilCleanup <= 7;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent
              ? Colors.red.shade300
              : colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isUrgent ? Colors.red.shade100 : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getDataTypeIcon(dataType),
              size: 20,
              color: isUrgent ? Colors.red.shade700 : Colors.orange.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getDataTypeDisplayName(dataType),
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scheduled: ${DateFormat('MMM dd, yyyy').format(scheduledDate)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$daysUntilCleanup days remaining',
                  style: textTheme.bodySmall?.copyWith(
                    color: isUrgent
                        ? Colors.red.shade700
                        : Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            onPressed: () => _showCleanupOptions(dataType),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primaryContainer.withOpacity(0.3),
              foregroundColor: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _showCleanupOptions(String dataType) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.schedule_send_outlined),
              title: const Text('Request grace period'),
              onTap: () {
                Navigator.pop(context);
                _requestGracePeriod(dataType);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutomationSettingsCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    size: 20,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Automation Settings',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enable Automatic Cleanup',
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Automatically delete data based on retention policies',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: _autoCleanupEnabled,
                  onChanged: (value) =>
                      setState(() => _autoCleanupEnabled = value),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Divider(color: colorScheme.outline.withOpacity(0.2)),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Default Grace Period',
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Time before data deletion where you can request recovery',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _gracePeriod.inDays,
                  items: [7, 14, 30, 60, 90]
                      .map(
                        (days) => DropdownMenuItem(
                          value: days,
                          child: Text('$days days'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _gracePeriod = Duration(days: value));
                    }
                  },
                  underline: const SizedBox(),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInformationCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Important Information',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ...[
              'Data is automatically deleted based on your retention settings',
              'Grace periods can be requested to delay deletion',
              'Some data may be retained longer for legal compliance',
              'Critical security logs are kept for minimum required periods',
              'You can export your data before deletion using the Data Export feature',
            ].map(
              (info) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        info,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Divider(color: colorScheme.outline.withOpacity(0.2)),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showDataTypesHelp(),
                    icon: const Icon(Icons.help_outline, size: 18),
                    label: const Text('Data Types Help'),
                    style: TextButton.styleFrom(
                      backgroundColor: colorScheme.primaryContainer.withOpacity(
                        0.3,
                      ),
                      foregroundColor: colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showRetentionHelp(),
                    icon: const Icon(Icons.policy_outlined, size: 18),
                    label: const Text('Retention Policy'),
                    style: TextButton.styleFrom(
                      backgroundColor: colorScheme.primaryContainer.withOpacity(
                        0.3,
                      ),
                      foregroundColor: colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  String _getDataTypeDisplayName(String dataType) {
    switch (dataType) {
      case 'profile_data':
        return 'Profile Data';
      case 'game_history':
        return 'Game History';
      case 'messages':
        return 'Messages';
      case 'audit_logs':
        return 'Security Logs';
      case 'login_history':
        return 'Login History';
      case 'media_files':
        return 'Media Files';
      case 'location_data':
        return 'Location Data';
      case 'analytics_data':
        return 'Analytics Data';
      default:
        return dataType.replaceAll('_', ' ').title();
    }
  }

  String _getDataTypeDescription(String dataType) {
    switch (dataType) {
      case 'profile_data':
        return 'Your profile information and settings';
      case 'game_history':
        return 'Records of games you\'ve played';
      case 'messages':
        return 'Chat messages and communications';
      case 'audit_logs':
        return 'Security and activity logs';
      case 'login_history':
        return 'Login attempts and session data';
      case 'media_files':
        return 'Photos and files you\'ve uploaded';
      case 'location_data':
        return 'Location information for game matching';
      case 'analytics_data':
        return 'Usage statistics and analytics';
      default:
        return 'Data of type: $dataType';
    }
  }

  IconData _getDataTypeIcon(String dataType) {
    switch (dataType) {
      case 'profile_data':
        return Icons.person;
      case 'game_history':
        return Icons.sports_esports;
      case 'messages':
        return Icons.message;
      case 'audit_logs':
        return Icons.security;
      case 'login_history':
        return Icons.login;
      case 'media_files':
        return Icons.photo;
      case 'location_data':
        return Icons.location_city;
      case 'analytics_data':
        return Icons.analytics;
      default:
        return Icons.data_object;
    }
  }

  Color _getDataTypeColor(String dataType) {
    switch (dataType) {
      case 'profile_data':
        return Colors.blue;
      case 'game_history':
        return Colors.green;
      case 'messages':
        return Colors.orange;
      case 'audit_logs':
        return Colors.red;
      case 'login_history':
        return Colors.purple;
      case 'media_files':
        return Colors.pink;
      case 'location_data':
        return Colors.teal;
      case 'analytics_data':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    if (days < 30) {
      return '$days days';
    } else if (days < 365) {
      final months = (days / 30).round();
      return '$months months';
    } else {
      final years = (days / 365).round();
      return '$years years';
    }
  }

  void _showDataTypesHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Data Types Explained'),
        content: const SingleChildScrollView(
          child: Text('''
Profile Data: Your personal information, preferences, and account settings.

Game History: Records of games you've participated in, including results and statistics.

Messages: All communications through the app, including chat messages.

Security Logs: Activity logs for security monitoring and fraud prevention.

Login History: Records of when and how you've accessed your account.

Media Files: Photos, videos, and other files you've uploaded.

Location Data: Approximate location information used for game matching.

Analytics Data: Usage statistics and app interaction data.
          '''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRetentionHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Data Retention Policy'),
        content: const SingleChildScrollView(
          child: Text('''
Our data retention policy ensures your data is kept only as long as necessary:

• Data is automatically deleted based on your preferences
• Grace periods can be requested to delay deletion
• Some data may be kept longer for legal compliance
• Security logs have minimum retention requirements
• You can export your data before deletion

You have full control over your data retention preferences within legal limits.
          '''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Extension to capitalize strings
extension StringExtension on String {
  String title() {
    return split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}

/// Dialog for requesting grace period
class _GracePeriodDialog extends StatefulWidget {
  final String dataType;

  const _GracePeriodDialog({required this.dataType});

  @override
  State<_GracePeriodDialog> createState() => _GracePeriodDialogState();
}

class _GracePeriodDialogState extends State<_GracePeriodDialog> {
  Duration _selectedDuration = Duration(days: 30);
  final _reasonController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Request Grace Period'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request a grace period for ${widget.dataType.replaceAll('_', ' ')} data deletion.',
          ),
          const SizedBox(height: 16),

          const Text('Grace Period Duration:'),
          DropdownButton<Duration>(
            value: _selectedDuration,
            isExpanded: true,
            items:
                [
                      Duration(days: 7),
                      Duration(days: 14),
                      Duration(days: 30),
                      Duration(days: 60),
                      Duration(days: 90),
                    ]
                    .map(
                      (duration) => DropdownMenuItem(
                        value: duration,
                        child: Text('${duration.inDays} days'),
                      ),
                    )
                    .toList(),
            onChanged: (value) => setState(() => _selectedDuration = value!),
          ),

          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'Why do you need this grace period?',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {
            'duration': _selectedDuration,
            'reason': _reasonController.text.trim().isEmpty
                ? null
                : _reasonController.text.trim(),
          }),
          child: const Text('Request'),
        ),
      ],
    );
  }
}
