package com.bluebubbles.messaging.services.foreground

import android.content.Context
import android.content.Intent
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.bluebubbles.messaging.services.foreground.SocketIOForegroundService

/// Stop the foreground service
class StopForegroundServiceHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag = "stop-foreground-service"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        try {
            val serviceIntent = Intent(context, SocketIOForegroundService::class.java)
            if (context != null) {
                context.stopService(serviceIntent)
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("STOP_FOREGROUND_SERVICE_ERROR", e.message, e)
        }
    }
}