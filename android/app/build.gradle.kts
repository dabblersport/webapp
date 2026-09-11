import java.util.Properties
import java.io.FileInputStream

// Signing credentials live in android/key.properties, which is gitignored and
// injected from CI secrets. They are never literals in this tracked file.
// See docs/DECISIONS.md T-003.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // Kotlin is applied by the Flutter Gradle Plugin (built-in Kotlin) — do
    // not apply kotlin-android here.
    // The Flutter Gradle Plugin must be applied after the Android plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.dabbler.dabblerapp"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Required for some libraries (e.g. flutter_local_notifications) that
        // use newer Java APIs on older Android versions.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.dabbler.dabblerapp"
        minSdk = flutter.minSdkVersion // pinned: existing Play Store APKs require minSdk 21
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    
    signingConfigs {
        create("release") {
            // Falls back to nothing when key.properties is absent: a release
            // build then fails loudly rather than silently signing with debug.
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        // Must match compileOptions source/target compatibility above.
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring to support newer Java language APIs
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    // AndroidX Activity for enableEdgeToEdge() backward compatibility (Android 15+)
    implementation("androidx.activity:activity-ktx:1.9.3")
}
