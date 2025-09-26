import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../domain/auth_service.dart';

/// Sign in page for email/password authentication
class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isSignUp = false;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authService = ref.read(authServiceProvider);
    
    try {
      if (_isSignUp) {
        await authService.signUpWithEmailPassword(
          email: _emailController.text,
          password: _passwordController.text,
          name: _nameController.text,
        );
        
        if (mounted) {
          _showSuccessMessage(
            'Account created successfully! Please check your email for verification.',
          );
          setState(() => _isSignUp = false);
        }
      } else {
        await authService.signInWithEmailPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    } catch (e) {
      // Error is handled by the auth service and shown in UI
    }
  }

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showErrorMessage('Please enter your email address first');
      return;
    }

    final authService = ref.read(authServiceProvider);
    
    try {
      await authService.resetPassword(_emailController.text);
      
      if (mounted) {
        _showSuccessMessage(
          'Password reset email sent. Please check your inbox.',
        );
      }
    } catch (e) {
      // Error is handled by the auth service
    }
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppTheme.spacingXXL),
              
              // App branding
              _buildHeader(),
              
              const SizedBox(height: AppTheme.spacingXXL),
              
              // Sign in/up form
              _buildForm(),
              
              const SizedBox(height: AppTheme.spacingL),
              
              // Submit button
              _buildSubmitButton(authState.isLoading),
              
              const SizedBox(height: AppTheme.spacingM),
              
              // Mode toggle
              _buildModeToggle(),
              
              if (!_isSignUp) ...[
                const SizedBox(height: AppTheme.spacingM),
                _buildForgotPasswordButton(),
              ],
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
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          ),
          child: Icon(
            Icons.hvac,
            size: 40,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        Text(
          'CUERON SAAN',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppTheme.spacingS),
        Text(
          'Enterprise HVAC/R Service Management',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isSignUp) ...[
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your full name';
                }
                if (value.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingM),
          ],
          
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email address';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleSubmit(),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (_isSignUp && value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    return FilledButton(
      onPressed: isLoading ? null : _handleSubmit,
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(_isSignUp ? 'Create Account' : 'Sign In'),
    );
  }

  Widget _buildModeToggle() {
    return TextButton(
      onPressed: () {
        setState(() {
          _isSignUp = !_isSignUp;
          _formKey.currentState?.reset();
        });
      },
      child: Text(
        _isSignUp
            ? 'Already have an account? Sign In'
            : 'Need an account? Sign Up',
      ),
    );
  }

  Widget _buildForgotPasswordButton() {
    return TextButton(
      onPressed: _handleForgotPassword,
      child: const Text('Forgot Password?'),
    );
  }
}