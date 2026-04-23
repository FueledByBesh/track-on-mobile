// Read MapBox download token from local.properties (git-ignored)
// Fall back to env var so CI builds work without a local file.
val mapboxDownloadsToken: String = run {
    val props = java.util.Properties()
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { props.load(it) }
    props.getProperty("MAPBOX_DOWNLOADS_TOKEN")
        ?: System.getenv("MAPBOX_DOWNLOADS_TOKEN")
        ?: ""
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            authentication {
                create<BasicAuthentication>("basic")
            }
            credentials {
                username = "mapbox"
                password = mapboxDownloadsToken
            }
        }
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
    project.evaluationDependsOn(":app")

    // Prevent third-party plugin lint/test errors from aborting the build
    project.plugins.whenPluginAdded {
        if (this is com.android.build.gradle.api.AndroidBasePlugin) {
            project.extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
                lintOptions {
                    isAbortOnError = false
                }
            }
        }
    }

    // Skip unit tests for all subprojects (third-party plugins)
    project.tasks.whenTaskAdded {
        if (name.contains("UnitTest")) {
            enabled = false
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
