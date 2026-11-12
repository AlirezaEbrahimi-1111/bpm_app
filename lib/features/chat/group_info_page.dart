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
  const GroupInfoPage({super.key, required this.conversationId});

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false;

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
    if (!await _confirm('خروج از گروه', warn, 'خروج')) return;
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
          title: const Text('اطلاعات گروه'),
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
            : RefreshIndicator(onRefresh: _load, child: _content(c)),
      ),
    );
  }

  Widget _content(AppColors c) {
    final title = (_data!['group_title'] ?? '').toString();
    final canEditInfo = _myPerms.contains('avatar');
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

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            onTap: canEditInfo ? _changePhoto : null,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ChatAvatar(
                  name: title,
                  imageUrl: _data!['group_avatar_url']?.toString(),
                  colorSeed: _cid,
                  isGroup: true,
                  size: 96,
                ),
                if (canEditInfo)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: c.primary,
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: c.textStrong,
                ),
              ),
            ),
            if (canEditInfo)
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 18, color: c.textMuted),
                onPressed: _rename,
                tooltip: 'تغییر نام گروه',
              ),
          ],
        ),
        Center(
          child: Text(
            toPersianDigits(
              '${members.length} عضو${online > 0 ? '، $online نفر آنلاین' : ''}',
            ),
            style: TextStyle(color: c.textMuted),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              if (_myPerms.contains('add_member'))
                ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: c.primary.withValues(alpha: 0.12),
                    child: Icon(
                      Icons.person_add_alt_1_rounded,
                      color: c.primary,
                    ),
                  ),
                  title: Text(
                    'افزودن عضو',
                    style: TextStyle(
                      color: c.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: _addMembers,
                ),
              ...members.map((m) => _memberTile(c, m, me)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text(
              'خروج از گروه',
              style: TextStyle(color: Colors.red),
            ),
            onTap: _leave,
          ),
        ),
      ],
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
      onTap: isMe ? null : () => _openDirect(m),
      leading: ChatAvatar(
        name: (m['full_name'] ?? '').toString(),
        imageUrl: m['avatar_url']?.toString(),
        colorSeed: m['id'],
        online: online,
        size: 44,
      ),
      title: Row(
        children: [
          if (customPerms) ...[
            Icon(Icons.star_rounded, size: 15, color: c.primary),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              isMe
                  ? '${m['full_name']} (شما)'
                  : (m['full_name'] ?? '').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.textStrong),
            ),
          ),
        ],
      ),
      subtitle: Text(
        online ? 'آنلاین' : chatLastSeen(m['last_seen_at']?.toString()),
        style: TextStyle(fontSize: 12, color: online ? c.primary : c.textMuted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOwner || isAdmin)
            Text(
              isOwner ? 'سازنده' : 'مدیر',
              style: TextStyle(
                color: c.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (canAccess)
            IconButton(
              icon: Icon(Icons.settings_rounded, size: 20, color: c.textMuted),
              tooltip: 'اختیارات',
              onPressed: () => _editAccess(m),
            ),
          if (canRemove)
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
                color: Colors.red,
              ),
              tooltip: 'حذف از گروه',
              onPressed: () => _remove(m),
            ),
        ],
      ),
    );
  }
}
