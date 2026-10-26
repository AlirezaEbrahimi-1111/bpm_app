import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/persian_number.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/navigation/app_nav.dart';

/// سه‌راهیِ افزودنِ پیوست — طبق درخواست: هم انتخابِ فایلِ موجود، هم
/// گرفتنِ عکسِ مستقیم با دوربین، هم ضبطِ صدای مستقیم با میکروفون؛ هر
/// سه مسیر یک خروجیِ یکسان (PlatformFile یا null اگر لغو شود) برمی‌گردانند
/// تا تماس‌گیرنده با یک مسیرِ آپلودِ واحد کار کند.
/// مدت‌زمانِ صدایِ ضبط‌شده با همین اپ — به خودِ PlatformFile چسبانده
/// می‌شود (Expando) تا لیستِ پیوست‌ها بتواند «زمان + حجم» را نشان دهد
final Expando<Duration> recordedDuration = Expando<Duration>('voiceDuration');

const _audioExts = {'mp3', 'm4a', 'ogg', 'aac', 'wav'};

bool isAudioAttachment(PlatformFile f) =>
    _audioExts.contains((f.extension ?? f.name.split('.').last).toLowerCase());

/// حجم به‌صورتِ خوانا: «۸۵۰ KB» / «۲٫۴ MB»
///
/// 🔧 طبق درخواست: واحد بعد از عدد (در خواندنِ راست‌به‌چپ). بدونِ نشانه‌ی
/// RLM، الگوریتمِ bidi عددِ فارسی و «KB» را در یک بلوکِ چپ‌به‌راست کنارِ هم
/// می‌گذاشت و واحد قبل از عدد خوانده می‌شد
const _rlm = '\u200F';
String formatFileSize(int bytes) {
  String withUnit(String n, String unit) => '${toPersianDigits(n)}$_rlm $unit';
  if (bytes < 1024) return withUnit('$bytes', 'B');
  final kb = bytes / 1024;
  if (kb < 1024) return withUnit('${kb.round()}', 'KB');
  final mb = kb / 1024;
  return withUnit(mb.toStringAsFixed(mb < 10 ? 1 : 0), 'MB');
}

/// «حجم» برایِ همه؛ برایِ صدایِ ضبط‌شده «۰۱:۲۳ · ۲۵۰ KB»
String attachmentMeta(PlatformFile f) {
  final size = formatFileSize(f.size);
  final d = recordedDuration[f];
  if (d == null) return size;
  final m = d.inMinutes.toString().padLeft(2, '0');
  final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '${toPersianDigits('$m:$sec')}$_rlm · $size';
}

/// 🔧 رفعِ باگ: بعد از ضبطِ صدا/انتخابِ فایل، فوکوس به فیلدِ قبلی (مثلاً
/// «عنوان کار») برمی‌گشت و صفحه‌کلید باز می‌شد — چون فلاتر بعد از بسته‌شدنِ
/// هر شیت، فوکوسِ قبلی را بازمی‌گرداند. حالا قبل از باز کردن و بعد از پایانِ
/// کار، فوکوس کاملاً برداشته می‌شود و هیچ فیلدی فوکوس نمی‌گیرد
Future<PlatformFile?> showAttachmentSourceSheet(
  BuildContext context, {
  List<String>? allowedExtensions,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  try {
    return await _showAttachmentSourceSheet(
      context,
      allowedExtensions: allowedExtensions,
    );
  } finally {
    // بعد از بسته‌شدنِ آخرین شیت (ضبط/دوربین/فایل‌پیکر) هم دوباره
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => FocusManager.instance.primaryFocus?.unfocus(),
    );
    FocusManager.instance.primaryFocus?.unfocus();
  }
}

Future<PlatformFile?> _showAttachmentSourceSheet(
  BuildContext context, {
  List<String>? allowedExtensions,
}) async {
  final c = AppColors.of(context);
  // 🔧 شیت فقط انتخابِ «منبع» را برمی‌گرداند؛ خودِ عملیات (فایل‌پیکر/
  // دوربین/ضبط) بعد از بسته‌شدنِ شیت اجرا می‌شود — چون ضبطِ صدا خودش
  // یک شیتِ دیگر باز می‌کند و تویِ همدیگر تداخل پیدا می‌کردند
  final choice = await Get.bottomSheet<String>(
    Container(
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        0,
        12,
        0,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: c.borderSoft,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'افزودن پیوست',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: c.textStrong,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.folder_outlined, color: c.primary),
            title: Text(
              'انتخاب از فایل‌ها',
              style: TextStyle(fontSize: 14, color: c.textStrong),
            ),
            onTap: () => AppNav.back(result: 'file'),
          ),
          ListTile(
            leading: Icon(Icons.camera_alt_outlined, color: c.primary),
            title: Text(
              'گرفتن عکس با دوربین',
              style: TextStyle(fontSize: 14, color: c.textStrong),
            ),
            onTap: () => AppNav.back(result: 'camera'),
          ),
          ListTile(
            leading: Icon(Icons.mic_none_rounded, color: c.primary),
            title: Text(
              'ضبط صدا',
              style: TextStyle(fontSize: 14, color: c.textStrong),
            ),
            onTap: () => AppNav.back(result: 'audio'),
          ),
        ],
      ),
    ),
    backgroundColor: Colors.transparent,
  );

  switch (choice) {
    case 'file':
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions == null ? FileType.any : FileType.custom,
        allowedExtensions: allowedExtensions,
        withData: true,
      );
      return (result != null && result.files.isNotEmpty)
          ? result.files.first
          : null;
    case 'camera':
      return pickCameraPhoto();
    case 'audio':
      if (!context.mounted) return null;
      return showAudioRecorderSheet(context);
    default:
      return null;
  }
}

