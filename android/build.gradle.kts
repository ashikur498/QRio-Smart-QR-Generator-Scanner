import java.io.File

buildscript {
    val kotlinVersion by extra("1.9.0")

    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.2.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

configurations.all {
    resolutionStrategy {
        force("androidx.core:core:1.12.0")
    }
}

// Optional: Keep your custom build directory logic if needed
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}

subprojects {
    afterEvaluate {
        val project = this
        if (project.plugins.hasPlugin("com.android.application") || project.plugins.hasPlugin("com.android.library")) {
            val androidExtension = project.extensions.findByName("android")
            if (androidExtension is com.android.build.gradle.BaseExtension) {
                androidExtension.compileSdkVersion(35)
            }
        }
    }
}

subprojects {
    project.buildDir = File(rootProject.buildDir, project.name)
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
