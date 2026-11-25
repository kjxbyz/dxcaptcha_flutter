group = "com.kjxbyz.plugins.dxcaptcha_flutter"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.4.0"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.1.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
    // 版本由宿主 settings.gradle.kts 的 pluginManagement 提供（Kotlin 2.4.0）。
    id("org.jetbrains.kotlin.android")
}

// ---------------------------------------------------------------------------
// 本地 aar 解包：AGP 禁止“构建 AAR 的库模块”直接依赖本地 .aar 文件
// （bundleDebugAar 阶段报 Direct local .aar file dependencies are not supported）。
// 因此在配置期把 android/libs/*.aar 解包成 classes.jar / assets / jniLibs，
// 分别注入编译类路径与 sourceSets，最终随插件 AAR 一起打进宿主工程。
// ---------------------------------------------------------------------------
val dxSdkGeneratedRoot = file("${layout.buildDirectory.get()}/generated/dxsdk")

dxSdkGeneratedRoot.mkdirs()
val dxCaptchaAarDirs =
    fileTree(projectDir) {
        include("libs/*.aar")
    }.files.map { aar ->
        // 每个独立目录，避免多个 aar 的 classes.jar 相互覆盖。
        val target = File(dxSdkGeneratedRoot, aar.nameWithoutExtension)
        target.mkdirs()
        copy {
            from(zipTree(aar))
            // classes.jar：字节码；jni/**：标准 aar 的 .so 布局；libs/**：部分 aar 的 .so 布局；
            // assets/**：验证码前端资源；res/**：资源。
            include("classes.jar", "jni/**", "libs/**", "assets/**", "res/**")
            into(target)
        }
        target
    }

android {
    namespace = "com.kjxbyz.plugins.dxcaptcha_flutter"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
            // aar 内的 assets（captcha.enc 等验证码前端资源）必须随插件打包。
            dxCaptchaAarDirs.forEach { dir ->
                assets.srcDir(File(dir, "assets"))
                // .so 文件：标准 aar 布局在 jni/<abi>/，部分 aar 在 libs/<abi>/。
                jniLibs.srcDir(File(dir, "jni"))
                jniLibs.srcDir(File(dir, "libs"))
            }
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
        // 顶象 SDK 需要被保留，避免宿主开启混淆后验证码失效。
        consumerProguardFiles("consumer-rules.pro")
    }

    // 官方文档要求 doNotStrip "**/lib*Risk*.so" 与 "**/lib*Captcha*.so"，
    // AGP Kotlin DSL 中对应 packaging.jniLibs.keepDebugSymbols。
    packaging {
        jniLibs {
            keepDebugSymbols += "**/lib*Risk*.so"
            keepDebugSymbols += "**/lib*Captcha*.so"
        }
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // 解包出的 classes.jar 参与编译（见上方“本地 aar 解包”说明）。
    dxCaptchaAarDirs.forEach { dir ->
        implementation(fileTree(mapOf("dir" to dir, "include" to listOf("*.jar"))))
    }
    // libs 下的普通 jar（非 aar）保持直接引入。
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.jar"))))
    testImplementation("org.jetbrains.kotlin:kotlin-test")
}