/// گرفتنِ عکس با دوربین و تبدیلِ آن به PlatformFile (همانِ نوعی که
/// file_picker برمی‌گرداند) تا مسیرِ آپلود مشترک بماند.
Future<PlatformFile?> pickCameraPhoto() async {
  try {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    final name = picked.name.isNotEmpty
        ? picked.name
        : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    return PlatformFile(name: name, size: bytes.length, bytes: bytes);
  } catch (_) {
    AppSnack.error('خطا', 'خطا در گرفتن عکس با دوربین');
    return null;
  }
}

/// شیتِ ضبطِ صدا — شروعِ خودکارِ ضبط با بازشدن، نمایشِ تایمر، و
/// دکمه‌های توقف/لغو/ارسال. خروجی: PlatformFileِ فایلِ صوتیِ ضبط‌شده
/// (فرمتِ m4a — طبقِ بک‌اند مجاز) یا null اگر لغو شود.
Future<PlatformFile?> showAudioRecorderSheet(BuildContext context) {
  return Get.bottomSheet<PlatformFile?>(
    const _AudioRecorderSheet(),
    backgroundColor: Colors.transparent,
    isDismissible: false,
  );
}

class _AudioRecorderSheet extends StatefulWidget {
  const _AudioRecorderSheet();

  @override
  State<_AudioRecorderSheet> createState() => _AudioRecorderSheetState();
}

class _AudioRecorderSheetState extends State<_AudioRecorderSheet> {
  final _recorder = AudioRecorder();
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _isRecording = false;
  bool _isStopped = false;
  bool _isStarting = false;
  String? _path;

  // 🔧 طبق درخواست: ضبط دیگر با بازشدنِ شیت خودکار شروع نمی‌شود — اول
  // «شروع / لغو»، بعد از شروع «توقف / لغو»، بعد از توقف «ارسال / لغو»

  Future<void> _start() async {
    if (_isStarting || _isRecording) return;
    setState(() => _isStarting = true);
    try {
      if (!await _recorder.hasPermission()) {
        AppSnack.error('خطا', 'دسترسی میکروفون داده نشد');
        AppNav.back();
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      setState(() {
        _isRecording = true;
        _isStarting = false;
        _path = path;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsed += const Duration(seconds: 1));
      });
    } catch (_) {
      AppSnack.error('خطا', 'خطا در شروع ضبط صدا');
      if (mounted) AppNav.back();
    } finally {
      if (mounted && _isStarting) setState(() => _isStarting = false);
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await _recorder.stop();
    setState(() {
      _isRecording = false;
      _isStopped = true;
    });
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    if (_isRecording) await _recorder.stop();
    final path = _path;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
    if (mounted) AppNav.back();
  }

  Future<void> _send() async {
    final path = _path;
    if (path == null) {
      AppNav.back();
      return;
    }
    final file = File(path);
    final bytes = await file.readAsBytes();
    if (mounted) {
      // 🔧 طبق درخواست: نامِ کوتاه‌تر — «voice-143052.m4a» (ساعت، دقیقه، ثانیه)
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final picked = PlatformFile(
        name: 'voice-${two(now.hour)}${two(now.minute)}${two(now.second)}.m4a',
        size: bytes.length,
        bytes: bytes,
      );
      recordedDuration[picked] = _elapsed;
      AppNav.back(result: picked);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _isRecording
                  ? c.danger.withValues(alpha: 0.12)
                  : c.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mic_rounded,
              size: 30,
              color: _isRecording ? c.danger : c.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _fmt(_elapsed),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: c.textStrong,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isRecording
                ? 'در حال ضبط...'
                : _isStopped
                ? 'ضبط متوقف شد'
                : 'برای شروع ضبط، «شروع» را بزنید',
            style: TextStyle(fontSize: 12.5, color: c.textMuted),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(color: c.borderSoft),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text('لغو', style: TextStyle(color: c.textMuted)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isStarting
                      ? null
                      : _isRecording
                      ? _stop
                      : (_isStopped ? _send : _start),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _isRecording
                        ? 'توقف'
                        : _isStopped
                        ? 'ارسال'
                        : 'شروع',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
