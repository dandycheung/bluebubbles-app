package com.bluebubbles.messaging.services.backend_ui_interop

import android.content.Context
import android.util.Log
import androidx.concurrent.futures.CallbackToFutureAdapter
import androidx.core.app.NotificationCompat
import androidx.work.ForegroundInfo
import androidx.work.ListenableWorker
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.MainActivity
import com.bluebubbles.messaging.R
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import com.google.gson.GsonBuilder
import com.google.gson.ToNumberPolicy
import com.google.gson.reflect.TypeToken
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterJNI
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.ApplicationInfoLoader
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume
import kotlinx.coroutines.guava.future

// Background worker plugins — only those required for notification/sync processing
import com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin
import com.github.dart_lang.jni.JniPlugin
import com.johnstef.flutter_user_certificates_android.FlutterUserCertificatesAndroidPlugin
import dev.fluttercommunity.plus.device_info.DeviceInfoPlusPlugin
import dev.fluttercommunity.plus.packageinfo.PackageInfoPlugin
import io.flutter.plugins.flutter_plugin_android_lifecycle.FlutterAndroidLifecyclePlugin
import io.flutter.plugins.pathprovider.PathProviderPlugin
import io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin
import io.objectbox.objectbox_flutter_libs.ObjectboxFlutterLibsPlugin
import net.wolverinebeach.flutter_timezone.FlutterTimezonePlugin
import org.unifiedpush.flutter.connector.Plugin as UnifiedPushConnectorPlugin

class DartWorker(context: Context, workerParams: WorkerParameters): ListenableWorker(context, workerParams) {

    companion object {
        var workerEngine: FlutterEngine? = null

        // Single lock guarding all [workerEngine] state transitions (init, use-selection,
        // and destroy) — split locks here previously allowed destroy/init races.
        var engineReady = Mutex()

        // Number of times a worker is re-enqueued after a transient failure before giving up.
        // The FCM payload lives in the work's input data, so each retry re-delivers the event.
        const val MAX_RETRY_ATTEMPTS = 3
    }

    /// Engine startup and method-channel failures are almost always transient (fresh headless
    /// process still initializing, engine handshake timeout, Dart handler not yet registered).
    /// Returning failure() drops the event permanently — retry with a cap instead.
    private fun retryOrFail(method: String): Result {
        return if (runAttemptCount < MAX_RETRY_ATTEMPTS) {
            Log.w(Constants.logTag, "Retrying worker with method $method (attempt ${runAttemptCount + 1} of $MAX_RETRY_ATTEMPTS)")
            Result.retry()
        } else {
            Log.e(Constants.logTag, "Worker with method $method failed after $MAX_RETRY_ATTEMPTS retries — giving up")
            Result.failure()
        }
    }

