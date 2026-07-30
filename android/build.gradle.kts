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

// Force compileSdk = 36 sur TOUS les modules (l'app ET les plugins comme
// file_picker), sans nommer de classe Android : c'est ce qui faisait planter
// le build #8. On cherche l'extension "android" par son nom, puis on applique
// 36 par réflexion, quelle que soit la version d'AGP.
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        val cls = androidExt.javaClass
        var forced = false
        // Essai 1 : compileSdkVersion(int)
        cls.methods.firstOrNull {
            it.name == "compileSdkVersion" &&
            it.parameterCount == 1 &&
            it.parameterTypes[0] == Int::class.javaPrimitiveType
        }?.let { m ->
            runCatching { m.invoke(androidExt, 36); forced = true }
        }
        // Essai 2 : setCompileSdk(String) pour les AGP récents
        if (!forced) {
            cls.methods.firstOrNull {
                it.name == "setCompileSdk" &&
                it.parameterCount == 1 &&
                it.parameterTypes[0] == String::class.java
            }?.let { m ->
                runCatching { m.invoke(androidExt, "android-36") }
            }
        }
    }
}
