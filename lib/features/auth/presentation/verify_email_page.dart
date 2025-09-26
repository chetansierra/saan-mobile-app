import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../domain/auth_service.dart';

/// Email verification page for confirming user registration
class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  final _emailController = TextEditingController();
  bool _canResend = true;
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    
    // Pre-fill email if available from auth state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = ref.read(authServiceProvider);
      final user = authService.currentUser;
      if (user?.email != null) {
        _emailController.text = user!.email!;
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResendEmail() async {
    if (!_canResend) return;
    
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showErrorMessage('Please enter your email address');
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      _showErrorMessage('Please enter a valid email address');
      return;
    }

    final authService = ref.read(authServiceProvider);
    
    try {
      await authService.resendEmailConfirmation(email);
      
      if (mounted) {
        _showSuccessMessage('Verification email sent successfully!');
        _startResendCooldown();
      }
    } catch (e) {
      // Error is handled by auth service and shown via state
    }
  }

  void _startResendCooldown() {
    setState(() {
      _canResend = false;
      _resendCooldown = 60; // 60 seconds cooldown
    });

    // Countdown timer
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        setState(() {
          _resendCooldown--;
        });
        
        if (_resendCooldown <= 0) {
          setState(() {
            _canResend = true;
          });
          return false; // Stop the loop
        }
      }
      
      return mounted && _resendCooldown > 0;
    });
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authServiceProvider).state;
    
    // Show error message if present
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (authState.error != null) {
        _showErrorMessage(authState.error!);
        ref.read(authServiceProvider).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/auth/sign-in'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Verify Email'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppTheme.spacingXL),
              
              // Header illustration
              _buildHeader(),
              
              const SizedBox(height: AppTheme.spacingXL),
              
              // Instructions
              _buildInstructions(),
              
              const SizedBox(height: AppTheme.spacingL),
              
              // Email input
              _buildEmailInput(),
              
              const SizedBox(height: AppTheme.spacingL),
              
              // Resend button
              _buildResendButton(authState.isLoading),
              
              const Spacer(),
              
              // Alternative actions
              _buildAlternativeActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Icon(
            Icons.mark_email_read,
            size: 48,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        Text(
          'Check Your Email',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Column(
      children: [
        Text(
          'We\'ve sent a verification link to your email address. '
          'Please check your inbox and click the link to verify your account.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.spacingM),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  'Don\'t forget to check your spam folder if you don\'t see the email.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email Address',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppTheme.spacingS),
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            hintText: 'Enter your email address',
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }

  Widget _buildResendButton(bool isLoading) {
    return FilledButton(
      onPressed: (_canResend && !isLoading) ? _handleResendEmail : null,
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              _canResend
                  ? 'Resend Verification Email'
                  : 'Resend in $_resendCooldown seconds',
            ),
    );
  }

  Widget _buildAlternativeActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: () => context.go('/auth/sign-in'),
          child: const Text('Back to Sign In'),
        ),
        const SizedBox(height: AppTheme.spacingS),
        TextButton(
          onPressed: () {
            // Open email app (this would require url_launcher in a real app)
            _showSuccessMessage('Opening email app...');
          },
          child: const Text('Open Email App'),
        ),
      ],
    );
  }
}