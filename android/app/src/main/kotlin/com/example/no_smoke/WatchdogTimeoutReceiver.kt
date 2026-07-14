package com.example.no_smoke

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class WatchdogTimeoutReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_TIMEOUT) {
            return
        }
        val watchdogId = intent.getStringExtra(NoResponseWatchdogService.EXTRA_WATCHDOG_ID).orEmpty()
        if (watchdogId.isBlank()) {
            return
        }

        val state = WatchdogStore.loadActive(context) ?: return
        if (state.watchdogId != watchdogId) {
            return
        }
        if (state.acknowledged) {
            WatchdogStore.clearActive(context)
            return
        }
        if (System.currentTimeMillis() >= state.dueAtMillis) {
            WatchdogViolationNotifier.triggerNoResponseViolation(context, state)
            WatchdogStore.clearActive(context)
            val stopIntent = Intent(context, NoResponseWatchdogService::class.java)
            context.stopService(stopIntent)
        }
    }

    companion object {
        const val ACTION_TIMEOUT = "com.example.no_smoke.watchdog.TIMEOUT"
    }
}
