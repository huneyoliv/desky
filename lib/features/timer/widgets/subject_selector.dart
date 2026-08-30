import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_translation.dart';
import '../../../core/utils/color_utils.dart';
import '../../../data/models/subject_model.dart';
import '../../../shared/widgets/subject_chip.dart';
import '../../../core/theme/app_colors.dart';

class SubjectSelector extends ConsumerWidget {
  final List<SubjectModel> subjects;
  final SubjectModel? selectedSubject;
  final ValueChanged<SubjectModel> onSelectSubject;
  final Function(String title, int colorInt) onCreateSubject;
  final ValueChanged<SubjectModel>? onUpdateSubject;
  final ValueChanged<int>? onArchiveSubject;
  final ValueChanged<int>? onDeleteSubject;

  const SubjectSelector({
    super.key,
    required this.subjects,
    required this.selectedSubject,
    required this.onSelectSubject,
    required this.onCreateSubject,
    this.onUpdateSubject,
    this.onArchiveSubject,
    this.onDeleteSubject,
  });

  void _showAddSubjectDialog(BuildContext context, WidgetRef ref, {SubjectModel? editSubject}) {
    final t = ref.read(appTranslationProvider);
    final titleController = TextEditingController(text: editSubject?.title ?? '');
    int selectedColorInt = editSubject?.colorInt ?? ColorUtils.defaultSubjectColors.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isEditing = editSubject != null;
          return AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              isEditing ? t.tr('edit_subject', fallback: 'Editar Matéria') : t.tr('new_subject', fallback: 'Nova Matéria'),
              style: const TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: t.tr('subject_title', fallback: 'Nome da matéria (ex: Matemática)'),
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.tr('color', fallback: 'Cor'),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: ColorUtils.defaultSubjectColors.map((colorInt) {
                          final color = ColorUtils.fromArgbInt(colorInt);
                          final isSelected = colorInt == selectedColorInt;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedColorInt = colorInt;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  width: isSelected ? 2.5 : 0,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),       actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t.tr('cancel', fallback: 'Cancelar'), style: const TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                onPressed: () {
                  final text = titleController.text.trim();
                  if (text.isNotEmpty) {
                    if (isEditing && onUpdateSubject != null) {
                      onUpdateSubject!(
                        editSubject.copyWith(
                          title: text,
                          colorInt: selectedColorInt,
                        ),
                      );
                    } else {
                      onCreateSubject(text, selectedColorInt);
                    }
                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: Text(
                  isEditing ? t.tr('save', fallback: 'Salvar') : t.tr('create', fallback: 'Criar'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSubjectOptionsMenu(BuildContext context, WidgetRef ref, SubjectModel subject) {
    final t = ref.read(appTranslationProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: Text(t.tr('edit_subject', fallback: 'Editar Matéria'), style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                _showAddSubjectDialog(context, ref, editSubject: subject);
              },
            ),
            if (onArchiveSubject != null)
              ListTile(
                leading: const Icon(Icons.archive, color: AppColors.warning),
                title: Text(t.tr('archive', fallback: 'Arquivar Matéria'), style: const TextStyle(color: AppColors.warning)),
                onTap: () {
                  Navigator.of(context).pop();
                  onArchiveSubject!(subject.id);
                },
              ),
            if (onDeleteSubject != null)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: AppColors.error),
                title: Text(t.tr('delete_subject', fallback: 'Excluir Matéria'), style: const TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.of(context).pop();
                  _showDeleteConfirmDialog(context, ref, subject);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref, SubjectModel subject) {
    if (onDeleteSubject == null) return;
    final t = ref.read(appTranslationProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('${t.tr("delete", fallback: "Excluir")} "${subject.title}"?', style: const TextStyle(color: Colors.white)),
        content: Text(
          t.tr('delete_confirm_desc', fallback: 'Tem certeza que deseja excluir esta matéria do servidor?'),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.tr('cancel', fallback: 'Cancelar'), style: const TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              onDeleteSubject!(subject.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(t.tr('delete', fallback: 'Excluir'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showManageSubjectsModal(BuildContext context, WidgetRef ref) {
    final t = ref.read(appTranslationProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(t.tr('manage_subjects', fallback: 'Gerenciar Matérias'), style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (subjects.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    t.tr('no_active_subjects', fallback: 'Nenhuma matéria cadastrada'),
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: subjects.length,
                    separatorBuilder: (_, __) => const Divider(color: AppColors.border),
                    itemBuilder: (context, index) {
                      final s = subjects[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: s.color,
                          radius: 8,
                        ),
                        title: Text(
                          s.title,
                          style: TextStyle(
                            color: s.isArchived ? AppColors.textMuted : Colors.white,
                            decoration: s.isArchived ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text(
                          s.isArchived ? t.tr('archived', fallback: 'Arquivada') : t.tr('active', fallback: 'Ativa'),
                          style: TextStyle(
                            color: s.isArchived ? AppColors.warning : AppColors.success,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
                              tooltip: t.tr('edit', fallback: 'Editar'),
                              onPressed: () {
                                Navigator.of(context).pop();
                                _showAddSubjectDialog(context, ref, editSubject: s);
                              },
                            ),
                            if (onArchiveSubject != null)
                              IconButton(
                                icon: Icon(
                                  s.isArchived ? Icons.unarchive : Icons.archive,
                                  color: AppColors.warning,
                                  size: 18,
                                  ),
                                tooltip: s.isArchived ? t.tr('unarchive', fallback: 'Desarquivar') : t.tr('archive', fallback: 'Arquivar'),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  onArchiveSubject!(s.id);
                                },
                              ),
                            if (onDeleteSubject != null)
                              IconButton(
                                icon: const Icon(Icons.delete_forever, color: AppColors.error, size: 18),
                                tooltip: t.tr('delete', fallback: 'Excluir'),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _showDeleteConfirmDialog(context, ref, s);
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.tr('close', fallback: 'Fechar'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final activeSubjects = subjects.where((s) => !s.isArchived).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ...activeSubjects.map((subject) {
            final isSelected = selectedSubject?.id == subject.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onLongPress: () => _showSubjectOptionsMenu(context, ref, subject),
                child: SubjectChip(
                  subject: subject,
                  isSelected: isSelected,
                  onTap: () => onSelectSubject(subject),
                ),
              ),
            );
          }),

          // Add Subject Button
          IconButton(
            onPressed: () => _showAddSubjectDialog(context, ref),
            tooltip: t.tr('new_subject', fallback: 'Adicionar Matéria'),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),

          // Manage Subjects Button
          IconButton(
            onPressed: () => _showManageSubjectsModal(context, ref),
            tooltip: t.tr('manage_subjects', fallback: 'Gerenciar Matérias'),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.tune_outlined, color: AppColors.primary, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
