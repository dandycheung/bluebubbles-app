# Gson model classes (android/app/src/main/kotlin/.../network/ApiModels.kt) rely on
# reflection over field names, so keep fields/annotations from being renamed or stripped.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep class com.bluebubbles.messaging.services.network.** { *; }

# Retrofit (BlueBubblesApi.kt) resolves service methods via annotations at runtime.
-keepattributes Exceptions
-keep class retrofit2.** { *; }
-keepclasseswithmembers class * {
    @retrofit2.http.* <methods>;
}
-dontwarn retrofit2.**
-dontwarn okhttp3.**
-dontwarn okio.**

# Firebase (Messaging/Database/Firestore) uses reflection for POJO (de)serialization.
-keepattributes *Annotation*
-keepclassmembers class * {
    @com.google.firebase.database.PropertyName <methods>;
    @com.google.firebase.database.PropertyName <fields>;
}
-dontwarn com.google.firebase.**

# ObjectBox generated entities/cursors are constructed reflectively by the core lib.
-keep class io.objectbox.** { *; }
-keep @io.objectbox.annotation.Entity class * { *; }
-keepclassmembers class * {
    @io.objectbox.annotation.* <fields>;
}

# ML Kit (smart reply / entity extraction) ships a native (JNI) layer that looks up
# Java classes/methods/fields by exact name (e.g. libpredictor_jni.so calling into
# PredictorJni). Renaming those classes desyncs the native side from the obfuscated
# Java layout and segfaults instead of throwing, so keep the whole surface untouched.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_smart_reply.** { *; }
-keep class com.google.android.gms.internal.mlkit_entity_extraction.** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keepclasseswithmembers class * {
    native <methods>;
}
-dontwarn com.google.mlkit.**

# Socket.IO client
-dontwarn org.json.**

# Kotlin coroutines debug hooks aren't present at runtime.
-dontwarn kotlinx.coroutines.debug.**
