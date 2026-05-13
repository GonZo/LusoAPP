package pt.meshcore.lusoapp

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val radioServiceChannel = "pt.meshcore.lusoapp/radio_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            radioServiceChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startRadioForeground" -> {
                    val radioName = call.argument<String>("radioName") ?: "Radio"
                    startRadioForeground(radioName)
                    result?.success(null)
                }
                "stopRadioForeground" -> {
                    stopRadioForeground()
                    result?.success(null)
                }
                else -> result?.notImplemented()
            }
        }
    }

    private fun startRadioForeground(radioName: String) {
        val intent = Intent(this, RadioForegroundService::class.java).apply {
            action = RadioForegroundService.ACTION_START
            putExtra(RadioForegroundService.EXTRA_RADIO_NAME, radioName)
        }
        startForegroundService(intent)
    }

    private fun stopRadioForeground() {
        val intent = Intent(this, RadioForegroundService::class.java).apply {
            action = RadioForegroundService.ACTION_STOP
        }
        startService(intent)
    }
}
