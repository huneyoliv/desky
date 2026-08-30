import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/localization/app_translation.dart';
import '../../core/cdn/cdn_resolver.dart';
import '../settings/settings_notifier.dart';
import '../settings/widgets/select_language_dialog.dart';
import 'auth_notifier.dart';
import 'signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    if (_formKey.currentState?.validate() == true) {
      ref.read(authStateProvider.notifier).signInWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
    }
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final t = ref.read(appTranslationProvider);
    int step = 1; // 1: Send Code, 2: Verify Code, 3: Reset Password
    final emailController = TextEditingController(text: _emailController.text);
    final codeController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.card,
            title: Text(
              step == 1
                  ? t.tr('forgot_password', fallback: 'Esqueci minha Senha')
                  : step == 2
                      ? t.tr('confirm', fallback: 'Digite o Código')
                      : t.tr('password', fallback: 'Nova Senha'),
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (errorText != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Text(
                        errorText!,
                        style: const TextStyle(color: AppColors.error, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (step == 1) ...[
                    Text(
                      t.tr('forgot_password_desc', fallback: 'Insira seu e-mail para receber um código de 6 dígitos de redefinição de senha:'),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: t.tr('email', fallback: 'Seu e-mail cadastrado'),
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ] else if (step == 2) ...[
                    Text(
                      '${t.tr('verification_code_sent', fallback: 'Enviamos um código de verificação para')} ${emailController.text}:',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 22, letterSpacing: 6),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '123456',
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      t.tr('new_password_prompt', fallback: 'Crie uma nova senha segura para sua conta:'),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: t.tr('password', fallback: 'Nova senha'),
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                child: Text(t.tr('cancel', fallback: 'Cancelar'), style: const TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final authRepo = ref.read(authRepositoryProvider);
                        setState(() {
                          isLoading = true;
                          errorText = null;
                        });

                        try {
                          if (step == 1) {
                            final email = emailController.text.trim();
                            if (email.isEmpty) throw Exception(t.tr('invalid_email', fallback: 'Digite um e-mail válido'));
                            await authRepo.sendPasswordResetCode(email);
                            setState(() {
                              step = 2;
                              isLoading = false;
                            });
                          } else if (step == 2) {
                            final code = codeController.text.trim();
                            if (code.length < 6) throw Exception(t.tr('verification_code_min_length', fallback: 'Digite o código de 6 dígitos'));
                            await authRepo.verifyPasswordResetCode(
                              emailController.text.trim(),
                              code,
                            );
                            setState(() {
                              step = 3;
                              isLoading = false;
                            });
                          } else {
                            final pass = newPasswordController.text.trim();
                            if (pass.length < 6) {
                              throw Exception(t.tr('password_min_length', fallback: 'A senha deve ter pelo menos 6 caracteres'));
                            }
                            await authRepo.resetPassword(
                              email: emailController.text.trim(),
                              password: pass,
                              code: codeController.text.trim(),
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(t.tr('password_reset_success', fallback: 'Senha redefinida com sucesso!')),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          setState(() {
                            isLoading = false;
                            errorText = e.toString().replaceAll('Exception: ', '');
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        step == 1
                            ? t.tr('send_code', fallback: 'Enviar Código')
                            : step == 2
                                ? t.tr('confirm', fallback: 'Verificar')
                                : t.tr('save', fallback: 'Redefinir Senha'),
                        style: const TextStyle(color: Colors.white),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final settingsState = ref.watch(settingsNotifierProvider);
    final t = ref.watch(appTranslationProvider);

    final langCode = settingsState.selectedLanguage;
    final langLabel = switch (langCode) {
      'pt' => 'Português',
      'en' => 'English',
      'es' => 'Español',
      'ko' => '한국어',
      'ja' => '日本語',
      'zh_hans' || 'zh-cn' => '简体中文',
      'zh_hant' || 'zh-tw' => '繁體中文',
      _ => langCode.toUpperCase(),
    };

    return Scaffold(
      body: Row(
        children: [
          // Left Panel - Decorative Branding & Mascot
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black,
                    AppColors.surface,
                    AppColors.surfaceLight,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.network(
                          CdnResolver.studiconUrl(377, StudiconPose.normal1),
                          width: 180,
                          height: 180,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/icons/icon.png',
                            width: 140,
                            height: 140,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Desky',
                          style: TextStyle(
                            fontFamily: AppTextStyles.fontDisplay,
                            fontFamilyFallback: AppTextStyles.fontFallbacks,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.tr('login_slogan', fallback: 'Foco, Disciplina & Comunidade no seu Desktop'),
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right Panel - Login Form
          Expanded(
            flex: 6,
            child: Container(
              color: AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 32),
              child: Stack(
                children: [
                  // Language Switcher in Top Right Corner of Login Screen
                  Align(
                    alignment: Alignment.topRight,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => SelectLanguageDialog.show(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.language_rounded, size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                langLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: SingleChildScrollView(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                t.tr('login_title', fallback: 'Entrar na sua conta'),
                                style: AppTextStyles.displayMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                t.tr('login_subtitle', fallback: 'Insira suas credenciais para continuar'),
                                style: AppTextStyles.bodyMedium,
                              ),
                              const SizedBox(height: 28),

                              // Error Banner if authentication failed
                              if (authState.errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.error),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline,
                                          color: AppColors.error, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          t.tr(authState.errorMessage!, fallback: authState.errorMessage!),
                                          style: const TextStyle(
                                            color: AppColors.error,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              // Email Field
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: t.tr('email', fallback: 'E-mail'),
                                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  prefixIcon: const Icon(Icons.email_outlined,
                                      color: AppColors.textSecondary),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppColors.primary),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return t.tr('enter_email', fallback: 'Por favor digite o e-mail');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Password Field
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: t.tr('password', fallback: 'Senha'),
                                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  prefixIcon: const Icon(Icons.lock_outline,
                                      color: AppColors.textSecondary),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppColors.primary),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return t.tr('enter_password', fallback: 'Por favor digite a senha');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 8),

                              // Forgot Password Link
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _showForgotPasswordDialog(context),
                                  child: Text(
                                    t.tr('forgot_password', fallback: 'Esqueci minha senha'),
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                                                  // Login Submit Button
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: authState.isLoading ? null : _submitLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: authState.isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          t.tr('login', fallback: 'Entrar'),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Or continue with Divider
                              Row(
                                children: [
                                  const Expanded(child: Divider(color: AppColors.border)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    child: Text(
                                      t.tr('or', fallback: 'ou').toUpperCase(),
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  const Expanded(child: Divider(color: AppColors.border)),
                                ],
                              ),
                              const SizedBox(height: 16),
                                                  // Google Login Button
                              SizedBox(
                                height: 46,
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: authState.isLoading
                                      ? null
                                      : () => ref.read(authStateProvider.notifier).signInWithGoogle(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF191919),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(color: AppColors.border),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/icons/google_icon.png',
                                        height: 20,
                                        width: 20,
                                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        t.tr('continue_with_google', fallback: 'Continuar com o Google'),
                                        style: const TextStyle(
                                          color: Color(0xFF191919),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Sign up link
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    t.tr('dont_have_account', fallback: 'Não tem uma conta? '),
                                    style: const TextStyle(color: AppColors.textSecondary),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const SignUpScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      t.tr('sign_up', fallback: 'Cadastre-se'),
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                t.tr('legal_disclaimer', fallback: 'O Desky é um cliente de terceiros independente e de código aberto, não sendo afiliado, endossado, patrocinado ou associado à Pallo Inc. ou ao Yeolpumta (YPT). Todas as marcas registradas pertencem aos seus respectivos proprietários.'),
                                style: TextStyle(
                                  color: AppColors.textMuted.withValues(alpha: 0.8),
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

