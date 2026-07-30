allprojects {
    repositories {
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

// Force compileSdk = 36 sur CHAQUE module, y compris le plugin file_picker
// (c'est LUI qui est coincé en 34, pas ton app). Technique "GroovyObject" :
// on ne nomme AUCUNE classe Android (c'est ça qui cassait la lecture du
// fichier avant), donc ce bloc ne peut PAS faire planter la config.
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt is groovy.lang.GroovyObject) {
            val attempts = listOf(
                "compileSdkVersion" to 36,
                "setCompileSdkVersion" to 36,
                "setCompileSdk" to "android-36",
                "setCompileSdk" to 36
            )
            for ((name, arg) in attempts) {
                try {
                    androidExt.invokeMethod(name, arg)
                    break
                } catch (_: Throwable) {
                }
            }
        }
    }
}
