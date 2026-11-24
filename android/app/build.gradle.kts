import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val flutterLocalProperties = Properties().apply {
    rootProject.file("local.properties").inputStream().use { load(it) }
}
val flutterSdkRoot = flutterLocalProperties.getProperty("flutter.sdk")
    ?: error("flutter.sdk is missing from android/local.properties")
val arm64FlutterEngineJar = file(
    "$flutterSdkRoot/bin/cache/artifacts/engine/android-arm64-release/flutter.jar"
)
val generatedFlutterJniLibs = layout.buildDirectory.dir("generated/flutter-jni-libs")
val copyArm64FlutterEngine = tasks.register<Copy>("copyArm64FlutterEngine") {
    from(zipTree(arm64FlutterEngineJar)) {
        include("lib/arm64-v8a/libflutter.so")
        eachFile { path = "arm64-v8a/libflutter.so" }
        includeEmptyDirs = false
    }
    into(generatedFlutterJniLibs)
}

android {
    namespace = "com.example.safezone"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.example.safezone"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    sourceSets.getByName("main").jniLibs.srcDir(generatedFlutterJniLibs.get().asFile)

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

tasks.named("preBuild").configure {
    dependsOn(copyArm64FlutterEngine)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
