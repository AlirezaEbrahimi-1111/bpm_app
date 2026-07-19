import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/persian_number.dart';
import '../tasks/task_detail_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const _primary = Color(0xFF6D28D9);
  static const _ink = Color(0xFF1A1A2E);

  List<dynamic> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = true;
  String _searchQuery = '';
  String _timeFilter = 'همه';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  List<dynamic> get _filteredNotifications {
    var list = List<dynamic>.from(_notifications);

    if (_timeFilter != 'همه') {
      final now = DateTime.now();
      list = list.where((n) {
        final dateStr = n['created_at']?.toString();
        if (dateStr == null) return false;
        try {
          final date = DateTime.parse(dateStr);
          if (_timeFilter == 'امروز') {
            return date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;
          } else if (_timeFilter == 'هفته جاری') {
            final diff = now.difference(date).inDays;
            return diff < 7;
          }
        } catch (_) {
          return false;
        }
        return true;
      }).toList();
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

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.dio.get('/api/notifications/list.php');
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        setState(() {
          _notifications = data['notifications'] ?? [];
          _unreadCount = data['unread_count'] ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
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
        Get.snackbar(
          '✅ موفق',
          'همه اعلان‌ها خوانده شد',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      }
    } catch (e) {
      Get.snackbar(
        'خطا',
        'خطا در اتصال به سرور',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  void _onNotificationTap(Map<String, dynamic> notif) async {
    final isRead = notif['is_read'] == 1 || notif['is_read'] == true;
    if (!isRead) {
      _markAsRead(notif['id']);
      setState(() => notif['is_read'] = 1);
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
    return Container(
      color: const Color(0xFFF7F7FB),
      child: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : Column(
                children: [
                  // عنوان + خواندن همه
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'اعلان‌ها',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: _ink,
                          ),
                        ),
                        if (_unreadCount > 0)
                          TextButton(
                            onPressed: _markAllRead,
                            child: const Text(
                              'خواندن همه',
                              style: TextStyle(color: _primary, fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // جستجو
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'جستجو در اعلان‌ها...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.grey.shade400,
                          size: 22,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: Colors.grey.shade400,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  // فیلترهای زمانی
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: ['همه', 'امروز', 'هفته جاری'].map((f) {
                        final selected = _timeFilter == f;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _timeFilter = f),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: selected ? _primary : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                f,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // لیست
                  Expanded(
                    child: RefreshIndicator(
                      color: _primary,
                      onRefresh: _loadNotifications,
                      child: _filteredNotifications.isEmpty
                          ? _buildEmpty()
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                              itemCount: _filteredNotifications.length,
                              itemBuilder: (ctx, i) =>
                                  _buildNotifCard(_filteredNotifications[i]),
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmpty() => ListView(
    children: [
      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
      Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFF0EEFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 48,
                color: _primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'اعلانی وجود ندارد',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildNotifCard(Map<String, dynamic> notif) {
    final isRead = notif['is_read'] == 1 || notif['is_read'] == true;
    final type = notif['type'] as String? ?? 'info';
    final ti = _typeInfo(type);

    return GestureDetector(
      onTap: () => _onNotificationTap(notif),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF0EEFF),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: ti.$1.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(ti.$2, color: ti.$1, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif['title'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isRead
                                ? FontWeight.w600
                                : FontWeight.bold,
                            color: _ink,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: _primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif['message'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    toPersianDigits(_timeAgo(notif['created_at']?.toString())),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, IconData) _typeInfo(String type) => switch (type) {
    'success' => (const Color(0xFF22C55E), Icons.check_circle_outline),
    'warning' => (const Color(0xFFF59E0B), Icons.warning_amber_rounded),
    'error' => (const Color(0xFFEF4444), Icons.error_outline),
    _ => (const Color(0xFF6D28D9), Icons.info_outline),
  };
}
