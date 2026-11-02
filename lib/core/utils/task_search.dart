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

/// امتیازِ داشتنِ عینِ عبارت؛ هر فیلدِ پایین‌تر (مثلاً توضیحات بعد از عنوان)
/// یک پله پایین‌تر است، ولی همیشه بالاتر از مطابقتِ کلمه‌به‌کلمه می‌ماند
double _phraseScore(String q, String text, int fieldIndex) {
  if (text.isEmpty || !text.contains(q)) return 0;
  return (_hasWholeWord(text, q) ? 900 : 800) - fieldIndex * 200.0;
}

double _wordsScore(List<String> words, String text, int fieldIndex) {
  final found = words.where(text.contains).length;
  if (found == 0) return 0;
  final whole = words.where((w) => _hasWholeWord(text, w)).length;
  return (250 * found / words.length + 50 * whole / words.length) /
      (fieldIndex + 1);
}

/// 🔧 طبق درخواست: اول مواردی که عینِ عبارت را دارند، بعد مواردی که بیشترِ
/// کلمه‌ها را دارند. در امتیازِ برابر ترتیبِ خودِ فهرست (تاریخ/مهلت) حفظ می‌شود.
/// [fields] به ترتیبِ اهمیت است (مثلاً عنوان، بعد توضیحات). [exactKey] مثلِ
/// شناسه، با برابریِ کامل همیشه اول است.
List<T> rankBySearch<T>(
  Iterable<T> items,
  String query,
  List<String> Function(T item) fields, {
  String Function(T item)? exactKey,
}) {
  final q = normalizeSearchText(query);
  if (q.isEmpty) return items.toList();
  final words = _queryWords(q);
  final scored = <(T, double, int)>[];
  var index = 0;
  for (final item in items) {
    final values = fields(item).map(normalizeSearchText).toList();
    var score = 0.0;
    for (var i = 0; i < values.length; i++) {
      final phrase = _phraseScore(q, values[i], i);
      final s = phrase > 0 ? phrase : _wordsScore(words, values[i], i);
      if (s > score) score = s;
    }
    if (exactKey != null && normalizeSearchText(exactKey(item)) == q) {
      score = 2000;
    }
    scored.add((item, score, index++));
  }
  scored.sort((a, b) {
    final byScore = b.$2.compareTo(a.$2);
    return byScore != 0 ? byScore : a.$3.compareTo(b.$3);
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
