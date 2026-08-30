import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/localization/app_translation.dart';

class PrivacyPolicyDialog extends ConsumerWidget {
  const PrivacyPolicyDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const PrivacyPolicyDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);

    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 650,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.privacy_tip_outlined, color: AppColors.primary, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.tr('drawer_settings_pallo_privacy_title', fallback: 'Política de Privacidade'),
                    style: AppTextStyles.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: AppColors.border, height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(t.tr('privacy_sec1_title', fallback: '1. Informações que Coletamos')),
                    _buildParagraph(t.tr('privacy_sec1_body', fallback: 'O YPT coleta informações fornecidas diretamente por você ao criar uma conta, tais como endereço de e-mail, nome de usuário (nickname), fuso horário e região. Durante a utilização do aplicativo, registramos métricas de estudo, incluindo matérias cadastradas, tempos de início e término de sessões no cronômetro e histórico de metas.')),
                    const SizedBox(height: 16),
                    _buildSectionTitle(t.tr('privacy_sec2_title', fallback: '2. Live Study e Mídia')),
                    _buildParagraph(t.tr('privacy_sec2_body', fallback: 'Ao participar de grupos de estudo com recurso de Live Study ativado, capturas periódicas de imagem podem ser processadas para verificação de presença em tempo real. As fotos de estudo temporárias não arquivadas são eliminadas automaticamente de nossos servidores após 7 dias corridos.')),
                    const SizedBox(height: 16),
                    _buildSectionTitle(t.tr('privacy_sec3_title', fallback: '3. Segurança e Privacidade no Desktop')),
                    _buildParagraph(t.tr('privacy_sec3_body', fallback: 'O Desky armazena credenciais e preferências de estudo de forma segura localmente utilizando encriptação nativa. Nenhuma informação sobre outros softwares ou arquivos do seu computador é acessada ou compartilhada.')),
                    const SizedBox(height: 16),
                    _buildSectionTitle(t.tr('privacy_sec4_title', fallback: '4. Compartilhamento e Armazenamento de Dados')),
                    _buildParagraph(t.tr('privacy_sec4_body', fallback: 'Não comercializamos, alugamos ou compartilhamos seus dados pessoais com terceiros para fins de marketing. O tráfego de dados é protegido por criptografia TLS/HTTPS e chaves de autenticação JWT seguras.')),
                    const SizedBox(height: 16),
                    _buildSectionTitle(t.tr('privacy_sec5_title', fallback: '5. Seus Direitos e Exclusão de Conta')),
                    _buildParagraph(t.tr('privacy_sec5_body', fallback: 'Em conformidade com a LGPD e GDPR, você pode solicitar a qualquer momento a visualização, retificação ou exclusão permanente de todos os seus dados e histórico através da opção "Excluir Minha Conta" nas configurações.')),
                    const SizedBox(height: 20),
                    Text(
                      t.tr('privacy_footer_contact', fallback: 'Pallo Inc. / TGCLab • Contato: contact@yeolpumta.com'),
                      style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.8), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(t.tr('btn_understand', fallback: 'Entendido'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
    );
  }
}
