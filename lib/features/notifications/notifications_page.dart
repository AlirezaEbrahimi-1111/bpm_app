import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/widgets/app_snack.dart';
import 'package:dio/dio.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/persian_number.dart';
import '../../core/theme/app_colors.dart';
import '../tasks/task_detail_page.dart';
import '../shell/widgets/nav_bar_metrics.dart';

class NotificationsPage extends StatefulWidget {
  // 🔧 اصلاح: با این callback، هر وقت تعداد اعلان‌های نخوانده تغییر کند
  // (بارگذاری اول، خوانده‌شدن یک اعلان، یا «همه را خوانده کن»)،
  // به بیرون (پوسته‌ی اصلی اپ) خبر می‌دهیم تا روی آیکون زنگوله، عدد
  // اعلان‌های نخوانده نشان داده شود.
  final ValueChanged<int>? onUnreadCountChanged;
  const NotificationsPage({super.key, this.onUnreadCountChanged});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<dynamic> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = true;
  String _searchQuery = '';
  // 🔧 اصلاح: فیلتر زمانی قبلی (امروز/هفته جاری) با فیلتر
  // خوانده‌نشده/همه جایگزین شد؛ گروه‌بندی بر اساس روز حالا جدا (همیشه
  // فعال) و به‌صورت سرتیترهای «امروز»/«دیروز»/تاریخ انجام می‌شود.
  String _readFilter = 'همه';
  final _searchController = TextEditingController();

  // 🔧 آفلاین سبک: آفلاین هستیم ولی هنوز هیچ کشی از قبل نداریم — نوار
  // «بدون اینترنت» خودش سطح بالاتر (در MainShell) نمایش داده می‌شود؛
  // این پرچم فقط برای توضیح این‌جا که چرا لیست خالی است لازم است.
  bool _offlineNoCache = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredNotifications {
    var list = List<dynamic>.from(_notifications);

    if (_readFilter == 'خوانده‌نشده') {
      list = list
          .where((n) => !(n['is_read'] == 1 || n['is_read'] == true))
          .toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim();
      list = list.where((n) {
        final title = (n['title'] ?? '').toString();
        final message = (n['message'] ?? '').toString();
        return title.contains(q) || message.contains(q);
      }).toList();
    }

    return list;
  }

