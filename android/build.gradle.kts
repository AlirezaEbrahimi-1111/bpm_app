allprojects {
    repositories {
        // 🔧 موقت: مخزنِ محلیِ جمع‌شده برایِ دورزدنِ قطعیِ شبکه — اینجا
        // (نه فقط در app/build.gradle.kts) چون زیرپروژه‌هایی مثلِ
        // file_picker برایِ configurationهایِ جداگانه‌ی خودشان (مثلِ
        // aapt2) این ریپوها را از همین‌جا می‌خوانند، نه از app
        maven { url = uri(rootProject.file("local-maven-repo")) }
        flatDir { dirs(rootProject.file("local-libs")) }
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
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
