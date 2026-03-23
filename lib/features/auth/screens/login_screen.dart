import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_theme.dart';
import '../widgets/auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _showVerifyBanner = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl.forward();

    // Listen for auth state changes so that when a user taps the
    // verification email link (deep link → PKCE completes), we
    // automatically navigate them to the correct dashboard.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      final event = data.event;
      final session = data.session;
      if ((event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.tokenRefreshed) &&
          session != null) {
        // Clear any verify banner
        setState(() => _showVerifyBanner = false);
        final role =
            session.user.userMetadata?['role'] as String? ?? 'parent';
        final route = switch (role) {
          'teacher' => '/teacher',
          'admin'   => '/admin',
          _         => '/parent',
        };
        context.go(route);
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    _fadeCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Sign-in with granular error handling ─────────────────────────────
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _showVerifyBanner = false;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      // Explicit role-based navigation (GoRouter refreshListenable also handles this)
      if (mounted) {
        final role = response.user?.userMetadata?['role'] as String? ?? 'parent';
        final route = switch (role) {
          'teacher' => '/teacher',
          'admin'   => '/admin',
          _         => '/parent',
        };
        context.go(route);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      final code = (e.code ?? '').toLowerCase();

      if (msg.contains('email not confirmed') ||
          code == 'email_not_confirmed') {
        // Email registered but not verified
        setState(() => _showVerifyBanner = true);
      } else if (msg.contains('banned') ||
          msg.contains('disabled') ||
          code == 'user_banned') {
        // Account blocked by admin
        _showBanner(
          icon: Icons.block_rounded,
          message:
              'Your account has been blocked. Please contact the center admin.',
          color: AppColors.danger,
        );
      } else {
        // Wrong password, unregistered email, invalid_credentials, etc.
        // All auth failures that aren't verify/ban → show the dialog
        _showCredentialErrorDialog();
      }
    } catch (_) {
      // Only truly unexpected errors (network down, timeout, etc.)
      if (!mounted) return;
      _showBanner(
        icon: Icons.wifi_off_rounded,
        message: 'Connection error. Check your internet and try again.',
        color: AppColors.danger,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Invalid credentials dialog (wrong password OR no account) ────────
  void _showCredentialErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.bgDarkSurface : AppColors.bgSurface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl)),
          icon: const Icon(Icons.help_outline_rounded,
              color: AppColors.primary, size: 36),
          title: Text(
            'Couldn\'t sign you in',
            style: AppTextStyles.heading3.copyWith(color: cs.onSurface),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'The email or password is incorrect, or no account exists with this email.\n\nNew here?',
            style: AppTextStyles.bodyMedium
                .copyWith(color: cs.onSurface.withValues(alpha: 0.55)),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Try again',
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.55))),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/register');
              },
              child: const Text('Create account'),
            ),
          ],
        );
      },
    );
  }


  void _showBanner({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: Colors.white))),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(AppSpacing.md),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
      duration: const Duration(seconds: 4),
    ));
  }

  Future<void> _resendVerification() async {
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: _emailCtrl.text.trim(),
      );
      if (mounted) {
        _showBanner(
          icon: Icons.check_circle_outline,
          message: 'Verification email resent! Check your inbox.',
          color: AppColors.success,
        );
      }
    } catch (_) {
      if (mounted) {
        _showBanner(
          icon: Icons.error_outline,
          message: 'Could not resend. Try again in a moment.',
          color: AppColors.danger,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          // ── Decorative blobs ──────────────────────────────────────
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary
                    .withValues(alpha: isDark ? 0.10 : 0.16),
              ),
            ),
          ),
          Positioned(
            top: 100,
            left: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary
                    .withValues(alpha: isDark ? 0.08 : 0.12),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.xxl),

                      // ── Brand ─────────────────────────────────────
                      Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (b) => const LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.secondary
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ).createShader(b),
                            child: Text(
                              'TinySteps',
                              style: GoogleFonts.lexend(
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Container(
                            height: 3,
                            width: 48,
                            decoration: BoxDecoration(
                              gradient: AppGradients.coralButton,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Every morning is a new adventure',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: cs.onSurface
                                        .withValues(alpha: 0.5)),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.xxl),

                      // ── Verify email banner ───────────────────────
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _showVerifyBanner
                            ? _VerifyBanner(
                                key: const ValueKey('banner'),
                                email: _emailCtrl.text.trim(),
                                onResend: _resendVerification,
                                onDismiss: () => setState(
                                    () => _showVerifyBanner = false),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('no-banner')),
                      ),
                      if (_showVerifyBanner)
                        const SizedBox(height: AppSpacing.md),

                      // ── Form card ─────────────────────────────────
                      // AbsorbPointer blocks all input while loading
                      AbsorbPointer(
                        absorbing: _loading,
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.bgDarkSurface
                                : AppColors.bgSurface,
                            borderRadius:
                                BorderRadius.circular(AppRadius.xl),
                            border: Border.all(
                              color: cs.outline.withValues(alpha: 0.35),
                            ),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.07),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sign in',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Welcome back to TinySteps',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          color: cs.onSurface
                                              .withValues(alpha: 0.5)),
                                ),
                                const SizedBox(height: AppSpacing.lg),

                                AuthTextField(
                                  label: 'Email Address',
                                  hint: 'hello@tinysteps.com',
                                  controller: _emailCtrl,
                                  icon: Icons.email_outlined,
                                  keyboardType:
                                      TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Required';
                                    }
                                    if (!v.contains('@')) {
                                      return 'Enter a valid email';
                                    }
                                    return null;
                                  },
                                ),

                                // Password row
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Password',
                                        style:
                                            AppTextStyles.labelBold
                                                .copyWith(
                                                    color:
                                                        cs.onSurface)),
                                    GestureDetector(
                                      onTap: () {/* TODO: forgot */},
                                      child: Text('Forgot?',
                                          style: AppTextStyles
                                              .labelMedium
                                              .copyWith(
                                                  color:
                                                      AppColors.primary,
                                                  fontWeight:
                                                      FontWeight.w700)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _passCtrl,
                                  obscureText: _obscure,
                                  style:
                                      TextStyle(color: cs.onSurface),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Required';
                                    }
                                    if (v.length < 8) {
                                      return 'Min 8 characters';
                                    }
                                    return null;
                                  },
                                  decoration: _inputDec(
                                    hint: '••••••••',
                                    icon: Icons.lock_outline,
                                    isDark: isDark,
                                    cs: cs,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _obscure
                                            ? Icons
                                                .visibility_outlined
                                            : Icons
                                                .visibility_off_outlined,
                                        size: 20,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.4),
                                      ),
                                      onPressed: () => setState(
                                          () => _obscure = !_obscure),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: AppSpacing.xl),

                                AuthGradientButton(
                                  label: 'Sign In',
                                  icon:
                                      Icons.arrow_forward_rounded,
                                  onTap: _loading ? null : _signIn,
                                  loading: _loading,
                                ),

                                const SizedBox(height: AppSpacing.md),

                                Center(
                                  child: GestureDetector(
                                    onTap: _loading
                                        ? null
                                        : () => context.go('/register'),
                                    child: RichText(
                                      text: TextSpan(
                                        style: AppTextStyles.bodySmall
                                            .copyWith(
                                                color: cs.onSurface
                                                    .withValues(
                                                        alpha: 0.5)),
                                        children: [
                                          const TextSpan(
                                              text:
                                                  "Don't have an account? "),
                                          TextSpan(
                                            text: 'Create account',
                                            style: TextStyle(
                                                color: AppColors
                                                    .primary,
                                                fontWeight:
                                                    FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Full-screen spinner overlay (covers everything) ────────
          if (_loading)
            Container(
              color: Colors.black.withValues(alpha: 0.18),
              child: const Center(
                child: _LoadingSpinner(),
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDec({
    required String hint,
    required IconData icon,
    required bool isDark,
    required ColorScheme cs,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodyMuted
          .copyWith(color: cs.onSurface.withValues(alpha: 0.35)),
      prefixIcon:
          Icon(icon, color: cs.onSurface.withValues(alpha: 0.4), size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: isDark ? AppColors.bgDarkMuted : AppColors.bgLight,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 15),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide:
              BorderSide(color: cs.outline.withValues(alpha: 0.4))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide:
              BorderSide(color: cs.outline.withValues(alpha: 0.4))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide:
              const BorderSide(color: AppColors.danger, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide:
              const BorderSide(color: AppColors.danger, width: 2)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Email verification banner
// ─────────────────────────────────────────────────────────────────────────────
class _VerifyBanner extends StatelessWidget {
  const _VerifyBanner({
    super.key,
    required this.email,
    required this.onResend,
    required this.onDismiss,
  });
  final String email;
  final VoidCallback onResend;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.mark_email_unread_outlined,
              color: AppColors.accent, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Please verify your email',
                    style: AppTextStyles.labelBold
                        .copyWith(color: AppColors.accent)),
                const SizedBox(height: 2),
                Text(
                  'We sent a verification link to $email. Check your inbox (and spam!)',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.accent.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: onResend,
                  child: Text('Resend email',
                      style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.accent,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.accent)),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close,
                size: 18,
                color: AppColors.accent.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading spinner card
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingSpinner extends StatelessWidget {
  const _LoadingSpinner();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDarkSurface : AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.floating,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Please wait…',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
