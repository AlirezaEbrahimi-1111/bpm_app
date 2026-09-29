import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/task_labels.dart';
import '../../../core/utils/task_search.dart';
import '../../tasks/task_detail_page.dart';

/// کادرِ جستجویِ سراسری — با دکمه‌ی «فلش رو به بالا»ی شناور در همه‌ی
/// صفحات باز می‌شود. بین «کارها» و «اعلامیه‌ها» جستجو می‌کند (داده‌ی
/// خودش را مستقل از صفحه‌ی جاری می‌گیرد، چون این دکمه در پوسته‌ی اصلی
/// است، نه داخل یک تبِ خاص).
///
/// 🔧 توجه: فیلتر «فرآیندهای جاری» که در طرح اولیه بود، فعلاً کنار
/// گذاشته شده چون هیچ داده‌ی معادلی در اپ نداریم.
Future<void> showGlobalSearchSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // 🔧 barrier خودِ مودال دیگر تیره نکند — همان جلوه را با
    // BackdropFilter (مات/بلور) پایین‌تر می‌سازیم
    barrierColor: Colors.transparent,
    builder: (ctx) => Stack(
      children: [
        // پس‌زمینه‌ی مات‌شده — با ضربه هم بسته می‌شود، مثل بیرونِ کادر
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: Colors.black.withValues(alpha: 0.25)),
            ),
          ),
        ),
        const _GlobalSearchSheet(),
      ],
    ),
  );
}

class _GlobalSearchSheet extends StatefulWidget {
  const _GlobalSearchSheet();

  @override
  State<_GlobalSearchSheet> createState() => _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends State<_GlobalSearchSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  String _query = '';
  String _filter = 'کارها'; // پیش‌فرض مثل طرح
  bool _isLoading = true;

