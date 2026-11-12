import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_number.dart';
import '../../core/utils/task_search.dart';
import '../../core/widgets/app_snack.dart';
import 'chat_api.dart';
import 'chat_conversation_page.dart';
import 'chat_widgets.dart';
import 'chat_media_tabs.dart';
import 'member_picker_page.dart';

/// اطلاعاتِ گروه — هم‌قاعده با کشوی «اطلاعات گروه» در وب (pages/chat.php):
/// - نام و عکس: با اختیارِ «تغییر اطلاعات گروه» (کلید avatar)
/// - افزودنِ عضو: اختیارِ add_member
/// - حذفِ عضو: اختیارِ remove_member؛ حذفِ یک مدیر فقط با سازنده
/// - اختیاراتِ اعضا و ارتقا به مدیر: فقط سازنده (سرور هم همین را چک می‌کند)
/// - خروج از گروه: همه
/// خروجی (Navigator.pop): 'left' اگر کاربر از گروه خارج شد.
class GroupInfoPage extends StatefulWidget {
  final int conversationId;

  /// وضعیتِ بی‌صدا از گفتگو (group-members.php آن را برنمی‌گرداند)
  final bool isMuted;
  const GroupInfoPage({
    super.key,
    required this.conversationId,
    this.isMuted = false,
  });

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false;
  late bool _muted = widget.isMuted;