    override fun startWork(): ListenableFuture<Result> {
        val method = inputData.getString("method")!!
        val data = inputData.getString("data")!!
        val gson = GsonBuilder()
                .setObjectToNumberStrategy(ToNumberPolicy.LONG_OR_DOUBLE)
                .create()

        val mainEngine = MainActivity.getEngine()
        if (mainEngine != null) {
            Log.d(Constants.logTag, "Using MainActivity engine to send to Dart")
        } else {
            Log.d(Constants.logTag, "Using DartWorker engine to send to Dart")
        }
        return CoroutineScope(Dispatchers.Main).future {
            // Initialize AND select the engine under the same lock so a concurrent
            // cleanup can't destroy the engine between init and selection.
            val engineToUse: FlutterEngine? = try {
                engineReady.withLock {
                    if (MainActivity.getEngine() == null && workerEngine == null) {
                        Log.d(Constants.logTag, "Initializing engine for worker with method $method")
                        initNewEngine()
                    }
                    MainActivity.getEngine() ?: workerEngine
                }
            } catch (e: Exception) {
                Log.e(Constants.logTag, "Engine init failed for worker with method $method: ${e.message}")
                return@future retryOrFail(method)
            }
            Log.d(Constants.logTag, "Sending event, '$method' to Dart")

            try {
                if (engineToUse == null) {
                    Log.d(Constants.logTag, "Engine is null, cannot send method $method to Dart")
                    return@future retryOrFail(method)
                }

                Log.d(Constants.logTag, "Invoking method channel...")
                val callResult = withTimeoutOrNull(120_000L) {
                    suspendCancellableCoroutine { cont ->
                        MethodChannel(engineToUse.dartExecutor.binaryMessenger, Constants.methodChannel).invokeMethod(method, gson.fromJson(data, TypeToken.getParameterized(HashMap::class.java, String::class.java, Any::class.java).type), object : MethodChannel.Result {
                            override fun success(result: Any?) {
                                Log.d(Constants.logTag, "Worker with method $method completed successfully")
                                if (cont.isActive) cont.resume(Result.success())
                                closeEngineIfNeeded()
                            }
    
                            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                                Log.e(Constants.logTag, "Worker with method $method failed! ($errorCode: $errorMessage)")
                                if (cont.isActive) cont.resume(retryOrFail(method))
                                closeEngineIfNeeded()
                            }

                            override fun notImplemented() {
                                // notImplemented also fires when the Dart side hasn't registered its
                                // method-call handler yet (engine still starting up), so treat it as transient.
                                Log.e(Constants.logTag, "Worker with method $method not implemented on Dart side")
                                if (cont.isActive) cont.resume(retryOrFail(method))
                                closeEngineIfNeeded()
                            }
                        })
                    }
                }

                if (callResult == null) {
                    Log.e(Constants.logTag, "Method $method invocation timed out after 120s")
                    closeEngineIfNeeded()
                    return@future retryOrFail(method)
                }

                // callResult carries the outcome resumed by the method-channel callback
                // (success, retry, or failure) — don't collapse it to success.
                return@future callResult
            } catch (e: Exception) {
                Log.d(Constants.logTag, "Error sending method $method to Dart: ${e.message}")
                return@future retryOrFail(method)
            }
        }
    }

    /// Code idea taken from https://github.com/flutter/flutter/wiki/Experimental:-Reuse-FlutterEngine-across-screens
    private suspend fun initNewEngine() {
        // Any failure below must not leave a half-initialized engine in [workerEngine]:
        // later workers would see it as non-null, skip init, and invoke into an engine
        // with no Dart running — hanging every subsequent event until the process dies.
        try {
            Log.d(Constants.logTag, "Ensuring Flutter is initialized before creating engine")
            val flutterLoader = FlutterLoader();
            flutterLoader.startInitialization(applicationContext)
            flutterLoader.ensureInitializationComplete(applicationContext, null)

            Log.d(Constants.logTag, "Loading callback info")
            val info = ApplicationInfoLoader.load(applicationContext)
            workerEngine = FlutterEngine(applicationContext, null, FlutterJNI(), null, false)
            registerWorkerPlugins(workerEngine!!)
            val ready = withTimeoutOrNull(30_000L) {
                suspendCancellableCoroutine<Unit> { cont ->
                    // set up the method channel to receive events from Dart
                    MethodChannel(workerEngine!!.dartExecutor.binaryMessenger, Constants.methodChannel).setMethodCallHandler {
                        call, result -> run {
                            if (call.method == "ready") {
                                Log.d(Constants.logTag, "Dart engine is ready!")
                                if (cont.isActive) cont.resume(Unit)
                            } else {
                                MethodCallHandler().methodCallHandler(call, result, applicationContext)
                            }
                        }
                    }
                    val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(applicationContext.getSharedPreferences("FlutterSharedPreferences", 0).getLong("backgroundCallbackHandle", -1))
                    val callback = DartExecutor.DartCallback(applicationContext.assets, info.flutterAssetsDir, callbackInfo)

                    Log.d(Constants.logTag, "Executing Dart callback")
                    workerEngine!!.dartExecutor.executeDartCallback(callback)
                }
            }

            if (ready == null) {
                throw Exception("DartWorker engine 'ready' handshake timed out after 30s")
            }
        } catch (e: Exception) {
            Log.e(Constants.logTag, "Engine init failed (${e.message}) — destroying engine")
            workerEngine?.destroy()
            workerEngine = null
            throw e
        }
    }

    private fun closeEngineIfNeeded() {
        // Delay 5 seconds so Dart has a chance to complete everything and in case new work comes in shortly after
        CoroutineScope(Dispatchers.Main).launch {
            delay(5_000L)
            // Take the SAME lock that guards engine init/use so we can never destroy an
            // engine another worker is initializing or about to invoke into. The destroy
            // must also happen synchronously inside the lock — deferring it (the old
            // behavior) let it fire after the lock was released, racing a new init and
            // potentially destroying or orphaning a freshly created engine.
            engineReady.withLock {
                if (workerEngine == null) {
                    Log.d(Constants.logTag, "Engine already destroyed by another worker")
                    return@withLock
                }

                // Exclude this worker's own ID — WorkManager may still report it as RUNNING
                // even after the Dart method callback has completed, which would cause the
                // engine to never be destroyed.
                val currentWork = withContext(Dispatchers.IO) {
                    WorkManager.getInstance(applicationContext).getWorkInfosByTag(Constants.dartWorkerTag).get()
                }.filter { element -> !element.state.isFinished && element.id != id }
                Log.d(Constants.logTag, "${currentWork.size} other worker(s) still queued")
                if (currentWork.isEmpty()) {
                    Log.d(Constants.logTag, "Closing ${Constants.dartWorkerTag} engine")
                    // Already on the main thread, as engine destruction requires
                    workerEngine?.destroy()
                    workerEngine = null
                }
            }
        }
    }

    /**
     * Registers only the plugins required for background notification and sync processing.
     * Heavy UI-only plugins (MLKit, camera, geolocator, printing, media, etc.) are excluded
     * to reduce startup overhead and avoid unnecessary initialisation in a headless context.
     */
    private fun registerWorkerPlugins(engine: FlutterEngine) {
        val plugins = engine.plugins
        // Core Flutter platform channels
        plugins.add(FlutterAndroidLifecyclePlugin())
        plugins.add(PathProviderPlugin())
        plugins.add(SharedPreferencesPlugin())
        // App information (used by FilesystemService and SettingsService init)
        plugins.add(PackageInfoPlugin())
        plugins.add(DeviceInfoPlusPlugin())
        // Database
        plugins.add(ObjectboxFlutterLibsPlugin())
        // Notifications
        plugins.add(FlutterLocalNotificationsPlugin())
        // Transport security (custom user certificates; JniPlugin is a required dependency)
        plugins.add(JniPlugin())
        plugins.add(FlutterUserCertificatesAndroidPlugin())
        // Timezone (used during message date handling)
        plugins.add(FlutterTimezonePlugin())
        // UnifiedPush
        plugins.add(UnifiedPushConnectorPlugin())
    }

    // Dumb thing that appears to be necessary for Android 11 and under (see https://stackoverflow.com/questions/69684656/upgrading-to-workmanager-2-7-0-how-to-implement-getforegroundinfoasync-for-rxwo)
    override fun getForegroundInfoAsync(): ListenableFuture<ForegroundInfo> {
        val notification = NotificationCompat.Builder(applicationContext, "com.bluebubbles.foreground_service")
            .setSmallIcon(R.mipmap.ic_stat_icon)
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentTitle("BlueBubbles DartWorker")
            .setContentText("BlueBubbles is performing short work in the background")
            .setColor(4888294)
            .build()
        return Futures.immediateFuture(ForegroundInfo(Constants.dartWorkerNotificationId, notification))
    }
}