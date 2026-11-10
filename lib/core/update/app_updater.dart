import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../network/api_client.dart';

/// به‌روزرسانیِ درون‌برنامه، بدونِ فروشگاه (۱۴۰۵/۰۸/۱۹).
///
/// GitHub Actions (build-apk.yml) هر نسخه را می‌سازد و APKها + latest.json را در
/// https://bpm.itmalek.com/app-releases/ می‌گذارد:
///   { version, build, min_build, notes, released_at,
///     files: { "arm64-v8a": {url, size}, "armeabi-v7a": {url, size} } }
/// اپ هنگام باز شدن (و دکمهٔ «بررسی به‌روزرسانی» در پروفایل) build خودش را با
/// build سرور مقایسه می‌کند. build کمتر از min_build = اجباری (بدون «بعداً»).
/// اختیاری: «بعداً» تا فردا دوباره پرسیده نمی‌شود. فقط اندروید (iOS نصبِ بیرونی ندارد).
/// نصب: دانلود در پوشهٔ موقت → صفحهٔ نصبِ اندروید (کاربر «نصب» را می‌زند؛ بار اول
/// اجازهٔ «نصب از این برنامه» را هم می‌دهد).
class AppUpdater {
  static const _latestUrl = 'https://bpm.itmalek.com/app-releases/latest.json';
  static const _snoozeKey = 'app_update_snooze';
  static const _storage = FlutterSecureStorage();
  static const _purple = Color(0xFF8E57FE);

  static bool _busy = false;

  /// برچسبِ نسخهٔ نصب‌شده برای پروفایل (مثل «۱.۰.۳ (۱۰۵)»)
  static Future<String> installedLabel() async {
    final i = await PackageInfo.fromPlatform();
    return '${i.version} (${i.buildNumber})';
  }

  /// نسخهٔ نصب‌شده را به سرور می‌گوید (یک بار در هر باز شدنِ برنامه، بعد از ورود) — برای آمارِ
  /// «چند نفر کدام نسخه را دارند» در صفحهٔ bpm.itmalek.com/app-releases (فقط مدیر کل).
  /// سرور: go-api/internal/appinfo → جدولِ app_installs. خطا بی‌صدا نادیده گرفته می‌شود.
  static bool _reported = false;
  static Future<void> reportInstalled() async {
    if (_reported) return;
    _reported = true;
    try {
      final i = await PackageInfo.fromPlatform();
      String abi = '';
      if (Platform.isAndroid) {
        final abis = (await DeviceInfoPlugin().androidInfo).supportedAbis;
        abi = abis.isNotEmpty ? abis.first : '';
      }
      await ApiClient.dio.post('/go/api/app/report-version', data: {
        'platform': Platform.isIOS ? 'ios' : 'android',
        'version': i.version,
        'build': int.tryParse(i.buildNumber) ?? 0,
        'abi': abi,
      });
    } catch (_) {
      _reported = false; // دفعهٔ بعد دوباره
    }
  }

