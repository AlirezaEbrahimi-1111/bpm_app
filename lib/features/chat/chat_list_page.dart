import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_number.dart';
import '../../core/utils/task_search.dart';
import '../../core/widgets/app_snack.dart';
import '../shell/widgets/app_bottom_nav.dart';
import 'chat_api.dart';
import 'chat_conversation_page.dart';
import 'chat_widgets.dart';
import 'new_chat_page.dart';

/// تبِ «چت» — فهرستِ گفتگوها به سبکِ تلگرام.
/// [isActive]: فقط وقتی همین تب دیده می‌شود هر چند ثانیه به‌روز می‌شود.
class ChatListPage extends StatefulWidget {
  final ValueListenable<int> currentTab;
  final int tabIndex;

  /// حالتِ «بایگانی‌شده‌ها» (صفحه‌ی جدا از تب) — بدونِ دکمه‌ی ✏️ و ردیفِ بایگانی
  final bool archived;
  const ChatListPage({
    super.key,
    required this.currentTab,
    required this.tabIndex,
    this.archived = false,
  });

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  Timer? _poll;
  int _archivedCount = 0;
  int _tick = 0;

  @override
  bool get wantKeepAlive => true;

  bool get _visible => widget.currentTab.value == widget.tabIndex;

  @override
  void initState() {
    super.initState();
    widget.currentTab.addListener(_onTabChanged);
    if (_visible) _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_visible && mounted) _load(silent: true);
    });
  }

  void _onTabChanged() {
    if (_visible) _load(silent: _items.isNotEmpty);
  }

  @override
  void dispose() {
    _poll?.cancel();
    widget.currentTab.removeListener(_onTabChanged);
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!ChatApi.enabled) return;
    if (!silent) setState(() => _loading = _items.isEmpty);
    try {
      final list = await ChatApi.conversations(archived: widget.archived);
      // تعدادِ بایگانی‌شده‌ها (برای ردیفِ «بایگانی‌شده» بالای فهرست) — هر ۳۰ ثانیه
      if (!widget.archived && (!silent || _tick++ % 6 == 0)) {
        ChatApi.conversations(archived: true)
            .then((a) {
              if (mounted && a.length != _archivedCount)
                setState(() => _archivedCount = a.length);
            })
            .catchError((_) {});
      }
      // سنجاق‌شده‌ها بالا (آخرین سنجاق اول)، بقیه به ترتیبِ آخرین فعالیت (همان ترتیبِ سرور)
      final pinned = list.where((c) => c['pinned_at'] != null).toList()
        ..sort(
          (a, b) =>
              b['pinned_at'].toString().compareTo(a['pinned_at'].toString()),
        );
      final rest = list.where((c) => c['pinned_at'] == null).toList();
      if (mounted) {
        setState(() {
          _items = [...pinned, ...rest];
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  List<Map<String, dynamic>> get _visibleItems {
    if (_query.trim().isEmpty) return _items;
    return rankBySearch<Map<String, dynamic>>(
      _items.where(
        (c) => searchMatches(_query, [(c['title'] ?? '').toString()]),
      ),
      _query,
      (c) => [(c['title'] ?? '').toString()],
    );
  }

  Future<void> _open(Map<String, dynamic> c) async {
    await Get.to(
      () => ChatConversationPage(
        conversationId: (c['conversation_id'] as num).toInt(),
        initial: c,
      ),
    );
    _load(silent: true);
  }

  Future<void> _newChat() async {
    final opened = await Get.to(() => const NewChatPage());
    if (opened == true) _load(silent: true);
  }

  Future<void> _openArchived() async {
    await Get.to(() => const ArchivedChatsPage());
    _load(silent: true);
  }

  /// لمسِ طولانی روی گفتگو — همان منوی راست‌کلیکِ وب: سنجاق، بی‌صدا، بایگانی، حذف/ترک
  void _convOptions(Map<String, dynamic> conv) {
    final c = AppColors.of(context);
    final id = (conv['conversation_id'] as num).toInt();
    final isGroup = conv['type'] != 'direct';
    final pinned = conv['pinned_at'] != null;
    final muted = conv['is_muted'] == true;
    Widget item(
      IconData icon,
      String label,
      Future<void> Function() run, {
      bool danger = false,
    }) {
      final color = danger ? Colors.red : null;
      return ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: TextStyle(color: color)),
        onTap: () async {
          Navigator.pop(context);
          try {
            await run();
          } catch (e) {
            AppSnack.error('خطا', e.toString());
          }
          _load(silent: true);
        },
      );
    }

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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Text(
                  (conv['title'] ?? '').toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: c.textStrong,
                  ),
                ),
              ),
              if (!widget.archived)
                item(
                  pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                  pinned ? 'برداشتن سنجاق' : 'سنجاق کردن',
                  () async => ChatApi.togglePinConversation(id),
                ),
              item(
                muted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                muted ? 'باصدا کردن' : 'بی‌صدا کردن',
                () async => ChatApi.toggleMute(id),
              ),
              item(
                widget.archived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                widget.archived ? 'خروج از بایگانی' : 'بایگانی',
                () => ChatApi.archive(id, !widget.archived),
              ),
              isGroup
                  ? item(Icons.logout_rounded, 'ترک گروه', () async {
                      if (await _confirm(
                        'ترک گروه',
                        'از گروه «${conv['title']}» خارج می‌شوید. ادامه می‌دهید؟',
                      )) {
                        await ChatApi.leaveGroup(id);
                      }
                    }, danger: true)
                  : item(Icons.delete_outline_rounded, 'حذف گفتگو', () async {
                      if (await _confirm(
                        'حذف گفتگو',
                        'این گفتگو فقط از فهرست شما حذف می‌شود؛ طرف مقابل همچنان پیام‌ها را می‌بیند. اگر پیام تازه‌ای بیاید، دوباره نمایش داده می‌شود.',
                      )) {
                        await ChatApi.deleteConversation(id);
                      }
                    }, danger: true),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirm(String title, String body) async {
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
              child: Text(title),
            ),
          ],
        ),
      ),
    );
    return r == true;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);
    final items = _visibleItems;
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'جستجو در گفتگوها',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: c.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(child: _body(c, items)),
          ],
        ),
        // ✏️ گفتگو / گروهِ جدید — پایین سمتِ چپ، بالای نوارِ پایین (مثلِ تلگرام)
        if (!widget.archived)
          Positioned(
            left: 16,
            bottom: navBarFootprint(context) + 8,
            child: FloatingActionButton(
              heroTag: 'chat_new',
              shape:
                  const CircleBorder(), // دایره، مثلِ تلگرام (پیش‌فرضِ Material 3 مربعِ گوشه‌گرد است)
              onPressed: _newChat,
              backgroundColor: c.primary,
              foregroundColor: Colors.white,
              tooltip: 'گفتگوی جدید',
              child: const Icon(Icons.edit_rounded),
            ),
          ),
      ],
    );
  }

  Widget _body(AppColors c, List<Map<String, dynamic>> items) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: c.textMuted)),
            TextButton(onPressed: _load, child: const Text('تلاش دوباره')),
          ],
        ),
      );
    }
    final showArchivedRow =
        !widget.archived && _archivedCount > 0 && _query.trim().isEmpty;
    if (items.isEmpty && !showArchivedRow) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 56,
              color: c.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 10),
            Text(
              widget.archived
                  ? 'گفتگوی بایگانی‌شده‌ای ندارید'
                  : (_query.isEmpty
                        ? 'هنوز گفتگویی ندارید'
                        : 'گفتگویی پیدا نشد'),
              style: TextStyle(color: c.textMuted),
            ),
            if (_query.isEmpty && !widget.archived)
              TextButton.icon(
                onPressed: _newChat,
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('شروع گفتگوی جدید'),
              ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        // جای دکمه‌ی شناورِ ✏️ هم بماند تا آخرین گفتگو زیرش نرود
        padding: EdgeInsets.only(
          bottom: widget.archived ? 24 : navBarFootprint(context) + 72,
        ),
        itemCount: items.length + (showArchivedRow ? 1 : 0),
        separatorBuilder: (_, _) =>
            Divider(height: 1, indent: 82, color: c.borderSoft),
        itemBuilder: (_, i) {
          if (showArchivedRow) {
            if (i == 0) return _archivedRow(c);
            return _tile(c, items[i - 1]);
          }
          return _tile(c, items[i]);
        },
      ),
    );
  }

  /// ردیفِ «بایگانی‌شده» بالای فهرست (مثلِ تلگرام)
  Widget _archivedRow(AppColors c) {
    return InkWell(
      onTap: _openArchived,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: c.textMuted.withValues(alpha: 0.6),
              child: const Icon(Icons.archive_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'بایگانی‌شده',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: c.textStrong,
                ),
              ),
            ),
            Text(
              toPersianDigits('$_archivedCount'),
              style: TextStyle(color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(AppColors c, Map<String, dynamic> conv) {
    final isGroup = conv['type'] != 'direct';
    final unread = (conv['unread_count'] as num? ?? 0).toInt();
    final muted = conv['is_muted'] == true;
    final typing = conv['other_user_is_typing'] == true;
    final last = (conv['last_message'] ?? '').toString().replaceAll('\n', ' ');
    final sender = conv['is_own_last'] == true
        ? 'شما'
        : (isGroup ? (conv['last_message_sender_name'] ?? '').toString() : '');
    final preview = last.isEmpty ? '📎 فایل' : last;

    return InkWell(
      onTap: () => _open(conv),
      onLongPress: () => _convOptions(conv),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            ChatAvatar(
              name: (conv['title'] ?? '').toString(),
              imageUrl: conv['avatar_url']?.toString(),
              colorSeed: conv['other_user_id'] ?? conv['conversation_id'],
              online: !isGroup && conv['other_user_is_online'] == true,
              isGroup: isGroup,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isGroup) ...[
                        Icon(
                          Icons.groups_2_rounded,
                          size: 16,
                          color: c.textMuted,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          (conv['title'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: c.textStrong,
                          ),
                        ),
                      ),
                      if (muted)
                        Icon(
                          Icons.volume_off_rounded,
                          size: 15,
                          color: c.textMuted,
                        ),
                      const SizedBox(width: 6),
                      Text(
                        chatListStamp(conv),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: unread > 0 ? c.primary : c.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: typing
                            ? Text(
                                'در حال نوشتن…',
                                style: TextStyle(
                                  color: c.primary,
                                  fontSize: 13.5,
                                ),
                              )
                            : Text.rich(
                                TextSpan(
                                  children: [
                                    if (sender.isNotEmpty)
                                      TextSpan(
                                        text: '$sender: ',
                                        style: TextStyle(color: c.primary),
                                      ),
                                    TextSpan(text: preview),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: c.textMuted,
                                  fontSize: 13.5,
                                ),
                              ),
                      ),
                      if (conv['pinned_at'] != null && unread == 0)
                        Icon(
                          Icons.push_pin_rounded,
                          size: 15,
                          color: c.textMuted,
                        ),
                      if (unread > 0)
                        Container(
                          constraints: const BoxConstraints(minWidth: 22),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: muted ? c.textMuted : c.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unread > 999 ? '+۹۹۹' : toPersianDigits('$unread'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
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

/// «بایگانی‌شده» — همان فهرست با archived=1 (لمسِ طولانی → خروج از بایگانی)
class ArchivedChatsPage extends StatelessWidget {
  const ArchivedChatsPage({super.key});

  static final _alwaysVisible = ValueNotifier<int>(0);

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
          title: const Text('بایگانی‌شده'),
        ),
        body: ChatListPage(
          currentTab: _alwaysVisible,
          tabIndex: 0,
          archived: true,
        ),
      ),
    );
  }
}
