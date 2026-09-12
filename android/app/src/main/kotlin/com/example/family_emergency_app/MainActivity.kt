package com.example.family_emergency_app

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.familyemergency.app/screen_time"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPermissionState" -> result.success(permissionState())
                    "openUsageAccessSettings" -> {
                        result.success(openUsageAccessSettings())
                    }
                    "queryUsageStats" -> {
                        if (permissionState() != "granted") {
                            result.error("usage-access-denied", "Usage access is not enabled.", null)
                            return@setMethodCallHandler
                        }
                        val startMs = call.argument<Number>("startMs")?.toLong()
                        val endMs = call.argument<Number>("endMs")?.toLong()
                        if (startMs == null || endMs == null || startMs >= endMs) {
                            result.error("invalid-range", "A valid local time range is required.", null)
                            return@setMethodCallHandler
                        }
                        result.success(queryUsageStats(startMs, endMs))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun permissionState(): String {
        val manager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return "unavailable"
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager
            ?: return "unavailable"
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName,
            )
        }
        return if (mode == AppOpsManager.MODE_ALLOWED) "granted" else "notGranted"
    }

    private fun openUsageAccessSettings(): Boolean = try {
        val appIntent = Intent(
            Settings.ACTION_USAGE_ACCESS_SETTINGS,
            Uri.parse("package:$packageName"),
        )
        if (appIntent.resolveActivity(packageManager) != null) {
            startActivity(appIntent)
        } else {
            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
        }
        true
    } catch (_: Exception) {
        false
    }

    private fun queryUsageStats(startMs: Long, endMs: Long): List<Map<String, Any>> {
        val manager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val stats = manager.queryAndAggregateUsageStats(startMs, endMs)
        return stats.values
            .asSequence()
            .filter { it.packageName != packageName && it.totalTimeInForeground > 0L }
            .map { usage ->
                val label = try {
                    val info = packageManager.getApplicationInfo(usage.packageName, 0)
                    packageManager.getApplicationLabel(info).toString()
                } catch (_: Exception) {
                    usage.packageName.substringAfterLast('.')
                }
                mapOf(
                    "packageName" to usage.packageName,
                    "appName" to label,
                    "totalTimeMs" to usage.totalTimeInForeground,
                    "lastTimeUsedMs" to usage.lastTimeUsed,
                )
            }
            .sortedByDescending { it["totalTimeMs"] as Long }
            .take(100)
            .toList()
    }
}