  // 🔧 گروه‌بندی بر اساس روز — امروز/دیروز/تاریخ شمسی
  List<(String, List<dynamic>)> get _groupedNotifications {
    final list = _filteredNotifications;
    final now = DateTime.now();
    final groups = <String, List<dynamic>>{};

    for (final n in list) {
      final dateStr = n['created_at']?.toString();
      String label = '';
      if (dateStr != null) {
        try {
          final d = DateTime.parse(dateStr);
          final today = DateTime(now.year, now.month, now.day);
          final that = DateTime(d.year, d.month, d.day);
          final diff = today.difference(that).inDays;
          if (diff == 0) {
            label = 'امروز';
          } else if (diff == 1) {
            label = 'دیروز';
          } else {
            final j = Jalali.fromDateTime(d);
            const mo = [
              'فروردین',
              'اردیبهشت',
              'خرداد',
              'تیر',
              'مرداد',
              'شهریور',
              'مهر',
              'آبان',
              'آذر',
              'دی',
              'بهمن',
              'اسفند',
            ];
            label = toPersianDigits('${j.day} ${mo[j.month - 1]}');
          }
        } catch (_) {
          label = 'قدیمی‌تر';
        }
      } else {
        label = 'قدیمی‌تر';
      }
      groups.putIfAbsent(label, () => []).add(n);
    }
    return groups.entries.map((e) => (e.key, e.value)).toList();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.dio.get('/api/notifications/list.php');
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        final notifications = data['notifications'] ?? [];
        final unreadCount = data['unread_count'] ?? 0;
        setState(() {
          _notifications = notifications;
          _unreadCount = unreadCount;
          _offlineNoCache = false;
          _isLoading = false;
        });
        widget.onUnreadCountChanged?.call(_unreadCount);
        // 🔧 آفلاین سبک: کش آخرین اعلان‌های موفق، فقط برای مشاهده وقتی
        // بعداً اینترنت نبود
        ApiClient.saveOfflineCache('notifications', {
          'notifications': notifications,
          'unread_count': unreadCount,
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      final cached = await ApiClient.readOfflineCache('notifications');
      if (mounted) {
        if (cached != null && cached['data'] is Map) {
          final data = cached['data'] as Map;
          setState(() {
            _notifications = data['notifications'] ?? [];
            _unreadCount = data['unread_count'] ?? 0;
            _offlineNoCache = false;
            _isLoading = false;
          });
          widget.onUnreadCountChanged?.call(_unreadCount);
        } else {
          setState(() {
            _isLoading = false;
            _offlineNoCache = e is DioException && e.response == null;
          });
        }
      }
    }
  }

  Future<void> _markAsRead(int notifId) async {
    try {
      await ApiClient.dio.post(
        '/api/notifications/mark-read.php',
        data: {'notification_id': notifId},
      );
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      final res = await ApiClient.dio.post(
        '/api/notifications/mark-all-read.php',
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        _loadNotifications();
        AppSnack.success('✅ موفق', 'همه اعلان‌ها خوانده شد');
      }
    } catch (e) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  void _onNotificationTap(Map<String, dynamic> notif) async {
    final isRead = notif['is_read'] == 1 || notif['is_read'] == true;
    if (!isRead) {
      _markAsRead(notif['id']);
      setState(() {
        notif['is_read'] = 1;
        if (_unreadCount > 0) _unreadCount--;
      });
      widget.onUnreadCountChanged?.call(_unreadCount);
    }
    if (notif['related_type'] == 'task' && notif['related_id'] != null) {
      final taskId = int.tryParse(notif['related_id'].toString());
      if (taskId != null) {
        await Get.to(() => TaskDetailPage(taskId: taskId));
        _loadNotifications();
      }
    }
  }

  String _timeAgo(String? gregorian) {
    if (gregorian == null || gregorian.isEmpty) return '';
    try {
      final date = DateTime.parse(gregorian);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'همین الان';
      if (diff.inMinutes < 60) return '${diff.inMinutes} دقیقه پیش';
      if (diff.inHours < 24) return '${diff.inHours} ساعت پیش';
      if (diff.inDays < 7) return '${diff.inDays} روز پیش';
      final j = Jalali.fromDateTime(date);
      const mo = [
        'فروردین',
        'اردیبهشت',
        'خرداد',
        'تیر',
        'مرداد',
        'شهریور',
        'مهر',
        'آبان',
        'آذر',
        'دی',
        'بهمن',
        'اسفند',
      ];
      return '${j.day} ${mo[j.month - 1]}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      color: c.bgPage,
      child: SafeArea(
        bottom: false,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: c.primary))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'اعلان‌ها',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: c.textStrong,
                        ),
                      ),
                    ),
                  ),
                  // جستجو
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: TextStyle(color: c.textStrong, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'جستجو در اعلان‌ها...',
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
                  // فیلتر خوانده‌نشده/همه
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: ['همه', 'خوانده‌نشده'].map((f) {
                        final selected = _readFilter == f;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _readFilter = f),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: c.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? c.primary
                                        : Colors.transparent,
                                    width: 1.3,
                                  ),
                                ),
                                child: Text(
                                  f,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: selected ? c.primary : c.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // لیست گروه‌بندی‌شده بر اساس روز
                  Expanded(
                    child: RefreshIndicator(
                      color: c.primary,
                      onRefresh: _loadNotifications,
                      child: _filteredNotifications.isEmpty
                          ? _buildEmpty(c)
                          : _buildGroupedList(c),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildGroupedList(AppColors c) {
    final groups = _groupedNotifications;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomNavClearance(context)),
      itemCount: groups.length,
      itemBuilder: (ctx, gi) {
        final (label, items) = groups[gi];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: c.textStrong,
                    ),
                  ),
                  // 🔧 «خواندن همه» فقط کنار اولین سرتیتر (نه هر گروه)
                  if (gi == 0 && _unreadCount > 0)
                    GestureDetector(
                      onTap: _markAllRead,
                      child: Row(
                        children: [
                          Text(
                            'خواندن همه',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: c.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: c.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            ...items.map((n) => _buildNotifCard(c, n)),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }

  Widget _buildEmpty(AppColors c) => ListView(
    children: [
      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
      Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _offlineNoCache
                    ? c.borderSoft.withValues(alpha: 0.4)
                    : c.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _offlineNoCache
                    ? Icons.wifi_off_rounded
                    : Icons.notifications_none_rounded,
                size: 48,
                color: _offlineNoCache ? c.textMuted : c.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _offlineNoCache
                  ? 'هنوز داده‌ای برای نمایش آفلاین ذخیره نشده'
                  : 'اعلانی وجود ندارد',
              style: TextStyle(color: c.textMuted, fontSize: 15),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildNotifCard(AppColors c, Map<String, dynamic> notif) {
    final isRead = notif['is_read'] == 1 || notif['is_read'] == true;
    final icon = _iconFor(notif);

    return GestureDetector(
      onTap: () => _onNotificationTap(notif),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead
                ? Colors.transparent
                : c.primary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔧 آیکون گرد بنفش — سمت راست (بدون سایه)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif['title'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                      color: c.textStrong,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif['message'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textMuted,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    toPersianDigits(_timeAgo(notif['created_at']?.toString())),
                    style: TextStyle(fontSize: 11, color: c.textMuted),
                  ),
                ],
              ),
            ),
            // نقطه‌ی نخوانده — سمت چپ
            SizedBox(
              width: 14,
              child: !isRead
                  ? Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: c.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // 🔧 انتخاب آیکون بر اساس کلیدواژه‌های عنوان/متن اعلان — چون فیلد
  // دقیقِ دسته‌بندی (مثل sms_pattern) در پاسخ API فعلاً در دسترس نیست؛
  // تلاشِ منطقی برای تطبیق با ظاهر طرح (کلیپ‌بورد/ساعت/فرآیند/سند)
  IconData _iconFor(Map<String, dynamic> notif) {
    final text = '${notif['title'] ?? ''} ${notif['message'] ?? ''}';
    if (text.contains('واگذار') || text.contains('ارجاع')) {
      return Icons.assignment_turned_in_outlined;
    }
    if (text.contains('مهلت') ||
        text.contains('موعد') ||
        text.contains('تمدید')) {
      return Icons.access_time_rounded;
    }
    if (text.contains('فرآیند') ||
        text.contains('مرحله') ||
        text.contains('روتین')) {
      return Icons.swap_horiz_rounded;
    }
    if (text.contains('تأیید') ||
        text.contains('درخواست') ||
        text.contains('رد شد')) {
      return Icons.fact_check_outlined;
    }
    return Icons.notifications_rounded;
  }
}
