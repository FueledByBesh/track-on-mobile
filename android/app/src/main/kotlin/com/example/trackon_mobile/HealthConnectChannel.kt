package com.example.trackon_mobile

import android.content.Context
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

class HealthConnectChannel(private val activity: ComponentActivity) {

    private val scope = CoroutineScope(Dispatchers.Main)
    private var pendingPermissionResult: MethodChannel.Result? = null

    private val requiredPermissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class)
    )

    // Permission request launcher
    private val permissionLauncher: ActivityResultLauncher<Set<String>> =
        activity.registerForActivityResult(
            PermissionController.createRequestPermissionResultContract()
        ) { granted ->
            val result = pendingPermissionResult
            pendingPermissionResult = null
            if (granted.containsAll(requiredPermissions)) {
                result?.success(true)
            } else {
                result?.success(false)
            }
        }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> isAvailable(result)
            "requestPermission" -> requestPermission(result)
            "hasPermission" -> hasPermission(result)
            "getSteps" -> {
                val since = call.argument<String>("since")!!
                getSteps(since, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun isAvailable(result: MethodChannel.Result) {
        val status = HealthConnectClient.getSdkStatus(activity)
        result.success(status == HealthConnectClient.SDK_AVAILABLE)
    }

    private fun requestPermission(result: MethodChannel.Result) {
        val status = HealthConnectClient.getSdkStatus(activity)
        if (status != HealthConnectClient.SDK_AVAILABLE) {
            result.success(false)
            return
        }
        pendingPermissionResult = result
        permissionLauncher.launch(requiredPermissions)
    }

    private fun hasPermission(result: MethodChannel.Result) {
        val status = HealthConnectClient.getSdkStatus(activity)
        if (status != HealthConnectClient.SDK_AVAILABLE) {
            result.success(false)
            return
        }

        scope.launch {
            try {
                val client = HealthConnectClient.getOrCreate(activity)
                val granted = client.permissionController.getGrantedPermissions()
                result.success(granted.containsAll(requiredPermissions))
            } catch (e: Exception) {
                result.success(false)
            }
        }
    }

    private fun getSteps(sinceStr: String, result: MethodChannel.Result) {
        val status = HealthConnectClient.getSdkStatus(activity)
        if (status != HealthConnectClient.SDK_AVAILABLE) {
            result.success(emptyList<Map<String, Any>>())
            return
        }

        scope.launch {
            try {
                val client = HealthConnectClient.getOrCreate(activity)
                val since = Instant.parse(sinceStr)

                val request = ReadRecordsRequest(
                    recordType = StepsRecord::class,
                    timeRangeFilter = TimeRangeFilter.after(since)
                )

                val response = client.readRecords(request)
                val userZone = ZoneId.systemDefault()
                val dateFormatter = DateTimeFormatter.ISO_LOCAL_DATE

                val intervals = response.records.map { record ->
                    val startLocal = record.startTime.atZone(record.startZoneOffset ?: userZone.rules.getOffset(record.startTime))
                    val endLocal = record.endTime.atZone(record.endZoneOffset ?: userZone.rules.getOffset(record.endTime))

                    mapOf(
                        "startTime" to record.startTime.toString(),
                        "endTime" to record.endTime.toString(),
                        "startTimeLocal" to startLocal.toString(),
                        "endTimeLocal" to endLocal.toString(),
                        "date" to startLocal.format(dateFormatter),
                        "stepsValue" to record.count.toInt(),
                        "source" to (record.metadata.dataOrigin.packageName)
                    )
                }

                result.success(intervals)
            } catch (e: Exception) {
                result.error("HEALTH_ERROR", e.message, null)
            }
        }
    }
}
