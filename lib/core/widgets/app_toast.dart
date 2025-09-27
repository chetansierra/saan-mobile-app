import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';

/// Provider for AppToast manager
final appToastProvider = ChangeNotifierProvider<AppToastManager>((ref) {
  return AppToastManager();
});

/// Unified toast management system
class AppToastManager extends ChangeNotifier {
  BuildContext? _context;
  OverlayEntry? _currentOverlay;

  /// Set the context for showing toasts
  void setContext(BuildContext context) {
    _context = context;
  }

  /// Show a success toast
  void showSuccess(String message, {Duration? duration}) {
    _showToast(
      message: message,
      type: AppToastType.success,
      duration: duration,
    );
  }

  /// Show an error toast
  void showError(String message, {Duration? duration}) {
    _showToast(
      message: message,
      type: AppToastType.error,
      duration: duration,
    );
  }

  /// Show a warning toast
  void showWarning(String message, {Duration? duration}) {
    _showToast(
      message: message,
      type: AppToastType.warning,
      duration: duration,
    );
  }

  /// Show an info toast
  void showInfo(String message, {Duration? duration}) {
    _showToast(
      message: message,
      type: AppToastType.info,
      duration: duration,
    );
  }

  /// Show a loading toast (persistent until dismissed)
  void showLoading(String message) {
    _showToast(
      message: message,
      type: AppToastType.loading,
      duration: null, // Persistent
    );
  }

  /// Dismiss current toast
  void dismiss() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  /// Internal method to show toast
  void _showToast({
    required String message,
    required AppToastType type,
    Duration? duration,
  }) {
    final context = _context;
    if (context == null || !context.mounted) {
      debugPrint('⚠️ Cannot show toast: No context available');
      return;
    }

    // Dismiss existing toast
    dismiss();

    // Create overlay entry
    _currentOverlay = OverlayEntry(
      builder: (context) => _AppToastWidget(
        message: message,
        type: type,
        onDismiss: dismiss,
      ),
    );

    // Show overlay
    Overlay.of(context).insert(_currentOverlay!);

    // Auto-dismiss after duration (if specified)
    if (duration != null) {
      Future.delayed(duration, () {
        dismiss();
      });
    } else if (type != AppToastType.loading) {
      // Default durations for non-loading toasts
      final defaultDuration = type == AppToastType.error 
          ? const Duration(seconds: 5)
          : const Duration(seconds: 3);
      
      Future.delayed(defaultDuration, () {
        dismiss();
      });
    }
  }
}

/// Toast types with different styling
enum AppToastType {
  success,
  error,
  warning,
  info,
  loading,
}

/// Toast widget configuration
class _ToastConfig {
  const _ToastConfig({
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
    required this.borderColor,
  });

  final Color backgroundColor;
  final Color textColor;
  final IconData icon;
  final Color borderColor;

  static _ToastConfig getConfig(AppToastType type, BuildContext context) {
    final theme = Theme.of(context);
    
    switch (type) {
      case AppToastType.success:
        return _ToastConfig(
          backgroundColor: Colors.green.shade50,
          textColor: Colors.green.shade800,
          icon: Icons.check_circle_outline,
          borderColor: Colors.green.shade200,
        );
      
      case AppToastType.error:
        return _ToastConfig(
          backgroundColor: Colors.red.shade50,
          textColor: Colors.red.shade800,
          icon: Icons.error_outline,
          borderColor: Colors.red.shade200,
        );
      
      case AppToastType.warning:
        return _ToastConfig(
          backgroundColor: Colors.orange.shade50,
          textColor: Colors.orange.shade800,
          icon: Icons.warning_outlined,
          borderColor: Colors.orange.shade200,
        );
      
      case AppToastType.info:
        return _ToastConfig(
          backgroundColor: Colors.blue.shade50,
          textColor: Colors.blue.shade800,
          icon: Icons.info_outline,
          borderColor: Colors.blue.shade200,
        );
      
      case AppToastType.loading:
        return _ToastConfig(
          backgroundColor: theme.colorScheme.surface,
          textColor: theme.colorScheme.onSurface,
          icon: Icons.refresh,
          borderColor: theme.colorScheme.outline,
        );
    }
  }
}

