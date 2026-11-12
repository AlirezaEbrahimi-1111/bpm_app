import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_number.dart';
import '../../core/widgets/app_snack.dart';
import 'chat_api.dart';
import 'chat_widgets.dart';

/// انتخابِ چند مخاطب (برای ساختِ گروه یا افزودنِ عضو) — به سبکِ تلگرام: انتخاب‌شده‌ها
/// به‌صورت تراشه بالای صفحه، جستجو با api/chat/search-users.php.
/// خروجی (Navigator.pop): `List<Map>` کاربرانِ انتخاب‌شده، یا null اگر منصرف شد.
class MemberPickerPage extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final Set<int> excludeIds;
  const MemberPickerPage({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.excludeIds = const {},
  });

  @override
  State<MemberPickerPage> createState() => _MemberPickerPageState();
}

class _MemberPickerPageState extends State<MemberPickerPage> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  final Map<int, Map<String, dynamic>> _selected = {};
  bool _loading = false;

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
      if (mounted && _ctrl.text.trim() == q) {
        setState(
          () => _results = list
              .where(
                (u) => !widget.excludeIds.contains((u['id'] as num).toInt()),
              )
              .toList(),
        );
      }
    } catch (e) {
      AppSnack.error('خطا', e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(Map<String, dynamic> u) {
    final id = (u['id'] as num).toInt();
    setState(
      () =>
          _selected.containsKey(id) ? _selected.remove(id) : _selected[id] = u,
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title),
              if (_selected.isNotEmpty)
                Text(
                  toPersianDigits('${_selected.length} نفر انتخاب شده'),
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
            ],
          ),
        ),
        floatingActionButton: _selected.isEmpty
            ? null
            : FloatingActionButton.extended(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                onPressed: () =>
                    Navigator.pop(context, _selected.values.toList()),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  textDirection: TextDirection.ltr,
                ),
                label: Text(widget.confirmLabel),
              ),
        body: Column(
          children: [
            if (_selected.isNotEmpty)
              SizedBox(
                height: 92,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  children: _selected.values.map((u) {
                    final name = (u['full_name'] ?? '').toString();
                    return GestureDetector(
                      onTap: () => _toggle(u),
                      child: SizedBox(
                        width: 66,
                        child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ChatAvatar(
                                  name: name,
                                  imageUrl: u['avatar_url']?.toString(),
                                  colorSeed: u['id'],
                                  size: 48,
                                ),
                                Positioned(
                                  left: -2,
                                  bottom: -2,
                                  child: CircleAvatar(
                                    radius: 9,
                                    backgroundColor: c.textMuted,
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              name.split(' ').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
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
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _results.isEmpty
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
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: _results.length,
                      itemBuilder: (_, i) {
                        final u = _results[i];
                        final id = (u['id'] as num).toInt();
                        final sel = _selected.containsKey(id);
                        final online = u['is_online'] == true;
                        final section = (u['section_label'] ?? '').toString();
                        return ListTile(
                          onTap: () => _toggle(u),
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
                          trailing: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            child: Icon(
                              sel
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              key: ValueKey(sel),
                              color: sel ? c.primary : c.textMuted,
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
