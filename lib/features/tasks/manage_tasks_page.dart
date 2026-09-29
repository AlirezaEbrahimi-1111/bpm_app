import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import 'my_tasks_page.dart';

/// «مدیریت کارها» — همان صفحه‌ی «کارها» با همان امکانات، ولی روی
/// فهرستِ کاملِ کارهایی که کاربر اجازه‌ی دیدنشان را دارد (API نسخه‌ی وب:
/// /api/tasks/all-tasks.php). از منوی دراور باز می‌شود.
class ManageTasksPage extends StatelessWidget {
  final Map<String, dynamic> user;
  const ManageTasksPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bgPage,
      appBar: AppBar(
        backgroundColor: c.bgPage,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: c.textStrong),
        title: Text(
          'مدیریت کارها',
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
          onPressed: () => Get.back(),
        ),
      ),
      body: MyTasksPage(user: user, manageMode: true),
    );
  }
}
