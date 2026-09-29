import 'package:flutter/material.dart';

/// سوییچِ استانداردِ کل اپ — طبق درخواست، حدود ۳۰٪ کوچک‌تر از سوییچِ
/// پیش‌فرضِ متریال و یک‌اندازه در همه‌جا. به‌جای هر بار `Switch(...)`ی
/// جداگانه، همه‌جا از همین ویجت استفاده شود تا اگر بعداً اندازه یا
/// سبکش عوض شد، فقط یک‌جا نیاز به تغییر باشد.
class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color activeColor;

  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.7,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: activeColor,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
