import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/data_export_service.dart' hide Logger;
import '../../../../widgets/common/loading_button.dart';
import '../../../../widgets/common/info_dialog.dart';
import 'package:dabbler/core/utils/logger.dart';

/// Data Export UI for GDPR compliance
class DataExportScreen extends ConsumerStatefulWidget {
  final String userId;
  final String userEmail;

  const DataExportScreen({
    super.key,
    required this.userId,
    required this.userEmail,
  });

  @override
  ConsumerState<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends ConsumerState<DataExportScreen> {
  DataExportFormat _selectedFormat = DataExportFormat.zip;
  bool _isLoading = false;
  List<DataExportRequest> _exportHistory = [];
  final DataExportService _dataExportService = DataExportService();

  @override
  void initState() {
    super.initState();
    _loadExportHistory();
  }

  Future<void> _loadExportHistory() async {
    try {
      final history = await _dataExportService.getUserExportHistory(
        widget.userId,
      );
      setState(() {
        _exportHistory = history;
      });
    } catch (e) {
      Logger.error('Error loading export history', e);
    }
  }

  Future<void> _requestExport() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final request = await _dataExportService.requestGDPRDataExport(
        userId: widget.userId,
        format: _selectedFormat,
        userEmail: widget.userEmail,
        sendEmailNotification: false,
      );

      if (mounted) {
        _showSuccessDialog(request);
        await _loadExportHistory();
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog(DataExportRequest request) {
    showDialog(
      context: context,
      builder: (context) => InfoDialog(
        title: 'Export Request Submitted',
        message:
            'Your data export request has been submitted successfully.\n\n'
            'Export ID: ${request.id}\n'
            'Format: ${request.format.name.toUpperCase()}\n'
            'Expected completion: Within 24 hours.',
        type: InfoType.success,
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => InfoDialog(
        title: 'Export Request Failed',
        message:
            'We encountered an error while processing your request:\n\n$error\n\n'
            'Please try again later or contact support if the problem persists.',
        type: InfoType.error,
      ),
    );
  }

  Future<void> _downloadExport(DataExportRequest request) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final file = await _dataExportService.downloadExportedData(
        request.id,
        widget.userId,
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export downloaded: ${file.path.split('/').last}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadExportHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelExport(DataExportRequest request) async {
    try {
      await _dataExportService.cancelExportRequest(request.id);
      await _loadExportHistory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export request cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      Logger.error('Error cancelling export', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Export'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
            child: Text(
              'GDPR Compliance',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildExportRequestCard(),
            const SizedBox(height: 24),
            _buildExportHistoryCard(),
            const SizedBox(height: 24),
            _buildGDPRInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildExportRequestCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.download, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Request Data Export',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Export all your personal data in compliance with GDPR regulations. '
              'Your data will be packaged securely and made available for download.',
            ),
            const SizedBox(height: 16),

            // Format selection
            const Text(
              'Export Format:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ...DataExportFormat.values.map(
              (format) => RadioListTile<DataExportFormat>(
                title: Text(_getFormatDescription(format)),
                subtitle: Text(_getFormatSubtitle(format)),
                value: format,
                groupValue: _selectedFormat,
                onChanged: (value) => setState(() => _selectedFormat = value!),
              ),
            ),

            const SizedBox(height: 16),

            // Request button
            SizedBox(
              width: double.infinity,
              child: LoadingButton(
                onPressed: _requestExport,
                isLoading: _isLoading,
                child: const Text('Request Data Export'),
              ),
            ),

            const SizedBox(height: 8),
            Text(
              '⚠️ Export requests are processed within 24 hours and remain available for 30 days.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Export History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_exportHistory.isEmpty) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No export history',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ..._exportHistory.map(
                (request) => _buildExportHistoryItem(request),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExportHistoryItem(DataExportRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(request.status),
          child: Icon(
            _getStatusIcon(request.status),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          '${request.format.name.toUpperCase()} Export',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Requested: ${DateFormat('MMM dd, yyyy HH:mm').format(request.requestedAt)}',
            ),
            Text('Status: ${_getStatusText(request)}'),
            if (request.isCompleted && request.filePath != null)
              Text('Downloads: ${request.downloadCount}'),
            if (request.hasFailed && request.errorMessage != null)
              Text(
                'Error: ${request.errorMessage}',
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
        trailing: _buildExportActions(request),
      ),
    );
  }

  Widget? _buildExportActions(DataExportRequest request) {
    if (request.isPending) {
      return PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'cancel') {
            _cancelExport(request);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'cancel', child: Text('Cancel Request')),
        ],
      );
    }

    if (request.isCompleted && !request.isExpired) {
      return ElevatedButton.icon(
        onPressed: () => _downloadExport(request),
        icon: const Icon(Icons.download, size: 16),
        label: const Text('Download'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      );
    }

    return null;
  }

  Widget _buildGDPRInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Your Data Rights (GDPR)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Under the General Data Protection Regulation (GDPR), you have the following rights:',
            ),
            const SizedBox(height: 12),

            ...[
              'Right to Access - Request copies of your personal data',
              'Right to Rectification - Request correction of inaccurate data',
              'Right to Erasure - Request deletion of your personal data',
              'Right to Restrict Processing - Limit how we use your data',
              'Right to Data Portability - Transfer your data to another service',
              'Right to Object - Object to certain data processing activities',
            ].map(
              (right) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(right)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _showPrivacyPolicy(),
                  icon: const Icon(Icons.policy),
                  label: const Text('Privacy Policy'),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () => _contactSupport(),
                  icon: const Icon(Icons.support_agent),
                  label: const Text('Contact Support'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getFormatDescription(DataExportFormat format) {
    switch (format) {
      case DataExportFormat.json:
        return 'JSON Format';
      case DataExportFormat.csv:
        return 'CSV Format';
      case DataExportFormat.zip:
        return 'Complete Archive (Recommended)';
    }
  }

  String _getFormatSubtitle(DataExportFormat format) {
    switch (format) {
      case DataExportFormat.json:
        return 'Machine-readable format, ideal for developers';
      case DataExportFormat.csv:
        return 'Multiple CSV files in ZIP archive';
      case DataExportFormat.zip:
        return 'Includes data files, documentation, and your rights information';
    }
  }

  Color _getStatusColor(DataExportStatus status) {
    switch (status) {
      case DataExportStatus.pending:
        return Colors.orange;
      case DataExportStatus.processing:
        return Colors.blue;
      case DataExportStatus.completed:
        return Colors.green;
      case DataExportStatus.failed:
        return Colors.red;
      case DataExportStatus.cancelled:
        return Colors.grey;
      case DataExportStatus.expired:
        return Colors.brown;
    }
  }

  IconData _getStatusIcon(DataExportStatus status) {
    switch (status) {
      case DataExportStatus.pending:
        return Icons.schedule;
      case DataExportStatus.processing:
        return Icons.sync;
      case DataExportStatus.completed:
        return Icons.check_circle;
      case DataExportStatus.failed:
        return Icons.error;
      case DataExportStatus.cancelled:
        return Icons.cancel;
      case DataExportStatus.expired:
        return Icons.access_time;
    }
  }

  String _getStatusText(DataExportRequest request) {
    switch (request.status) {
      case DataExportStatus.pending:
        return 'Queued for processing';
      case DataExportStatus.processing:
        return 'Preparing your data...';
      case DataExportStatus.completed:
        if (request.isExpired) {
          return 'Completed (Expired)';
        }
        return 'Ready for download (${request.timeUntilExpiry.inDays} days left)';
      case DataExportStatus.failed:
        return 'Failed - Contact support';
      case DataExportStatus.cancelled:
        return 'Cancelled by user';
      case DataExportStatus.expired:
        return 'Expired and removed';
    }
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const Text(
          'This would open the privacy policy at:\nhttps://dabbler.app/privacy-policy',
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

  void _contactSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: const Text(
          'For data protection questions, contact:\nprivacy@dabbler.app',
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
