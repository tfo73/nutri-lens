# General rules
-keepattributes Signature,*Annotation*,EnclosingMethod,InnerClasses

# Flutter Local Notifications rules
-keep class com.dexterous.** { *; }

# Gson rules
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken { *; }
-keepclassmembers class * extends com.google.gson.reflect.TypeToken {
    <init>(...);
}
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Google Sign In / Play Services Auth rules
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.**