  List<dynamic> _tasks = [];
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_fetchTasks(), _fetchNotifications()]);
      if (!mounted) return;
      setState(() {
        _tasks = results[0];
        _notifications = results[1];
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<dynamic>> _fetchTasks() async {
    try {
      final res = await ApiClient.dio.get('/api/tasks/my-tasks.php');
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        final list = data['data']?['tasks'];
        return list is List ? list : [];
      }
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> _fetchNotifications() async {
    try {
      final res = await ApiClient.dio.get('/api/notifications/list.php');
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        final list = data['notifications'];
        return list is List ? list : [];
      }
    } catch (_) {}
    return [];
  }

  bool _notifMatches(dynamic n, String q) {
    final title = (n['title'] ?? '').toString().toLowerCase();
    final message = (n['message'] ?? '').toString().toLowerCase();
    return title.contains(q.toLowerCase()) || message.contains(q.toLowerCase());
  }

  List<dynamic> get _results {
    if (_filter == 'کارها') {
      if (_query.trim().isEmpty) return _tasks.take(5).toList();
      return _tasks.where((t) => taskMatchesQuery(t, _query)).toList();
    }
    if (_query.trim().isEmpty) return _notifications.take(5).toList();
    return _notifications.where((n) => _notifMatches(n, _query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    final keyboardOpen = keyboard > 0;
    // 🔧 رفعِ خطای «bottom overflowed» و پنهان‌شدن زیرِ صفحه‌کلید: فاصله‌ی
    // صفحه‌کلید حالا «بیرونِ» DraggableScrollableSheet اعمال می‌شود، پس
    // ارتفاعِ کادر (کسری از فضای باقی‌مانده) خودش کوچک می‌شود و ستونِ
    // داخلش هرگز از جایش بیشتر نمی‌گیرد. وقتی صفحه‌کلید باز است، کادر
    // ۱۵٪ ارتفاعِ صفحه هم بالاتر از صفحه‌کلید می‌نشیند (عدد ۰.۱۵ پایین)
    // تا در گوشی‌هایی که صفحه‌کلیدشان کمی بالاتر می‌آید هم پنهان نشود.
    // فاصله‌ی اضافه‌ی کادر از صفحه‌کلید، به‌صورت کسری از ارتفاعِ صفحه. ۰ یعنی
    // کادر مستقیم روی صفحه‌کلید می‌نشیند؛ اگر در گوشی‌ای زیرِ صفحه‌کلید
    // رفت، عددی مثل ۰.۰۵ بگذارید.
    const liftFraction = 0.0;
    final lift = keyboardOpen ? mq.size.height * liftFraction : 0.0;
    // نوارِ وضعیتِ واقعی (مودال padding بالا را حذف می‌کند)
    final view = View.of(context);
    final statusBar = view.padding.top / view.devicePixelRatio;
    // 🔧 رفعِ پرشِ کیبورد: قبلاً با عوض‌شدنِ key، کلِ کادر (و فیلدِ متن)
    // هر بار ساخته و فوکوس گم می‌شد و کیبورد بلافاصله بسته می‌شد. حالا
    // درخت ثابت است و فقط ارتفاعِ کادر عوض می‌شود.
    final availableHeight = mq.size.height - keyboard - lift - statusBar - 8;
    final sheetHeight = keyboardOpen ? availableHeight : mq.size.height * 0.5;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard + lift),
        child: SizedBox(
          height: sheetHeight,
          child: Builder(
            builder: (ctx) => Container(
              decoration: BoxDecoration(
                // 🔧 طبق M3، شیت پایین‌رونده باید سطحی مرتفع‌تر از bgPage باشد
                color: c.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.borderSoft,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Icon(Icons.close_rounded, color: c.textMuted),
                        ),
                        Expanded(
                          child: Text(
                            'جستجو',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: c.textStrong,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24), // موازنه با دکمه‌ی بستن
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _controller,
                      onChanged: (v) => setState(() => _query = v),
                      style: TextStyle(color: c.textStrong, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'جستجوی وظیفه یا اطلاعیه',
                        hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: c.textMuted,
                        ),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: c.textMuted,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _controller.clear();
                                  setState(() => _query = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: c.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _chip(c, 'کارها'),
                        const SizedBox(width: 8),
                        _chip(c, 'اطلاعیه‌ها'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_query.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 15,
                            color: c.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'پیشنهادات اخیر',
                            style: TextStyle(fontSize: 12, color: c.textMuted),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(color: c.primary),
                          )
                        : _buildResults(c, _scrollController),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(AppColors c, String label) {
    final selected = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? c.primary : c.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : c.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildResults(AppColors c, ScrollController scrollController) {
    final results = _results;
    if (results.isEmpty) {
      return Center(
        child: Text(
          'نتیجه‌ای یافت نشد',
          style: TextStyle(color: c.textMuted, fontSize: 13),
        ),
      );
    }
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: results.length,
      itemBuilder: (ctx, i) => _filter == 'کارها'
          ? _taskResultRow(c, results[i])
          : _notifResultRow(c, results[i]),
    );
  }

  Widget _taskResultRow(AppColors c, dynamic task) {
    final subtitle = (task['status'] != null) ? _statusSubtitle(task) : '';
    return _resultRow(
      c: c,
      icon: Icons.task_alt_rounded,
      title: task['title'] ?? '',
      subtitle: subtitle,
      onTap: () {
        Navigator.of(context).pop();
        Get.to(() => TaskDetailPage(taskId: task['id']));
      },
    );
  }

  String _statusSubtitle(dynamic task) {
    final status = task['status'];
    final priority = task['priority'];
    const priorityLabels = {
      'high': 'اولویت بالا',
      'medium': 'اولویت متوسط',
      'low': 'اولویت پایین',
    };
    final parts = [
      TaskLabels.statusLabel(status?.toString()),
      if (priorityLabels.containsKey(priority)) priorityLabels[priority]!,
    ].where((s) => s.isNotEmpty).toList();
    return parts.join(' • ');
  }

  Widget _notifResultRow(AppColors c, dynamic notif) {
    return _resultRow(
      c: c,
      icon: Icons.notifications_rounded,
      title: notif['title'] ?? '',
      subtitle: (notif['message'] ?? '').toString(),
      onTap: () {
        Navigator.of(context).pop();
        final taskId = int.tryParse(notif['related_id']?.toString() ?? '');
        if (notif['related_type'] == 'task' && taskId != null) {
          Get.to(() => TaskDetailPage(taskId: taskId));
        }
      },
    );
  }

  Widget _resultRow({
    required AppColors c,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: c.iconAccent, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: c.textStrong,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: c.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.more_vert_rounded, color: c.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
