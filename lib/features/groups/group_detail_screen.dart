import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/localization/app_translation.dart';
import '../../data/models/group_model.dart';
import '../../data/models/group_member_model.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/repositories/group_repository.dart';
import 'group_leader_panel.dart';
import 'widgets/cam_study_member_tile.dart';
import 'widgets/sticker_picker_panel.dart';
import 'widgets/group_studicon_picker_dialog.dart';
import '../../data/models/sticker_model.dart';
import '../../shared/widgets/studicon_avatar.dart';
import '../../core/cdn/cdn_resolver.dart';
import '../auth/auth_notifier.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository();
});

class GroupDetailScreen extends ConsumerStatefulWidget {
  final GroupModel group;

  const GroupDetailScreen({
    super.key,
    required this.group,
  });

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _refreshTimer;

  List<GroupMemberModel> _members = [];
  List<GroupMemberModel> _weeklyRanks = [];
  List<ChatMessageModel> _chatMessages = [];
  bool _isLoadingMembers = true;
  bool _showStickerPicker = false;
  String _selectedGroupRankPeriod = 'week';

  final _chatInputController = TextEditingController();

  Future<void> _sendSticker(Sticker sticker) async {
    setState(() => _showStickerPicker = false);
    final user = ref.read(authStateProvider).user;
    final t = ref.read(appTranslationProvider);
    final newMsg = ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      senderId: user?.id ?? 1,
      senderName: user?.name ?? t.tr('you', fallback: 'Você'),
      studiconId: user?.studiconId ?? -1,
      message: '',
      stickerUrl: sticker.url,
      type: 'sticker',
      sentAt: DateTime.now(),
    );

    setState(() {
      _chatMessages = [newMsg, ..._chatMessages];
    });

