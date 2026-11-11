import 'package:flutter_test/flutter_test.dart';
import 'package:bpm_app/core/utils/task_search.dart';

void main() {
  final tasks = [
    {'id': 1, 'title': 'بررسی نام شرکت ها در یکتا'},
    {'id': 2, 'title': 'پیگیری واریز حواله شرکت برای رضا'},
    {'id': 3, 'title': 'بررسی نام شرکت‌ها در تهران'},
  ];

  test('«شرکت»: کلمهٔ کامل بالاتر از «شرکت ها» / «شرکت‌ها»', () {
    final r = rankTasksBySearch(tasks, 'شرکت').map((t) => t['id']).toList();
    expect(r.first, 2);
  });

  test('«شرکت ها»: عنوان‌های جمع اول، هم‌امتیازها از الف تا ی', () {
    final r = rankTasksBySearch(tasks, 'شرکت ها').map((t) => t['id']).toList();
    expect(r, [3, 1, 2]); // «...در تهران» پیش از «...در یکتا»
  });

  test('ترتیب الفبای فارسی و عددی', () {
    final names = ['یکتا', 'پیگیری', 'بررسی', 'آب', 'الف', 'چک', 'تست 10', 'تست 2', 'گل', 'کار'];
    names.sort(compareFaText);
    expect(names, ['آب', 'الف', 'بررسی', 'پیگیری', 'تست 2', 'تست 10', 'چک', 'کار', 'گل', 'یکتا']);
  });
}
