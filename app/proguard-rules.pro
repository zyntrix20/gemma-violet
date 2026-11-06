# LiteRT-LM использует JNI — сохраняем его классы целиком
-keep class com.google.ai.edge.litertlm.** { *; }
-keep class com.google.protobuf.** { *; }
-keepclassmembers class * { native <methods>; }
-keepattributes Signature,*Annotation*,InnerClasses,EnclosingMethod

-dontwarn com.google.ai.edge.litertlm.**
-dontwarn com.google.protobuf.**
-ignorewarnings
