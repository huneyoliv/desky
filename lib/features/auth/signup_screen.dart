import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/cdn/cdn_resolver.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/localization/app_translation.dart';
import '../../data/models/category_model.dart';
import '../../data/models/country_model.dart';
import '../settings/settings_notifier.dart';
import 'auth_notifier.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _currentStep = 1; // 1: Email, 2: Code, 3: Profile & Password
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  CountryModel? _selectedCountry;
  CategoryModel? _selectedCategory;
  List<CategoryModel> _categories = [];
  bool _isLoadingCategories = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final countries = await settingsRepo.fetchCountries();
    if (countries.isNotEmpty) {
      final defaultCountry = countries.firstWhere(
        (c) => c.code.toUpperCase() == 'BR',
        orElse: () => countries.first,
      );
      if (mounted) {
        setState(() {
          _selectedCountry = defaultCountry;
        });
        _loadCategories(defaultCountry.id);
      }
    }
  }

  Future<void> _loadCategories(int countryId) async {
    setState(() => _isLoadingCategories = true);
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final lang = ref.read(settingsNotifierProvider).selectedLanguage;
    final categories = await settingsRepo.fetchCategoriesByCountry(
      countryId: countryId,
      language: lang.isNotEmpty ? lang : 'pt',
    );
    if (mounted) {
      setState(() {
        _categories = categories;
        _selectedCategory = categories.isNotEmpty ? categories.first : null;
        _isLoadingCategories = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _resendCooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCooldown > 0) {
          _resendCooldown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _handleSendVerificationCode() async {
    final t = ref.read(appTranslationProvider);
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = t.tr('alert_sign_check_email_msg', fallback: 'Formato de e-mail inválido.'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.sendSignUpVerificationCode(email);
      if (mounted) {
        setState(() {
          _currentStep = 2;
          _isLoading = false;
        });
        _startCooldown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('ApiException: ', '');
        });
      }
    }
  }

  Future<void> _handleVerifyCode() async {
    final t = ref.read(appTranslationProvider);
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    if (code.length < 6) {
      setState(() => _errorMessage = t.tr('verification_code_min_length', fallback: 'Insira o código de 6 dígitos recebido.'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.verifySignUpCode(email, code);
      if (mounted) {
        setState(() {
          _currentStep = 3;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('ApiException: ', '');
        });
      }
    }
  }

  Future<void> _handleCompleteSignUp() async {
    final t = ref.read(appTranslationProvider);
    final nickname = _nicknameController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final code = _codeController.text.trim();

    if (nickname.isEmpty) {
      setState(() => _errorMessage = t.tr('enter_nickname', fallback: 'Por favor, insira seu apelido/nickname.'));
      return;
    }
    if (nickname.length < 2) {
      setState(() => _errorMessage = t.tr('alert_user_nickname_error1', fallback: 'O apelido deve ter pelo menos 2 caracteres.'));
      return;
    }
    if (nickname.length > 60) {
      setState(() => _errorMessage = t.tr('alert_user_nickname_error2', fallback: 'O apelido deve ter menos de 60 caracteres.'));
      return;
    }
    if (password.length < 8) {
      setState(() => _errorMessage = t.tr('sign_up_password_rule', fallback: 'A senha deve conter no mínimo 8 caracteres.'));
      return;
    }
    if (password != confirmPassword) {
      setState(() => _errorMessage = t.tr('alert_user_sign_up_error1', fallback: 'As senhas digitadas não coincidem.'));
      return;
    }
    if (_selectedCountry == null) {
      setState(() => _errorMessage = t.tr('select_country', fallback: 'Selecione um país.'));
      return;
    }

    final categoryId = _selectedCategory?.id ?? 0;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await ref.read(authStateProvider.notifier).signUp(
          email: _emailController.text.trim(),
          password: password,
          code: code,
          nickname: nickname,
          categoryId: categoryId,
          countryId: _selectedCountry!.id,
        );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (!success) {
          _errorMessage = ref.read(authStateProvider).errorMessage ?? 'Falha ao realizar cadastro.';
        }
      });
      if (success) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);

    return Scaffold(
      body: Row(
        children: [
          // Left Decorative Panel
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
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      CdnResolver.studiconUrl(354, StudiconPose.normal1),
                      width: 180,
                      height: 180,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/icons/icon.png',
                        width: 140,
                        height: 140,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      t.tr('sign_up_title', fallback: 'Crie sua Conta'),
                      style: const TextStyle(
                        fontFamily: AppTextStyles.fontDisplay,
                        fontFamilyFallback: AppTextStyles.fontFallbacks,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.tr('sign_up_slogan', fallback: 'Junte-se à maior comunidade de estudos focados'),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right Form Panel
          Expanded(
            flex: 6,
            child: Container(
              color: AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Back & Title
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () {
                                if (_currentStep > 1) {
                                  setState(() => _currentStep--);
                                } else {
                                  Navigator.of(context).pop();
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${t.tr("step", fallback: "Passo")} $_currentStep ${t.tr("of", fallback: "de")} 3',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Text(
                          _currentStep == 1
                              ? t.tr('what_is_your_email', fallback: 'Qual é o seu e-mail?')
                              : _currentStep == 2
                                  ? t.tr('confirm_code', fallback: 'Confirme o código')
                                  : t.tr('profile_info', fallback: 'Informações do Perfil'),
                          style: AppTextStyles.displayMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentStep == 1
                              ? t.tr('email_code_desc', fallback: 'Enviaremos um código de 6 dígitos para verificar seu endereço.')
                              : _currentStep == 2
                                  ? '${t.tr("enter_code_sent_to", fallback: "Digite o código enviado para")} ${_emailController.text}'
                                  : t.tr('profile_setup_desc', fallback: 'Defina seu apelido, senha de acesso e categoria de estudos.'),
                          style: AppTextStyles.bodyMedium,
                        ),
                        const SizedBox(height: 24),

                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.error),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        if (_currentStep == 1) ...[
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: t.tr('email', fallback: 'E-mail'),
                              labelStyle: const TextStyle(color: AppColors.textSecondary),
                              filled: true,
                              fillColor: AppColors.surface,
                              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textSecondary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSendVerificationCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(t.tr('send_code', fallback: 'Enviar Código'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ] else if (_currentStep == 2) ...[
                          TextFormField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
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
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: _resendCooldown > 0 || _isLoading
                                    ? null
                                    : _handleSendVerificationCode,
                                child: Text(
                                  _resendCooldown > 0
                                      ? '${t.tr("resend_code", fallback: "Reenviar código")} (${_resendCooldown}s)'
                                      : t.tr('resend_code', fallback: 'Reenviar código'),
                                  style: TextStyle(
                                    color: _resendCooldown > 0 ? AppColors.textMuted : AppColors.primary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleVerifyCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(t.tr('verify_code', fallback: 'Verificar Código'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ] else ...[
                          // Nickname Field
                          TextFormField(
                            controller: _nicknameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: t.tr('nickname', fallback: 'Apelido (Nickname)'),
                              labelStyle: const TextStyle(color: AppColors.textSecondary),
                              filled: true,
                              fillColor: AppColors.surface,
                              prefixIcon: const Icon(Icons.person_outline, color: AppColors.textSecondary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: t.tr('password', fallback: 'Senha (mínimo 8 caracteres)'),
                              labelStyle: const TextStyle(color: AppColors.textSecondary),
                              filled: true,
                              fillColor: AppColors.surface,
                              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.textSecondary),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Confirm Password Field
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: t.tr('confirm_password', fallback: 'Confirmar Senha'),
                              labelStyle: const TextStyle(color: AppColors.textSecondary),
                              filled: true,
                              fillColor: AppColors.surface,
                              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: AppColors.textSecondary),
                                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Category Dropdown
                          if (_isLoadingCategories)
                            const Center(child: CircularProgressIndicator())
                          else if (_categories.isNotEmpty)
                            DropdownButtonFormField<CategoryModel>(
                              value: _selectedCategory,
                              dropdownColor: AppColors.card,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: t.tr('category', fallback: 'Categoria de Estudo'),
                                labelStyle: const TextStyle(color: AppColors.textSecondary),
                                filled: true,
                                fillColor: AppColors.surface,
                                prefixIcon: const Icon(Icons.school_outlined, color: AppColors.textSecondary),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                              ),
                              items: _categories.map((cat) {
                                return DropdownMenuItem<CategoryModel>(
                                  value: cat,
                                  child: Text(cat.title, style: const TextStyle(color: Colors.white)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedCategory = val);
                                }
                              },
                            ),
                          const SizedBox(height: 24),

                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleCompleteSignUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(t.tr('sign_up', fallback: 'Concluir Cadastro'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(t.tr('already_have_account', fallback: 'Já possui uma conta?'), style: const TextStyle(color: AppColors.textSecondary)),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(t.tr('login', fallback: 'Entrar'), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
