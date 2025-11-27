allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
        // FFmpegKit Maven repository for ffmpeg-kit artifacts
        maven { url = uri("https://download.ffmpegkit.com/maven") }
        // Removed ffmpeg-kit Maven repository that requires GitHub Packages credentials.
        // If you need offline FFmpeg processing, re-add the repository & credentials or use an alternate distribution.
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
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
