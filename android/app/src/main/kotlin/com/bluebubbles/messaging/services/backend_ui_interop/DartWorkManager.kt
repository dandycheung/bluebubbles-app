package com.bluebubbles.messaging.services.backend_ui_interop

import android.content.Context
import android.util.Log
import androidx.lifecycle.Observer
import androidx.work.BackoffPolicy
import androidx.work.Data
import androidx.work.OneTimeWorkRequest
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.WorkRequest
import java.util.concurrent.TimeUnit
import com.bluebubbles.messaging.Constants
import com.google.gson.GsonBuilder
import com.google.gson.ToNumberPolicy
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

object DartWorkManager {
    fun createWorker(context: Context, method: String, arguments: HashMap<String, Any?>, callback: () -> (Unit)) {
        Log.d(Constants.logTag, "Creating new ${Constants.dartWorkerTag} for method $method")
        val gson = GsonBuilder()
            .setObjectToNumberStrategy(ToNumberPolicy.LONG_OR_DOUBLE)
            .create()
        val work = OneTimeWorkRequest.Builder(DartWorker::class.java)
            .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
            // Retries redeliver dropped events (e.g. notifications); use the minimum
            // backoff so a retried notification arrives seconds late, not minutes.
            .setBackoffCriteria(BackoffPolicy.LINEAR, WorkRequest.MIN_BACKOFF_MILLIS, TimeUnit.MILLISECONDS)
            .setInputData(Data.Builder()
                .putString("method", method)
                .putString("data", gson.toJson(arguments).toString()).build())
            .addTag(Constants.dartWorkerTag)
            .build()
        WorkManager.getInstance(context).enqueue(work)

        // Observe when the worker is finished and run the provided callback.
        // Everything runs on the main thread (LiveData requirement), and we must hold
        // the ONE LiveData instance: getWorkInfoByIdLiveData returns a new instance per
        // call, so removing the observer from a second instance would be a no-op and
        // leak the observer (and its Room subscription) for the life of the process.
        CoroutineScope(Dispatchers.Main).launch {
            try {
                val liveData = WorkManager.getInstance(context).getWorkInfoByIdLiveData(work.id)
                // WorkInfo? — the LiveData emits null once the work record is pruned;
                // a non-null Observer<WorkInfo> would NPE on that emission and crash the process.
                lateinit var observer: Observer<WorkInfo?>
                observer = Observer { workInfo ->
                    if (workInfo != null && !workInfo.state.isFinished) return@Observer
                    // Remove first (we're on the main thread, so this is synchronous) so a
                    // re-emission can't run the callback twice.
                    liveData.removeObserver(observer)
                    if (workInfo == null) {
                        Log.w(Constants.logTag, "Work record for method $method was pruned before completion was observed")
                        return@Observer
                    }
                    Log.d(Constants.logTag, "Running callback after worker with method $method completed (state: ${workInfo.state})")
                    try {
                        callback()
                    } catch (e: Exception) {
                        Log.e(Constants.logTag, "Error running callback for worker $method", e)
                    }
                }
                liveData.observeForever(observer)
            } catch (e: Exception) {
                Log.e(Constants.logTag, "Error observing worker $method", e)
            }
        }
    }
}