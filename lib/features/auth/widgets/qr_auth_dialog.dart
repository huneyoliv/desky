import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/localization/app_translation.dart';
import '../../../core/oauth/qr_auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../auth_notifier.dart';

class QrAuthDialog extends ConsumerStatefulWidget {
  final String providerName;

  const QrAuthDialog({
    super.key,
    this.providerName = 'Web',
  });

  static Future<bool?> show(BuildContext context, {String providerName = 'Web'}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => QrAuthDialog(providerName: providerName),
    );
  }

  @override
  ConsumerState<QrAuthDialog> createState() => _QrAuthDialogState();
}

class _QrAuthDialogState extends ConsumerState<QrAuthDialog> {
  QrAuthSession? _session;
  late final QrAuthService _qrAuthService;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isCopied = false;
  bool _showManualInput = false;
  final TextEditingController _tokenController = TextEditingController();
  bool _isSubmittingManual = false;

  @override
  void initState() {
    super.initState();
    _qrAuthService = ref.read(qrAuthServiceProvider);
    _startSession();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    if (_session != null) {
      _qrAuthService.cancel();
    }
    super.dispose();
  }

  Future<void> _startSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = await _qrAuthService.startSession(
        timeout: const Duration(minutes: 5),
      );

      if (!mounted) return;
      setState(() {
        _session = session;
        _isLoading = false;
      });

      _awaitSession(session);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Falha ao iniciar servidor local: $e';
      });
    }
  }

  Future<void> _awaitSession(QrAuthSession session) async {
    final t = ref.read(appTranslationProvider);
    try {
      final token = await session.tokenFuture;
      if (!mounted) return;

      final success = await ref.read(authStateProvider.notifier).signInWithCustomJwt(token);
      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = t.tr('qr_session_expired', fallback: 'Sessão transferida inválida ou expirada.');
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (!e.toString().contains('cancelado')) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('OAuthException: ', '');
        });
      }
    }
  }

  Future<void> _submitManualToken() async {
    final t = ref.read(appTranslationProvider);
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;

    setState(() {
      _isSubmittingManual = true;
      _errorMessage = null;
    });

    try {
      final success = await ref.read(authStateProvider.notifier).signInWithCustomJwt(token);
      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = t.tr('qr_invalid_token', fallback: 'Token JWT inválido ou não reconhecido pelo servidor.');
          _isSubmittingManual = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isSubmittingManual = false;
      });
    }
  }

  void _copyLink() {
    if (_session == null) return;
    Clipboard.setData(ClipboardData(text: _session!.pairingUrl));
    setState(() => _isCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 520,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(t),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  child: _buildBody(t),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppTranslation t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 20, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              LucideIcons.qrCode,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.tr('sign_in_with_provider', args: [widget.providerName], fallback: 'Entrar com ${widget.providerName}'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.tr('qr_auth_subtitle', fallback: 'Sincronização via Celular / QR Code'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(LucideIcons.x, color: Colors.white70, size: 20),
            splashRadius: 20,
            tooltip: t.tr('close', fallback: 'Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppTranslation t) {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
            const SizedBox(height: 16),
            Text(
              t.tr('qr_starting_server', fallback: 'Iniciando servidor de pareamento local...'),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(LucideIcons.alertCircle, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _startSession,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: Text(t.tr('try_again', fallback: 'Tentar Novamente')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: QrImageView(
            data: _session!.pairingUrl,
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildNetworkInterfaceSelector(t),
        const SizedBox(height: 14),
        _buildStep(
          number: '1',
          text: t.tr('qr_step_1', fallback: 'Conecte o celular na mesma rede Wi-Fi deste computador.'),
        ),
        const SizedBox(height: 8),
        _buildStep(
          number: '2',
          text: t.tr('qr_step_2', fallback: 'Abra a câmera ou leitor de QR Code do celular e aponte para o código.'),
        ),
        const SizedBox(height: 8),
        _buildStep(
          number: '3',
          text: t.tr('qr_step_3', fallback: 'Cole seu token ou confirme no celular para entrar instantaneamente.'),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copyLink,
                icon: Icon(
                  _isCopied ? LucideIcons.check : LucideIcons.copy,
                  size: 15,
                  color: _isCopied ? Colors.greenAccent : Colors.white70,
                ),
                label: Text(
                  _isCopied
                      ? t.tr('link_copied', fallback: 'Link Copiado!')
                      : t.tr('copy_pairing_link', fallback: 'Copiar Link de Pareamento'),
                  style: TextStyle(
                    fontSize: 13,
                    color: _isCopied ? Colors.greenAccent : Colors.white,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: () => setState(() => _showManualInput = !_showManualInput),
              icon: Icon(
                _showManualInput ? LucideIcons.chevronUp : LucideIcons.terminal,
                color: AppColors.primary,
                size: 20,
              ),
              tooltip: t.tr('manual_token_input', fallback: 'Entrada manual de Token'),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        if (_showManualInput) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.tr('paste_jwt_token', fallback: 'Colar Token JWT Manualmente:'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tokenController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: t.tr('paste_jwt_placeholder', fallback: 'Cole o token JWT aqui...'),
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    contentPadding: const EdgeInsets.all(10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmittingManual ? null : _submitManualToken,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmittingManual
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(t.tr('validate_and_sign_in', fallback: 'Validar e Entrar'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.lightbulb, color: AppColors.primary, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.tr('qr_hint_prefer_password', fallback: 'Prefere entrar com senha? No app do celular vá em Configurações > Conta > Definir Senha. Depois entre direto pelo E-mail no Desky.'),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep({required String number, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkInterfaceSelector(AppTranslation t) {
    if (_session == null) return const SizedBox.shrink();

    final availableIps = _session!.availableIps;
    final currentIp = _session!.hostIp;
    final currentInfo = availableIps.firstWhere(
      (info) => info.ip == currentIp,
      orElse: () => LanInterfaceInfo(name: 'Rede Local', ip: currentIp),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            currentInfo.isVirtual ? LucideIcons.network : LucideIcons.wifi,
            size: 14,
            color: currentInfo.isVirtual ? Colors.amberAccent : Colors.greenAccent,
          ),
          const SizedBox(width: 8),
          Text(
            t.tr('local_ip', fallback: 'IP Local: '),
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            '${currentInfo.ip} (${currentInfo.name})',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (availableIps.length > 1) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: t.tr('change_network_interface', fallback: 'Trocar interface de rede'),
              padding: EdgeInsets.zero,
              icon: const Icon(
                LucideIcons.chevronDown,
                size: 14,
                color: AppColors.textSecondary,
              ),
              color: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.border),
              ),
              onSelected: (newIp) {
                setState(() {
                  _session = _session!.copyWithIp(newIp);
                });
              },
              itemBuilder: (context) => availableIps.map((info) {
                final isSelected = info.ip == currentIp;
                return PopupMenuItem<String>(
                  value: info.ip,
                  height: 36,
                  child: Row(
                    children: [
                      Icon(
                        info.isVirtual ? LucideIcons.network : LucideIcons.wifi,
                        size: 14,
                        color: info.isVirtual ? Colors.amberAccent : Colors.greenAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${info.name}: ${info.ip}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                            color: isSelected ? AppColors.primary : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
