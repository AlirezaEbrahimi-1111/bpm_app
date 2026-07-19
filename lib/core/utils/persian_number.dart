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
