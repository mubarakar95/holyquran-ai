import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/service_providers.dart';
import '../../providers/settings_provider.dart';

class AuthModalWidget extends ConsumerStatefulWidget {
  const AuthModalWidget({super.key});

  @override
  ConsumerState<AuthModalWidget> createState() => _AuthModalWidgetState();
}

class _AuthModalWidgetState extends ConsumerState<AuthModalWidget> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  int _authMode = 0; // 0: SignIn, 1: SignUp, 2: MagicLink
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final supa = ref.read(supabaseServiceProvider);

    try {
      if (_authMode == 2) {
        // Magic link
        await supa.signInWithOtp(email);
        setState(() {
          _successMessage = 'Check your email for the login link!';
          _isLoading = false;
        });
      } else if (_authMode == 0) {
        // Sign in
        final res = await supa.signInWithPassword(email, password);
        if (res.user != null) {
          if (mounted) Navigator.pop(context);
        }
      } else {
        // Sign up
        final res = await supa.signUp(email, password);
        if (res.user != null) {
          setState(() {
            _successMessage = 'Account created! Please check your email to confirm.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('AuthException: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final colors = AppColors.fromMode(settings.theme);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _authMode == 0 ? 'Sign In' : _authMode == 1 ? 'Create Account' : 'Magic Link',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.foreground),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Email field
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),

          if (_authMode != 2) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],

          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: Colors.red)),
          ],

          if (_successMessage != null) ...[
            const SizedBox(height: 10),
            Text(_successMessage!, style: TextStyle(fontSize: 12, color: colors.accent)),
          ],

          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: _isLoading ? null : _handleAuth,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(_authMode == 0 ? 'Sign In' : _authMode == 1 ? 'Sign Up' : 'Send Link'),
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => setState(() => _authMode = _authMode == 0 ? 1 : 0),
                child: Text(_authMode == 0 ? "Don't have an account? Sign Up" : 'Already have an account? Sign In'),
              ),
              Text('•', style: TextStyle(color: colors.muted)),
              TextButton(
                onPressed: () => setState(() => _authMode = 2),
                child: const Text('Magic Link'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