/// Internal toast widget
class _AppToastWidget extends StatefulWidget {
  const _AppToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  final String message;
  final AppToastType type;
  final VoidCallback onDismiss;

  @override
  State<_AppToastWidget> createState() => _AppToastWidgetState();
}

class _AppToastWidgetState extends State<_AppToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _animateOut() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final config = _ToastConfig.getConfig(widget.type, context);
    final mediaQuery = MediaQuery.of(context);
    
    return Positioned(
      top: mediaQuery.padding.top + AppTheme.spacingM,
      left: AppTheme.spacingM,
      right: AppTheme.spacingM,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  decoration: BoxDecoration(
                    color: config.backgroundColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    border: Border.all(color: config.borderColor),
                  ),
                  child: InkWell(
                    onTap: widget.type != AppToastType.loading ? _animateOut : null,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Row(
                        children: [
                          // Icon
                          widget.type == AppToastType.loading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      config.textColor,
                                    ),
                                  ),
                                )
                              : Icon(
                                  config.icon,
                                  color: config.textColor,
                                  size: 20,
                                  semanticLabel: widget.type.name,
                                ),
                          
                          const SizedBox(width: AppTheme.spacingM),
                          
                          // Message
                          Expanded(
                            child: Text(
                              widget.message,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: config.textColor,
                                fontWeight: FontWeight.w500,
                              ),
                              semanticsLabel: '${widget.type.name}: ${widget.message}',
                            ),
                          ),
                          
                          // Close button (for non-loading toasts)
                          if (widget.type != AppToastType.loading) ...[
                            const SizedBox(width: AppTheme.spacingS),
                            InkWell(
                              onTap: _animateOut,
                              borderRadius: BorderRadius.circular(AppTheme.radiusS),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: config.textColor.withOpacity(0.7),
                                  semanticLabel: 'Dismiss notification',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Extension methods for easy toast usage
extension AppToastExtension on BuildContext {
  /// Show success toast
  void showSuccessToast(String message, {Duration? duration}) {
    final toastManager = ProviderScope.containerOf(this).read(appToastProvider);
    toastManager.setContext(this);
    toastManager.showSuccess(message, duration: duration);
  }

  /// Show error toast
  void showErrorToast(String message, {Duration? duration}) {
    final toastManager = ProviderScope.containerOf(this).read(appToastProvider);
    toastManager.setContext(this);
    toastManager.showError(message, duration: duration);
  }

  /// Show warning toast
  void showWarningToast(String message, {Duration? duration}) {
    final toastManager = ProviderScope.containerOf(this).read(appToastProvider);
    toastManager.setContext(this);
    toastManager.showWarning(message, duration: duration);
  }

  /// Show info toast
  void showInfoToast(String message, {Duration? duration}) {
    final toastManager = ProviderScope.containerOf(this).read(appToastProvider);
    toastManager.setContext(this);
    toastManager.showInfo(message, duration: duration);
  }

  /// Show loading toast
  void showLoadingToast(String message) {
    final toastManager = ProviderScope.containerOf(this).read(appToastProvider);
    toastManager.setContext(this);
    toastManager.showLoading(message);
  }

  /// Dismiss current toast
  void dismissToast() {
    final toastManager = ProviderScope.containerOf(this).read(appToastProvider);
    toastManager.dismiss();
  }
}

/// Widget for setting up toast context
class AppToastProvider extends ConsumerWidget {
  const AppToastProvider({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toastManager = ref.watch(appToastProvider);
    
    // Set context for toast manager
    WidgetsBinding.instance.addPostFrameCallback((_) {
      toastManager.setContext(context);
    });

    return child;
  }
}