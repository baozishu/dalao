# Flutter 混淆规则
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Google Play Core (修复 R8 编译错误)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# 保留 FlutterPlayStoreSplitApplication
-keep class io.flutter.app.FlutterPlayStoreSplitApplication { *; }
