import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import 'my_tasks_page.dart';
import '../shell/widgets/app_bottom_nav.dart';
import '../../core/navigation/app_nav.dart';

/// «کارهای واگذارشده» — 🔧 طبق درخواست، عیناً مثلِ «مدیریت کارها»: همان
/// صفحه‌ی «کارها» با همان جستجو، کارت‌هایِ آماری، فیلترِ گروه و شیتِ
/// فیلترها (پرسنل/وضعیت/اولویت/نوع)، به‌علاوه‌ی «ارجاعات سابق» مثلِ نسخه‌ی
/// وب — فقط منبعِ داده /api/tasks/delegated-tasks.php است. از دراور باز می‌شود.
class DelegatedTasksPage extends StatelessWidget {
  final Map<String, dynamic>? user;
  const DelegatedTasksPage({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final u = user ?? ApiClient.currentUser ?? const <String, dynamic>{};
    return AppShellOverlays(
      child: Scaffold(
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
            icon: Transform.rotate(
              angle: math.pi,
              child: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
            ),
            onPressed: () => AppNav.back(),
          ),
        ),
        body: MyTasksPage(user: u, delegatedMode: true),
        floatingActionButton: const AppCreateTaskFab(),
        floatingActionButtonLocation: const LoweredDockedFabLocation(),
        // محتوا زیرِ نوار هم ادامه دارد تا محوشدنِ دورِ نوار دیده شود
        extendBody: true,
        bottomNavigationBar: const AppBottomNav(),
      ),
    );
  }
}
