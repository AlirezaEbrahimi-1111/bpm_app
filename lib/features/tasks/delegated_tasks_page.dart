import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import 'task_detail_page.dart';
import '../../core/utils/task_search.dart';
import '../../core/utils/task_preload.dart';
import 'widgets/task_list_card.dart';

class DelegatedTasksPage extends StatefulWidget {
  const DelegatedTasksPage({super.key});

  @override
  State<DelegatedTasksPage> createState() => _DelegatedTasksPageState();
}

class _DelegatedTasksPageState extends State<DelegatedTasksPage> {
  List<dynamic> _tasks = [];
  bool _isLoading = true;
  String? _loadError;

  String _filter = 'همه';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final res = await ApiClient.dio.get('/api/tasks/delegated-tasks.php');
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        final list = data['tasks'];
        _tasks = list is List ? List<dynamic>.from(list) : [];
        // 🔧 آفلاین سبک: کش آخرین لیست موفق، فقط برای مشاهده وقتی
        // بعداً اینترنت نبود
        ApiClient.saveOfflineCache('delegated_tasks', _tasks);
        // 🔧 آفلاین سبک: جزئیات کامل هر کار هم در پس‌زمینه کش شود — بدون
        // await، تا لود لیست منتظرش نماند
        preloadTaskDetails(_tasks);
      } else {
        _loadError = data['message']?.toString() ?? 'خطا در دریافت کارها';
      }
    } catch (e) {
      final cached = await ApiClient.readOfflineCache('delegated_tasks');
      if (cached != null && cached['data'] is List) {
        _tasks = List<dynamic>.from(cached['data']);
      } else {
        _loadError = (e is DioException && e.response == null)
            ? 'اینترنت ندارید و هنوز داده‌ای برای نمایش آفلاین ذخیره نشده'
            : 'خطا در اتصال به سرور';
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<dynamic> get _filteredTasks {
    var list = List<dynamic>.from(_tasks);

    if (_filter == 'در جریان') {
      // 🔧 اصلاح: قبلاً هر وضعیتی غیر از completed/approved (حتی
      // «شروع نشده» و «ارجاع شده») این‌جا نمایش داده می‌شد. الان فقط
      // کارهایی که واقعاً «در حال انجام»ند نشان داده می‌شوند.
      list = list.where((t) => t['status'] == 'in_progress').toList();
    } else if (_filter == 'تکمیل شده') {
      list = list
          .where((t) => t['status'] == 'completed' || t['status'] == 'approved')
          .toList();
    } else if (_filter == 'منتظر تأیید') {
      list = list.where((t) => t['status'] == 'pending_approval').toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      list = list.where((t) => taskMatchesQuery(t, _searchQuery)).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // 🔧 رفعِ باگ: این صفحه از دراور به‌صورت push باز می‌شود، ولی
    // Scaffold/AppBar (و در نتیجه دکمه‌ی برگشت) نداشت — کاربر فقط با
    // اشاره/دکمه‌ی سیستمی می‌توانست برگردد. حالا مثلِ بقیه‌ی صفحاتِ
    // push‌شده (پروفایل/تنظیمات/...) هدرِ خودش را دارد و کاملاً با
    // AppColors هماهنگ (تمِ روشن/تاریک) است.
    return Scaffold(
      backgroundColor: c.bgPage,
      appBar: AppBar(
        backgroundColor: c.bgPage,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: c.textStrong),
        title: Text(
          'کارهای واگذارشده',
          style: TextStyle(
            color: c.textStrong,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          // 🔧 طبق درخواست: فلش ۱۸۰ درجه چرخید
          icon: Transform.rotate(
            angle: math.pi,
            child: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : Column(
              children: [
                // جستجو
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(color: c.textStrong, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'جستجو در عنوان یا نام مسئول...',
                      hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: c.textMuted,
                        size: 22,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: c.textMuted,
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: c.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: c.borderSoft),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: c.borderSoft),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: c.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                // فیلترها
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: ['همه', 'در جریان', 'منتظر تأیید', 'تکمیل شده']
                        .map((f) {
                          final selected = _filter == f;
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _filter = f),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: selected ? c.primary : c.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected ? c.primary : c.borderSoft,
                                  ),
                                ),
                                child: Text(
                                  f,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : c.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          );
                        })
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                // لیست
                Expanded(
                  child: RefreshIndicator(
                    color: c.primary,
                    onRefresh: _loadTasks,
                    child: _loadError != null
                        ? _buildErrorView(c)
                        : _filteredTasks.isEmpty
                        ? _buildEmpty(c)
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              20,
                              0,
                              20,
                              20 + MediaQuery.of(context).padding.bottom,
                            ),
                            itemCount: _filteredTasks.length,
                            itemBuilder: (ctx, i) =>
                                _buildTaskCard(c, _filteredTasks[i]),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildErrorView(AppColors c) => ListView(
    children: [
      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
      Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: c.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded, size: 48, color: c.danger),
            ),
            const SizedBox(height: 16),
            Text(
              _loadError ?? 'خطا',
              style: TextStyle(color: c.textMuted, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadTasks,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('تلاش مجدد'),
              style: TextButton.styleFrom(foregroundColor: c.primary),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildEmpty(AppColors c) => ListView(
    children: [
      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
      Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.send_outlined, size: 48, color: c.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'کار واگذارشده‌ای وجود ندارد',
              style: TextStyle(color: c.textMuted, fontSize: 15),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildTaskCard(AppColors c, Map<String, dynamic> task) {
    // 🔧 طبق درخواست: دقیقاً همان کارتِ صفحه‌ی «کارها»
    return TaskListCard(
      task: task,
      onChanged: _loadTasks,
      onTap: () async {
        final result = await Get.to(() => TaskDetailPage(taskId: task['id']));
        if (result == true) _loadTasks();
      },
    );
  }
}
