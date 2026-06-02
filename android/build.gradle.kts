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

subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        try {
            val getNamespace = androidExt.javaClass.getMethod("getNamespace")
            val currentNamespace = getNamespace.invoke(androidExt) as? String
            if (currentNamespace.isNullOrEmpty()) {
                val ns = project.group.toString().takeIf { it.isNotEmpty() } ?: project.name
                androidExt.javaClass.getMethod("setNamespace", String::class.java)
                    .invoke(androidExt, ns)
            }
        } catch (e: Exception) {
            // namespace API not available on this Android extension version
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