    try {
      final repo = ref.read(groupRepositoryProvider);
      await repo.sendMessage(groupId: widget.group.id, stickerUrl: sticker.url);
    } catch (_) {}
  }

  Future<void> _joinGroup() async {
    final t = ref.read(appTranslationProvider);
    final repo = ref.read(groupRepositoryProvider);
    final success = await repo.joinGroup(widget.group.id);
    if (success) {
      await ref.read(authStateProvider.notifier).refreshUserGroups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.tr('joined_group_success', fallback: 'Você entrou no grupo com sucesso!')),
            backgroundColor: AppColors.primary,
          ),
        );
        _loadGroupData();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.tr('joined_group_failed', fallback: 'Não foi possível entrar no grupo.')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _leaveGroup() async {
    final t = ref.read(appTranslationProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(t.tr('leave_group', fallback: 'Sair do Grupo'), style: const TextStyle(color: Colors.white)),
        content: Text(
          t.tr('leave_group_confirm', fallback: 'Tem certeza que deseja sair deste grupo?'),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.tr('cancel', fallback: 'Cancelar'), style: const TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(t.tr('leave', fallback: 'Sair'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repo = ref.read(groupRepositoryProvider);
      final success = await repo.leaveGroup(widget.group.id);
      if (success) {
        await ref.read(authStateProvider.notifier).refreshUserGroups();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.tr('left_group_success', fallback: 'Você saiu do grupo.'))),
          );
        }
      }
    }
  }

  Timer? _chatTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadGroupData();

    // Auto refresh active members every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadMembersSilently();
    });

    // Auto refresh live chat messages every 3 seconds
    _chatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadChatSilently();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _chatTimer?.cancel();
    _tabController.dispose();
    _chatInputController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupData() async {
    setState(() => _isLoadingMembers = true);
    await Future.wait([
      _loadMembersSilently(),
      _loadGroupRanksSilently(),
      _loadChatSilently(),
    ]);
    if (mounted) setState(() => _isLoadingMembers = false);
  }

  bool _isLoadingRanks = false;

  Future<void> _loadGroupRanksSilently() async {
    setState(() => _isLoadingRanks = true);
    try {
      final repo = ref.read(groupRepositoryProvider);
      final ranks = await repo.fetchGroupRanks(widget.group.id, period: _selectedGroupRankPeriod);
      if (mounted) {
        setState(() {
          _weeklyRanks = ranks;
          _isLoadingRanks = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRanks = false);
    }
  }

  Future<void> _loadMembersSilently() async {
    try {
      final repo = ref.read(groupRepositoryProvider);
      final list = await repo.fetchMembers(widget.group.id);
      if (mounted) {
        setState(() => _members = list);
      }
    } catch (_) {}
  }

  Future<void> _loadChatSilently() async {
    try {
      final repo = ref.read(groupRepositoryProvider);
      final messages = await repo.fetchChatMessages(widget.group.id);
      if (mounted) {
        setState(() => _chatMessages = messages);
      }
    } catch (_) {}
  }

  Future<void> _shakeUser(GroupMemberModel member) async {
    final t = ref.read(appTranslationProvider);
    try {
      final repo = ref.read(groupRepositoryProvider);
      await repo.shakeMember(groupId: widget.group.id, targetUserId: member.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.tr("shake_sent_to", fallback: "Chacoalhada enviada para")} ${member.name}! 🔔'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.tr("notification_sent_to", fallback: "Notificação enviada para")} ${member.name}!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authStateProvider).user;
    final t = ref.read(appTranslationProvider);
    _chatInputController.clear();
    final newMsg = ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      senderId: user?.id ?? 1,
      senderName: user?.name ?? t.tr('you', fallback: 'Você'),
      studiconId: user?.studiconId ?? -1,
      message: text,
      sentAt: DateTime.now(),
    );

    setState(() {
      _chatMessages = [newMsg, ..._chatMessages];
    });

    try {
      final repo = ref.read(groupRepositoryProvider);
      await repo.sendMessage(
        groupId: widget.group.id,
        nickname: user?.name ?? 'Usuário',
        userId: user?.id ?? 0,
        message: text,
      );
      _loadChatSilently();
    } catch (_) {}
  }

  Future<void> _toggleReaction(ChatMessageModel msg, String emoji) async {
    final user = ref.read(authStateProvider).user;
    final myId = user?.id ?? 1;

    final existingReactions = Map<String, List<int>>.from(msg.reactions);
    final usersForEmoji = List<int>.from(existingReactions[emoji] ?? []);

    if (usersForEmoji.contains(myId)) {
      usersForEmoji.remove(myId);
      if (usersForEmoji.isEmpty) {
        existingReactions.remove(emoji);
      } else {
        existingReactions[emoji] = usersForEmoji;
      }
    } else {
      usersForEmoji.add(myId);
      existingReactions[emoji] = usersForEmoji;
    }

    final updatedMsg = msg.copyWith(reactions: existingReactions);
    setState(() {
      _chatMessages = _chatMessages.map((m) => m.id == msg.id ? updatedMsg : m).toList();
    });

    try {
      final repo = ref.read(groupRepositoryProvider);
      await repo.sendReaction(
        groupId: widget.group.id,
        messageId: msg.id,
        emoji: emoji,
      );
    } catch (_) {}
  }

  void _showReactionPicker(ChatMessageModel msg) {
    const emojis = ['👍', '❤️', '🔥', '😂', '😮', '😢', '😡'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: emojis.map((emoji) {
              return InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _toggleReaction(msg, emoji);
                },
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _attachMedia() async {
    final t = ref.read(appTranslationProvider);
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(t.tr('attach_image_chat', fallback: 'Anexar Imagem ao Chat'), style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.tr('attach_image_desc', fallback: 'Insira a URL da imagem ou captura de estudo:'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: t.tr('image_url_hint', fallback: 'https://exemplo.com/estudo.jpg'),
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.tr('cancel', fallback: 'Cancelar'), style: const TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(t.tr('send_photo', fallback: 'Enviar Foto'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (url != null && url.isNotEmpty) {
      final user = ref.read(authStateProvider).user;
      final newMsg = ChatMessageModel(
        id: DateTime.now().millisecondsSinceEpoch,
        senderId: user?.id ?? 1,
        senderName: user?.name ?? t.tr('you', fallback: 'Você'),
        studiconId: user?.studiconId ?? -1,
        message: t.tr('photo', fallback: 'Foto'),
        imageUrl: url,
        type: 'image',
        sentAt: DateTime.now(),
      );

      setState(() {
        _chatMessages = [newMsg, ..._chatMessages];
      });

      try {
        final repo = ref.read(groupRepositoryProvider);
        await repo.sendMessage(
          groupId: widget.group.id,
          nickname: user?.name ?? 'Você',
          userId: user?.id ?? 0,
          imageUrl: url,
        );
      } catch (_) {}
    }
  }

  String _formatMs(int ms) {
    final mins = ms ~/ 60000;
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final studyingMembers = _members.where((m) => m.isStudying && !m.isPaused).toList();
    final activeUser = ref.watch(authStateProvider).user;
    final t = ref.watch(appTranslationProvider);
    final isLeader = activeUser != null &&
        (widget.group.leaderUserId == activeUser.id ||
            (widget.group.leaderName.isNotEmpty && widget.group.leaderName == activeUser.name));
    final isMember = activeUser != null && activeUser.userGroups.any((g) => g.id == widget.group.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.group.name, style: AppTextStyles.titleLarge),
            Text(
              '${studyingMembers.length} ${t.tr("studying_now", fallback: "estudando agora")} • ${t.tr("goal", fallback: "Meta")}: ${widget.group.dailyGoalHours}h/${t.tr("today", fallback: "dia")}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          if (isMember || isLeader)
            IconButton(
              icon: const Icon(Icons.face_retouching_natural_outlined, color: AppColors.primaryLight),
              tooltip: t.tr('group_avatar', fallback: 'Avatar do Grupo'),
              onPressed: () async {
                final myMember = _members.firstWhere(
                  (m) => m.userId == activeUser.id,
                  orElse: () => GroupMemberModel(
                    userId: activeUser.id,
                    name: activeUser.name,
                    studiconId: activeUser.studiconId,
                    isStudying: false,
                    studyMs: 0,
                    hasCustomAvatar: false,
                  ),
                );
                final updatedId = await GroupStudiconPickerDialog.show(
                  context,
                  groupId: widget.group.id,
                  groupName: widget.group.name,
                  currentStudiconId: myMember.studiconId,
                  currentNickname: activeUser.name,
                );
                if (updatedId != null) {
                  _loadMembersSilently();
                }
              },
            ),
          if (isLeader)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: AppColors.primary),
              tooltip: t.tr('leader_menu', fallback: 'Menu do Líder'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => GroupLeaderPanel(
                      group: widget.group,
                      members: _members,
                    ),
                  ),
                );
              },
            )
          else if (isMember)
            IconButton(
              icon: const Icon(Icons.exit_to_app, color: AppColors.error),
              tooltip: t.tr('leave_group', fallback: 'Sair do Grupo'),
              onPressed: _leaveGroup,
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.group_add, color: AppColors.primary),
              label: Text(t.tr('join', fallback: 'Entrar'), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              onPressed: _joinGroup,
            ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(text: t.tr('studying_now', fallback: 'Estudando Agora')),
            Tab(text: t.tr('group_chat', fallback: 'Chat do Grupo')),
            Tab(text: t.tr('weekly_ranking', fallback: 'Ranking Semanal')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Studying Now Live Grid
          _isLoadingMembers
              ? const Center(child: CircularProgressIndicator())
              : _buildMembersGridTab(t),

          // Tab 2: Group Chat
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  reverse: true,
                  itemCount: _chatMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _chatMessages[index];
                    final activeUser = ref.read(authStateProvider).user;
                    final isMe = (activeUser != null && msg.senderId == activeUser.id) ||
                        (activeUser != null && msg.senderName == activeUser.name) ||
                        (msg.senderName == t.tr('you', fallback: 'Você'));

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onSecondaryTap: () => _showReactionPicker(msg),
                            onLongPress: () => _showReactionPicker(msg),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.all(12),
                              constraints: const BoxConstraints(maxWidth: 400),
                              decoration: BoxDecoration(
                                color: isMe ? AppColors.primary : AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Text(
                                      msg.senderName,
                                      style: const TextStyle(
                                        color: AppColors.primaryLight,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (msg.stickerUrl != null)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Image.network(
                                        msg.stickerUrl!,
                                        height: 100,
                                        width: 100,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.extension, color: Colors.white70),
                                      ),
                                    )
                                  else if (msg.imageUrl != null)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          msg.imageUrl!,
                                          height: 180,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white70),
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                      msg.message,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          // Reactions pill row
                          if (msg.reactions.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Wrap(
                                spacing: 4,
                                children: msg.reactions.entries.map((entry) {
                                  final emoji = entry.key;
                                  final count = entry.value.length;
                                  final hasMine = activeUser != null && entry.value.contains(activeUser.id);
                                  return InkWell(
                                    onTap: () => _toggleReaction(msg, emoji),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: hasMine ? AppColors.primary.withValues(alpha: 0.3) : AppColors.card,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: hasMine ? AppColors.primary : AppColors.border,
                                        ),
                                      ),
                                      child: Text(
                                        '$emoji $count',
                                        style: const TextStyle(fontSize: 11, color: Colors.white),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (_showStickerPicker)
                StickerPickerPanel(
                  onStickerSelected: _sendSticker,
                ),
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.surface,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file_rounded, color: AppColors.textSecondary),
                      tooltip: t.tr('attach_image', fallback: 'Anexar Imagem'),
                      onPressed: _attachMedia,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.emoji_emotions_outlined,
                        color: _showStickerPicker ? AppColors.primary : AppColors.textSecondary,
                      ),
                      tooltip: t.tr('stickers', fallback: 'Figurinhas'),
                      onPressed: () {
                        setState(() => _showStickerPicker = !_showStickerPicker);
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _chatInputController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: t.tr('type_message', fallback: 'Digite sua mensagem...'),
                          hintStyle: const TextStyle(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.card,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: AppColors.primary),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Tab 3: Group Rankings
          (() {
            final displayList = _weeklyRanks.isNotEmpty
                ? _weeklyRanks
                : (_selectedGroupRankPeriod == 'day' ? _members : <GroupMemberModel>[]);
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  color: AppColors.surface,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text(t.tr('today', fallback: 'Hoje')),
                        selected: _selectedGroupRankPeriod == 'day',
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.card,
                        labelStyle: TextStyle(color: _selectedGroupRankPeriod == 'day' ? Colors.white : AppColors.textMuted),
                        onSelected: (_) {
                          setState(() => _selectedGroupRankPeriod = 'day');
                          _loadGroupRanksSilently();
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(t.tr('this_week', fallback: 'Esta Semana')),
                        selected: _selectedGroupRankPeriod == 'week',
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.card,
                        labelStyle: TextStyle(color: _selectedGroupRankPeriod == 'week' ? Colors.white : AppColors.textMuted),
                        onSelected: (_) {
                          setState(() => _selectedGroupRankPeriod = 'week');
                          _loadGroupRanksSilently();
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(t.tr('this_month', fallback: 'Este Mês')),
                        selected: _selectedGroupRankPeriod == 'month',
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.card,
                        labelStyle: TextStyle(color: _selectedGroupRankPeriod == 'month' ? Colors.white : AppColors.textMuted),
                        onSelected: (_) {
                          setState(() => _selectedGroupRankPeriod = 'month');
                          _loadGroupRanksSilently();
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoadingRanks
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : displayList.isEmpty
                          ? Center(
                              child: Text(
                                t.tr('no_records', fallback: 'Nenhum registro encontrado para este período.'),
                                style: const TextStyle(color: AppColors.textMuted),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(24),
                              itemCount: displayList.length,
                              itemBuilder: (context, index) {
                                final member = displayList[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: AppColors.card,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: index == 0
                                      ? const Color(0xFFFFD700)
                                      : index == 1
                                          ? const Color(0xFFC0C0C0)
                                          : index == 2
                                              ? const Color(0xFFCD7F32)
                                              : AppColors.surface,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: index < 3 ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.surface,
                                backgroundImage: NetworkImage(member.avatarUrl),
                              ),
                            ],
                          ),
                          title: Text(
                            member.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                          ),
                          trailing: Text(
                            _formatMs(member.studyMs),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  ),
                ),
              ],
            );
          })(),
        ],
      ),
    );
  }

  Widget _buildMembersGridTab(AppTranslation t) {
    final studyingMembers = _members.where((m) => m.isStudying && !m.isPaused).toList()
      ..sort((a, b) {
        final cmp = b.studyMs.compareTo(a.studyMs);
        if (cmp != 0) return cmp;
        return a.name.compareTo(b.name);
      });

    final restingMembers = _members.where((m) => !m.isStudying || m.isPaused).toList()
      ..sort((a, b) {
        final cmp = b.studyMs.compareTo(a.studyMs);
        if (cmp != 0) return cmp;
        return a.name.compareTo(b.name);
      });

    if (_members.isEmpty) {
      return Center(
        child: Text(
          t.tr('no_group_members', fallback: 'Nenhum membro no grupo ainda.'),
          style: const TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        if (studyingMembers.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${t.tr("studying_now", fallback: "Estudando Agora")} (${studyingMembers.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                childAspectRatio: 0.82,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildMemberCard(studyingMembers[index], t),
                childCount: studyingMembers.length,
              ),
            ),
          ),
        ],
        if (restingMembers.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${t.tr("resting_inactive", fallback: "Descansando / Inativos")} (${restingMembers.length})',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                childAspectRatio: 0.82,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildMemberCard(restingMembers[index], t),
                childCount: restingMembers.length,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMemberCard(GroupMemberModel member, AppTranslation t) {
    if (widget.group.isCamStudy) {
      return CamStudyMemberTile(
        member: member,
        onShake: () => _shakeUser(member),
      );
    }

    final isActivelyStudying = member.isStudying && !member.isPaused;
    final StudiconPose pose;
    if (isActivelyStudying) {
      pose = member.studyMs > 7200000 ? StudiconPose.ignite1 : StudiconPose.sweat1;
    } else if (member.isPaused) {
      pose = StudiconPose.smoke1;
    } else {
      pose = StudiconPose.normal1;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActivelyStudying
              ? AppColors.primary.withValues(alpha: 0.6)
              : AppColors.border,
          width: isActivelyStudying ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              member.hasCustomAvatar
                  ? CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.surface,
                      backgroundImage: NetworkImage(member.avatarUrl),
                    )
                  : StudiconAvatar(
                      studiconId: member.studiconId,
                      pose: pose,
                      size: 56,
                    ),
              if (isActivelyStudying)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.card, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            member.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isActivelyStudying
                ? '${t.tr("studying", fallback: "Estudando")} (${_formatMs(member.studyMs)})'
                : member.isPaused
                    ? '${t.tr("paused", fallback: "Pausado")} (${_formatMs(member.studyMs)})'
                    : '${t.tr("resting", fallback: "Descansando")} (${_formatMs(member.studyMs)})',
            style: TextStyle(
              fontSize: 12,
              color: isActivelyStudying
                  ? AppColors.primary
                  : member.isPaused
                      ? AppColors.warning
                      : AppColors.textMuted,
            ),
          ),
          if (!isActivelyStudying) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _shakeUser(member),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '🔔 ${t.tr("shake", fallback: "Shake")}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
