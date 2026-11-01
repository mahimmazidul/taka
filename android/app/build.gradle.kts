import java.io.FileInputStream
import java.util.Properties

// ── release signing ─────────────────────────────────────────────────────────
// The key lives outside the repository, always. Two sources, in this order:
//   1. android/key.properties  (local builds; git-ignored)
//   2. environment variables   (GitHub Actions secrets)
// Without either, we fall back to the debug key and say so loudly — a release
// signed with the debug key cannot replace a release signed with the real key,
// which is exactly the "app package conflicts" error users were seeing.
val keystoreProps = Properties()
val keystorePropsFile = rootProject.file("key.properties")
if (keystorePropsFile.exists()) {
    FileInputStream(keystorePropsFile).use { keystoreProps.load(it) }
}

fun signingValue(propName: String, envName: String): String? {
    val fromProps = keystoreProps.getProperty(propName)?.trim()
    if (!fromProps.isNullOrEmpty()) return fromProps
    val fromEnv = System.getenv(envName)?.trim()
    return if (fromEnv.isNullOrEmpty()) null else fromEnv
}

val releaseStorePath = signingValue("storeFile", "TAKA_KEYSTORE_PATH")
val releaseStorePassword = signingValue("storePassword", "TAKA_STORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "TAKA_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "TAKA_KEY_PASSWORD")

val releaseKeystoreFile: File? = releaseStorePath?.let {
    // Relative paths in key.properties are relative to android/app/.
    val direct = file(it)
    if (direct.exists()) direct else rootProject.file(it)
}
val hasReleaseKey = releaseKeystoreFile?.exists() == true &&
    !releaseStorePassword.isNullOrEmpty() &&
    !releaseKeyAlias.isNullOrEmpty()

if (!hasReleaseKey) {
    logger.warn(
        "[taka] No release keystore found (android/key.properties or TAKA_* env vars). " +
            "Building with the debug key — do not publish this artifact."
    )
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mahimmazidul.taka"
    // Plugins (file_picker, share_plus, path_provider) are compiled against API 36,
    // so the app must match or AGP rejects :file_picker:checkReleaseAarMetadata.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mahimmazidul.taka"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = releaseKeystoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword ?: releaseStorePassword
                // v1/v2/v3 all on: v2+ is required from Android 11 for clean
                // in-place updates, and v1 keeps very old phones happy.
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
