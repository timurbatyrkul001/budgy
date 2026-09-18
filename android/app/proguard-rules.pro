# Flutter + Firebase için varsayılan kurallar yeterli; aşağıdakiler
# R8'in yansıma (reflection) ile kullanılan sınıfları silmesini engeller.

# flutter_local_notifications zamanlanmış bildirimleri Gson ile saklıyor.
-keep class com.dexterous.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keepattributes Signature
-keepattributes *Annotation*

# Firebase model sınıfları yansıma ile okunur.
-keepnames class com.google.firebase.** { *; }
