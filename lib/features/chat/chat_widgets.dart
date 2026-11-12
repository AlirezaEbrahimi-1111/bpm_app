import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/persian_number.dart';
import '../../core/widgets/app_snack.dart';
import 'chat_api.dart';

/// رنگ‌های تلگرام‌مانندِ چت (روشن/تاریک)
class ChatColors {
  final Color background;
  final Color ownBubble;
  final Color otherBubble;
  final Color ownMeta;
  final Color otherMeta;
  final Color text;
  final Color link;
  final Color readTick;
  final Color dateChip;
  final Color dateChipText;

  const ChatColors._({
    required this.background,
    required this.ownBubble,
    required this.otherBubble,
    required this.ownMeta,
    required this.otherMeta,
    required this.text,
    required this.link,
    required this.readTick,
    required this.dateChip,
    required this.dateChipText,
  });

  static ChatColors of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? const ChatColors._(
            background: Color(0xFF0E1621),
            ownBubble: Color(0xFF2B5278),
            otherBubble: Color(0xFF182533),
            ownMeta: Color(0xFF7DA8D3),
            otherMeta: Color(0xFF6D7F8F),
            text: Color(0xFFF5F5F5),
            link: Color(0xFF71BAFA),
            readTick: Color(0xFF64B5F6),
            dateChip: Color(0x661E2C3A),
            dateChipText: Colors.white,
          )
        : const ChatColors._(
            background: Color(0xFFDCE6EE),
            ownBubble: Color(0xFFEEFFDE),
            otherBubble: Colors.white,
            ownMeta: Color(0xFF5DA35A),
            otherMeta: Color(0xFF9AA4AC),
            text: Color(0xFF111111),
            link: Color(0xFF2A7FD4),
            readTick: Color(0xFF4FAE4E),
            dateChip: Color(0x55557A95),
            dateChipText: Colors.white,
          );
  }
}

/// رنگِ ثابت برای هر شخص/گروه (مثلِ تلگرام) — از روی شناسه یا نام
const _avatarPalette = [
  Color(0xFFE17076),
  Color(0xFF7BC862),
  Color(0xFFE5CA77),
  Color(0xFF65AADD),
  Color(0xFFA695E7),
  Color(0xFFEE7AAE),
  Color(0xFF6EC9CB),
  Color(0xFFFAA774),
];

Color chatPersonColor(Object seed) =>
    _avatarPalette[seed.toString().hashCode.abs() % _avatarPalette.length];

String chatInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '؟';
  if (parts.length == 1) return parts.first.characters.first;
  return '${parts.first.characters.first}${parts[1].characters.first}';
}

class ChatAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final Object? colorSeed;
  final bool online;
  final bool isGroup;

  const ChatAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 52,
    this.colorSeed,
    this.online = false,
    this.isGroup = false,
  });

  @override
  Widget build(BuildContext context) {
    final url = ChatApi.absoluteUrl(imageUrl);
    final color = chatPersonColor(colorSeed ?? name);
    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: url == null
            ? LinearGradient(
                colors: [color.withValues(alpha: 0.85), color],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
        image: url != null
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: url == null
          ? (isGroup
                ? Icon(
                    Icons.groups_rounded,
                    color: Colors.white,
                    size: size * 0.5,
                  )
                : Text(
                    chatInitials(name),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: size * 0.36,
                    ),
                  ))
          : null,
    );
    if (!online) return circle;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        circle,
        Positioned(
          left: size * 0.02,
          bottom: size * 0.02,
          child: Container(
            width: size * 0.26,
            height: size * 0.26,
            decoration: BoxDecoration(
              color: const Color(0xFF4CD964),
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ساعتِ «HH:MM» از «Y-m-d H:i:s» سرور، با رقم فارسی
String chatTime(String? mysqlDt) {
  if (mysqlDt == null || mysqlDt.length < 16) return '';
  return toPersianDigits(mysqlDt.substring(11, 16));
}

/// برای فهرستِ گفتگوها: امروز → فقط ساعت؛ وگرنه تاریخِ شمسی (از سرور)
String chatListStamp(Map c) {
  final at = c['last_message_at']?.toString();
  if (at == null || at.isEmpty) return '';
  if (ChatApi.serverDate.isNotEmpty && at.startsWith(ChatApi.serverDate))
    return chatTime(at);
  final j = c['last_message_jalali']?.toString() ?? '';
  final date = j.split(' ').first;
  // «۱۴۰۵/۰۸/۲۰» → «۰۸/۲۰» (سالِ جاری کوتاه)
  final parts = date.split('/');
  return parts.length == 3 ? '${parts[1]}/${parts[2]}' : date;
}

/// دانلود و باز کردنِ پیوستِ چت با برنامه‌ی گوشی (گفتگو و تبِ فایل‌های اطلاعات گروه)
Future<void> openChatAttachment(Map a) async {
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
    if (r.type != ResultType.done) {
      AppSnack.error('خطا', 'برنامه‌ای برای باز کردن این فایل پیدا نشد');
    }
  } catch (_) {
    AppSnack.error('خطا', 'دریافت فایل ناموفق بود');
  }
}

/// «آخرین بازدید …» — امروز: ساعت؛ وگرنه ماه/روز (تاریخِ امروز از سرور)
String chatLastSeen(String? seen) {
  if (seen == null || seen.length < 16) return 'اخیراً دیده نشده';
  if (ChatApi.serverDate.isNotEmpty && seen.startsWith(ChatApi.serverDate)) {
    return 'آخرین بازدید ${chatTime(seen)}';
  }
  return 'آخرین بازدید ${toPersianDigits(seen.substring(5, 10).replaceAll('-', '/'))}';
}

String chatFileSize(int bytes) {
  if (bytes < 1024) return toPersianDigits('$bytes بایت');
  if (bytes < 1024 * 1024)
    return toPersianDigits('${(bytes / 1024).toStringAsFixed(0)} کیلوبایت');
  return toPersianDigits('${(bytes / 1024 / 1024).toStringAsFixed(1)} مگابایت');
}
