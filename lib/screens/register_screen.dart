import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';
import '../utils/page_transitions.dart';
import 'login_screen.dart';
import 'homepage_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await ref.read(authNotifierProvider).register(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (result['success']) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            CustomPageTransitions.fadeWithScale(const HomepageScreen()),
            (route) => false,
          );
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
                      const SizedBox(height: 40),
                      
                      // App Logo/Title
                      _buildAppHeader(),
                      
                      const SizedBox(height: AppConstants.largePadding),
                      
                      // Welcome Text
                      _buildWelcomeText(),
                      
                      const SizedBox(height: AppConstants.largePadding),
                      
                      // Registration Form
                      _buildRegistrationForm(),
                      
                      const SizedBox(height: AppConstants.largePadding),
                      
                      // Register Button
                      _buildRegisterButton(),
                      
                      const SizedBox(height: 16),
                      
                      // Login Link
                      _buildLoginLink(),
                      
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
          'assets/images/haikyu-team.png',
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

  // Widget _buildAppHeader() {
  //   return Column(
  //     children: [
  //       Container(
  //         padding: const EdgeInsets.all(20),
  //         decoration: BoxDecoration(
  //           gradient: AppTheme.secondaryGradient,
  //           borderRadius: BorderRadius.circular(25),
  //           boxShadow: [
  //             BoxShadow(
  //               color: AppTheme.secondaryColor.withOpacity(0.4),
  //               blurRadius: 20,
  //               offset: const Offset(0, 10),
  //             ),
  //           ],
  //         ),
  //         child: const Icon(
  //           Icons.person_add_rounded,
  //           color: Colors.white,
  //           size: 50,
  //         ),
  //       ),
  //       const SizedBox(height: 20),
  //       Text(
  //         'JOIN US',
  //         style: TextStyle(
  //           fontSize: 28,
  //           fontWeight: FontWeight.w900,
  //           color: AppTheme.secondaryColor,
  //           letterSpacing: 4,
  //         ),
  //       ),
  //     ],
  //   ).animate().fadeIn(duration: AppConstants.mediumAnimation).slideY(begin: -0.3);
  // }

  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text(
          'Create Account',
          style: AppTheme.heading1.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Start your anime adventure today',
          style: AppTheme.body2.copyWith(
            fontSize: 16,
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

  Widget _buildRegistrationForm() {
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
            style: AppTheme.body1,
            decoration: InputDecoration(
              hintText: 'Username',
              prefixIcon: const Icon(Icons.person_rounded, color: AppTheme.secondaryColor),
              filled: true,
              fillColor: AppTheme.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.secondaryColor, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a username';
              }
              if (value.length < 3) {
                return 'Username must be at least 3 characters';
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
              prefixIcon: const Icon(Icons.lock_rounded, color: AppTheme.secondaryColor),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: AppTheme.textSecondary,
                ),
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
                borderSide: const BorderSide(color: AppTheme.secondaryColor, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
        ),
        
        // No confirm password in simplified flow
      ],
    ).animate().fadeIn(
      duration: AppConstants.mediumAnimation,
      delay: const Duration(milliseconds: 400),
    ).slideY(begin: 0.3);
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.secondaryColor,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: AppTheme.secondaryColor.withOpacity(0.4),
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
                'Create Account',
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

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: AppTheme.body2.copyWith(color: AppTheme.textSecondary),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              CustomPageTransitions.slideFromLeft(const LoginScreen()),
            );
          },
          child: Text(
            'Sign In',
            style: AppTheme.body2.copyWith(
              color: AppTheme.secondaryColor,
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