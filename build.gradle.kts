import com.github.c64lib.retroassembler.domain.AssemblerType

plugins {
    id("com.github.c64lib.retro-assembler") version "1.6.0"
    id("com.github.hierynomus.license") version "0.16.1"
}

val kickAssVersion = "5.25"

retroProject {
    dialect = AssemblerType.KickAssembler
    dialectVersion = kickAssVersion
}

license {
    header = file("LICENSE")
    excludes(listOf(".ra"))
    include("**/*.asm")
    mapping("asm", "SLASHSTAR_STYLE")
}

tasks.register<com.hierynomus.gradle.license.tasks.LicenseFormat>("licenseFormatAsm") {
    source = fileTree(".") {
        include("**/*.asm")
        exclude(".ra")
        exclude("build")
    }
}
tasks.register<com.hierynomus.gradle.license.tasks.LicenseCheck>("licenseAsm") {
    source = fileTree(".") {
        include("**/*.asm")
        exclude(".ra")
        exclude("build")
    }
}
tasks["licenseFormat"].dependsOn("licenseFormatAsm")

val kickAssJar = ".ra/asms/ka/$kickAssVersion/KickAss.jar"

tasks.register<Exec>("build-crt-bin") {
    group = "build"
    description = "links the whole game as a raw cart image"
    commandLine("java", "-jar",  kickAssJar, 
    "demo.asm")
}

tasks.register<Exec>("build-crt") {
    dependsOn("build-crt-bin")
    group = "build"
    description = "links the whole game as a CRT cart image"
    commandLine("cartconv", "-t", "md", "-i", "demo.bin", "-o", "demo.crt", "-l", "$8000")
}
