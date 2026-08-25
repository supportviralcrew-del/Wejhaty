# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Play Core (for Flutter deferred components)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Google Maps
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Geolocator
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Lottie
-keep class com.airbnb.lottie.** { *; }
-dontwarn com.airbnb.lottie.**

# Keep model classes
-keep class com.wejhaty.app.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep serialization classes
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses

# Remove logging
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
}
