import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

val android6CompatibilityEnabled =
    providers.gradleProperty("android6Compatibility").isPresent

allprojects {
    repositories {
        if (android6CompatibilityEnabled) {
            maven {
                name = "android6PatchedFlutter"
                url = uri(rootProject.file("android6-engine-repo"))
            }
        }
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    afterEvaluate {
        if (project.extensions.findByName("android") != null) {
            val androidExtension =
                project.extensions.getByName("android") as com.android.build.gradle.BaseExtension

            if (androidExtension.namespace == null) {
                androidExtension.namespace = project.group.toString()
            }

            androidExtension.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }

            project.tasks.withType<KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }

            val pluginCompileSdkStr = androidExtension.compileSdkVersion
            val pluginCompileSdk = pluginCompileSdkStr
                ?.removePrefix("android-")
                ?.toIntOrNull()
            if (pluginCompileSdk != null && pluginCompileSdk < 36) {
                project.logger.error(
                    "Warning: Overriding compileSdk version in Flutter plugin: ${project.name} " +
                            "from $pluginCompileSdk to 36 (to work around https://issuetracker.google.com/issues/199180389).\n" +
                            "If there is not a new version of ${project.name}, consider filing an issue against ${project.name} " +
                            "to increase their compileSdk to the latest (otherwise try updating to the latest version)."
                )
                androidExtension.setCompileSdkVersion(36)
            }

            // Force minSdkVersion to 23 for Android 6.0+ compatibility
            val currentMinSdk = androidExtension.defaultConfig.minSdkVersion?.apiLevel
            if (currentMinSdk != null && currentMinSdk > 23) {
                project.logger.warn(
                    "Overriding minSdkVersion in Flutter plugin: ${project.name} " +
                            "from $currentMinSdk to 23 for Android 6.0 compatibility."
                )
                androidExtension.defaultConfig.minSdkVersion(23)
            }
        }

        project.buildDir = File(rootProject.buildDir, project.name)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
