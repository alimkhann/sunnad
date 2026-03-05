plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ksp)
}

fun Project.stringBuildConfig(names: List<String>, default: String = ""): String {
    for (name in names) {
        val value = providers.gradleProperty(name).orNull
        if (!value.isNullOrBlank()) {
            return value
        }
    }
    return default
}

fun Project.stringBuildConfig(name: String, default: String = ""): String {
    return stringBuildConfig(listOf(name), default)
}

fun Project.boolBuildConfig(names: List<String>, default: Boolean): Boolean {
    return stringBuildConfig(names, default.toString()).toBooleanStrictOrNull() ?: default
}

fun Project.boolBuildConfig(name: String, default: Boolean): Boolean {
    return boolBuildConfig(listOf(name), default)
}

fun Project.intBuildConfig(names: List<String>, default: Int): Int {
    return stringBuildConfig(names, default.toString()).toIntOrNull() ?: default
}

fun Project.intBuildConfig(name: String, default: Int): Int {
    return intBuildConfig(listOf(name), default)
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

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    flavorDimensions += "env"
    productFlavors {
        create("prod") {
            dimension = "env"
            buildConfigField(
                "String",
                "SUNNAD_SUPABASE_URL",
                "\"${stringBuildConfig(listOf("SUNNAD_SUPABASE_URL_PROD", "SUNNAD_SUPABASE_URL"), "https://artwfvypcdacdpqhciqt.supabase.co")}\""
            )
            buildConfigField(
                "String",
                "SUNNAD_SUPABASE_ANON_KEY",
                "\"${stringBuildConfig(listOf("SUNNAD_SUPABASE_ANON_KEY_PROD", "SUNNAD_SUPABASE_ANON_KEY"), "sb_publishable_HD28BdGSy4amEvirJ8Exvw_QnDF26OW")}\""
            )
            buildConfigField(
                "String",
                "SUNNAD_AUTH_REDIRECT_URL",
                "\"${stringBuildConfig(listOf("SUNNAD_AUTH_REDIRECT_URL_PROD", "SUNNAD_AUTH_REDIRECT_URL"), "adat://auth-callback")}\""
            )
            buildConfigField(
                "boolean",
                "SUNNAD_GOOGLE_AUTH_ENABLED",
                boolBuildConfig(listOf("SUNNAD_GOOGLE_AUTH_ENABLED_PROD", "SUNNAD_GOOGLE_AUTH_ENABLED"), true).toString()
            )
            buildConfigField(
                "boolean",
                "SUNNAD_APPLE_AUTH_ENABLED",
                boolBuildConfig(listOf("SUNNAD_APPLE_AUTH_ENABLED_PROD", "SUNNAD_APPLE_AUTH_ENABLED"), false).toString()
            )
            buildConfigField(
                "int",
                "SUNNAD_AUTH_RESEND_COOLDOWN_SECONDS",
                intBuildConfig(listOf("SUNNAD_AUTH_RESEND_COOLDOWN_SECONDS_PROD", "SUNNAD_AUTH_RESEND_COOLDOWN_SECONDS"), 180).toString()
            )
            buildConfigField(
                "String",
                "SUNNAD_STORAGE_NAMESPACE",
                "\"${stringBuildConfig(listOf("SUNNAD_STORAGE_NAMESPACE_PROD", "SUNNAD_STORAGE_NAMESPACE"), "prod")}\""
            )
            buildConfigField(
                "String",
                "SUNNAD_ENV_LABEL",
                "\"${stringBuildConfig(listOf("SUNNAD_ENV_LABEL_PROD", "SUNNAD_ENV_LABEL"), "prod")}\""
            )
            buildConfigField(
                "String",
                "SUNNAD_DEBUG_PUSH_TOKEN",
                "\"${stringBuildConfig(listOf("SUNNAD_DEBUG_PUSH_TOKEN_PROD", "SUNNAD_DEBUG_PUSH_TOKEN"))}\""
            )
            buildConfigField(
                "String",
                "SUNNAD_ONESIGNAL_APP_ID",
                "\"${stringBuildConfig(listOf("SUNNAD_ONESIGNAL_APP_ID_PROD", "SUNNAD_ONESIGNAL_APP_ID"), "2c4a8b41-6f38-4e25-9c5d-f527c02a3a54")}\""
            )
        }

        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            buildConfigField(
                "String",
                "SUNNAD_SUPABASE_URL",
                "\"${stringBuildConfig(listOf("SUNNAD_SUPABASE_URL_DEV", "SUNNAD_SUPABASE_URL"), "https://wejnrzlxnesqhbtvgdga.supabase.co")}\""
            )
            buildConfigField(
                "String",
                "SUNNAD_SUPABASE_ANON_KEY",
                "\"${stringBuildConfig(listOf("SUNNAD_SUPABASE_ANON_KEY_DEV", "SUNNAD_SUPABASE_ANON_KEY"), "sb_publishable_cXKO2pyGC65YX_bRJ1h1DQ_Ip3iWbib")}\""
            )
            buildConfigField(
                "String",
                "SUNNAD_AUTH_REDIRECT_URL",
                "\"${stringBuildConfig(listOf("SUNNAD_AUTH_REDIRECT_URL_DEV", "SUNNAD_AUTH_REDIRECT_URL"), "adat://auth-callback")}\""
            )
            buildConfigField(
                "boolean",
                "SUNNAD_GOOGLE_AUTH_ENABLED",
                boolBuildConfig(listOf("SUNNAD_GOOGLE_AUTH_ENABLED_DEV", "SUNNAD_GOOGLE_AUTH_ENABLED"), true).toString()
            )
            buildConfigField(
                "boolean",
                "SUNNAD_APPLE_AUTH_ENABLED",
                boolBuildConfig(listOf("SUNNAD_APPLE_AUTH_ENABLED_DEV", "SUNNAD_APPLE_AUTH_ENABLED"), false).toString()
            )
            buildConfigField(
                "int",
                "SUNNAD_AUTH_RESEND_COOLDOWN_SECONDS",
                intBuildConfig(listOf("SUNNAD_AUTH_RESEND_COOLDOWN_SECONDS_DEV", "SUNNAD_AUTH_RESEND_COOLDOWN_SECONDS"), 120).toString()
            )
            buildConfigField(
                "String",
                "SUNNAD_STORAGE_NAMESPACE",
                "\"${stringBuildConfig(listOf("SUNNAD_STORAGE_NAMESPACE_DEV", "SUNNAD_STORAGE_NAMESPACE"), "android-dev")}\""
            )
            buildConfigField(
                "String",
                "SUNNAD_ENV_LABEL",
                "\"${stringBuildConfig(listOf("SUNNAD_ENV_LABEL_DEV", "SUNNAD_ENV_LABEL"), "dev")}\""
            )
            buildConfigField(
                "String",
                "SUNNAD_DEBUG_PUSH_TOKEN",
                "\"${stringBuildConfig(listOf("SUNNAD_DEBUG_PUSH_TOKEN_DEV", "SUNNAD_DEBUG_PUSH_TOKEN"))}\""
            )
            buildConfigField(
                "String",
                "SUNNAD_ONESIGNAL_APP_ID",
                "\"${stringBuildConfig(listOf("SUNNAD_ONESIGNAL_APP_ID_DEV", "SUNNAD_ONESIGNAL_APP_ID"), "2c4a8b41-6f38-4e25-9c5d-f527c02a3a54")}\""
            )
        }

        create("local") {
            dimension = "env"
            applicationIdSuffix = ".local"
            versionNameSuffix = "-local"
            buildConfigField(
                "String",
                "SUNNAD_SUPABASE_URL",
                "\"${stringBuildConfig(listOf("SUNNAD_SUPABASE_URL_LOCAL", "SUNNAD_SUPABASE_URL"), "http://127.0.0.1:55421")}\""
            )
            buildConfigField(
                "String",
                "SUNNAD_SUPABASE_ANON_KEY",
                "\"${stringBuildConfig(listOf("SUNNAD_SUPABASE_ANON_KEY_LOCAL", "SUNNAD_SUPABASE_ANON_KEY"), "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH")}\""
            )
            buildConfigField(
                "String",
                "SUNNAD_AUTH_REDIRECT_URL",
                "\"${stringBuildConfig(listOf("SUNNAD_AUTH_REDIRECT_URL_LOCAL", "SUNNAD_AUTH_REDIRECT_URL"), "adat://auth-callback")}\""
            )
            buildConfigField(
                "boolean",
                "SUNNAD_GOOGLE_AUTH_ENABLED",
                boolBuildConfig(listOf("SUNNAD_GOOGLE_AUTH_ENABLED_LOCAL", "SUNNAD_GOOGLE_AUTH_ENABLED"), true).toString()
            )
            buildConfigField(
                "boolean",
                "SUNNAD_APPLE_AUTH_ENABLED",
                boolBuildConfig(listOf("SUNNAD_APPLE_AUTH_ENABLED_LOCAL", "SUNNAD_APPLE_AUTH_ENABLED"), false).toString()
            )
            buildConfigField(
                "int",
                "SUNNAD_AUTH_RESEND_COOLDOWN_SECONDS",
                intBuildConfig(listOf("SUNNAD_AUTH_RESEND_COOLDOWN_SECONDS_LOCAL", "SUNNAD_AUTH_RESEND_COOLDOWN_SECONDS"), 120).toString()
            )
            buildConfigField(
                "String",
                "SUNNAD_STORAGE_NAMESPACE",
                "\"${stringBuildConfig(listOf("SUNNAD_STORAGE_NAMESPACE_LOCAL", "SUNNAD_STORAGE_NAMESPACE"), "local")}\""
            )
            buildConfigField(
                "String",
                "SUNNAD_ENV_LABEL",
                "\"${stringBuildConfig(listOf("SUNNAD_ENV_LABEL_LOCAL", "SUNNAD_ENV_LABEL"), "local")}\""
            )
            buildConfigField(
                "String",
                "SUNNAD_DEBUG_PUSH_TOKEN",
                "\"${stringBuildConfig(listOf("SUNNAD_DEBUG_PUSH_TOKEN_LOCAL", "SUNNAD_DEBUG_PUSH_TOKEN"))}\""
            )
            buildConfigField(
                "String",
                "SUNNAD_ONESIGNAL_APP_ID",
                "\"${stringBuildConfig(listOf("SUNNAD_ONESIGNAL_APP_ID_LOCAL", "SUNNAD_ONESIGNAL_APP_ID"), "2c4a8b41-6f38-4e25-9c5d-f527c02a3a54")}\""
            )
        }
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
    implementation(libs.onesignal)

    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    debugImplementation(libs.androidx.compose.ui.tooling)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}
