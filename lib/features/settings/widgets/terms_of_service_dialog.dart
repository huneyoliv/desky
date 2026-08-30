import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/localization/app_translation.dart';

class TermsOfServiceDialog extends ConsumerWidget {
  const TermsOfServiceDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const TermsOfServiceDialog(),
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
                const Icon(Icons.description_outlined, color: AppColors.primary, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.tr('drawer_settings_pallo_terms_title', fallback: 'Termos de Uso e Serviço'),
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
                    _buildSectionTitle(t.tr('terms_sec1_title', fallback: '1. Aceitação dos Termos')),
                    _buildParagraph(t.tr('terms_sec1_body', fallback: 'Ao criar uma conta ou utilizar a plataforma YPT através do Desky, você concorda expressamente com os presentes Termos de Uso e com nossa Política de Privacidade. Caso discorde de qualquer disposição, não utilize o serviço.')),
                    const SizedBox(height: 16),
                    _buildSectionTitle(t.tr('terms_sec2_title', fallback: '2. Regras da Comunidade e Grupos')),
                    _buildParagraph(t.tr('terms_sec2_body', fallback: 'É estritamente proibido publicar ou transmitir em mensagens de grupo, fotos de perfil ou transmissões de Live Study: conteúdo pornográfico, discurso de ódio, assédio, ameaças, publicidade não autorizada ou qualquer conteúdo ilícito. A violação resultará em banimento imediato sem aviso prévio.')),
                    const SizedBox(height: 16),
                    _buildSectionTitle(t.tr('terms_sec3_title', fallback: '3. Integridade do Registro de Estudo')),
                    _buildParagraph(t.tr('terms_sec3_body', fallback: 'O usuário compromete-se a registrar honestamente suas horas de estudo. O uso de scripts automatizados, bots ou qualquer artifício com o intuito de manipular rankings globais ou de grupos é proibido e passível de desclassificação e encerramento de conta.')),
                    const SizedBox(height: 16),
                    _buildSectionTitle(t.tr('terms_sec4_title', fallback: '4. Propriedade Intelectual e Avatares')),
                    _buildParagraph(t.tr('terms_sec4_body', fallback: 'Todos os direitos sobre avatares, marcas, interfaces e ilustrações são de titularidade de seus respectivos detentores. O Desky é um cliente de desktop independente de código aberto e não possui vínculo corporativo oficial com a Pallo Inc.')),
                    const SizedBox(height: 16),
                    _buildSectionTitle(t.tr('terms_sec5_title', fallback: '5. Modificações e Encerramento')),
                    _buildParagraph(t.tr('terms_sec5_body', fallback: 'A Pallo Inc. reserva-se o direito de atualizar estes termos periodicamente. O uso contínuo dos serviços após alterações constitui aceitação tácita dos novos termos.')),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.gavel_rounded, size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              t.tr('legal_disclaimer', fallback: 'O Desky é um cliente de terceiros independente e de código aberto, não sendo afiliado, endossado, patrocinado ou associado à Pallo Inc. ou ao Yeolpumta (YPT). Todas as marcas registradas pertencem aos seus respectivos proprietários.'),
                              style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.9), fontSize: 11, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t.tr('terms_last_update', fallback: 'Última atualização: 2026 • TGCLab / Pallo Inc.'),
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
                child: Text(t.tr('btn_agree_close', fallback: 'Concordar e Fechar'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
