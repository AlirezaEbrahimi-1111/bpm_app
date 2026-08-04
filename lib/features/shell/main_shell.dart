import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import '../../core/network/api_client.dart';
import '../../core/utils/persian_number.dart';
import '../dashboard/dashboard_page.dart';
import '../tasks/my_tasks_page.dart';
import '../tasks/delegated_tasks_page.dart';
import '../notifications/notifications_page.dart';
import '../tasks/create_task_page.dart';
import 'app_drawer.dart';
import 'widgets/app_top_bar.dart';

/// پوسته اصلی اپ: نوار پایین ثابت + جابجایی بین تب‌ها + Drawer
class MainShell extends StatefulWidget {
  final Map<String, dynamic> user;
  const MainShell({super.key, required this.user});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const _primary = Color(0xFF6D28D9);

  // کلید Scaffold برای باز کردن Drawer از داخل صفحات
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // کلید برای دسترسی به state هر تب (برای refresh بعد از ساخت کار)
  final _myTasksKey = GlobalKey<MyTasksPageState>();
  final _dashboardKey = GlobalKey<DashboardPageState>();

  // 🔧 کنترلر PageView — برای این‌که با کشیدن (swipe) هم بشود بین تب‌ها
  // جابه‌جا شد، نه فقط با ضربه روی نوار پایین یا Drawer
  final _pageController = PageController();

  late final List<Widget> _pages;

  // 🔧 اصلاح: تعداد اعلان‌های نخوانده — برای نشان دادن روی آیکون زنگوله
  int _unreadCount = 0;
  Timer? _unreadPollTimer;

  // باز کردن Drawer — به صفحات پاس داده می‌شود
  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardPage(key: _dashboardKey, user: widget.user),
      MyTasksPage(key: _myTasksKey, user: widget.user),
      const DelegatedTasksPage(),
      NotificationsPage(
        onUnreadCountChanged: (count) {
          if (mounted) setState(() => _unreadCount = count);
        },
      ),
    ];

    // 🔧 همان لحظه‌ی باز شدن اپ، یک‌بار تعداد نخوانده‌ها را می‌گیریم...
    _loadUnreadCount();
    // ...و بعد هر ۳۰ ثانیه دوباره چک می‌کنیم، تا حتی وقتی کاربر توی
    // تبِ اعلان‌ها نیست هم، عدد روی زنگوله به‌روز بماند.
    _unreadPollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadUnreadCount(),
    );
  }

  @override
  void dispose() {
    _unreadPollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final res = await ApiClient.dio.get('/api/notifications/list.php');
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true && mounted) {
        setState(() => _unreadCount = data['unread_count'] ?? 0);
      }
    } catch (_) {
      // خطای شمارش اعلان نباید کل اپ را مختل کند
    }
  }

  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _openCreateTask() async {
    final result = await Get.to(
      () => CreateTaskPage(
        userRole: widget.user['role'] ?? '',
        currentUserId: widget.user['id'],
      ),
    );
    if (result == true) {
      _dashboardKey.currentState?.reload();
      _myTasksKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF7F7FB),
      drawer: AppDrawer(
        user: widget.user,
        currentIndex: _selectedIndex,
        onTabSelected: _onTabTapped,
      ),
      // 🔧 اصلاح: دکمه‌ی همبرگری و آیکون پروفایل حالا بیرون از PageView
      // و فقط یک‌بار رندر می‌شوند — مثل هدر یک سایت، ثابت می‌مانند و با
      // جابه‌جایی/کشیدن بین تب‌ها تکان نمی‌خورند؛ فقط محتوای زیرشان عوض
      // می‌شود.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTopBar(user: widget.user, onMenuTap: _openDrawer),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) =>
                    setState(() => _selectedIndex = index),
                children: _pages,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateTask,
        backgroundColor: _primary,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: _primary,
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFamily: 'Vazir',
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontFamily: 'Vazir',
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              label: 'داشبورد',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.task_alt_rounded),
              label: 'کارهای من',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.send_rounded),
              label: 'واگذارشده',
            ),
            BottomNavigationBarItem(
              icon: _buildNotificationIcon(),
              label: 'اعلان‌ها',
            ),
          ],
        ),
      ),
    );
  }

  // 🔧 اصلاح: آیکون زنگوله + نقطه‌ی قرمزِ شمارنده‌ی اعلان‌های نخوانده
  Widget _buildNotificationIcon() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_rounded),
        if (_unreadCount > 0)
          Positioned(
            right: -7,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                _unreadCount > 99
                    ? '${toPersianDigits('99')}+'
                    : toPersianDigits(_unreadCount.toString()),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
