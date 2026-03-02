plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ksp)
}

fun Project.stringBuildConfig(name: String, default: String = ""): String {
    return providers.gradleProperty(name).orElse(default).get()
}

fun Project.boolBuildConfig(name: String, default: Boolean): Boolean {
    return providers.gradleProperty(name).orElse(default.toString()).get().toBooleanStrictOrNull() ?: default
}

fun Project.intBuildConfig(name: String, default: Int): Int {
    return providers.gradleProperty(name).orElse(default.toString()).get().toIntOrNull() ?: default
}

android {
    namespace = "com.arystan.almasuly.sunnadandroid"
    compileSdk {
        version = release(36) {
            minorApiLevel = 1
        }
    }

    defaultConfig {
        applicationId = "com.arystan.almasuly.sunnadandroid"
        minSdk = 28
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        buildConfigField("String", "SUNNAD_SUPABASE_URL", "\"${stringBuildConfig("SUNNAD_SUPABASE_URL")}\"")
        buildConfigField("String", "SUNNAD_SUPABASE_ANON_KEY", "\"${stringBuildConfig("SUNNAD_SUPABASE_ANON_KEY")}\"")
        buildConfigField("String", "SUNNAD_AUTH_REDIRECT_URL", "\"${stringBuildConfig("SUNNAD_AUTH_REDIRECT_URL", "sunnad://auth-callback")}\"")
        buildConfigField("boolean", "SUNNAD_GOOGLE_AUTH_ENABLED", boolBuildConfig("SUNNAD_GOOGLE_AUTH_ENABLED", true).toString())
        buildConfigField("boolean", "SUNNAD_APPLE_AUTH_ENABLED", boolBuildConfig("SUNNAD_APPLE_AUTH_ENABLED", false).toString())
        buildConfigField("int", "SUNNAD_AUTH_RESEND_COOLDOWN_SECONDS", intBuildConfig("SUNNAD_AUTH_RESEND_COOLDOWN_SECONDS", 120).toString())
        buildConfigField("String", "SUNNAD_STORAGE_NAMESPACE", "\"${stringBuildConfig("SUNNAD_STORAGE_NAMESPACE", "android")}\"")
        buildConfigField("String", "SUNNAD_ENV_LABEL", "\"${stringBuildConfig("SUNNAD_ENV_LABEL", "dev")}\"")
        buildConfigField("String", "SUNNAD_DEBUG_PUSH_TOKEN", "\"${stringBuildConfig("SUNNAD_DEBUG_PUSH_TOKEN")}\"")

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.appcompat)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.androidx.datastore.preferences)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.work.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material3.adaptive.nav)
    implementation(libs.androidx.compose.material.icons.extended)
    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)
    implementation(platform(libs.supabase.bom))
    implementation(libs.supabase.auth)
    implementation(libs.supabase.postgrest)
    implementation(libs.supabase.functions)
    implementation(libs.supabase.realtime)
    implementation(libs.supabase.storage)
    implementation(libs.ktor.client.okhttp)
    implementation(libs.coil.compose)

    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    debugImplementation(libs.androidx.compose.ui.tooling)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}
