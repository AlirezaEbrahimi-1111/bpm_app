# SDK متریکس (از طریقِ Apache Tika) به javax.xml.stream ارجاع می‌دهد که
# روی اندروید وجود ندارد و هرگز صدا زده نمی‌شود — بدونِ این R8 بیلدِ
# release را می‌شکند
-dontwarn javax.xml.stream.**

# طبقِ مستنداتِ متریکس
-keep class ir.metrix.** { *; }
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