  int get _cid => widget.conversationId;
  List<String> get _myPerms =>
      ((_data?['my_permissions'] as List?) ?? []).map((e) => '$e').toList();
  bool get _isOwner => _data?['is_owner'] == true;
  bool get _canManage => _data?['can_manage'] == true;
  List<Map<String, dynamic>> get _members =>
      ((_data?['members'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ChatApi.groupMembers(_cid);
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _run(Future<void> Function() job, {String? ok}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
      if (ok != null) AppSnack.success('انجام شد', ok);
      await _load();
    } catch (e) {
      AppSnack.error('خطا', e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── نام و عکس ──
  Future<void> _rename() async {
    final ctrl = TextEditingController(
      text: (_data?['group_title'] ?? '').toString(),
    );
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('نام گروه'),
          content: TextField(controller: ctrl, autofocus: true, maxLength: 100),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
    final t = title?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    if (t.isEmpty) return;
    _run(() => ChatApi.renameGroup(_cid, t), ok: 'نام گروه عوض شد');
  }

  Future<void> _changePhoto() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final f = r?.files.firstOrNull;
    if (f?.bytes == null) return;
    _run(
      () async =>
          ChatApi.uploadGroupAvatar(_cid, ChatUpload(f!.name, f.bytes!)),
      ok: 'عکس گروه عوض شد',
    );
  }

  // ── اعضا ──
  Future<void> _addMembers() async {
    final picked = await Navigator.of(context).push<List<Map<String, dynamic>>>(
      MaterialPageRoute(
        builder: (_) => MemberPickerPage(
          title: 'افزودن عضو',
          confirmLabel: 'افزودن',
          excludeIds: _members.map((m) => (m['id'] as num).toInt()).toSet(),
        ),
      ),
    );
    if (picked == null || picked.isEmpty) return;
    _run(
      () => ChatApi.addMembers(
        _cid,
        picked.map((u) => (u['id'] as num).toInt()).toList(),
      ),
      ok: toPersianDigits('${picked.length} عضو اضافه شد'),
    );
  }

  Future<void> _remove(Map<String, dynamic> m) async {
    final ok = await _confirm(
      'حذف عضو',
      '«${m['full_name']}» از گروه حذف شود؟',
      'حذف',
    );
    if (ok)
      _run(
        () => ChatApi.removeMember(_cid, (m['id'] as num).toInt()),
        ok: 'عضو حذف شد',
      );
  }

  Future<void> _leave() async {
    final warn = _isOwner
        ? 'شما سازندهٔ این گروه هستید. اگر خارج شوید، گروه بدون سازنده می‌ماند و دیگر کسی نمی‌تواند اختیارات اعضا را تغییر دهد. ادامه می‌دهید؟'
        : 'از این گروه خارج می‌شوید و دیگر پیام‌های آن را نمی‌بینید. ادامه می‌دهید؟';
    if (!await _confirm('ترک گروه', warn, 'ترک گروه')) return;
    setState(() => _busy = true);
    try {
      await ChatApi.leaveGroup(_cid);
      if (mounted) Navigator.pop(context, 'left');
    } catch (e) {
      AppSnack.error('خطا', e.toString());
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDirect(Map<String, dynamic> m) async {
    try {
      final id = await ChatApi.start((m['id'] as num).toInt());
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatConversationPage(
            conversationId: id,
            initial: {
              'conversation_id': id,
              'type': 'direct',
              'title': m['full_name'],
              'avatar_url': m['avatar_url'],
              'other_user_id': m['id'],
              'other_user_is_online': m['is_online'],
              'other_user_last_seen_at': m['last_seen_at'],
            },
          ),
        ),
      );
    } catch (e) {
      AppSnack.error('خطا', e.toString());
    }
  }

  /// اختیاراتِ یک عضو — فقط سازنده (مثلِ مودالِ وب)
  Future<void> _editAccess(Map<String, dynamic> m) async {
    final c = AppColors.of(context);
    if (!_isOwner) {
      AppSnack.info(
        'اختیارات',
        'فقط سازندهٔ گروه می‌تواند اختیارات اعضا را تغییر دهد',
      );
      return;
    }
    final all =
        ((_data?['all_permissions'] as List?) ??
                ChatApi.groupPermissionLabels.keys.toList())
            .map((e) => '$e')
            .toList();
    final granted = ((m['permissions'] as List?) ?? [])
        .map((e) => '$e')
        .toSet();
    var admin = m['is_admin'] == true;
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'اختیارات ${m['full_name']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: c.textStrong,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...all.map(
                    (k) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(ChatApi.groupPermissionLabels[k] ?? k),
                      value: granted.contains(k),
                      onChanged: (v) =>
                          setS(() => v ? granted.add(k) : granted.remove(k)),
                    ),
                  ),
                  const Divider(),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'ارتقا به مدیر',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    value: admin,
                    onChanged: (v) => setS(() => admin = v ?? false),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('ذخیره'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (save != true) return;
    _run(
      () => ChatApi.setMemberAccess(
        _cid,
        (m['id'] as num).toInt(),
        admin: admin,
        permissions: granted.toList(),
      ),
      ok: 'اختیارات ذخیره شد',
    );
  }

  Future<bool> _confirm(String title, String body, String yes) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(yes),
            ),
          ],
        ),
      ),
    );
    return r == true;
  }

  // ───────────── نما — به سبکِ صفحه‌ی اطلاعاتِ گروهِ تلگرام ─────────────

  Future<void> _toggleMute() async {
    try {
      final m = await ChatApi.toggleMute(_cid);
      if (mounted) setState(() => _muted = m);
    } catch (e) {
      AppSnack.error('خطا', e.toString());
    }
  }

  /// ✏️ نوارِ بالا: تغییرِ نام و عکس (اختیارِ «تغییر اطلاعات گروه»)
  void _editInfoSheet() {
    final c = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('تغییر نام گروه'),
                onTap: () {
                  Navigator.pop(ctx);
                  _rename();
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_a_photo_outlined),
                title: const Text('تغییر عکس گروه'),
                onTap: () {
                  Navigator.pop(ctx);
                  _changePhoto();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// لمسِ طولانی روی یک عضو (مثلِ تلگرام): پیام، اختیارات، حذف از گروه
  void _memberOptions(
    Map<String, dynamic> m, {
    required bool canAccess,
    required bool canRemove,
  }) {
    final c = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  (m['full_name'] ?? '').toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: c.textStrong,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded),
                title: const Text('ارسال پیام'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openDirect(m);
                },
              ),
              if (canAccess)
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('اختیارات'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _editAccess(m);
                  },
                ),
              if (canRemove)
                ListTile(
                  leading: const Icon(
                    Icons.person_remove_outlined,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'حذف از گروه',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _remove(m);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final canEditInfo = _myPerms.contains('avatar');
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: c.bgPage,
        appBar: AppBar(
          backgroundColor: c.bgPage,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          actions: [
            if (_data != null && canEditInfo)
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                tooltip: 'ویرایش گروه',
                onPressed: _editInfoSheet,
              ),
            if (_data != null)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'گزینه‌های بیشتر',
                onSelected: (v) {
                  if (v == 'add') _addMembers();
                  if (v == 'leave') _leave();
                },
                itemBuilder: (_) => [
                  if (_myPerms.contains('add_member'))
                    const PopupMenuItem(
                      value: 'add',
                      child: Row(
                        children: [
                          Icon(Icons.person_add_alt_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('افزودن عضو'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'leave',
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('ترک گروه', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
          bottom: _busy
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : null,
        ),
        body: _data == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: TextStyle(color: c.textMuted)),
                          TextButton(
                            onPressed: _load,
                            child: const Text('تلاش دوباره'),
                          ),
                        ],
                      ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: _content(c, canEditInfo),
              ),
      ),
    );
  }

  Widget _content(AppColors c, bool canEditInfo) {
    final title = (_data!['group_title'] ?? '').toString();
    final members = _members
      ..sort((a, b) {
        // سازنده، بعد مدیرها، بعد آنلاین‌ها، بعد الفبا
        int rank(Map m) =>
            m['is_owner'] == true ? 0 : (m['is_admin'] == true ? 1 : 2);
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        final o = (b['is_online'] == true ? 1 : 0).compareTo(
          a['is_online'] == true ? 1 : 0,
        );
        if (o != 0) return o;
        return compareFaText(
          '${a['full_name'] ?? ''}',
          '${b['full_name'] ?? ''}',
        );
      });
    final online = members.where((m) => m['is_online'] == true).length;
    final me = ApiClient.currentUserId;
    final rows = <Widget>[
      if (_myPerms.contains('add_member'))
        ListTile(
          leading: SizedBox(
            width: 46,
            child: Icon(
              Icons.person_add_alt_outlined,
              size: 26,
              color: c.textStrong,
            ),
          ),
          title: Text(
            'افزودن عضو',
            style: TextStyle(fontSize: 16, color: c.textStrong),
          ),
          onTap: _addMembers,
        ),
      ...members.map((m) => _memberTile(c, m, me)),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      children: [
        // ── عکس، نام، تعداد اعضا ──
        Center(
          child: GestureDetector(
            onTap: canEditInfo ? _changePhoto : null,
            child: ChatAvatar(
              name: title,
              imageUrl: _data!['group_avatar_url']?.toString(),
              colorSeed: _cid,
              isGroup: true,
              size: 112,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: c.textStrong,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          toPersianDigits(
            '${members.length} عضو${online > 0 ? '، $online نفر آنلاین' : ''}',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14.5, color: c.textMuted),
        ),
        const SizedBox(height: 22),

        // ── سه دکمه: پیام، بی‌صدا، ترک ──
        Row(
          children: [
            _actionButton(
              c,
              Icons.chat_bubble_outline_rounded,
              'پیام',
              () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            _actionButton(
              c,
              _muted
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_none_rounded,
              _muted ? 'باصدا' : 'بی‌صدا',
              _toggleMute,
            ),
            const SizedBox(width: 8),
            _actionButton(c, Icons.logout_rounded, 'ترک', _leave),
          ],
        ),
        const SizedBox(height: 22),

        // ── کارتِ اعضا ──
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 72, color: c.borderSoft),
                rows[i],
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        // ── رسانه / فایل / لینک (مرحله‌ی ۳) ──
        ChatMediaTabs(conversationId: _cid),
      ],
    );
  }

  Widget _actionButton(
    AppColors c,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(icon, size: 26, color: c.textStrong),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textStrong,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _memberTile(AppColors c, Map<String, dynamic> m, int? me) {
    final isMe = me != null && (m['id'] as num).toInt() == me;
    final isOwner = m['is_owner'] == true;
    final isAdmin = m['is_admin'] == true;
    final customPerms =
        !isOwner && ((m['permissions'] as List?) ?? []).isNotEmpty;
    final canAccess =
        !isMe && !isOwner && (_isOwner || (_canManage && !isAdmin));
    final canRemove =
        !isMe &&
        !isOwner &&
        _myPerms.contains('remove_member') &&
        (!isAdmin || _isOwner);
    final online = m['is_online'] == true;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: isMe ? null : () => _openDirect(m),
      onLongPress: isMe
          ? null
          : () => _memberOptions(m, canAccess: canAccess, canRemove: canRemove),
      leading: ChatAvatar(
        name: (m['full_name'] ?? '').toString(),
        imageUrl: m['avatar_url']?.toString(),
        colorSeed: m['id'],
        size: 46,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              isMe
                  ? '${m['full_name']} (شما)'
                  : (m['full_name'] ?? '').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.textStrong,
              ),
            ),
          ),
          if (customPerms) ...[
            const SizedBox(width: 4),
            Icon(Icons.star_rounded, size: 15, color: c.primary),
          ],
        ],
      ),
      subtitle: Text(
        online ? 'آنلاین' : chatLastSeen(m['last_seen_at']?.toString()),
        style: TextStyle(
          fontSize: 13.5,
          color: online ? const Color(0xFF2A8FD4) : c.textMuted,
        ),
      ),
      trailing: (isOwner || isAdmin)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isOwner ? 'سازنده' : 'مدیر',
                style: TextStyle(
                  color: c.primary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }
}
