import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/sru_branding.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/app_user.dart';
import '../../models/models.dart';
import 'mentee_profile_dialog.dart';

/// Real-Time Mentorship Group Chat.
/// Each Senior Mentor and all of their assigned Junior Mentees share one dedicated Group Chat room
/// keyed by the Mentor's UID (`chats/{mentorId}/messages/{messageId}`).
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _searchCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String _memberQuery = '';
  bool _sending = false;
  bool _mobileShowMembers = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendGroupMessage({
    required AppUser currentUser,
    required String mentorId,
    required String mentorName,
    required String mentorCode,
    required String senderCode,
    required String? batchId,
    required String? batchName,
    String? presetText,
  }) async {
    final text = (presetText ?? _msgCtrl.text).trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    if (presetText == null) {
      _msgCtrl.clear();
    }

    final isMentor = currentUser.role == UserRole.mentor;
    final db = ref.read(firestoreProvider);
    final groupRef = db.doc('chats/$mentorId');
    final msgRef = groupRef.collection('messages').doc();
    final now = Timestamp.now();

    try {
      await groupRef.set({
        'id': mentorId,
        'mentorId': mentorId,
        'mentorName': mentorName,
        'mentorCode': mentorCode,
        'batchId': batchId,
        'batchName': batchName,
        'lastMessage': text,
        'lastSenderId': currentUser.uid,
        'lastSenderName': currentUser.name,
        'lastSenderCode': senderCode,
        'lastSenderRole': isMentor ? 'MENTOR' : 'STUDENT',
        'lastMessageAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      await msgRef.set({
        'id': msgRef.id,
        'chatId': mentorId,
        'mentorId': mentorId,
        'studentId': isMentor ? '' : currentUser.uid,
        'senderId': currentUser.uid,
        'senderName': currentUser.name,
        'senderCode': senderCode,
        'senderRole': isMentor ? 'MENTOR' : 'STUDENT',
        'text': text,
        'isRead': true,
        'createdAt': now,
      });

      _scrollToBottom();
    } catch (e) {
      if (presetText == null && _msgCtrl.text.isEmpty) {
        _msgCtrl.text = text;
      }
      if (mounted) {
        showSnack(context, 'Failed to send message: ${friendlyError(e)}', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(e),
      data: (user) {
        if (user == null) {
          return const EmptyState(title: 'Not signed in', message: 'Please sign in to access group chat.');
        }

        if (user.role == UserRole.mentor) {
          final mentorProfile = ref.watch(myMentorProfileProvider).valueOrNull;
          final mentorId = user.uid;
          final mentorName = mentorProfile?.name ?? user.name;
          final mentorCode = mentorProfile?.mentorCode ?? user.rollNo ?? 'MENTOR';
          final batchId = mentorProfile?.batchId ?? user.batchId;
          final batchName = mentorProfile?.batchName ?? batchId ?? 'Batch';

          return _buildGroupChatScaffold(
            context: context,
            currentUser: user,
            mentorId: mentorId,
            mentorName: mentorName,
            mentorCode: mentorCode,
            senderCode: mentorCode,
            batchId: batchId,
            batchName: batchName,
            mentorProfile: mentorProfile,
          );
        }

        if (user.role == UserRole.student) {
          final studentAsync = ref.watch(myStudentProfileProvider);
          final mentorProfile = ref.watch(studentAssignedMentorProvider).valueOrNull;

          return studentAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(myStudentProfileProvider)),
            data: (student) {
              final mentorId = student?.mentorId ?? user.seniorUid;
              if (student == null || mentorId == null || mentorId.isEmpty) {
                return const PageBody(
                  title: 'Mentorship Group Chat',
                  subtitle: 'Collaborate with your Senior Mentor and fellow group mentees',
                  child: AppCard(
                    child: EmptyState(
                      icon: Icons.groups_outlined,
                      title: 'No Mentorship Group Assigned Yet',
                      message: 'Once an administrator assigns you to a Senior Mentor, your mentorship group chat will appear here.',
                    ),
                  ),
                );
              }

              final mentorName = mentorProfile?.name ?? student.mentorName ?? 'Senior Mentor';
              final mentorCode = mentorProfile?.mentorCode ?? student.mentorCode ?? 'MENTOR';
              final batchName = student.batchName ?? student.batchId;

              return _buildGroupChatScaffold(
                context: context,
                currentUser: user,
                mentorId: mentorId,
                mentorName: mentorName,
                mentorCode: mentorCode,
                senderCode: student.studentCode,
                batchId: student.batchId,
                batchName: batchName,
                mentorProfile: mentorProfile,
              );
            },
          );
        }

        return const PageBody(
          title: 'Mentorship Group Chat',
          subtitle: 'Group chat rooms for Senior Mentors and their assigned Junior Mentees.',
          child: AppCard(
            child: EmptyState(
              icon: Icons.groups_rounded,
              title: 'Mentor & Mentee Group Channel',
              message: 'Sign in as a Senior Mentor or Junior Mentee to participate in your Mentorship Group Chat.',
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupChatScaffold({
    required BuildContext context,
    required AppUser currentUser,
    required String mentorId,
    required String mentorName,
    required String mentorCode,
    required String senderCode,
    required String? batchId,
    required String batchName,
    required MentorProfile? mentorProfile,
  }) {
    final groupStudentsAsync = ref.watch(groupStudentsProvider(mentorId));
    final groupStudents = groupStudentsAsync.valueOrNull ?? const <StudentProfile>[];

    return PageBody(
      title: 'Mentorship Group Chat',
      subtitle: '$mentorName ($mentorCode) • Batch $batchName • ${groupStudents.length + 1} Group Members (1 Mentor, ${groupStudents.length} Mentees)',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 820;

          final membersSidebar = _buildGroupMembersSidebar(
            context: context,
            currentUser: currentUser,
            mentorId: mentorId,
            mentorName: mentorName,
            mentorCode: mentorCode,
            batchName: batchName,
            mentorProfile: mentorProfile,
            students: groupStudents,
            showBackToChat: !isWide,
            onBackToChat: () => setState(() => _mobileShowMembers = false),
          );

          final chatWindow = _buildGroupChatWindow(
            context: context,
            currentUser: currentUser,
            mentorId: mentorId,
            mentorName: mentorName,
            mentorCode: mentorCode,
            senderCode: senderCode,
            batchId: batchId,
            batchName: batchName,
            memberCount: groupStudents.length + 1,
            showMembersToggle: !isWide,
            onToggleMembers: () => setState(() => _mobileShowMembers = true),
          );

          if (isWide) {
            return SizedBox(
              height: 680,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 330, child: membersSidebar),
                  const SizedBox(width: 16),
                  Expanded(child: chatWindow),
                ],
              ),
            );
          }

          return SizedBox(
            height: 660,
            child: _mobileShowMembers ? membersSidebar : chatWindow,
          );
        },
      ),
    );
  }

  // ─────────────────────────── GROUP MEMBERS SIDEBAR ───────────────────────────

  Widget _buildGroupMembersSidebar({
    required BuildContext context,
    required AppUser currentUser,
    required String mentorId,
    required String mentorName,
    required String mentorCode,
    required String batchName,
    required MentorProfile? mentorProfile,
    required List<StudentProfile> students,
    required bool showBackToChat,
    required VoidCallback onBackToChat,
  }) {
    final isMentor = currentUser.role == UserRole.mentor;
    final filteredStudents = students.where((s) {
      if (_memberQuery.isEmpty) return true;
      final q = _memberQuery.toLowerCase();
      return s.name.toLowerCase().contains(q) ||
          s.studentCode.toLowerCase().contains(q) ||
          (s.branch ?? '').toLowerCase().contains(q);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SruColors.blueBorder, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Sidebar Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
              border: Border(bottom: BorderSide(color: SruColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (showBackToChat) ...[
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        onPressed: onBackToChat,
                        tooltip: 'Back to Group Chat',
                      ),
                      const SizedBox(width: 4),
                    ],
                    const Icon(Icons.groups_rounded, color: SruColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Group Members (${students.length + 1})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: SruColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        batchName,
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _memberQuery = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Filter members by name or roll...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: _memberQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _memberQuery = '');
                            },
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),

          // Pinned Senior Mentor Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: SruColors.surfaceBlue.withOpacity(0.55),
              border: const Border(bottom: BorderSide(color: SruColors.border)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: SruColors.primary,
                  foregroundColor: Colors.white,
                  child: Text(
                    mentorName.isNotEmpty ? mentorName[0].toUpperCase() : 'M',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              mentorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: SruColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: SruColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'MENTOR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$mentorCode • Group Lead',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: SruColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Mentees List
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Text(
              'ASSIGNED MENTEES (${filteredStudents.length})',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: SruColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: filteredStudents.isEmpty
                ? const EmptyState(
                    icon: Icons.person_search_rounded,
                    title: 'No matching mentees',
                    message: 'Try clearing the search filter.',
                  )
                : ListView.separated(
                    itemCount: filteredStudents.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final s = filteredStudents[index];
                      final isMe = s.uid == currentUser.uid;

                      return ListTile(
                        dense: true,
                        onTap: isMentor
                            ? () => showMenteeProfileDialog(
                                  context,
                                  student: s,
                                  mentor: mentorProfile,
                                  batchName: batchName,
                                )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        leading: CircleAvatar(
                          radius: 17,
                          backgroundColor: isMe ? const Color(0xFF059669) : const Color(0xFFDBEAFE),
                          foregroundColor: isMe ? Colors.white : SruColors.primary,
                          child: Text(
                            s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: isMe ? FontWeight.w900 : FontWeight.w700,
                                  fontSize: 13,
                                  color: SruColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isMe)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'YOU',
                                  style: TextStyle(
                                    color: Color(0xFF15803D),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${s.studentCode} • ${s.branch ?? "CSE"} • 🔥 ${s.potdCount}',
                          style: const TextStyle(fontSize: 11, color: SruColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                        trailing: isMentor
                            ? const Tooltip(
                                message: 'Inspect Mentee Profile',
                                child: Icon(Icons.analytics_outlined, size: 16, color: SruColors.primary),
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── GROUP CHAT WINDOW ───────────────────────────

  Widget _buildGroupChatWindow({
    required BuildContext context,
    required AppUser currentUser,
    required String mentorId,
    required String mentorName,
    required String mentorCode,
    required String senderCode,
    required String? batchId,
    required String batchName,
    required int memberCount,
    required bool showMembersToggle,
    required VoidCallback onToggleMembers,
  }) {
    final messagesAsync = ref.watch(chatMessagesProvider(mentorId));
    final isMentor = currentUser.role == UserRole.mentor;

    final quickPrompts = isMentor
        ? const [
            'Good morning team! Please solve today\'s Problem of the Day (POTD) 🔥',
            'Reminder: Please submit your assigned coding problems before the deadline.',
            'Drop any doubts or complexity questions here and let\'s discuss!',
          ]
        : const [
            'Hi everyone! I just solved today\'s POTD 🔥',
            'Hello Ma\'am/Sir, I have a doubt regarding the optimal time complexity for today\'s task.',
            'I have submitted my task solution for review!',
          ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SruColors.blueBorder, width: 1.4),
      ),
      child: Column(
        children: [
          // ── Group Chat Window Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: SruColors.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: Colors.white,
                  foregroundColor: SruColors.primary,
                  child: const Icon(Icons.groups_rounded, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '$mentorName\'s Mentorship Group',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              mentorCode,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              batchName,
                              style: const TextStyle(
                                color: Color(0xFF92400E),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$memberCount Members (1 Senior Mentor + ${memberCount - 1} Junior Mentees) • Live Group Room',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.88),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (showMembersToggle)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.45)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.people_alt_outlined, size: 15, color: Colors.white),
                    label: Text('Members ($memberCount)', style: const TextStyle(fontSize: 11.5)),
                    onPressed: onToggleMembers,
                  ),
              ],
            ),
          ),

          // ── Group Messages Stream Area ──
          Expanded(
            child: Container(
              color: const Color(0xFFF8FAFC),
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(chatMessagesProvider(mentorId))),
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: const BoxDecoration(
                                color: SruColors.surfaceBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.forum_rounded, size: 34, color: SruColors.primary),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Welcome to $mentorName\'s Mentorship Group!',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: SruColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Every message sent here is visible in real time to your Senior Mentor and all mentees in this group.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12.5, color: SruColors.textSecondary),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: quickPrompts
                                  .map(
                                    (prompt) => ActionChip(
                                      backgroundColor: Colors.white,
                                      side: const BorderSide(color: SruColors.blueBorder),
                                      avatar: const Icon(Icons.bolt_rounded, size: 16, color: SruColors.primary),
                                      label: Text(
                                        prompt,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      onPressed: _sending
                                          ? null
                                          : () => _sendGroupMessage(
                                                currentUser: currentUser,
                                                mentorId: mentorId,
                                                mentorName: mentorName,
                                                mentorCode: mentorCode,
                                                senderCode: senderCode,
                                                batchId: batchId,
                                                batchName: batchName,
                                                presetText: prompt,
                                              ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollCtrl.hasClients && _scrollCtrl.position.maxScrollExtent > 0) {
                      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                    }
                  });

                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      final isMe = m.senderId == currentUser.uid;
                      final prev = i > 0 ? messages[i - 1] : null;
                      final showDateHeader = _shouldShowDateSeparator(prev?.createdAt, m.createdAt);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDateHeader && m.createdAt != null)
                            _buildDateSeparator(m.createdAt!),
                          _GroupMessageBubble(
                            message: m,
                            isMe: isMe,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // ── Group Message Composer Input Bar ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(17)),
              border: Border(top: BorderSide(color: SruColors.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed) {
                        _sendGroupMessage(
                          currentUser: currentUser,
                          mentorId: mentorId,
                          mentorName: mentorName,
                          mentorCode: mentorCode,
                          senderCode: senderCode,
                          batchId: batchId,
                          batchName: batchName,
                        );
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _msgCtrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendGroupMessage(
                        currentUser: currentUser,
                        mentorId: mentorId,
                        mentorName: mentorName,
                        mentorCode: mentorCode,
                        senderCode: senderCode,
                        batchId: batchId,
                        batchName: batchName,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Message $mentorName\'s Mentorship Group... (Press Enter to send)',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: SruColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: SruColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: SruColors.primary, width: 1.6),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: SruColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _sending
                        ? null
                        : () => _sendGroupMessage(
                              currentUser: currentUser,
                              mentorId: mentorId,
                              mentorName: mentorName,
                              mentorCode: mentorCode,
                              senderCode: senderCode,
                              batchId: batchId,
                              batchName: batchName,
                            ),
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(_sending ? 'Sending' : 'Send'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowDateSeparator(DateTime? previous, DateTime? current) {
    if (current == null) return false;
    if (previous == null) return true;
    return previous.year != current.year ||
        previous.month != current.month ||
        previous.day != current.day;
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(msgDay).inDays;

    final String label;
    if (diff == 0) {
      label = 'Today';
    } else if (diff == 1) {
      label = 'Yesterday';
    } else {
      label = DateFormat('dd MMM yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _GroupMessageBubble({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final isSenderMentor = message.senderRole == 'MENTOR';
    final timeLabel = message.createdAt != null
        ? DateFormat('hh:mm a').format(message.createdAt!)
        : 'Just now';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: isSenderMentor ? SruColors.primary : const Color(0xFFDBEAFE),
              foregroundColor: isSenderMentor ? Colors.white : SruColors.primary,
              child: Text(
                message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 540),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? SruColors.primary
                    : (isSenderMentor ? const Color(0xFFEFF6FF) : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: isMe
                    ? null
                    : Border.all(
                        color: isSenderMentor ? SruColors.blueBorder : SruColors.border,
                        width: isSenderMentor ? 1.4 : 1.0,
                      ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Sender Identity Header inside bubble
                  Wrap(
                    spacing: 6,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        isMe ? 'You (${message.senderName})' : message.senderName,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: isMe
                              ? Colors.white.withOpacity(0.92)
                              : (isSenderMentor ? SruColors.primary : const Color(0xFF334155)),
                        ),
                      ),
                      if (message.senderCode.isNotEmpty)
                        Text(
                          '• ${message.senderCode}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isMe ? Colors.white70 : SruColors.textSecondary,
                          ),
                        ),
                      if (isSenderMentor)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFFFEF3C7) : SruColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'MENTOR',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: isMe ? const Color(0xFF92400E) : Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  SelectableText(
                    message.text,
                    style: TextStyle(
                      color: isMe ? Colors.white : SruColors.textPrimary,
                      fontSize: 13.5,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeLabel,
                        style: TextStyle(
                          color: isMe ? Colors.white.withOpacity(0.75) : SruColors.textSecondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.done_all_rounded,
                          size: 14,
                          color: Color(0xFF93C5FD),
                        ),
                      ],
                    ],
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
