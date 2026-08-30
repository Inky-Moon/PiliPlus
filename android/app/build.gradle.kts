import com.android.build.gradle.internal.api.ApkVariantOutputImpl
import org.jetbrains.kotlin.konan.properties.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val agpMajorVersion = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION
    .substringBefore('.')
    .toInt()
val builtInKotlinProperty = providers.gradleProperty("android.builtInKotlin").orNull
val isBuiltInKotlinEnabled = agpMajorVersion >= 9 &&
        (builtInKotlinProperty == null || builtInKotlinProperty.toBoolean())
if (!isBuiltInKotlinEnabled) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

android {
    namespace = "com.example.piliplus"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.piliplus"
        minSdk = 23  // Hardcoded for Android 6.0+ compatibility (flutter.minSdkVersion defaults to 24 in Flutter 3.35+)
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packagingOptions.jniLibs.useLegacyPackaging = true

    val keyProperties = Properties().also {
        val properties = rootProject.file("key.properties")
        if (properties.exists())
            it.load(properties.inputStream())
    }

    val config = keyProperties.getProperty("storeFile")?.let {
        signingConfigs.create("release") {
            storeFile = file(it)
            storePassword = keyProperties.getProperty("storePassword")
            keyAlias = keyProperties.getProperty("keyAlias")
            keyPassword = keyProperties.getProperty("keyPassword")
            enableV1Signing = true
            enableV2Signing = true
        }
    } ?: signingConfigs.create("fallback") {
        storeFile = file("piliplus.jks")
        storePassword = "123456"
        keyAlias = "piliplus"
        keyPassword = "123456"
        enableV1Signing = true
        enableV2Signing = true
    }

    buildFeatures {
        if (project.hasProperty("dev")) {
            resValues = true
        }
    }

    buildTypes {
        all {
            signingConfig = config ?: signingConfigs["debug"]
        }
        release {
            if (project.hasProperty("dev")) {
                applicationIdSuffix = ".dev"
                resValue(
                    type = "string",
                    name = "app_name",
                    value = "PiliPlus dev",
                )
            }
//            proguardFiles(
//                getDefaultProguardFile("proguard-android-optimize.txt"),
//                "proguard-rules.pro"
//            )
        }
        debug {
            applicationIdSuffix = ".debug"
        }
    }

    applicationVariants.all {
        val variant = this
        variant.outputs.forEach { output ->
            (output as ApkVariantOutputImpl).versionCodeOverride = flutter.versionCode
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

val android6CompatibilityEnabled =
    providers.gradleProperty("android6Compatibility").isPresent

if (android6CompatibilityEnabled) {
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (requested.group == "io.flutter" &&
                requested.name == "flutter_embedding_release" &&
                !requested.version.orEmpty().endsWith("-android6")
            ) {
                useVersion("${requested.version}-android6")
                because("Use the API 23-compatible Flutter embedding")
            }
        }
    }

    tasks.register("verifyAndroid6FlutterEmbedding") {
        doLast {
            val componentIds = configurations
                .getByName("releaseRuntimeClasspath")
                .incoming
                .resolutionResult
                .allComponents
                .mapNotNull { component ->
                    val id = component.id
                    if (id is org.gradle.api.artifacts.component.ModuleComponentIdentifier &&
                        id.group == "io.flutter" &&
                        id.module == "flutter_embedding_release"
                    ) {
                        id
                    } else {
                        null
                    }
                }
            check(componentIds.size == 1) {
                "Expected one Flutter release embedding, found ${componentIds.size}"
            }

            val version = componentIds.single().version
            check(version.endsWith("-android6")) {
                "Resolved unpatched Flutter embedding $version"
            }
            val repositoryFile = rootProject.file(
                "android6-engine-repo/io/flutter/flutter_embedding_release/" +
                    "$version/flutter_embedding_release-$version.jar",
            )
            val checkConfiguration = project.configurations.detachedConfiguration(
                project.dependencies.create("io.flutter:flutter_embedding_release:$version"),
            ).apply {
                isTransitive = false
            }
            val resolvedFile = checkConfiguration.singleFile
            check(repositoryFile.isFile &&
                repositoryFile.readBytes().contentEquals(resolvedFile.readBytes())) {
                "Resolved Flutter embedding does not match the patched local artifact"
            }
            println("Verified patched Flutter embedding: $version")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
