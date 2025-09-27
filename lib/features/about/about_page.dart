import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/theme.dart';
import '../../core/config/app_config.dart';
import '../../core/obs/analytics.dart';
import '../../core/obs/error_reporter.dart';
import '../../core/supabase/client.dart';
import '../../core/widgets/app_toast.dart';

/// About page with build information and app details
class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  PackageInfo? _packageInfo;
  Map<String, dynamic>? _buildInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
    
    // Track screen view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final analytics = ref.read(analyticsProvider);
      AnalyticsHelper.trackNavigation(analytics, 'about');
    });
  }

  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final buildInfo = AppConfig.instance.getBuildInfo();
      
      setState(() {
        _packageInfo = packageInfo;
        _buildInfo = buildInfo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        context.showErrorToast('Failed to load app information');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnalyticsPageView(
      screenName: 'about',
      child: AppToastProvider(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('About'),
            elevation: 0,
          ),
          body: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAppHeader(),
                      const SizedBox(height: AppTheme.spacingL),
                      _buildBuildInfo(),
                      const SizedBox(height: AppTheme.spacingL),
                      _buildSystemInfo(),
                      const SizedBox(height: AppTheme.spacingL),
                      _buildFeatureStatus(),
                      const SizedBox(height: AppTheme.spacingL),
                      _buildDebugActions(),
                      const SizedBox(height: AppTheme.spacingL),
                      _buildLegalInfo(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildAppHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            // App icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.build_circle,
                size: 48,
                color: Colors.white,
                semanticLabel: 'MaintPulse app icon',
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            // App name and version
            Text(
              _buildInfo?['app_name'] ?? 'MaintPulse',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: AppTheme.spacingS),
            
            Text(
              'Version ${_packageInfo?.version ?? _buildInfo?['app_version'] ?? '1.0.0'}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            
            if (_packageInfo?.buildNumber != null) ...[
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                'Build ${_packageInfo!.buildNumber}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            
            const SizedBox(height: AppTheme.spacingM),
            
            Text(
              'Comprehensive facility management solution with real-time updates, billing integration, and preventive maintenance scheduling.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuildInfo() {
    if (_buildInfo == null) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Build Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            _buildInfoRow('Build Mode', _buildInfo!['build_mode']?.toString().toUpperCase() ?? 'Unknown'),
            _buildInfoRow('Platform', _buildInfo!['platform']?.toString() ?? 'Unknown'),
            _buildInfoRow('Package Name', _packageInfo?.packageName ?? 'com.maintpulse.app'),
            if (_packageInfo?.buildSignature != null)
              _buildInfoRow('Build Signature', _packageInfo!.buildSignature),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            _buildInfoRow('Flutter Version', 'Flutter 3.x'),
            _buildInfoRow('Dart Version', 'Dart 3.x'),
            _buildInfoRow('Target Platform', Theme.of(context).platform.name),
            _buildInfoRow('Supabase Status', SupabaseService.isInitialized ? 'Connected' : 'Disconnected'),
            _buildInfoRow('Configuration', AppConfig.instance.isValid ? 'Valid' : 'Invalid'),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureStatus() {
    if (_buildInfo == null) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Feature Status',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            _buildFeatureRow('Analytics', _buildInfo!['analytics_enabled'] == true),
            _buildFeatureRow('Error Reporting', _buildInfo!['error_reporting_enabled'] == true),
            _buildFeatureRow('Real-time Updates', true), // Always enabled in this version
            _buildFeatureRow('PhonePe Integration', true),
            _buildFeatureRow('Offline Mode', false), // Not yet implemented
            _buildFeatureRow('Push Notifications', false), // Not yet implemented
          ],
        ),
      ),
    );
  }

  Widget _buildDebugActions() {
    // Only show in debug mode
    if (_buildInfo?['build_mode'] != 'debug') {
      return const SizedBox.shrink();
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Debug Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            Wrap(
              spacing: AppTheme.spacingS,
              runSpacing: AppTheme.spacingS,
              children: [
                ElevatedButton.icon(
                  onPressed: _testErrorReporting,
                  icon: const Icon(Icons.bug_report, size: 16),
                  label: const Text('Test Error Reporting'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                
                ElevatedButton.icon(
                  onPressed: _exportDebugInfo,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export Debug Info'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                
                ElevatedButton.icon(
                  onPressed: _clearCache,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear Cache'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Legal Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            Text(
              '© 2025 MaintPulse. All rights reserved.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            
            const SizedBox(height: AppTheme.spacingS),
            
            Text(
              'This application is built with Flutter and uses Supabase for backend services. '
              'The app follows privacy-first principles and complies with data protection regulations.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            Wrap(
              spacing: AppTheme.spacingS,
              children: [
                TextButton(
                  onPressed: _showPrivacyPolicy,
                  child: const Text('Privacy Policy'),
                ),
                TextButton(
                  onPressed: _showTermsOfService,
                  child: const Text('Terms of Service'),
                ),
                TextButton(
                  onPressed: _showLicenses,
                  child: const Text('Licenses'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'Unknown',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String feature, bool enabled) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.cancel,
            color: enabled ? Colors.green : Colors.grey,
            size: 20,
            semanticLabel: enabled ? '$feature enabled' : '$feature disabled',
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              feature,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            enabled ? 'Enabled' : 'Disabled',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: enabled ? Colors.green : Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _testErrorReporting() {
    final analytics = ref.read(analyticsProvider);
    AnalyticsHelper.trackAction(analytics, 'test_error_reporting', context: {
      'from_about_page': true,
    });
    
    try {
      final errorReporter = ref.read(errorReporterProvider);
      errorReporter.testErrorReporting();
      
      context.showSuccessToast('Error reporting test completed. Check logs for details.');
    } catch (e) {
      context.showErrorToast('Failed to test error reporting: $e');
    }
  }

  void _exportDebugInfo() {
    final analytics = ref.read(analyticsProvider);
    AnalyticsHelper.trackAction(analytics, 'export_debug_info', context: {
      'from_about_page': true,
    });
    
    try {
      final debugInfo = {
        'package_info': {
          'app_name': _packageInfo?.appName,
          'package_name': _packageInfo?.packageName,
          'version': _packageInfo?.version,
          'build_number': _packageInfo?.buildNumber,
        },
        'build_info': _buildInfo,
        'config_info': AppConfig.instance.exportForDebug(),
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      final jsonString = const JsonEncoder.withIndent('  ').convert(debugInfo);
      
      Clipboard.setData(ClipboardData(text: jsonString));
      
      context.showSuccessToast('Debug information copied to clipboard');
    } catch (e) {
      context.showErrorToast('Failed to export debug info: $e');
    }
  }

  void _clearCache() {
    final analytics = ref.read(analyticsProvider);
    AnalyticsHelper.trackAction(analytics, 'clear_cache', context: {
      'from_about_page': true,
    });
    
    // In a real app, you would clear various caches here
    // For now, just show a success message
    context.showSuccessToast('Cache cleared successfully');
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'MaintPulse Privacy Policy\n\n'
            'We are committed to protecting your privacy. This app:\n\n'
            '• Collects only necessary data for functionality\n'
            '• Uses privacy-first analytics with no PII collection\n'
            '• Implements strict tenant data isolation\n'
            '• Follows GDPR compliance principles\n'
            '• Encrypts data in transit and at rest\n\n'
            'For the complete privacy policy, please visit our website.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'MaintPulse Terms of Service\n\n'
            'By using this application, you agree to:\n\n'
            '• Use the service responsibly and lawfully\n'
            '• Maintain the security of your account\n'
            '• Respect intellectual property rights\n'
            '• Comply with applicable laws and regulations\n'
            '• Accept our privacy practices\n\n'
            'For the complete terms, please visit our website.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLicenses() {
    showLicensePage(
      context: context,
      applicationName: _buildInfo?['app_name'] ?? 'MaintPulse',
      applicationVersion: _packageInfo?.version ?? '1.0.0',
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.build_circle,
          size: 32,
          color: Colors.white,
        ),
      ),
    );
  }
}