  /// [manual] = از دکمهٔ پروفایل: «بعداً» نادیده گرفته می‌شود و نتیجه (حتی «آخرین نسخه را دارید») اعلام می‌شود.
  static Future<void> check(BuildContext context, {bool manual = false}) async {
    if (_busy) return;
    if (!Platform.isAndroid) {
      if (manual) _toast(context, 'به‌روزرسانی درون‌برنامه فقط برای اندروید است.');
      return;
    }
    _busy = true;
    try {
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;

      final res = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 10),
        responseType: ResponseType.plain,
      )).get(_latestUrl, queryParameters: {'t': DateTime.now().millisecondsSinceEpoch});
      final j = jsonDecode(res.data.toString()) as Map<String, dynamic>;
      final latest = (j['build'] as num?)?.toInt() ?? 0;
      final minBuild = (j['min_build'] as num?)?.toInt() ?? 0;

      if (latest <= current) {
        if (manual && context.mounted) _toast(context, 'آخرین نسخه را دارید (${info.version}).');
        return;
      }
      final forced = current < minBuild;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (!forced && !manual) {
        final snooze = await _storage.read(key: _snoozeKey);
        if (snooze == '$today:$latest') return; // امروز «بعداً» زده
      }

      final file = await _pickFile(j['files']);
      if (file == null) {
        if (manual && context.mounted) _toast(context, 'فایلِ مناسبِ این گوشی پیدا نشد.');
        return;
      }
      if (!context.mounted) return;
      final ok = await _askUser(context, j['version']?.toString() ?? '', j['notes']?.toString() ?? '', forced);
      if (!ok) {
        await _storage.write(key: _snoozeKey, value: '$today:$latest');
        return;
      }
      if (!context.mounted) return;
      await _downloadAndInstall(context, file, latest, forced);
    } catch (e) {
      if (manual && context.mounted) _toast(context, 'بررسی به‌روزرسانی ممکن نشد؛ اینترنت را بررسی کنید.');
    } finally {
      _busy = false;
    }
  }

  /// فایلِ مناسبِ پردازندهٔ گوشی (۶۴ بیتی اول)
  static Future<Map<String, dynamic>?> _pickFile(dynamic files) async {
    if (files is! Map) return null;
    final abis = (await DeviceInfoPlugin().androidInfo).supportedAbis;
    for (final abi in ['arm64-v8a', 'armeabi-v7a']) {
      if (abis.contains(abi) && files[abi] is Map) {
        return Map<String, dynamic>.from(files[abi] as Map);
      }
    }
    return null;
  }

  static Future<bool> _askUser(BuildContext context, String version, String notes, bool forced) async {
    final r = await showDialog<bool>(
      context: context,
      barrierDismissible: !forced,
      builder: (ctx) => PopScope(
        canPop: !forced,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(forced ? 'به‌روزرسانی لازم است' : 'نسخهٔ جدید آماده است'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(forced
                      ? 'برای ادامهٔ کار با برنامه، نسخهٔ $version را نصب کنید.'
                      : 'نسخهٔ $version برنامه منتشر شده است.'),
                  if (notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('تغییرات:', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(notes.trim()),
                  ],
                ],
              ),
            ),
            actions: [
              if (!forced)
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('بعداً')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _purple),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('به‌روزرسانی'),
              ),
            ],
          ),
        ),
      ),
    );
    return r == true;
  }

  static Future<void> _downloadAndInstall(
      BuildContext context, Map<String, dynamic> file, int build, bool forced) async {
    final progress = ValueNotifier<double>(0);
    final cancel = CancelToken();
    var dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('در حال دانلود نسخهٔ جدید'),
            content: ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (_, v, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: v > 0 ? v : null, color: _purple),
                  const SizedBox(height: 10),
                  Text('${(v * 100).round()}٪'),
                ],
              ),
            ),
            actions: [
              if (!forced)
                TextButton(
                  onPressed: () {
                    cancel.cancel();
                    dialogOpen = false;
                    Navigator.pop(ctx);
                  },
                  child: const Text('انصراف'),
                ),
            ],
          ),
        ),
      ),
    );

    void closeDialog() {
      if (dialogOpen && context.mounted) {
        dialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/bpm-update-$build.apk';
      await Dio().download(
        file['url'].toString(),
        path,
        cancelToken: cancel,
        onReceiveProgress: (got, total) {
          if (total > 0) progress.value = got / total;
        },
      );
      final expected = (file['size'] as num?)?.toInt() ?? 0;
      if (expected > 0 && await File(path).length() != expected) {
        throw Exception('size');
      }
      closeDialog();
      final r = await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
      if (r.type != ResultType.done && context.mounted) {
        _toast(context, 'برای نصب، اجازهٔ «نصب از این برنامه» را در تنظیمات گوشی بدهید و دوباره امتحان کنید.');
      }
    } catch (e) {
      closeDialog();
      if (!cancel.isCancelled && context.mounted) {
        _toast(context, 'دانلود نسخهٔ جدید ناموفق بود؛ دوباره امتحان کنید.');
      }
    }
  }

  static void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(msg, textDirection: TextDirection.rtl)),
    );
  }
}
