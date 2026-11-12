import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_number.dart';
import '../../core/widgets/app_snack.dart';
import 'chat_api.dart';
import 'chat_widgets.dart';
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
    _input.addListener(() => setState(() {}));
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
  }

  @override
  void dispose() {
    if (ChatConversationPage.openConversationId == _cid)
      ChatConversationPage.openConversationId = null;
    for (final t in [_pollTimer, _receiptTimer, _pingTimer, _infoTimer]) {
      t?.cancel();
    }
    _input.dispose();
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
      if (me != null && mounted) setState(() => _conv = me);
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

  Future<void> _openFile(Map a) async {
    final id = (a['id'] as num).toInt();
    AppSnack.info('دانلود', 'در حال دریافت فایل…');
    try {
      final dir = await getTemporaryDirectory();
      final name = (a['original_name'] ?? 'file').toString().replaceAll(
        RegExp(r'[\\/:*?"<>|]'),
        '_',
      );
      final path = '${dir.path}${Platform.pathSeparator}chat_${id}_$name';
      if (!File(path).existsSync()) {
        await ApiClient.dio.download(
          '/api/chat/download.php',
          path,
          queryParameters: {'id': id},
        );
      }
      final r = await OpenFilex.open(path);
      if (r.type != ResultType.done)
        AppSnack.error('خطا', 'برنامه‌ای برای باز کردن این فایل پیدا نشد');
    } catch (_) {
      AppSnack.error('خطا', 'دریافت فایل ناموفق بود');
    }
  }

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
              const SizedBox(height: 6),
              _action(ctx, Icons.reply_rounded, 'پاسخ', () => _startReply(m)),
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
    if (_isGroup) return toPersianDigits('${_conv['member_count'] ?? ''} عضو');
    if (_conv['other_user_is_typing'] == true) return 'در حال نوشتن…';
    if (_conv['other_user_is_online'] == true) return 'آنلاین';
    return chatLastSeen(_conv['other_user_last_seen_at']?.toString());
  }

  /// لمسِ نوارِ بالا در گروه → اطلاعات گروه (مرحله‌ی ۲)
  Future<void> _openInfo() async {
    if (!_isGroup) return;
    final r = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => GroupInfoPage(conversationId: _cid)),
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
    final live = sub == 'آنلاین' || sub == 'در حال نوشتن…';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: cc.background,
        appBar: AppBar(
          backgroundColor: c.surface,
          elevation: 0.5,
          titleSpacing: 0,
          title: GestureDetector(
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
            if (_isGroup)
              IconButton(
                icon: const Icon(Icons.info_outline_rounded),
                tooltip: 'اطلاعات گروه',
                onPressed: _openInfo,
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(child: _messagesView(c, cc)),
            _composer(c, cc),
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
    return Padding(
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
              child: Text(
                text,
                style: TextStyle(fontSize: 15, height: 1.45, color: cc.text),
              ),
            ),
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
