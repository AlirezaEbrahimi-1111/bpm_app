import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../dashboard/dashboard_page.dart';
import '../tasks/my_tasks_page.dart';
import '../tasks/delegated_tasks_page.dart';
import '../notifications/notifications_page.dart';
import '../tasks/create_task_page.dart';
import 'app_drawer.dart';

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

  late final List<Widget> _pages;

  // باز کردن Drawer — به صفحات پاس داده می‌شود
  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardPage(
        key: _dashboardKey,
        user: widget.user,
        onMenuTap: _openDrawer,
      ),
      MyTasksPage(key: _myTasksKey, user: widget.user, onMenuTap: _openDrawer),
      const DelegatedTasksPage(),
      const NotificationsPage(),
    ];
  }

  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);
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
      body: IndexedStack(index: _selectedIndex, children: _pages),
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              label: 'داشبورد',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.task_alt_rounded),
              label: 'کارهای من',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.send_rounded),
              label: 'واگذارشده',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_rounded),
              label: 'اعلان‌ها',
            ),
          ],
        ),
      ),
    );
  }
}
