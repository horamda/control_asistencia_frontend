import org.gradle.api.GradleException
import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties().apply {
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use(::load)
    }
}

fun readSigningValue(propertyKey: String, envKey: String): String? {
    val value = keystoreProperties.getProperty(propertyKey)
        ?: System.getenv(envKey)
    return value?.trim()?.takeIf { it.isNotEmpty() }
}

fun resolveSigningFile(path: String): File {
    val candidate = File(path)
    return if (candidate.isAbsolute) candidate else rootProject.file(path)
}

val releaseStoreFilePath = readSigningValue("storeFile", "ANDROID_KEYSTORE_PATH")
val releaseStorePassword = readSigningValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = readSigningValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = readSigningValue("keyPassword", "ANDROID_KEY_PASSWORD")

val releaseSigningFields = mapOf(
    "storeFile" to releaseStoreFilePath,
    "storePassword" to releaseStorePassword,
    "keyAlias" to releaseKeyAlias,
    "keyPassword" to releaseKeyPassword,
)

val configuredReleaseSigningFields = releaseSigningFields.filterValues { !it.isNullOrBlank() }
if (
    configuredReleaseSigningFields.isNotEmpty() &&
    configuredReleaseSigningFields.size != releaseSigningFields.size
) {
    val missingFields = releaseSigningFields
        .filterValues { it.isNullOrBlank() }
        .keys
        .sorted()
        .joinToString(", ")
    throw GradleException("Incomplete Android release signing configuration. Missing: $missingFields")
}

val hasReleaseSigning = configuredReleaseSigningFields.size == releaseSigningFields.size
val resolvedReleaseStoreFile = releaseStoreFilePath?.let(::resolveSigningFile)

if (hasReleaseSigning && (resolvedReleaseStoreFile == null || !resolvedReleaseStoreFile.exists())) {
    throw GradleException("Android release keystore not found: ${resolvedReleaseStoreFile?.path}")
}

android {
    namespace = "com.controlasistencia.ficharqr"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.controlasistencia.ficharqr"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = resolvedReleaseStoreFile
                storePassword = releaseStorePassword!!
                keyAlias = releaseKeyAlias!!
                keyPassword = releaseKeyPassword!!
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}
