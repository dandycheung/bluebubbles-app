package com.bluebubbles.messaging.utils

import android.content.Context
import android.util.Log
import com.bluebubbles.messaging.Constants
import java.io.File
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.concurrent.Executors

/// Appends critical native-side events (DartWorker failures, engine init errors)
/// to a file inside the Flutter log directory so they survive logcat rollover and
/// are included in the app's log export (which zips every *.log in that folder).
/// Timestamps are UTC ISO-8601, matching the Dart Logger's convention.
object PersistentLog {
    private const val FILE_NAME = "native-dartworker.log"
    private const val ROTATED_FILE_NAME = "native-dartworker.1.log"
    private const val MAX_SIZE_BYTES = 512 * 1024L

    // Single-threaded so writes stay ordered and never block the caller (failure
    // paths run on the main thread).
    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "PersistentLog").apply { isDaemon = true }
    }

    fun log(context: Context, message: String) {
        val appContext = context.applicationContext
        executor.execute {
            try {
                // Same directory path_provider uses for getApplicationDocumentsDirectory
                val dir = File(appContext.getDir("flutter", Context.MODE_PRIVATE), "logs")
                if (!dir.exists()) dir.mkdirs()

                val file = File(dir, FILE_NAME)
                if (file.exists() && file.length() > MAX_SIZE_BYTES) {
                    val rotated = File(dir, ROTATED_FILE_NAME)
                    if (rotated.exists()) rotated.delete()
                    file.renameTo(rotated)
                }

                val timestamp = DateTimeFormatter.ISO_INSTANT.format(Instant.now())
                file.appendText("$timestamp [NATIVE] $message\n")
            } catch (e: Exception) {
                Log.e(Constants.logTag, "Failed to write persistent log entry", e)
            }
        }
    }
}
