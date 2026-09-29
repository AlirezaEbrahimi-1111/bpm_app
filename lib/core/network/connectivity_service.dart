import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';

/// نظارت زنده روی وضعیت اتصال — بدون نیاز به هیچ پکیج جدید (فقط dart:io).
///
/// هر چند ثانیه یک‌بار (فقط وقتی اپ در پیش‌زمینه است) با یک DNS lookup
/// سبک به دامنه‌ی سرور اپ چک می‌کند که آیا اینترنت وصل است یا نه، و از
/// طریق ValueNotifier به کل اپ خبر می‌دهد. این یعنی اگر کاربر وسط کار
/// اینترنتش قطع شود، صفحه‌ی باز نیازی به یک درخواست ناموفق ندارد تا
/// متوجه‌ی آفلاین‌بودن بشود — خودش زودتر می‌فهمد.
class ConnectivityService with WidgetsBindingObserver {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  static const _checkHost = 'bpm.itmalek.com';
  static const _checkInterval = Duration(seconds: 10);

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  Timer? _timer;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _check();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_checkInterval, (_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _check();
      _startTimer();
    } else if (state == AppLifecycleState.paused) {
      // در پس‌زمینه نیازی به چک دوره‌ای نیست — باتری صرفه‌جویی شود
      _timer?.cancel();
    }
  }

  Future<void> _check() async {
    try {
      final result = await InternetAddress.lookup(
        _checkHost,
      ).timeout(const Duration(seconds: 5));
      isOnline.value = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      isOnline.value = false;
    }
  }
}
