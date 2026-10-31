import '../network/api_client.dart';

/// 🔧 آفلاین سبک: بعد از این‌که یک لیست کار با موفقیت لود شد، جزئیات
/// کامل هر کار را هم در پس‌زمینه (بدون این‌که کاربر منتظر بماند) کش
/// می‌کند — تا وقتی کاربر بعداً آفلاین شد و برای اولین‌بار روی یک کار
/// از همین لیست بزند، صفحه‌ی جزئیات خالی نباشد.
///
/// عمداً یکی‌یکی (نه هم‌زمان) اجرا می‌شود تا فشار ناگهانی روی سرور
/// نیاورد — چون این کار در پس‌زمینه انجام می‌شود، سرعتش برای کاربر مهم
/// نیست. این تابع را بدون await صدا بزنید (fire-and-forget).
///
/// 🔧 کارایی: قبلاً با هر بازشدن یا تازه‌شدنِ لیست، برایِ همه‌ی کارها دوباره
/// درخواست می‌رفت. حالا هر کار در هر اجرایِ اپ یک‌بار، حداکثر [_maxPerRun] کار
/// در هر نوبت، با مکث بینِ درخواست‌ها تا اپ و شبکه درگیر نمانند.
const _maxPerRun = 15;
final Set<String> _preloaded = {};

Future<void> preloadTaskDetails(List<dynamic> tasks) async {
  var count = 0;
  for (final task in tasks) {
    final id = task['id'];
    if (id == null || !_preloaded.add(id.toString())) continue;
    if (++count > _maxPerRun) {
      _preloaded.remove(id.toString());
      break;
    }
    await Future.delayed(const Duration(milliseconds: 400));
    try {
      final res = await ApiClient.dio.get(
        '/api/tasks/detail.php',
        queryParameters: {'id': id},
      );
      if (res.data['success'] == true) {
        await ApiClient.saveOfflineCache('task_detail_$id', {
          'task': res.data['task'],
          'history': res.data['history'] ?? [],
          'can_edit': res.data['can_edit'] == true,
        });
      }
    } catch (_) {
      // پیش‌بارگیری یک کار نباید بقیه یا خودِ صفحه را متوقف کند
    }
  }
}
