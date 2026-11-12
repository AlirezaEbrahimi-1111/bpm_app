import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_snack.dart';
import 'chat_api.dart';
import 'chat_conversation_page.dart';
import 'chat_widgets.dart';
import 'group_create_page.dart';
import 'member_picker_page.dart';

/// شروعِ گفتگوی یک‌به‌یک — جستجوی مخاطبانِ هم‌سازمان (api/chat/search-users.php)
/// و باز کردن/ساختنِ گفتگو (api/chat/start.php). برمی‌گرداند true اگر گفتگو باز شد.
class NewChatPage extends StatefulWidget {
  const NewChatPage({super.key});

  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _users = [];
  bool _loading = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _search(''); // فهرستِ کاملِ مخاطبان از همان اول (مثلِ تلگرام)
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _search(v.trim()),
    );
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final list = await ChatApi.searchUsers(q);
      if (mounted && _ctrl.text.trim() == q) setState(() => _users = list);
    } catch (e) {
      AppSnack.error('خطا', e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _start(Map<String, dynamic> u) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final id = await ChatApi.start((u['id'] as num).toInt());
      if (!mounted) return;
      // همین صفحه با گفتگو جایگزین شود؛ true یعنی فهرستِ گفتگوها تازه شود
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatConversationPage(
            conversationId: id,
            initial: {
              'conversation_id': id,
              'type': 'direct',
              'title': u['full_name'],
              'avatar_url': u['avatar_url'],
              'other_user_id': u['id'],
              'other_user_is_online': u['is_online'],
              'other_user_last_seen_at': u['last_seen_at'],
            },
          ),
        ),
        result: true,
      );
    } catch (e) {
      AppSnack.error('خطا', e.toString());
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _newGroup() async {
    final picked = await Navigator.of(context).push<List<Map<String, dynamic>>>(
      MaterialPageRoute(
        builder: (_) =>
            const MemberPickerPage(title: 'افزودن اعضا', confirmLabel: 'بعدی'),
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GroupCreatePage(members: picked)),
      result: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: c.bgPage,
        appBar: AppBar(
          backgroundColor: c.bgPage,
          elevation: 0,
          title: const Text('گفتگوی جدید'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _ctrl,
                autofocus: false,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'جستجوی مخاطب…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: c.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            // گروهِ جدید (مرحله‌ی ۲): انتخابِ اعضا → نام و عکس
            ListTile(
              leading: CircleAvatar(
                radius: 23,
                backgroundColor: c.primary.withValues(alpha: 0.12),
                child: Icon(Icons.group_add_rounded, color: c.primary),
              ),
              title: Text(
                'گروه جدید',
                style: TextStyle(color: c.primary, fontWeight: FontWeight.w600),
              ),
              onTap: _newGroup,
            ),
            Divider(height: 1, color: c.borderSoft),
            if (_loading || _starting)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _users.isEmpty
                  ? Center(
                      child: Text(
                        _loading
                            ? ''
                            : (_ctrl.text.trim().isEmpty
                                  ? 'مخاطبی وجود ندارد'
                                  : 'مخاطبی پیدا نشد'),
                        style: TextStyle(color: c.textMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (_, i) {
                        final u = _users[i];
                        final online = u['is_online'] == true;
                        final section = (u['section_label'] ?? '').toString();
                        return ListTile(
                          onTap: () => _start(u),
                          leading: ChatAvatar(
                            name: (u['full_name'] ?? '').toString(),
                            imageUrl: u['avatar_url']?.toString(),
                            colorSeed: u['id'],
                            online: online,
                            size: 46,
                          ),
                          title: Text(
                            (u['full_name'] ?? '').toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: c.textStrong,
                            ),
                          ),
                          subtitle: Text(
                            online
                                ? 'آنلاین'
                                : (section.isEmpty ? ' ' : section),
                            style: TextStyle(
                              color: online ? c.primary : c.textMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
