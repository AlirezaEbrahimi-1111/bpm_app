import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_number.dart';
import '../../core/widgets/app_snack.dart';
import 'chat_api.dart';
import 'chat_widgets.dart';
import 'forward_picker_page.dart';
import 'group_info_page.dart';

/// صفحه‌ی یک گفتگو — به سبکِ تلگرام.
///
/// مرحله‌ی ۱: پیام‌ها (بارگذاریِ قدیمی‌ترها با اسکرول، دریافتِ تازه‌ها هر ۳ ثانیه)،
/// ارسالِ متن و فایل، پاسخ (کشیدنِ حباب یا منوی لمسِ طولانی)، ویرایش، حذف (برای من /
/// برای همه)، کپی، رسیدِ خواندن (✓ / ✓✓)، جداکننده‌ی تاریخ، نمایشِ عکس و دانلودِ فایل.
class ChatConversationPage extends StatefulWidget {
  final int conversationId;

  /// ردیفِ همین گفتگو از فهرست (اگر از فهرست باز شده) — بدونِ آن (مثلاً از اعلان)
  /// خودش از سرور گرفته می‌شود
  final Map<String, dynamic>? initial;

  const ChatConversationPage({
    super.key,
    required this.conversationId,
    this.initial,
  });

  /// گفتگویی که همین الان باز است (برای اینکه شِل/اعلان دوباره بازش نکند)
  static int? openConversationId;

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _Pending {
  final int tempId;
  final String text;
  final Map<String, dynamic>? replyTo;
  final List<ChatUpload> files;
  _Pending(this.tempId, this.text, this.replyTo, this.files);
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  Map<String, dynamic> _conv = {};
  final List<Map<String, dynamic>> _messages = []; // صعودی بر اساس id
  final List<_Pending> _pending = [];
  Map<int, int> _receipts = {};
  bool _loading = true;
  bool _loadingOlder = false;
  bool _hasMore = false;
  String? _error;
  String _todayJ = '', _yesterdayJ = '';

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  Map<String, dynamic>? _replyTo;
  Map<String, dynamic>? _editing;
  final List<ChatUpload> _files = [];
  bool _sending = false;

  Timer? _pollTimer, _receiptTimer, _pingTimer, _infoTimer;

  // جستجو در گفتگو (منوی سه‌نقطه)
  bool _searching = false;
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _searchResults = [];
  bool _searchLoading = false;
  int? _highlightId;
  final Map<int, GlobalKey> _keys = {};

  // مرحله‌ی ۳: سنجاق، «در حال نوشتن»، منشن
  Map<String, dynamic>? _pinned;
  bool _canPin = false;
  bool _otherTyping = false;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _extrasTimer;
  List<Map<String, dynamic>> _groupMembers = [];
  List<Map<String, dynamic>> _mentionOptions = [];
  Map<String, String> _headers = {};

  int get _cid => widget.conversationId;
  bool get _isGroup => (_conv['type'] ?? 'direct') != 'direct';
  int get _lastId =>
      _messages.isEmpty ? 0 : (_messages.last['id'] as num).toInt();

  @override
  void initState() {
    super.initState();
    ChatConversationPage.openConversationId = _cid;
    _conv = Map<String, dynamic>.from(widget.initial ?? {});
    _scroll.addListener(_onScroll);
    _input.addListener(_onInputChanged);
    ChatApi.authHeaders().then(
      (h) => mounted ? setState(() => _headers = h) : null,
    );
    _loadInfo();
    _loadInitial();
    ChatApi.ping();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
    _receiptTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _loadReceipts(),
    );
    _pingTimer = Timer.periodic(
      const Duration(seconds: 50),
      (_) => ChatApi.ping(),
    );
    _infoTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _loadInfo(),
    );
    // سنجاق + واکنش‌ها + «در حال نوشتن» — هم‌گام با بقیه (وب هم polling دارد)
    _loadPinned();
    _extrasTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _pollExtras(),
    );
    if ((widget.initial?['type'] ?? 'direct') != 'direct') _loadGroupMembers();
  }

  // ───────────── مرحله‌ی ۳: سنجاق، واکنش، تایپ، منشن ─────────────

  int _extrasTick = 0;
  Future<void> _pollExtras() async {
    if (!mounted) return;
    final typing = await ChatApi.typingStatus(_cid);
    if (mounted && typing != _otherTyping)
      setState(() => _otherTyping = typing);
    _extrasTick++;
    if (_extrasTick % 2 == 0) _syncReactions();
    if (_extrasTick % 5 == 0) _loadPinned();
  }

  Future<void> _loadPinned() async {
    final d = await ChatApi.pinnedMessage(_cid);
    if (!mounted || d.isEmpty) return;
    setState(() {
      _pinned = d['pinned'] is Map
          ? Map<String, dynamic>.from(d['pinned'])
          : null;
      // گفتگوی مستقیم: هر دو طرف؛ گروه: سازنده/مدیرِ دارای اختیارِ pin (سرور تعیین می‌کند)
      _canPin = !_isGroup || d['can_manage'] == true;
    });
  }

  Future<void> _syncReactions() async {
    final map = await ChatApi.reactions(_cid);
    if (!mounted) return;
    var changed = false;
    for (final m in _messages) {
      final next = map[(m['id'] as num).toInt()] ?? const [];
      final prev = (m['reactions'] as List?) ?? const [];
      if (prev.length != next.length || prev.toString() != next.toString()) {
        m['reactions'] = next;
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  Future<void> _react(Map<String, dynamic> m, String emoji) async {
    try {
      final r = await ChatApi.react((m['id'] as num).toInt(), emoji);
      if (mounted) setState(() => m['reactions'] = r);
    } catch (e) {
      AppSnack.error('خطا', e.toString());
    }
  }

  Future<void> _pinMessage(Map<String, dynamic> m) async {
    try {
      await ChatApi.pin(_cid, (m['id'] as num).toInt());
      await _loadPinned();
    } catch (e) {
      AppSnack.error('خطا', e.toString());
    }
  }

  Future<void> _unpin() async {
    try {
      await ChatApi.unpin(_cid);
      if (mounted) setState(() => _pinned = null);
    } catch (e) {
      AppSnack.error('خطا', e.toString());
    }
  }

  Future<void> _forward(Map<String, dynamic> m) async {
    final targets = await Navigator.of(context)
        .push<List<Map<String, dynamic>>>(
          MaterialPageRoute(builder: (_) => const ForwardPickerPage()),
        );
    if (targets == null || targets.isEmpty) return;
    var ok = 0;
    for (final t in targets) {
      try {
        await ChatApi.forward(
          (m['id'] as num).toInt(),
          (t['conversation_id'] as num).toInt(),
        );
        ok++;
      } catch (_) {}
    }
    if (ok == targets.length) {
      AppSnack.success(
        'هدایت شد',
        toPersianDigits('پیام به $ok گفتگو فرستاده شد'),
      );
    } else {
      AppSnack.error(
        'هدایت',
        toPersianDigits('$ok از ${targets.length} گفتگو موفق بود'),
      );
    }
    if (targets.any((t) => (t['conversation_id'] as num).toInt() == _cid))
      _poll();
  }

  Future<void> _loadGroupMembers() async {
    try {
      final d = await ChatApi.groupMembers(_cid);
      if (mounted) {
        _groupMembers = ((d['members'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {}
  }

  /// تایپ: بجِ «در حال نوشتن» برای طرف مقابل (حداکثر هر ۳ ثانیه یک بار) + پیشنهادِ منشن
  void _onInputChanged() {
    setState(() {});
    final text = _input.text;
    if (text.trim().isNotEmpty &&
        _editing == null &&
        DateTime.now().difference(_lastTypingSent).inSeconds >= 3) {
      _lastTypingSent = DateTime.now();
      ChatApi.typing(_cid);
    }
    _updateMentionOptions();
  }

  /// منشن در گروه: کلمه‌ی جاری با @ شروع شود → فهرستِ اعضا (مثلِ وب)
  void _updateMentionOptions() {
    if (!_isGroup || _groupMembers.isEmpty) {
      if (_mentionOptions.isNotEmpty) setState(() => _mentionOptions = []);
      return;
    }
    final sel = _input.selection;
    final cursor = sel.isValid ? sel.baseOffset : _input.text.length;
    final before = _input.text.substring(
      0,
      cursor.clamp(0, _input.text.length),
    );
    final at = before.lastIndexOf('@');
    if (at < 0 || (at > 0 && !RegExp(r'\s').hasMatch(before[at - 1]))) {
      if (_mentionOptions.isNotEmpty) setState(() => _mentionOptions = []);
      return;
    }
    final q = before.substring(at + 1);
    if (q.contains('\n') || q.length > 30) {
      if (_mentionOptions.isNotEmpty) setState(() => _mentionOptions = []);
      return;
    }
    final me = ApiClient.currentUserId;
    final opts = _groupMembers
        .where((m) => (m['id'] as num).toInt() != me)
        .where((m) => (m['full_name'] ?? '').toString().contains(q.trim()))
        .take(6)
        .toList();
    setState(() => _mentionOptions = opts);
  }

  void _applyMention(Map<String, dynamic> m) {
    final text = _input.text;
    final sel = _input.selection;
    final cursor = sel.isValid ? sel.baseOffset : text.length;
    final at = text.substring(0, cursor).lastIndexOf('@');
    if (at < 0) return;
    final insert = '@${m['full_name']} ';
    final next = text.replaceRange(at, cursor, insert);
    _input.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: at + insert.length),
    );
    setState(() => _mentionOptions = []);
  }

  /// متنِ پیام با منشن‌های رنگی (@نامِ عضو) — مثلِ highlightMentions وب
  Widget _messageText(ChatColors cc, String text) {
    final style = TextStyle(fontSize: 15, height: 1.45, color: cc.text);
    if (!_isGroup || _groupMembers.isEmpty || !text.contains('@')) {
      return Text(text, style: style);
    }
    final names =
        _groupMembers
            .map((m) => '@${m['full_name']}')
            .where((n) => n.length > 1)
            .toList()
          ..sort((a, b) => b.length.compareTo(a.length));
    final spans = <TextSpan>[];
    var i = 0;
    while (i < text.length) {
      String? hit;
      for (final n in names) {
        if (text.startsWith(n, i)) {
          hit = n;
          break;
        }
      }
      if (hit != null) {
        spans.add(
          TextSpan(
            text: hit,
            style: TextStyle(color: cc.link, fontWeight: FontWeight.w600),
          ),
        );
        i += hit.length;
      } else {
        final next = text.indexOf('@', i + 1);
        final end = next < 0 ? text.length : next;
        spans.add(TextSpan(text: text.substring(i, end)));
        i = end;
      }
    }
    return Text.rich(TextSpan(children: spans), style: style);
  }

  @override
  void dispose() {
    if (ChatConversationPage.openConversationId == _cid)
      ChatConversationPage.openConversationId = null;
    for (final t in [
      _pollTimer,
      _receiptTimer,
      _pingTimer,
      _infoTimer,
      _extrasTimer,
    ]) {
      t?.cancel();
    }
    _input.dispose();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    ChatApi.refreshUnread();
    super.dispose();
  }

  // ───────────────────────── داده ─────────────────────────

  Future<void> _loadInfo() async {
    try {
      final list = await ChatApi.conversations();
      final me = list.firstWhereOrNull(
        (c) => (c['conversation_id'] as num).toInt() == _cid,
      );
      if (me != null && mounted) {
        setState(() => _conv = me);
        if (_isGroup && _groupMembers.isEmpty) _loadGroupMembers();
      }
    } catch (_) {}
  }

  void _absorbDates(Map<String, dynamic> data) {
    _todayJ = (data['today_jalali'] ?? _todayJ).toString();
    _yesterdayJ = (data['yesterday_jalali'] ?? _yesterdayJ).toString();
  }

  Future<void> _loadInitial() async {
    try {
      final data = await ChatApi.messages(_cid, limit: 40);
      _absorbDates(data);
      final list =
          (data['messages'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
            ..sort((a, b) => (a['id'] as num).compareTo(b['id'] as num));
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
        _hasMore = data['has_more'] == true;
        _loading = false;
      });
      if (_lastId > 0) ChatApi.markRead(_cid, upToId: _lastId);
      _loadReceipts();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _poll() async {
    if (_loading || !mounted) return;
    try {
      // after_id: سرور همین پیام‌های تازه را «خوانده‌شده» هم ثبت می‌کند
      final data = await ChatApi.messages(_cid, afterId: _lastId, limit: 100);
      _absorbDates(data);
      final list = (data['messages'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (list.isEmpty || !mounted) return;
      final known = _messages.map((m) => m['id']).toSet();
      setState(() {
        _messages.addAll(list.where((m) => !known.contains(m['id'])));
        _messages.sort((a, b) => (a['id'] as num).compareTo(b['id'] as num));
      });
    } catch (_) {}
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore || _messages.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final data = await ChatApi.messages(
        _cid,
        beforeId: (_messages.first['id'] as num).toInt(),
        limit: 40,
      );
      final list = (data['messages'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        final known = _messages.map((m) => m['id']).toSet();
        _messages.insertAll(0, list.where((m) => !known.contains(m['id'])));
        _messages.sort((a, b) => (a['id'] as num).compareTo(b['id'] as num));
        _hasMore = data['has_more'] == true;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _loadReceipts() async {
    final r = await ChatApi.readReceipts(_cid);
    if (mounted && r.isNotEmpty) setState(() => _receipts = r);
  }

  void _onScroll() {
    // لیست برعکس است: بالای صفحه = انتهای اسکرول
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400)
      _loadOlder();
  }

  // ───────────────────────── اقدام‌ها ─────────────────────────

  Future<void> _pickFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: ChatUpload.allowedExtensions,
      );
      if (res == null) return;
      final tooBig = res.files.where((f) => f.size > 20 * 1024 * 1024).length;
      setState(() {
        _files.addAll(
          res.files
              .where((f) => f.bytes != null && f.size <= 20 * 1024 * 1024)
              .map((f) => ChatUpload(f.name, f.bytes!)),
        );
      });
      if (tooBig > 0)
        AppSnack.error('فایل بزرگ', 'حجم هر فایل حداکثر ۲۰ مگابایت است');
    } catch (_) {
      AppSnack.error('خطا', 'انتخاب فایل ناموفق بود');
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (_editing != null) return _saveEdit(text);
    if (text.isEmpty && _files.isEmpty) return;
    final p = _Pending(
      DateTime.now().microsecondsSinceEpoch,
      text,
      _replyTo,
      List.of(_files),
    );
    setState(() {
      _pending.add(p);
      _input.clear();
      _files.clear();
      _replyTo = null;
    });
    _jumpToBottom();
    try {
      await ChatApi.send(
        _cid,
        text,
        replyToId: p.replyTo == null ? null : (p.replyTo!['id'] as num).toInt(),
        files: p.files,
      );
      await _poll();
    } catch (e) {
      AppSnack.error('ارسال نشد', e.toString());
      // متن برنگردد گم شود
      if (mounted && _input.text.isEmpty) _input.text = text;
    } finally {
      if (mounted) setState(() => _pending.remove(p));
    }
  }

  Future<void> _saveEdit(String text) async {
    final m = _editing!;
    if (text.isEmpty) return;
    if (text == (m['message'] ?? '').toString()) {
      setState(() => _editing = null);
      _input.clear();
      return;
    }
    setState(() => _sending = true);
    try {
      await ChatApi.edit((m['id'] as num).toInt(), text);
      setState(() {
        m['message'] = text;
        m['is_edited'] = true;
        _editing = null;
        _input.clear();
      });
    } catch (e) {
      AppSnack.error('خطا', e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startReply(Map<String, dynamic> m) {
    HapticFeedback.selectionClick();
    setState(() {
      _editing = null;
      _replyTo = m;
    });
    _focus.requestFocus();
  }

  void _startEdit(Map<String, dynamic> m) {
    setState(() {
      _replyTo = null;
      _files.clear();
      _editing = m;
      _input.text = (m['message'] ?? '').toString();
    });
    _focus.requestFocus();
  }

  Future<void> _delete(
    Map<String, dynamic> m, {
    required bool forEveryone,
  }) async {
    try {
      await ChatApi.delete((m['id'] as num).toInt(), forEveryone: forEveryone);
      setState(() => _messages.removeWhere((x) => x['id'] == m['id']));
    } catch (e) {
      AppSnack.error('خطا', e.toString());
    }
  }

  void _jumpToBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _openFile(Map a) => openChatAttachment(a);

  void _showActions(Map<String, dynamic> m) {
    final own = m['is_own'] == true;
    final text = (m['message'] ?? '').toString();
    final c = AppColors.of(context);
    HapticFeedback.mediumImpact();
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
              // ردیفِ واکنشِ سریع (مثلِ تلگرام/وب)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ChatApi.quickReactions.map((e) {
                    final mine = ((m['reactions'] as List?) ?? []).any(
                      (r) => r['emoji'] == e && r['reacted_by_me'] == true,
                    );
                    return InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        Navigator.pop(ctx);
                        _react(m, e);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: mine
                              ? c.primary.withValues(alpha: 0.15)
                              : null,
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 26)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1),
              _action(ctx, Icons.reply_rounded, 'پاسخ', () => _startReply(m)),
              _action(ctx, Icons.shortcut_rounded, 'هدایت', () => _forward(m)),
              if (_canPin)
                (_pinned != null && _pinned!['id'] == m['id'])
                    ? _action(
                        ctx,
                        Icons.push_pin_outlined,
                        'برداشتن سنجاق',
                        _unpin,
                      )
                    : _action(
                        ctx,
                        Icons.push_pin_rounded,
                        'سنجاق',
                        () => _pinMessage(m),
                      ),
              if (text.isNotEmpty)
                _action(ctx, Icons.copy_rounded, 'کپی متن', () {
                  Clipboard.setData(ClipboardData(text: text));
                  AppSnack.success('کپی شد', 'متن پیام کپی شد');
                }),
              if (own && text.isNotEmpty)
                _action(ctx, Icons.edit_rounded, 'ویرایش', () => _startEdit(m)),
              _action(
                ctx,
                Icons.delete_outline_rounded,
                'حذف برای من',
                () => _delete(m, forEveryone: false),
                danger: true,
              ),
              if (own || _conv['is_owner'] == true)
                _action(
                  ctx,
                  Icons.delete_forever_rounded,
                  'حذف برای همه',
                  () => _confirmDeleteAll(m),
                  danger: true,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(
    BuildContext ctx,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    final color = danger ? Colors.red : null;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
    );
  }

  Future<void> _confirmDeleteAll(Map<String, dynamic> m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف برای همه'),
          content: const Text(
            'این پیام برای همهٔ اعضای گفتگو حذف می‌شود. ادامه می‌دهید؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) _delete(m, forEveryone: true);
  }

  // ───────────────────────── نما ─────────────────────────

  String _subtitle() {
    if (_isGroup) {
      if (_otherTyping) return 'کسی در حال نوشتن است…';
      return toPersianDigits('${_conv['member_count'] ?? ''} عضو');
    }
    if (_otherTyping || _conv['other_user_is_typing'] == true)
      return 'در حال نوشتن…';
    if (_conv['other_user_is_online'] == true) return 'آنلاین';
    return chatLastSeen(_conv['other_user_last_seen_at']?.toString());
  }

  // ───────────── منوی سه‌نقطه ─────────────

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    bool danger = false,
  }) {
    final color = danger ? Colors.red : null;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Future<void> _onMenu(String v) async {
    switch (v) {
      case 'search':
        setState(() {
          _searching = true;
          _searchResults = [];
          _searchCtrl.clear();
        });
      case 'mute':
        try {
          final muted = await ChatApi.toggleMute(_cid);
          if (!mounted) return;
          setState(() => _conv['is_muted'] = muted);
          AppSnack.success(
            muted ? 'بی‌صدا شد' : 'باصدا شد',
            muted
                ? 'برای پیام‌های این گفتگو اعلان نمی‌آید'
                : 'اعلان پیام‌های این گفتگو دوباره فعال شد',
          );
        } catch (e) {
          AppSnack.error('خطا', e.toString());
        }
      case 'leave':
        await _leaveGroup();
    }
  }

  Future<void> _leaveGroup() async {
    final owner = _conv['is_owner'] == true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('ترک گروه'),
          content: Text(
            owner
                ? 'شما سازندهٔ این گروه هستید. اگر خارج شوید، گروه بدون سازنده می‌ماند و دیگر کسی نمی‌تواند اختیارات اعضا را تغییر دهد. ادامه می‌دهید؟'
                : 'از این گروه خارج می‌شوید و دیگر پیام‌های آن را نمی‌بینید. ادامه می‌دهید؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('ترک گروه'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ChatApi.leaveGroup(_cid);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      AppSnack.error('خطا', e.toString());
    }
  }

  // ───────────── جستجو در گفتگو ─────────────

  void _closeSearch() {
    _searchDebounce?.cancel();
    setState(() {
      _searching = false;
      _searchResults = [];
      _searchCtrl.clear();
    });
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    setState(() {});
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final q = v.trim();
      if (q.length < 2) {
        if (mounted) setState(() => _searchResults = []);
        return;
      }
      setState(() => _searchLoading = true);
      try {
        final r = await ChatApi.searchMessages(_cid, q);
        if (mounted && _searchCtrl.text.trim() == q)
          setState(() => _searchResults = r);
      } catch (_) {
      } finally {
        if (mounted) setState(() => _searchLoading = false);
      }
    });
  }

  Widget _searchResultsView(AppColors c) {
    return Container(
      color: c.surface,
      child: _searchLoading && _searchResults.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _searchResults.isEmpty
          ? Center(
              child: Text(
                _searchCtrl.text.trim().length < 2
                    ? 'دست‌کم دو حرف بنویسید'
                    : 'پیامی پیدا نشد',
                style: TextStyle(color: c.textMuted),
              ),
            )
          : ListView.separated(
              itemCount: _searchResults.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, indent: 16, color: c.borderSoft),
              itemBuilder: (_, i) {
                final r = _searchResults[i];
                return ListTile(
                  title: Text(
                    r['is_own'] == true
                        ? 'شما'
                        : (r['sender_name'] ?? '').toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: c.textStrong,
                    ),
                  ),
                  subtitle: Text(
                    (r['snippet'] ?? '').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    '${r['date_jalali'] ?? ''}\n${r['time_jalali'] ?? ''}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: c.textMuted),
                  ),
                  onTap: () {
                    final id = (r['message_id'] as num).toInt();
                    _closeSearch();
                    _jumpTo(id);
                  },
                );
              },
            ),
    );
  }

  /// پرش به یک پیام: اگر بارگذاری نشده، پیام‌های اطرافش گرفته می‌شود؛ بعد اسکرول و هاله‌ی کوتاه
  Future<void> _jumpTo(int id) async {
    if (!_messages.any((m) => (m['id'] as num).toInt() == id)) {
      try {
        final data = await ChatApi.messagesAround(_cid, id);
        final list =
            (data['messages'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
              ..sort((a, b) => (a['id'] as num).compareTo(b['id'] as num));
        if (!mounted) return;
        setState(() {
          _messages
            ..clear()
            ..addAll(list);
          _hasMore =
              true; // قدیمی‌ترها با اسکرول؛ تازه‌ترها با polling (after_id) پر می‌شوند
        });
      } catch (e) {
        AppSnack.error('خطا', e.toString());
        return;
      }
    }
    setState(() => _highlightId = id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[id]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _highlightId == id) setState(() => _highlightId = null);
    });
  }

  /// لمسِ نوارِ بالا در گروه → اطلاعات گروه (مرحله‌ی ۲)
  Future<void> _openInfo() async {
    if (!_isGroup) return;
    final r = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => GroupInfoPage(
          conversationId: _cid,
          isMuted: _conv['is_muted'] == true,
        ),
      ),
    );
    if (!mounted) return;
    if (r == 'left') {
      Navigator.of(context).pop();
      return;
    }
    _loadInfo();
    _poll();
  }

  String _dayLabel(String j) {
    if (j == _todayJ) return 'امروز';
    if (j == _yesterdayJ) return 'دیروز';
    return j;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final cc = ChatColors.of(context);
    final title = (_conv['title'] ?? '').toString();
    final sub = _subtitle();
    final live = sub == 'آنلاین' || sub.contains('در حال نوشتن');
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: cc.background,
        appBar: AppBar(
          backgroundColor: c.surface,
          elevation: 0.5,
          titleSpacing: 0,
          leading: _searching
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _closeSearch,
                )
              : null,
          title: _searching
              ? TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'جستجو در این گفتگو…',
                    border: InputBorder.none,
                  ),
                )
              : GestureDetector(
                  onTap: _openInfo,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      ChatAvatar(
                        name: title,
                        imageUrl: _conv['avatar_url']?.toString(),
                        colorSeed: _conv['other_user_id'] ?? _cid,
                        isGroup: _isGroup,
                        size: 40,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: c.textStrong,
                              ),
                            ),
                            Text(
                              sub,
                              style: TextStyle(
                                fontSize: 12,
                                color: live ? c.primary : c.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          actions: [
            // منوی سه‌نقطه: جستجو، بی‌صدا/باصدا، ترک گروه (فقط گروه — هر عضوی، مثلِ وب)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'گزینه‌های بیشتر',
              onSelected: _onMenu,
              itemBuilder: (_) => [
                _menuItem('search', Icons.search_rounded, 'جستجو'),
                _conv['is_muted'] == true
                    ? _menuItem('mute', Icons.volume_up_rounded, 'باصدا کردن')
                    : _menuItem(
                        'mute',
                        Icons.volume_off_rounded,
                        'بی‌صدا کردن',
                      ),
                if (_isGroup)
                  _menuItem(
                    'leave',
                    Icons.logout_rounded,
                    'ترک گروه',
                    danger: true,
                  ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            if (_pinned != null && !_searching) _pinnedBar(c),
            Expanded(
              child: Stack(
                children: [
                  _messagesView(c, cc),
                  if (_searching && _searchCtrl.text.trim().isNotEmpty)
                    _searchResultsView(c),
                ],
              ),
            ),
            if (!_searching && _mentionOptions.isNotEmpty) _mentionList(c),
            if (!_searching) _composer(c, cc),
          ],
        ),
      ),
    );
  }

  Widget _messagesView(AppColors c, ChatColors cc) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: c.textMuted)),
            TextButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _loadInitial();
              },
              child: const Text('تلاش دوباره'),
            ),
          ],
        ),
      );
    }

    // ترتیبِ زمانی با جداکننده‌ی تاریخ؛ بعد برعکس برای ListView(reverse)
    final entries = <Object>[];
    String? lastDay;
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final day = (m['date_jalali'] ?? '').toString();
      if (day != lastDay) {
        entries.add(_DaySep(_dayLabel(day)));
        lastDay = day;
      }
      entries.add(m);
    }
    entries.addAll(_pending);
    final items = entries.reversed.toList();

    if (items.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: cc.dateChip,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'هنوز پیامی نیست. اولین پیام را بفرستید 👋',
            style: TextStyle(color: cc.dateChipText),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      reverse: true,
      // پیام‌های بیشتری ساخته بمانند تا پرش به نتیجه‌ی جستجو پیدایشان کند
      cacheExtent: 4000,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      itemCount: items.length + (_hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == items.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final e = items[i];
        if (e is _DaySep) return _dayChip(cc, e.label);
        if (e is _Pending) return _pendingBubble(c, cc, e);
        final m = e as Map<String, dynamic>;
        // آواتار فقط برای آخرین پیامِ یک «دنباله» از همان فرستنده (مثلِ تلگرام)
        final newer = i > 0 ? items[i - 1] : null;
        final lastOfRun =
            newer is! Map<String, dynamic> || newer['user_id'] != m['user_id'];
        return _messageRow(c, cc, m, lastOfRun);
      },
    );
  }

  Widget _dayChip(ChatColors cc, String label) => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: cc.dateChip,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        toPersianDigits(label),
        style: TextStyle(
          color: cc.dateChipText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  Widget _messageRow(
    AppColors c,
    ChatColors cc,
    Map<String, dynamic> m,
    bool lastOfRun,
  ) {
    if (m['type'] == 'system') {
      return _dayChip(cc, (m['message'] ?? '').toString());
    }
    final own = m['is_own'] == true;
    final showAvatar = _isGroup && !own;
    final bubble = _SwipeToReply(
      onReply: () => _startReply(m),
      child: GestureDetector(
        onLongPress: () => _showActions(m),
        child: _bubble(c, cc, m, own, lastOfRun),
      ),
    );
    final id = (m['id'] as num).toInt();
    return AnimatedContainer(
      key: _keys.putIfAbsent(id, () => GlobalKey()),
      duration: const Duration(milliseconds: 400),
      // هاله‌ی سرتاسری وقتی از نتیجه‌ی جستجو به این پیام پریدیم (مثلِ وب)
      color: _highlightId == id
          ? AppColors.of(context).primary.withValues(alpha: 0.18)
          : Colors.transparent,
      padding: EdgeInsets.only(bottom: lastOfRun ? 6 : 2),
      child: Row(
        mainAxisAlignment: own
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(child: bubble),
          if (showAvatar) ...[
            const SizedBox(width: 6),
            lastOfRun
                ? ChatAvatar(
                    name: (m['user_name'] ?? '').toString(),
                    imageUrl: m['user_avatar_url']?.toString(),
                    colorSeed: m['user_id'],
                    size: 34,
                  )
                : const SizedBox(width: 34),
          ],
        ],
      ),
    );
  }

  Widget _bubble(
    AppColors c,
    ChatColors cc,
    Map<String, dynamic> m,
    bool own,
    bool lastOfRun,
  ) {
    final maxW = MediaQuery.sizeOf(context).width * 0.78;
    final text = (m['message'] ?? '').toString();
    final atts = (m['attachments'] as List? ?? []).cast<Map>();
    final images = atts.where((a) => a['is_image'] == true).toList();
    final files = atts.where((a) => a['is_image'] != true).toList();
    final reply = m['reply_to'] as Map?;
    final fwd = m['forwarded_from'];
    final meta = own ? cc.ownMeta : cc.otherMeta;
    const r = Radius.circular(16);
    const tail = Radius.circular(4);

    return Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
      decoration: BoxDecoration(
        color: own ? cc.ownBubble : cc.otherBubble,
        borderRadius: BorderRadiusDirectional.only(
          topStart: r,
          topEnd: r,
          bottomStart: own && lastOfRun ? tail : r,
          bottomEnd: !own && lastOfRun ? tail : r,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isGroup && !own)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                (m['user_name'] ?? '').toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: chatPersonColor(m['user_id']),
                ),
              ),
            ),
          if (fwd != null && fwd.toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                'هدایت‌شده از $fwd',
                style: TextStyle(
                  fontSize: 12,
                  color: cc.link,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (reply != null) _replyQuote(cc, reply, own),
          ...images.map((a) => _imageAttachment(a)),
          ...files.map((a) => _fileAttachment(c, cc, a, own)),
          if (text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: _messageText(cc, text),
            ),
          if (((m['reactions'] as List?) ?? []).isNotEmpty)
            _reactionChips(c, cc, m, own),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (m['is_edited'] == true)
                Text(
                  'ویرایش‌شده  ',
                  style: TextStyle(fontSize: 10.5, color: meta),
                ),
              Text(
                chatTime(m['created_at']?.toString()),
                style: TextStyle(fontSize: 11, color: meta),
              ),
              if (own) ...[const SizedBox(width: 3), _ticks(cc, m)],
            ],
          ),
        ],
      ),
    );
  }

  /// تراشه‌های واکنش زیرِ متن (ایموجی + تعداد)؛ لمس = تاگلِ همان ایموجی
  Widget _reactionChips(
    AppColors c,
    ChatColors cc,
    Map<String, dynamic> m,
    bool own,
  ) {
    final list = ((m['reactions'] as List?) ?? []).cast<Map>();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: list.map((r) {
          final mine = r['reacted_by_me'] == true;
          return GestureDetector(
            onTap: () => _react(m, r['emoji'].toString()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: mine
                    ? (own ? cc.ownMeta : c.primary)
                    : (own ? cc.ownMeta : c.primary).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${r['emoji']} ${toPersianDigits('${r['count']}')}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: mine ? Colors.white : cc.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// نوارِ پیامِ سنجاق‌شده بالای گفتگو — لمس: پرش به پیام؛ × فقط برای کسی که اجازه دارد
  Widget _pinnedBar(AppColors c) {
    final p = _pinned!;
    final snippet = (p['snippet'] ?? '').toString();
    return Material(
      color: c.surface,
      child: InkWell(
        onTap: () => _jumpTo((p['id'] as num).toInt()),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.borderSoft)),
          ),
          child: Row(
            children: [
              Container(width: 3, height: 34, color: c.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'پیام سنجاق‌شده',
                      style: TextStyle(
                        color: c.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                    Text(
                      snippet.isEmpty ? '📎 فایل' : snippet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: c.textStrong),
                    ),
                  ],
                ),
              ),
              if (_canPin)
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 20, color: c.textMuted),
                  tooltip: 'برداشتن سنجاق',
                  onPressed: _unpin,
                )
              else
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.push_pin_rounded,
                    size: 18,
                    color: c.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// پیشنهادِ منشن بالای کادرِ نوشتن
  Widget _mentionList(AppColors c) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.borderSoft)),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: _mentionOptions
            .map(
              (m) => ListTile(
                dense: true,
                leading: ChatAvatar(
                  name: (m['full_name'] ?? '').toString(),
                  imageUrl: m['avatar_url']?.toString(),
                  colorSeed: m['id'],
                  size: 32,
                ),
                title: Text((m['full_name'] ?? '').toString()),
                onTap: () => _applyMention(m),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _ticks(ChatColors cc, Map<String, dynamic> m) {
    final id = (m['id'] as num).toInt();
    final seen = _receipts.values.where((v) => v >= id).length;
    if (seen == 0) return Icon(Icons.done_rounded, size: 15, color: cc.ownMeta);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.done_all_rounded, size: 15, color: cc.readTick),
        if (_isGroup && seen > 1)
          Text(
            toPersianDigits('$seen'),
            style: TextStyle(fontSize: 10, color: cc.readTick),
          ),
      ],
    );
  }

  Widget _replyQuote(ChatColors cc, Map reply, bool own) {
    final name = (reply['user_name'] ?? '').toString();
    final deleted = reply['is_deleted'] == true;
    final snippet = deleted
        ? 'پیام حذف شده'
        : ((reply['snippet'] ?? '').toString().isEmpty
              ? '📎 فایل'
              : reply['snippet'].toString());
    final color = chatPersonColor(name);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: BorderDirectional(start: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            snippet,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: cc.text.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageAttachment(Map a) {
    final url = ChatApi.fileUrl((a['id'] as num).toInt(), view: true);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTap: () => Get.to(() => _ImageViewer(url: url, headers: _headers)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260, minWidth: 120),
            child: _headers.isEmpty
                ? const SizedBox(width: 200, height: 150)
                : Image.network(
                    url,
                    headers: _headers,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 200,
                      height: 120,
                      child: Center(child: Icon(Icons.broken_image_outlined)),
                    ),
                    loadingBuilder: (_, child, p) => p == null
                        ? child
                        : const SizedBox(
                            width: 200,
                            height: 150,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _fileAttachment(AppColors c, ChatColors cc, Map a, bool own) {
    final name = (a['original_name'] ?? 'فایل').toString();
    return InkWell(
      onTap: () => _openFile(a),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: own ? cc.ownMeta : c.primary,
              child: const Icon(
                Icons.insert_drive_file_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: cc.text,
                    ),
                  ),
                  Text(
                    chatFileSize((a['file_size'] as num? ?? 0).toInt()),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: own ? cc.ownMeta : cc.otherMeta,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingBubble(AppColors c, ChatColors cc, _Pending p) {
    final maxW = MediaQuery.sizeOf(context).width * 0.78;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: maxW),
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
            decoration: BoxDecoration(
              color: cc.ownBubble.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (p.replyTo != null)
                  _replyQuote(cc, {
                    'user_name': p.replyTo!['user_name'],
                    'snippet': p.replyTo!['message'],
                  }, true),
                ...p.files.map(
                  (f) => Text(
                    '📎 ${f.name}',
                    style: TextStyle(color: cc.text, fontSize: 13),
                  ),
                ),
                if (p.text.isNotEmpty)
                  Text(
                    p.text,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: cc.text,
                    ),
                  ),
                Icon(Icons.schedule_rounded, size: 13, color: cc.ownMeta),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer(AppColors c, ChatColors cc) {
    final ref = _editing ?? _replyTo;
    final hasContent = _input.text.trim().isNotEmpty || _files.isNotEmpty;
    return Material(
      color: c.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ref != null)
              Container(
                padding: const EdgeInsets.fromLTRB(8, 6, 12, 0),
                child: Row(
                  children: [
                    Icon(
                      _editing != null
                          ? Icons.edit_rounded
                          : Icons.reply_rounded,
                      color: c.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _editing != null
                                ? 'ویرایش پیام'
                                : 'پاسخ به ${ref['user_name'] ?? ''}',
                            style: TextStyle(
                              color: c.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            (ref['message'] ?? '').toString().isEmpty
                                ? '📎 فایل'
                                : ref['message'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: c.textMuted),
                      onPressed: () => setState(() {
                        if (_editing != null) _input.clear();
                        _editing = null;
                        _replyTo = null;
                      }),
                    ),
                  ],
                ),
              ),
            if (_files.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  children: _files
                      .map(
                        (f) => Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: InputChip(
                            avatar: Icon(
                              f.isImage
                                  ? Icons.image_outlined
                                  : Icons.insert_drive_file_outlined,
                              size: 16,
                            ),
                            label: Text(
                              f.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onDeleted: () => setState(() => _files.remove(f)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 6, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_editing == null)
                    IconButton(
                      icon: Icon(Icons.attach_file_rounded, color: c.textMuted),
                      onPressed: _pickFiles,
                      tooltip: 'پیوست فایل',
                    ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'پیام',
                        isDense: true,
                        filled: true,
                        fillColor: c.bgPage,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedScale(
                    scale: hasContent ? 1 : 0.85,
                    duration: const Duration(milliseconds: 150),
                    child: Material(
                      color: hasContent
                          ? c.primary
                          : c.textMuted.withValues(alpha: 0.4),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: hasContent && !_sending ? _send : null,
                        child: Padding(
                          padding: const EdgeInsets.all(11),
                          child: _sending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  _editing != null
                                      ? Icons.check_rounded
                                      : Icons.send_rounded,
                                  color: Colors.white,
                                  size: 20,
                                  // در RTL هم فلش رو به جلو (سمت چپ)
                                  textDirection: TextDirection.rtl,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySep {
  final String label;
  _DaySep(this.label);
}

/// کشیدنِ افقیِ حباب برای «پاسخ» (مثلِ تلگرام)
class _SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  const _SwipeToReply({required this.child, required this.onReply});

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  double _dx = 0;
  bool _fired = false;
  static const _threshold = 64.0;

  @override
  Widget build(BuildContext context) {
    final progress = (_dx.abs() / _threshold).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragUpdate: (d) => setState(() {
        _dx = (_dx + d.delta.dx).clamp(-90.0, 90.0);
        if (!_fired && _dx.abs() >= _threshold) {
          _fired = true;
          HapticFeedback.lightImpact();
        }
      }),
      onHorizontalDragEnd: (_) {
        if (_fired) widget.onReply();
        setState(() {
          _dx = 0;
          _fired = false;
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_dx != 0)
            Positioned(
              left: _dx < 0 ? null : 0,
              right: _dx < 0 ? 0 : null,
              child: Opacity(
                opacity: progress,
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.black26,
                  child: const Icon(
                    Icons.reply_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          AnimatedContainer(
            duration: Duration(milliseconds: _dx == 0 ? 180 : 0),
            transform: Matrix4.translationValues(_dx, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// نمایشِ تمام‌صفحه‌ی عکس با بزرگ‌نمایی
class _ImageViewer extends StatelessWidget {
  final String url;
  final Map<String, String> headers;
  const _ImageViewer({required this.url, required this.headers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.network(url, headers: headers),
        ),
      ),
    );
  }
}
