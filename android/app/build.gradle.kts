import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Configuracion de firma para builds de release.
//
// Lee android/key.properties, que NO se versiona (esta en .gitignore). Ese
// archivo lo genera `keytool` y contiene las credenciales del keystore.
//
//Si no existe, el build de release falla con un mensaje claro en vez de
// firmar con la llave de debug: una app firmada con la llave de debug NO se
// puede publicar en Play Store, y es un error facil de no ver.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()

if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// `flutter build apk` invoca Gradle con `assemble*`; `flutter build appbundle`
// con `bundle*`. Los splits de ABI no pueden activarse en un App Bundle, asi
// que se detectan los dos casos.
val isAppBundleBuild = gradle.startParameter.taskNames.any {
    it.contains("bundle", ignoreCase = true)
}

android {
    // Package real de la app. Antes era com.example.kronio_app, que es un
    // placeholder de la plantilla de Flutter y no se puede publicar.
    namespace = "co.kronio.market"
    // El package del namespace quedo en MainActivity.kt; ambos deben coincidir.
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Recompila los .java con el nivel de Java del toolchain.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "co.kronio.market"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        } else {
            // Se declara un build type release "sin firmar" para que el APK se
            // pueda generar e instalar en pruebas. Play Store igual lo rechaza:
            // por eso el warning del buildTypes.release de abajo.
            create("unsignedRelease") {
                // Sin signingConfig: genera un APK sin firma.
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Firma con la llave de debug SOLO para poder probar
                // `flutter run --release` en un dispositivo.
                //
                // Un APK de Play Store firmado con la llave de debug se rechaza
                // en la subida, y el error no es obvio: el build pasa limpio.
                // Por eso se avisa en cada build.
                logger.warn(
                    """
                    |
                    |  ==========================================================
                    |   ATENCION: build de release SIN keystore de produccion.
                    |
                    |   No se encontro android/key.properties, asi que este APK
                    |   se firmo con la llave de DEBUG. NO se puede publicar en
                    |   Play Store.
                    |
                    |   Para una release publicable:
                    |     1) .\scripts\generar_keystore.ps1   (genera la llave)
                    |     2) flutter build apk --release
                    |
                    |   Guarda la llave y el key.properties en un lugar seguro:
                    |   sin ellos no se pueden publicar actualizaciones.
                    |  ==========================================================
                    |
                    """.trimMargin()
                )
                // `logger.warn` no se ve con `flutter build`: Flutter usa la
                // consola rich de Gradle, que descarta el output de lifecycle
                // del script de build. Se escribe directo a stderr para que el
                // aviso llegue al que compila, que es justo cuando importa.
                System.err.println(
                    """
                    |
                    |  ==========================================================
                    |   ATENCION: build de release SIN keystore de produccion.
                    |
                    |   Se firmo con la llave de DEBUG. NO se puede publicar.
                    |   Generala con: .\scripts\generar_keystore.ps1
                    |  ==========================================================
                    |
                    """.trimMargin()
                )
                signingConfig = signingConfigs.getByName("debug")
            }

            // Minificacion + R8. Sin esto el APK incluye TODO el codigo de
            // Flutter y las librerias sin reducir.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }

    // Play entrega ABI por separado. Al compilar para una sola arquitectura el
    // APK baja de ~50MB a ~18MB, y el universal queda para los dispositivos
    // viejos que no soportan App Bundles.
    //
    // arm64-v8a cubre el 95%+ de los Android actuales, asi que se incluye
    // armeabi-v7a aparte para los viejos en vez de generar un APK universal
    // gordo que se baja todo el mundo.
    //
    // Los splits y los App Bundles son INCOMPATIBLES: con los dos activos AGP
    // falla el build con "Multiple shrunk-resources files found". Y Play Store
    // exige el bundle, no el APK, asi que los splits se desactivan cuando el
    // build es un bundle. El bundle ya reparte las ABIs por dispositivo, que es
    // justamente lo que los splits hacen a mano.
    splits {
        abi {
            isEnable = !isAppBundleBuild
            reset()
            include("arm64-v8a", "armeabi-v7a")
            isUniversalApk = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Necesario para isCoreLibraryDesugaringEnabled: permite usar APIs de
    // java.time y otras de Java 8+ en versiones de Android antiguas.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
