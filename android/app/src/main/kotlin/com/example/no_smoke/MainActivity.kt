package com.example.no_smoke

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "no_smoke/watchdog"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"startWatchdog" -> {
						val taskTitle = call.argument<String>("taskTitle").orEmpty()
						val watchdogId = call.argument<String>("watchdogId").orEmpty()
						val dueAtMillis = call.argument<Number>("dueAtMillis")?.toLong() ?: 0L
						if (taskTitle.isBlank() || watchdogId.isBlank() || dueAtMillis <= 0L) {
							result.error("invalid_args", "taskTitle/watchdogId/dueAtMillis required", null)
							return@setMethodCallHandler
						}
						NoResponseWatchdogService.start(this, taskTitle, watchdogId, dueAtMillis)
						result.success(true)
					}

					"ackWatchdog" -> {
						val watchdogId = call.argument<String>("watchdogId").orEmpty()
						if (watchdogId.isNotBlank()) {
							NoResponseWatchdogService.acknowledge(this, watchdogId)
						}
						result.success(true)
					}

					"consumeWatchdogViolations" -> {
						val rows = WatchdogStore.drainViolations(this)
						val mapped = rows.mapNotNull { row ->
							val parts = row.split("|")
							if (parts.size < 3) {
								return@mapNotNull null
							}
							mapOf(
								"type" to parts[0],
								"taskTitle" to parts[1],
								"createdAtMillis" to (parts[2].toLongOrNull() ?: System.currentTimeMillis()),
							)
						}
						result.success(mapped)
					}

					else -> result.notImplemented()
				}
			}
	}
}
