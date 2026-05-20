import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    final success = await ref.read(authStateProvider.notifier)
        .login(_emailCtrl.text.trim(), _passCtrl.text);
    if (!success && mounted) {
      final error = ref.read(authStateProvider).error ?? 'Login failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            height: size.height * 0.45,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primary, AppTheme.primaryLight],
              ),
            ),
          ),
          // Wave shape
          Positioned(
            top: size.height * 0.35,
            left: 0, right: 0,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Logo
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: const Center(
                      child: Text('MRS', style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primary,
                      )),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('MRS HRMS', style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5,
                  )),
                  const Text('Enterprise HR & Payroll', style: TextStyle(fontSize: 13, color: Colors.white70)),
                  const SizedBox(height: 48),

                  // Card
                  SlideTransition(
                    position: _slideAnim,
                    child: Card(
                      elevation: 8,
                      shadowColor: AppTheme.primary.withOpacity(0.15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Welcome back', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text('Sign in to your account', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                              const SizedBox(height: 28),

                              AppTextField(
                                controller: _emailCtrl,
                                label: 'Work Email',
                                hint: 'you@company.com',
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: Icons.email_outlined,
                                validator: (v) => v!.isEmpty ? 'Enter your email' : null,
                              ),
                              const SizedBox(height: 16),

                              AppTextField(
                                controller: _passCtrl,
                                label: 'Password',
                                hint: '••••••••',
                                obscureText: _obscure,
                                prefixIcon: Icons.lock_outline,
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                                validator: (v) => v!.isEmpty ? 'Enter your password' : null,
                                onFieldSubmitted: (_) => _login(),
                              ),
                              const SizedBox(height: 8),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {},
                                  child: const Text('Forgot Password?'),
                                ),
                              ),
                              const SizedBox(height: 8),

                              AppButton(
                                text: 'Sign In',
                                onPressed: auth.isLoading ? null : _login,
                                isLoading: auth.isLoading,
                                width: double.infinity,
                              ),
                              const SizedBox(height: 16),

                              // Demo credentials hint
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 16, color: AppTheme.primary.withOpacity(0.7)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Use your work email and the temporary password provided by HR',
                                        style: TextStyle(fontSize: 12, color: AppTheme.primary.withOpacity(0.8)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text('v1.0.0 · MRS Technologies Pvt. Ltd.', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
