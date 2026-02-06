import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Screen displaying open source licenses and attributions
class LicensesScreen extends ConsumerStatefulWidget {
  const LicensesScreen({super.key});

  @override
  ConsumerState<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends ConsumerState<LicensesScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Sample license data - in a real app, this would be loaded from packages
  final List<LicenseInfo> _licenses = [
    LicenseInfo(
      name: 'Flutter',
      version: '3.24.0',
      description: 'UI toolkit for building natively compiled applications',
      license: 'BSD 3-Clause License',
      copyright: 'Copyright 2014 The Flutter Authors',
      url: 'https://flutter.dev',
    ),
    LicenseInfo(
      name: 'Riverpod',
      version: '2.6.1',
      description: 'A reactive caching and data-binding framework',
      license: 'MIT License',
      copyright: 'Copyright 2020 Remi Rousselet',
      url: 'https://riverpod.dev',
    ),
    LicenseInfo(
      name: 'go_router',
      version: '14.2.7',
      description: 'Declarative routing package for Flutter',
      license: 'BSD 3-Clause License',
      copyright: 'Copyright 2013 The Flutter Authors',
      url: 'https://pub.dev/packages/go_router',
    ),
    LicenseInfo(
      name: 'http',
      version: '1.2.0',
      description:
          'Composable, multi-platform, future-based API for HTTP requests',
      license: 'BSD 3-Clause License',
      copyright: 'Copyright 2014, the Dart project authors',
      url: 'https://pub.dev/packages/http',
    ),
    LicenseInfo(
      name: 'shared_preferences',
      version: '2.2.3',
      description:
          'Flutter plugin for reading and writing simple key-value pairs',
      license: 'BSD 3-Clause License',
      copyright: 'Copyright 2013 The Flutter Authors',
      url: 'https://pub.dev/packages/shared_preferences',
    ),
    LicenseInfo(
      name: 'image_picker',
      version: '1.1.2',
      description:
          'Flutter plugin for selecting images from the gallery or camera',
      license: 'BSD 3-Clause License',
      copyright: 'Copyright 2013 The Flutter Authors',
      url: 'https://pub.dev/packages/image_picker',
    ),
    LicenseInfo(
      name: 'supabase_flutter',
      version: '2.5.6',
      description: 'Flutter integration for Supabase',
      license: 'MIT License',
      copyright: 'Copyright 2020 Supabase',
      url: 'https://pub.dev/packages/supabase_flutter',
    ),
    LicenseInfo(
      name: 'lucide_icons',
      version: '0.4.0',
      description: 'Lucide icons for Flutter',
      license: 'MIT License',
      copyright: 'Copyright 2021 Lucide Contributors',
      url: 'https://pub.dev/packages/lucide_icons',
    ),
  ];

  List<LicenseInfo> get _filteredLicenses {
    if (_searchQuery.isEmpty) return _licenses;
    return _licenses.where((license) {
      return license.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          license.description.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          license.license.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupScrollListener();
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

  void _setupScrollListener() {
    _scrollController.addListener(() {
      setState(() {
        _isScrolled = _scrollController.offset > 100;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Source Licenses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        elevation: _isScrolled ? 2 : 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showLicenseInfo,
            tooltip: 'About Licenses',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              _buildHeaderSection(),
              _buildSearchBar(),
              Expanded(child: _buildLicensesList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.code, size: 48, color: Colors.green.shade700),
              const SizedBox(height: 16),
              Text(
                'Open Source Licenses',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This app is built with amazing open source libraries. We thank all contributors for their work.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '${_licenses.length} open source packages',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search licenses...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: const Icon(Icons.clear),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).cardColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildLicensesList() {
    final filteredLicenses = _filteredLicenses;

    if (filteredLicenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No licenses found',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search query',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: filteredLicenses.length,
      itemBuilder: (context, index) {
        final license = filteredLicenses[index];
        return _buildLicenseCard(license);
      },
    );
  }

  Widget _buildLicenseCard(LicenseInfo license) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showLicenseDetails(license),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      license.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getLicenseColor(
                        license.license,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'v${license.version}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _getLicenseColor(license.license),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                license.description,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.balance,
                    size: 16,
                    color: _getLicenseColor(license.license),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    license.license,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _getLicenseColor(license.license),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getLicenseColor(String license) {
    switch (license.toLowerCase()) {
      case 'mit license':
        return Colors.green;
      case 'bsd 3-clause license':
        return Colors.blue;
      case 'apache license 2.0':
        return Colors.orange;
      default:
        return Colors.purple;
    }
  }

  void _showLicenseDetails(LicenseInfo license) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      license.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Version', license.version),
              _buildDetailRow('License', license.license),
              _buildDetailRow('Copyright', license.copyright),
              _buildDetailRow('URL', license.url),
              const SizedBox(height: 16),
              Text(
                'Description',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                license.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Opening ${license.url}')),
                    );
                  },
                  child: const Text('View on Web'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  void _showLicenseInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Open Source Licenses'),
        content: const Text(
          'This app uses various open source libraries and packages. Each license defines the terms under which the code can be used, modified, and distributed.\n\n'
          'We are grateful to all the developers and contributors who make their work available under open source licenses.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class LicenseInfo {
  final String name;
  final String version;
  final String description;
  final String license;
  final String copyright;
  final String url;

  LicenseInfo({
    required this.name,
    required this.version,
    required this.description,
    required this.license,
    required this.copyright,
    required this.url,
  });
}
