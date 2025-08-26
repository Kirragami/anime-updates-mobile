import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';
import '../utils/page_transitions.dart';
import 'register_screen.dart';
import 'homepage_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final Widget? destination;
  const LoginScreen({super.key, this.destination});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await ref.read(authNotifierProvider).login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (result['success']) {
        if (mounted) {
          if (widget.destination != null) {
            // Navigate to destination, with homepage as the previous route
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => widget.destination!),
              (route) => route.isFirst,
            );
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              CustomPageTransitions.fadeWithScale(const HomepageScreen()),
              (route) => route.isFirst,
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.largePadding),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 
                           MediaQuery.of(context).padding.top - 
                           MediaQuery.of(context).padding.bottom - 
                           (AppConstants.largePadding * 2),
              ),
              child: IntrinsicHeight(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      
                      // App Logo/Title
                      _buildAppHeader(),
                      
                      const SizedBox(height: AppConstants.largePadding),
                      
                      // Welcome Text
                      _buildWelcomeText(),
                      
                      const SizedBox(height: AppConstants.largePadding),
                      
                      // Login Form
                      _buildLoginForm(),
                      
                      const SizedBox(height: AppConstants.largePadding),
                      
                      // Login Button
                      _buildLoginButton(),
                      
                      const SizedBox(height: 16),
                      
                      // Register Link
                      _buildRegisterLink(),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppHeader() {
    return Column(
      children: [
        Image.asset(
          'assets/gifs/rem-ram.gif',
          width: 120,
          height: 120,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.animation_rounded,
              color: AppTheme.primaryColor,
              size: 120,
            );
          },
        ),
        // const SizedBox(height: 20),
        // Text(
        //   'ANIME UPDATES',
        //   style: TextStyle(
        //     fontSize: 28,
        //     fontWeight: FontWeight.w900,
        //     color: AppTheme.primaryColor,
        //     letterSpacing: 4,
        //   ),
        // ),
      ],
    ).animate().fadeIn(duration: AppConstants.mediumAnimation).slideY(begin: -0.3);
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text(
          'Okaerinasai!',
          style: AppTheme.heading1.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'How long are you going to just stand there? Sign in',
          style: AppTheme.body2.copyWith(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ).animate().fadeIn(
      duration: AppConstants.mediumAnimation,
      delay: const Duration(milliseconds: 200),
    ).slideY(begin: 0.3);
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        // Username Field
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TextFormField(
            controller: _usernameController,
            keyboardType: TextInputType.text,
            style: AppTheme.body1,
            decoration: InputDecoration(
              hintText: 'Username',
              prefixIcon: const Icon(Icons.person_outline, color: AppTheme.primaryColor),
              filled: true,
              fillColor: AppTheme.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Nanashibito san? Enter your name!';
              }
              return null;
            },
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Password Field
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            style: AppTheme.body1,
            decoration: InputDecoration(
              hintText: 'Password',
              prefixIcon: const Icon(Icons.lock_rounded, color: AppTheme.primaryColor),
              suffixIcon: IconButton(
                icon: Image.asset(
                  _isPasswordVisible 
                      ? 'assets/images/gojo-eye-open.png' 
                      : 'assets/images/gojo-eye-closed.png',
                  width: 34,
                  height: 34,
                ),
                padding: const EdgeInsets.all(8),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              filled: true,
              fillColor: AppTheme.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'How do you plan to sign in without a password?';
              }
              if (value.length < 6) {
                return 'You are suspicious. Passwords are at least 6';
              }
              return null;
            },
          ),
        ),
      ],
    ).animate().fadeIn(
      duration: AppConstants.mediumAnimation,
      delay: const Duration(milliseconds: 400),
    ).slideY(begin: 0.3);
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: AppTheme.primaryColor.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Sign In',
                style: AppTheme.body1.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
      ),
    ).animate().fadeIn(
      duration: AppConstants.mediumAnimation,
      delay: const Duration(milliseconds: 600),
    ).slideY(begin: 0.3);
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Join us today - it's free",
          style: AppTheme.body2.copyWith(color: AppTheme.textSecondary),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              CustomPageTransitions.slideFromRight(
                RegisterScreen(destination: widget.destination),
              ),
            );
          },
          child: Text(
            'Sign Up',
            style: AppTheme.body2.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(
      duration: AppConstants.mediumAnimation,
      delay: const Duration(milliseconds: 800),
    ).slideY(begin: 0.3);
  }
} 