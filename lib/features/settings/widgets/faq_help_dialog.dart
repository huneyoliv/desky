import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/localization/app_translation.dart';

class FaqHelpDialog extends ConsumerWidget {
  const FaqHelpDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const FaqHelpDialog(),
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
        width: 680,
        constraints: const BoxConstraints(maxHeight: 720),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.tr('faq_title', fallback: 'Ajuda & FAQ'),
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
              child: ListView(
                children: [
                  _buildFaqTile(
                    icon: Icons.timer,
                    question: t.tr('faq_q1_title', fallback: 'Como funciona o Cronômetro e o modo Pomodoro?'),
                    answer: t.tr('faq_q1_desc', fallback: 'Selecione uma matéria na lista e clique em "Iniciar". No modo Contagem Livre (Stopwatch), o tempo corre continuamente. No modo Pomodoro, você estuda em blocos com intervalos programados (ex.: 25 min de foco, 5 min de descanso).'),
                  ),
                  _buildFaqTile(
                    icon: Icons.groups_rounded,
                    question: t.tr('faq_q2_title', fallback: 'Como funcionam os Grupos de Estudo e o Live Study?'),
                    answer: t.tr('faq_q2_desc', fallback: 'Você pode entrar em até 10 grupos de estudo simultâneos. No Live Study, fotos da sua webcam são capturadas periodicamente para compartilhar seu foco com o grupo.'),
                  ),
                  _buildFaqTile(
                    icon: Icons.fullscreen_rounded,
                    question: t.tr('faq_q3_title', fallback: 'Como usar a Tela Cheia, Mini Player e o Leitor de PDF?'),
                    answer: t.tr('faq_q3_desc', fallback: 'Na tela do cronômetro, use os botões no topo para alternar para modo Tela Cheia (Focus) ou Mini-Player compacto flutuante. Acesse a aba Flashcards para abrir o leitor de apostilas e PDFs.'),
                  ),
                  _buildFaqTile(
                    icon: Icons.sync,
                    question: t.tr('faq_q4_title', fallback: 'O que acontece quando estou sem internet (Offline)?'),
                    answer: t.tr('faq_q4_desc', fallback: 'O Desky continua gravando seu tempo normalmente em modo offline. Assim que a conexão for restabelecida, a fila de sincronização enviará suas sessões pendentes aos servidores automaticamente.'),
                  ),
                  _buildFaqTile(
                    icon: Icons.support_agent,
                    question: t.tr('faq_q5_title', fallback: 'Precisa de suporte ou encontrou algum problema?'),
                    answer: t.tr('faq_q5_desc', fallback: 'Nossa equipe de suporte está à disposição. Entre em contato diretamente pelo e-mail oficial: contact@yeolpumta.com informando seu Nickname e ID de usuário.'),
                  ),
                ],
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
                child: Text(t.tr('close_btn', fallback: 'Fechar'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqTile({required IconData icon, required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: Icon(icon, color: AppColors.primary, size: 22),
          title: Text(
            question,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.textMuted,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              answer,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
