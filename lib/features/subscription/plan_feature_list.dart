import 'package:flutter/material.dart';
import '../../core/plan/plan_access.dart';

/// آیکن + برچسبِ یک ردیف در فهرستِ «امکانات و قابلیت‌ها»یِ یک پلن.
///
/// 🔧 طبق درخواست: این فهرست‌ها قبلاً سه‌بار (در صفحه‌ی خریدِ طلایی/نقره‌ای،
/// صفحه‌ی پلنِ رایگان، و حالا در شیتِ «جزئیاتِ پلنِ فعلی») تکرار می‌شدند؛
/// این‌جا یک‌بار تعریف شده تا هر سه نقطه از همین منبعِ واحد بخوانند.
typedef PlanFeatureEntry = (IconData, String);

const List<PlanFeatureEntry> goldPlanFeatures = [
  (Icons.add_task_rounded, 'ایجاد کار (مقطعی، دوره‌ای)'),
  (Icons.task_alt_rounded, 'مشاهده و مدیریت کارها'),
  (Icons.flag_outlined, 'تعیین اولویت برای کارها'),
  (Icons.play_circle_outline_rounded, 'شروع و تکمیل کار'),
  (Icons.checklist_rounded, 'افزودن چک‌لیست گام‌به‌گام برای هر کار'),
  (Icons.notes_rounded, 'درج توضیح برای کار'),
  (Icons.attach_file_rounded, 'پیوست‌کردن و ارسال فایل برای هر کار'),
  (Icons.folder_copy_outlined, 'گروه‌بندی کارها برای دسته‌بندی بهتر'),
  (Icons.filter_list_rounded, 'فیلتر پیشرفته بر اساس وضعیت و اولویت'),
  (Icons.history_rounded, 'نمایش جزئیات و تاریخچه‌ی کامل کارها'),
  (Icons.search_rounded, 'جستجوی سریع در میان همه‌ی کارها'),
  (Icons.calendar_view_week_rounded, 'نمای برنامه‌ی روزانه، هفتگی، ماهانه'),
  (Icons.wifi_rounded, 'همگام‌سازی آنی اطلاعات به‌صورت آنلاین'),
  (Icons.person_add_alt_1_outlined, 'ایجاد کار برای همکاران'),
  (
    Icons.notifications_active_outlined,
    'اعلان‌های لحظه‌ای برای کارها و رویدادها',
  ),
  (Icons.dashboard_customize_outlined, 'داشبورد مدیریتی'),
  (Icons.visibility_outlined, 'نظارت بر کارهای واحدها'),
  (Icons.insights_rounded, 'تحلیل گلوگاه‌ها'),
  (Icons.analytics_outlined, 'مانیتورینگ روتین‌ها'),
  (Icons.people_alt_outlined, 'نمایش کاربران و کارهای دارای تأخیر'),
  (
    Icons.account_tree_outlined,
    'تعریف کار روتین چندمرحله‌ای (آبشاری، موازی)',
  ),
  (Icons.send_rounded, 'ارجاع بی‌نهایت کار به فرد یا واحد'),
  (Icons.schema_outlined, 'تعریف واحدهای درون‌سازمانی'),
  (Icons.forum_outlined, 'پیام‌رسان درون‌سازمانی'),
  (Icons.description_outlined, 'لاگ کامل مستندات'),
  (Icons.devices_outlined, 'دسترسی به پنل وب'),
];

const List<PlanFeatureEntry> silverPlanFeatures = [
  (Icons.add_task_rounded, 'ایجاد کار (مقطعی، دوره‌ای)'),
  (Icons.task_alt_rounded, 'مشاهده و مدیریت کارها'),
  (Icons.flag_outlined, 'تعیین اولویت برای کارها'),
  (Icons.play_circle_outline_rounded, 'شروع و تکمیل کار'),
  (Icons.checklist_rounded, 'افزودن چک‌لیست گام‌به‌گام برای هر کار'),
  (Icons.notes_rounded, 'درج توضیح برای کار'),
  (Icons.attach_file_rounded, 'پیوست‌کردن و ارسال فایل برای هر کار'),
  (Icons.folder_copy_outlined, 'گروه‌بندی کارها برای دسته‌بندی بهتر'),
  (Icons.filter_list_rounded, 'فیلتر پیشرفته بر اساس وضعیت و اولویت'),
  (Icons.history_rounded, 'نمایش جزئیات و تاریخچه‌ی کامل کارها'),
  (Icons.search_rounded, 'جستجوی سریع در میان همه‌ی کارها'),
  (Icons.calendar_view_week_rounded, 'نمای برنامه‌ی روزانه، هفتگی، ماهانه'),
  (Icons.wifi_rounded, 'همگام‌سازی آنی اطلاعات به‌صورت آنلاین'),
  (Icons.person_add_alt_1_outlined, 'ایجاد کار برای همکاران'),
];

const List<PlanFeatureEntry> freePlanFeatures = [
  (Icons.add_task_rounded, 'ایجاد کار (مقطعی، دوره‌ای)'),
  (Icons.task_alt_rounded, 'مشاهده و مدیریت کارها'),
  (Icons.flag_outlined, 'تعیین اولویت برای کارها'),
  (Icons.play_circle_outline_rounded, 'شروع و تکمیل کار'),
  (Icons.checklist_rounded, 'افزودن چک‌لیست گام‌به‌گام برای هر کار'),
  (Icons.notes_rounded, 'درج توضیح برای کار'),
  (Icons.attach_file_rounded, 'پیوست‌کردن و ارسال فایل برای هر کار'),
  (Icons.folder_copy_outlined, 'گروه‌بندی کارها برای دسته‌بندی بهتر'),
  (Icons.filter_list_rounded, 'فیلتر پیشرفته بر اساس وضعیت و اولویت'),
  (Icons.history_rounded, 'نمایش جزئیات و تاریخچه‌ی کامل کارها'),
  (Icons.search_rounded, 'جستجوی سریع در میان همه‌ی کارها'),
];

List<PlanFeatureEntry> planFeatureList(PlanLevel level) => switch (level) {
  PlanLevel.gold => goldPlanFeatures,
  PlanLevel.silver => silverPlanFeatures,
  PlanLevel.free => freePlanFeatures,
};
