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

// Force compileSdk = 36 sur TOUS les modules (app + plugins comme file_picker).
// Bloc blindé : aucun type Android nommé, aucune syntaxe risquée, et TOUT est
// dans un try/catch Throwable -> il ne peut JAMAIS faire planter la config.
subprojects {
    afterEvaluate {
        try {
            val androidExt = extensions.findByName("android")
            if (androidExt != null) {
                val methods = androidExt.javaClass.methods
                val setterInt = methods.firstOrNull {
                    it.name == "setCompileSdkVersion" && it.parameterTypes.size == 1
                }
                val setterStr = methods.firstOrNull {
                    it.name == "setCompileSdk" && it.parameterTypes.size == 1
                }
                when {
                    setterInt != null -> setterInt.invoke(androidExt, 36)
                    setterStr != null -> setterStr.invoke(androidExt, "android-36")
                }
            }
        } catch (ignored: Throwable) {
            // avale toute erreur : au pire le forçage ne s'applique pas,
            // mais le build ne plantera jamais à cause de ce bloc.
        }
    }
}
