import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_number.dart';
import '../../core/utils/task_search.dart';
import 'chat_api.dart';
import 'chat_widgets.dart';

/// «هدایت به…» — انتخابِ یک یا چند گفتگو (api/chat/forward-message.php برای هر کدام).
/// خروجی: `List<Map>` گفتگوهای انتخاب‌شده، یا null.
class ForwardPickerPage extends StatefulWidget {
  const ForwardPickerPage({super.key});

  @override
  State<ForwardPickerPage> createState() => _ForwardPickerPageState();
}

class _ForwardPickerPageState extends State<ForwardPickerPage> {
  List<Map<String, dynamic>> _all = [];
  final Map<int, Map<String, dynamic>> _selected = {};
  String _q = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ChatApi.conversations()
        .then((l) {
          if (mounted) {
            setState(() {
              _all = l;
              _loading = false;
            });
          }
        })
        .catchError((_) {
          if (mounted) setState(() => _loading = false);
        });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final items = _q.trim().isEmpty
        ? _all
        : rankBySearch<Map<String, dynamic>>(
            _all.where(
              (x) => searchMatches(_q, [(x['title'] ?? '').toString()]),
            ),
            _q,
            (x) => [(x['title'] ?? '').toString()],
          );
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: c.bgPage,
        appBar: AppBar(
          backgroundColor: c.bgPage,
          elevation: 0,
          title: Text(
            _selected.isEmpty
                ? 'هدایت به…'
                : toPersianDigits('${_selected.length} گفتگو انتخاب شده'),
          ),
        ),
        floatingActionButton: _selected.isEmpty
            ? null
            : FloatingActionButton(
                shape: const CircleBorder(),
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                onPressed: () =>
                    Navigator.pop(context, _selected.values.toList()),
                child: const Icon(
                  Icons.send_rounded,
                  textDirection: TextDirection.rtl,
                ),
              ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'جستجو',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  filled: true,
                  fillColor: c.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final x = items[i];
                        final id = (x['conversation_id'] as num).toInt();
                        final sel = _selected.containsKey(id);
                        final isGroup = x['type'] != 'direct';
                        return ListTile(
                          onTap: () => setState(
                            () =>
                                sel ? _selected.remove(id) : _selected[id] = x,
                          ),
                          leading: ChatAvatar(
                            name: (x['title'] ?? '').toString(),
                            imageUrl: x['avatar_url']?.toString(),
                            colorSeed: x['other_user_id'] ?? id,
                            isGroup: isGroup,
                            size: 46,
                          ),
                          title: Text(
                            (x['title'] ?? '').toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: c.textStrong,
                            ),
                          ),
                          subtitle: isGroup
                              ? Text(
                                  toPersianDigits(
                                    '${x['member_count'] ?? ''} عضو',
                                  ),
                                  style: TextStyle(
                                    color: c.textMuted,
                                    fontSize: 12.5,
                                  ),
                                )
                              : null,
                          trailing: Icon(
                            sel
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: sel ? c.primary : c.textMuted,
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
