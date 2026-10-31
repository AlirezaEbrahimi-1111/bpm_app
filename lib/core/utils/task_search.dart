/// نرمال‌سازی ارقام فارسی و عربی به ارقام لاتین.
///
/// این‌طوری جستجوی «۱» (فارسی)، «١» (عربی) و «1» (لاتین) دقیقاً همان
/// نتیجه را می‌دهد — بدون این تابع مقایسه‌ی رشته‌ای این سه را متفاوت
/// می‌دید.
String _normalizeDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(rune - 0x06F0 + 0x30); // ۰-۹ فارسی
    } else if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(rune - 0x0660 + 0x30); // ٠-٩ عربی
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// ارقام لاتین، ی/ک فارسی، نیم‌فاصله مثلِ فاصله، بدونِ حساسیت به بزرگی حروف
String normalizeSearchText(String input) => _normalizeDigits(input)
    .replaceAll('\u200c', ' ')
    .replaceAll('ي', 'ی')
    .replaceAll('ك', 'ک')
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

List<String> _queryWords(String normalized) =>
    normalized.split(' ').where((w) => w.isNotEmpty).toList();

bool _isDigits(String word) => RegExp(r'^\d+$').hasMatch(word);

/// 🔧 طبق درخواست: موردی در نتیجه می‌آید که کلِ عبارت یا دست‌کم یکی از
/// کلمه‌های اصلیِ آن را داشته باشد؛ ترتیبِ نتایج را [rankBySearch] می‌سازد.
/// کلمه‌های کوتاه مثلِ «ها» به‌تنهایی موردی را واردِ نتیجه نمی‌کنند.
bool searchMatches(String query, Iterable<String> fields) {
  final q = normalizeSearchText(query);
  if (q.isEmpty) return true;
  final text = normalizeSearchText(fields.join(' '));
  if (text.contains(q)) return true;
  final words = _queryWords(q);
  final main = words.where((w) => w.length >= 3 || _isDigits(w)).toList();
  if (main.isEmpty) return words.every(text.contains);
  return main.any(text.contains);
}

bool _hasWholeWord(String text, String phrase) =>
    ' $text '.contains(' $phrase ');

double _fieldScore(String q, List<String> words, String text) {
  if (text.isEmpty) return 0;
  if (text == q) return 1000;
  if (text.startsWith('$q ')) return 950;
  if (_hasWholeWord(text, q)) return 900;
  if (text.startsWith(q)) return 850;
  if (text.contains(q)) return 800;
  final found = words.where(text.contains).length;
  if (found == 0) return 0;
  final whole = words.where((w) => _hasWholeWord(text, w)).length;
  return 700 * found / words.length + 50 * whole / words.length;
}

/// 🔧 طبق درخواست: نزدیک‌ترین نتیجه به عبارتِ جستجو اول می‌آید. ترتیب:
/// برابریِ کامل، شروع با عبارت، داشتنِ کلِ عبارت، سپس تعدادِ کلمه‌های پیدا‌شده.
/// [fields] به ترتیبِ اهمیت است (مثلاً عنوان، بعد توضیحات) و در امتیازِ برابر
/// متنِ کوتاه‌تر جلوتر است. [exactKey] مثلِ شناسه، با برابریِ کامل همیشه اول است.
List<T> rankBySearch<T>(
  Iterable<T> items,
  String query,
  List<String> Function(T item) fields, {
  String Function(T item)? exactKey,
}) {
  final q = normalizeSearchText(query);
  if (q.isEmpty) return items.toList();
  final words = _queryWords(q);
  final scored = <(T, double, int, int)>[];
  var index = 0;
  for (final item in items) {
    final values = fields(item).map(normalizeSearchText).toList();
    var score = 0.0;
    for (var i = 0; i < values.length; i++) {
      final s = _fieldScore(q, words, values[i]) / (i + 1);
      if (s > score) score = s;
    }
    if (exactKey != null && normalizeSearchText(exactKey(item)) == q) {
      score = 2000;
    }
    final length = values.isEmpty ? 0 : values.first.length;
    scored.add((item, score, length, index++));
  }
  scored.sort((a, b) {
    final byScore = b.$2.compareTo(a.$2);
    if (byScore != 0) return byScore;
    final byLength = a.$3.compareTo(b.$3);
    return byLength != 0 ? byLength : a.$4.compareTo(b.$4);
  });
  return scored.map((e) => e.$1).toList();
}

bool taskMatchesQuery(Map task, String query) => searchMatches(query, [
  (task['id'] ?? '').toString(),
  (task['title'] ?? '').toString(),
  (task['description'] ?? '').toString(),
  (task['history_text'] ?? '').toString(),
]);

List<dynamic> rankTasksBySearch(Iterable<dynamic> tasks, String query) =>
    rankBySearch<dynamic>(
      tasks,
      query,
      (t) => [
        (t['title'] ?? '').toString(),
        (t['description'] ?? t['snippet'] ?? '').toString(),
        (t['history_text'] ?? '').toString(),
      ],
      exactKey: (t) => (t['id'] ?? '').toString(),
    );
