import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_number.dart';
import 'chat_api.dart';
import 'chat_widgets.dart';

/// تب‌های «رسانه / فایل / لینک» زیرِ کارتِ اعضا در اطلاعاتِ گروه (مثلِ تلگرام و تبِ وب)
/// api/chat/media.php و api/chat/links.php
class ChatMediaTabs extends StatefulWidget {
  final int conversationId;
  const ChatMediaTabs({super.key, required this.conversationId});

  @override
  State<ChatMediaTabs> createState() => _ChatMediaTabsState();
}

class _ChatMediaTabsState extends State<ChatMediaTabs> {
  int _tab = 0; // ۰ رسانه، ۱ فایل، ۲ لینک
  List<Map<String, dynamic>>? _files;
  List<Map<String, dynamic>>? _links;
  Map<String, String> _headers = {};

  @override
  void initState() {
    super.initState();
    ChatApi.authHeaders().then(
      (h) => mounted ? setState(() => _headers = h) : null,
    );
    ChatApi.media(widget.conversationId)
        .then((f) {
          if (mounted) setState(() => _files = f);
        })
        .catchError((_) {
          if (mounted) setState(() => _files = []);
        });
    ChatApi.links(widget.conversationId)
        .then((l) {
          if (mounted) setState(() => _links = l);
        })
        .catchError((_) {
          if (mounted) setState(() => _links = []);
        });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final images = (_files ?? []).where((f) => f['is_image'] == true).toList();
    final docs = (_files ?? []).where((f) => f['is_image'] != true).toList();
    final labels = [
      'رسانه${images.isEmpty ? '' : ' ${toPersianDigits(images.length)}'}',
      'فایل${docs.isEmpty ? '' : ' ${toPersianDigits(docs.length)}'}',
      'لینک${(_links ?? []).isEmpty ? '' : ' ${toPersianDigits(_links!.length)}'}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final sel = i == _tab;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(labels[i]),
                selected: sel,
                showCheckmark: false,
                onSelected: (_) => setState(() => _tab = i),
                selectedColor: c.primary.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: sel ? c.primary : c.textMuted,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                ),
                shape: const StadiumBorder(),
                side: BorderSide.none,
                backgroundColor: c.surface,
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: switch (_tab) {
            0 => _mediaGrid(c, images),
            1 => _fileList(c, docs),
            _ => _linkList(c),
          },
        ),
      ],
    );
  }

  Widget _empty(AppColors c, String text, bool loading) => Padding(
    padding: const EdgeInsets.all(28),
    child: Center(
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(text, style: TextStyle(color: c.textMuted)),
    ),
  );

  Widget _mediaGrid(AppColors c, List<Map<String, dynamic>> images) {
    if (images.isEmpty) return _empty(c, 'عکسی ارسال نشده است', _files == null);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: images.length,
      itemBuilder: (_, i) {
        final url = ChatApi.fileUrl(
          (images[i]['id'] as num).toInt(),
          view: true,
        );
        return GestureDetector(
          onTap: () => Get.to(
            () => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              body: Center(
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Image.network(url, headers: _headers),
                ),
              ),
            ),
          ),
          child: _headers.isEmpty
              ? Container(color: c.borderSoft)
              : Image.network(
                  url,
                  headers: _headers,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: c.borderSoft,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
        );
      },
    );
  }

  Widget _fileList(AppColors c, List<Map<String, dynamic>> docs) {
    if (docs.isEmpty) return _empty(c, 'فایلی ارسال نشده است', _files == null);
    return Column(
      children: [
        for (var i = 0; i < docs.length; i++) ...[
          if (i > 0) Divider(height: 1, indent: 68, color: c.borderSoft),
          ListTile(
            onTap: () => openChatAttachment(docs[i]),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: c.primary,
              child: const Icon(
                Icons.insert_drive_file_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              (docs[i]['original_name'] ?? '').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.textStrong),
            ),
            subtitle: Text(
              '${chatFileSize((docs[i]['file_size'] as num? ?? 0).toInt())} · ${docs[i]['uploader_name'] ?? ''}',
              style: TextStyle(fontSize: 12, color: c.textMuted),
            ),
          ),
        ],
      ],
    );
  }

  Widget _linkList(AppColors c) {
    final links = _links ?? [];
    if (links.isEmpty) return _empty(c, 'لینکی ارسال نشده است', _links == null);
    return Column(
      children: [
        for (var i = 0; i < links.length; i++) ...[
          if (i > 0) Divider(height: 1, indent: 68, color: c.borderSoft),
          ListTile(
            onTap: () async {
              final u = Uri.tryParse((links[i]['url'] ?? '').toString());
              if (u != null)
                await launchUrl(u, mode: LaunchMode.externalApplication);
            },
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: c.primary.withValues(alpha: 0.15),
              child: Text(
                (links[i]['host'] ?? '?')
                    .toString()
                    .characters
                    .first
                    .toUpperCase(),
                style: TextStyle(color: c.primary, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              (links[i]['host'] ?? '').toString(),
              style: TextStyle(color: c.textStrong),
            ),
            subtitle: Text(
              (links[i]['url'] ?? '').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
              style: TextStyle(fontSize: 12, color: c.primary),
            ),
          ),
        ],
      ],
    );
  }
}
