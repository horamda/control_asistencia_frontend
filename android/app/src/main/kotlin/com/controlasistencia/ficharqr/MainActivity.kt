package com.controlasistencia.ficharqr

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    private companion object {
        // Cambiar a true para volver a bloquear capturas, grabacion y mirroring.
        const val SCREEN_PROTECTION_ENABLED = false
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (SCREEN_PROTECTION_ENABLED) {
            // Evita capturas de pantalla, grabacion de pantalla y aparicion en el
            // switcher de tareas recientes. Protege credenciales y datos de asistencia
            // frente a apps maliciosas que lean el buffer de pantalla.
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
