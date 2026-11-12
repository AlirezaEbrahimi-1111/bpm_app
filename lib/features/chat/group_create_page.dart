import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_number.dart';
import '../../core/widgets/app_snack.dart';
import 'chat_api.dart';
import 'chat_conversation_page.dart';
import 'chat_widgets.dart';

/// گامِ دومِ ساختِ گروه (بعد از انتخابِ اعضا): نام و عکسِ گروه (اختیاری).
/// api/chat/create-group.php، بعد اگر عکس انتخاب شده upload-group-avatar.php.
class GroupCreatePage extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  const GroupCreatePage({super.key, required this.members});

  @override
  State<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends State<GroupCreatePage> {
  final _title = TextEditingController();
  ChatUpload? _photo;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final f = r?.files.firstOrNull;
    if (f?.bytes != null)
      setState(() => _photo = ChatUpload(f!.name, f.bytes!));
  }

  Future<void> _create() async {
    final title = _title.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isEmpty) {
      AppSnack.error('نام گروه', 'لطفاً یک نام برای گروه بنویسید');
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await ChatApi.createGroup(
        title,
        widget.members.map((u) => (u['id'] as num).toInt()).toList(),
      );
      String? avatar;
      if (_photo != null) {
        try {
          avatar = await ChatApi.uploadGroupAvatar(id, _photo!);
        } catch (e) {
          AppSnack.error('عکس گروه', 'گروه ساخته شد ولی عکس ذخیره نشد: $e');
        }
      }
      if (!mounted) return;
      // فهرست → [انتخاب اعضا، همین صفحه] هر دو بسته شوند و گفتگوی گروه باز شود
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatConversationPage(
            conversationId: id,
            initial: {
              'conversation_id': id,
              'type': 'group',
              'title': title,
              'avatar_url': avatar,
              'member_count': widget.members.length + 1,
              'is_owner': true,
            },
          ),
        ),
      );
    } catch (e) {
      AppSnack.error('خطا', e.toString());
      if (mounted) setState(() => _saving = false);
    }
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
          title: const Text('گروه جدید'),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          onPressed: _saving ? null : _create,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: _pickPhoto,
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: c.primary,
                    backgroundImage: _photo != null
                        ? MemoryImage(_photo!.bytes)
                        : null,
                    child: _photo == null
                        ? const Icon(
                            Icons.add_a_photo_rounded,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _title,
                    autofocus: true,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      hintText: 'نام گروه',
                      counterText: '',
                    ),
                    onSubmitted: (_) => _create(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              toPersianDigits('${widget.members.length} عضو'),
              style: TextStyle(color: c.primary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ...widget.members.map(
              (u) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ChatAvatar(
                  name: (u['full_name'] ?? '').toString(),
                  imageUrl: u['avatar_url']?.toString(),
                  colorSeed: u['id'],
                  size: 42,
                ),
                title: Text((u['full_name'] ?? '').toString()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
