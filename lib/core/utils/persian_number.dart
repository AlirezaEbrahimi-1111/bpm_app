import 'package:flutter/services.dart';

/// تبدیل اعداد انگلیسی به فارسی در هر متن
String toPersianDigits(dynamic input) {
  if (input == null) return '';
  String text = input.toString();
  const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  for (int i = 0; i < en.length; i++) {
    text = text.replaceAll(en[i], fa[i]);
  }
  return text;
}

/// تبدیل اعداد فارسی به انگلیسی — قبل از parse کردن یا ارسال به سرور لازم است
String toEnglishDigits(dynamic input) {
  if (input == null) return '';
  String text = input.toString();
  const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  for (int i = 0; i < fa.length; i++) {
    text = text.replaceAll(fa[i], en[i]);
  }
  return text;
}

/// برایِ فیلدهایِ عددیِ قابلِ‌ویرایش: هرچه تایپ شود (رقمِ انگلیسی یا
/// فارسی) بلافاصله به رقمِ فارسی نمایش داده می‌شود؛ چون تبدیل رقم‌به‌رقم
/// است و طولِ متن را عوض نمی‌کند، موقعیتِ نشانگر هم دست‌نخورده می‌ماند
class PersianDigitsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: toPersianDigits(newValue.text));
  }
}

/// رقم‌هایِ خالص (فقط ۰-۹ انگلیسی) را در گروه‌هایِ سه‌تایی با کاما جدا می‌کند
String groupThousands(String digitsOnly) {
  final buf = StringBuffer();
  for (int i = 0; i < digitsOnly.length; i++) {
    if (i > 0 && (digitsOnly.length - i) % 3 == 0) buf.write(',');
    buf.write(digitsOnly[i]);
  }
  return buf.toString();
}

/// برایِ فیلدهایِ مبلغیِ بزرگ (مثلِ مبالغِ ریالی): همزمان با تایپ،
/// رقم‌ها (فارسی یا انگلیسی) با کاما گروه‌بندی و با رقمِ فارسی نمایش
/// داده می‌شوند. نشانگر همیشه به انتها می‌رود — چون معمولاً وسطِ یک
/// مبلغ ویرایش نمی‌شود، ساده‌ترین رفتارِ قابلِ‌اعتماد همین است
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = toEnglishDigits(
      newValue.text,
    ).replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final display = toPersianDigits(groupThousands(digitsOnly));
    return TextEditingValue(
      text: display,
      selection: TextSelection.collapsed(offset: display.length),
    );
  }
}
