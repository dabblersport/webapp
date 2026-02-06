import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io' show Platform;

/// Screen for reporting bugs and issues
class BugReportScreen extends ConsumerStatefulWidget {
  const BugReportScreen({super.key});

  @override
  ConsumerState<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends ConsumerState<BugReportScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stepsController = TextEditingController();
  final _emailController = TextEditingController();

  String _selectedSeverity = 'Medium';
  String _selectedCategory = 'General Bug';
  bool _isSubmitting = false;
  bool _includeDeviceInfo = true;
  bool _includeAppLogs = true;

  final List<String> _severityLevels = ['Low', 'Medium', 'High', 'Critical'];

  final List<String> _categories = [
    'General Bug',
    'UI/Visual Issue',
    'Performance Issue',
    'Crash/Freeze',
    'Login/Authentication',
    'Profile/Settings',
    'Games/Activities',
    'Notifications',
    'Social Features',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadUserEmail();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  void _loadUserEmail() {
    _emailController.text = 'user@example.com';
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _stepsController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report a Bug'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(),
                  const SizedBox(height: 30),
                  _buildBugReportForm(),
                  const SizedBox(height: 30),
                  _buildDeviceInfoSection(),
                  const SizedBox(height: 30),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.bug_report, size: 48, color: Colors.orange.shade700),
            const SizedBox(height: 16),
            Text(
              'Found a Bug?',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Help us improve by reporting any issues you encounter. The more details you provide, the faster we can fix it!',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBugReportForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bug Details',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Your Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Bug Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(value: category, child: Text(category));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),

            const SizedBox(height: 16),

            // Severity
            DropdownButtonFormField<String>(
              initialValue: _selectedSeverity,
              decoration: const InputDecoration(
                labelText: 'Severity Level',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.priority_high),
              ),
              items: _severityLevels.map((severity) {
                return DropdownMenuItem(
                  value: severity,
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 12,
                        color: _getSeverityColor(severity),
                      ),
                      const SizedBox(width: 8),
                      Text(severity),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSeverity = value!;
                });
              },
            ),

            const SizedBox(height: 16),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Bug Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
                hintText: 'Brief description of the issue',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a bug title';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Detailed Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
                hintText:
                    'Describe what happened and what you expected to happen',
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please describe the bug';
                }
                if (value.length < 20) {
                  return 'Please provide more details (at least 20 characters)';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Steps to reproduce
            TextFormField(
              controller: _stepsController,
              decoration: const InputDecoration(
                labelText: 'Steps to Reproduce',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.list),
                alignLabelWithHint: true,
                hintText: '1. Go to...\n2. Click on...\n3. See error',
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please provide steps to reproduce the bug';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Additional Information',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Include Device Information'),
              subtitle: const Text('OS version, device model, screen size'),
              value: _includeDeviceInfo,
              onChanged: (value) {
                setState(() {
                  _includeDeviceInfo = value;
                });
              },
            ),

            const Divider(),

            SwitchListTile(
              title: const Text('Include App Logs'),
              subtitle: const Text('Recent app activity and error logs'),
              value: _includeAppLogs,
              onChanged: (value) {
                setState(() {
                  _includeAppLogs = value;
                });
              },
            ),

            if (_includeDeviceInfo) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Information to Include:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('• Platform: ${_getPlatformName()}'),
                    const Text('• App Version: 1.0.5'),
                    const Text('• Flutter Version: 3.x.x'),
                    Text(
                      '• Screen Resolution: ${MediaQuery.of(context).size.width.toInt()}x${MediaQuery.of(context).size.height.toInt()}',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitBugReport,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.orange.shade600,
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Submit Bug Report',
                style: TextStyle(color: Colors.white),
              ),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'Low':
        return Colors.green;
      case 'Medium':
        return Colors.orange;
      case 'High':
        return Colors.red;
      case 'Critical':
        return Colors.red.shade900;
      default:
        return Colors.grey;
    }
  }

  String _getPlatformName() {
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
      if (Platform.isWindows) return 'Windows';
      if (Platform.isMacOS) return 'macOS';
      if (Platform.isLinux) return 'Linux';
      return 'Unknown';
    } catch (e) {
      return 'Web';
    }
  }

  Future<void> _submitBugReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bug report submitted successfully! Thank you for helping us improve.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit bug report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
