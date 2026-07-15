import '../models/sensor_usage_event.dart';
import 'storage_service.dart';

/// Infers device activity states from historical usage and sensor samples.
class PhoneStateService {
	final StorageService _storageService;

	PhoneStateService({StorageService? storageService})
			: _storageService = storageService ?? StorageService();

	  /// Runs only when explicitly requested by UI or workflow; no periodic background loop.
	Future<Map<String, dynamic>> inferDailyStateSummary() async {
		final events = await _storageService.loadRecentSensorUsage(limit: 240);
		if (events.isEmpty) {
			return {
				'activeHours': <String>[],
				'passiveHours': <String>[],
				'drivingPrediction': 'unknown',
			};
		}

		final activeBuckets = <int, int>{};
		final passiveBuckets = <int, int>{};
		var drivingVotes = 0;
		for (final event in events) {
			final hour = event.createdAt.hour;
			final isActive = event.appUsageMinutes >= 10 || event.screenUnlockCount >= 8;
			if (isActive) {
				activeBuckets[hour] = (activeBuckets[hour] ?? 0) + 1;
			} else {
				passiveBuckets[hour] = (passiveBuckets[hour] ?? 0) + 1;
			}

			if (_isLikelyDriving(event)) {
				drivingVotes += 1;
			}
		}

		return {
			'activeHours': _topHours(activeBuckets),
			'passiveHours': _topHours(passiveBuckets),
			'drivingPrediction': drivingVotes >= (events.length * 0.2) ? 'driving' : 'not-driving',
		};
	}

	/// Lightweight real-time context used to avoid disruptive notifications.
	Future<Map<String, dynamic>> inferRealtimeInterruptionContext() async {
		final recent = await _storageService.loadRecentSensorUsage(limit: 5);
		if (recent.isEmpty) {
			return {
				'isDriving': false,
				'isRunningOrWorkout': false,
				'isEatingLikely': false,
				'recommendedDeferralMinutes': 0,
				'confidence': 0.0,
				'contextLabel': 'normal',
			};
		}

		final latest = recent.last;
		final activity = _normalize(latest.activityState);
		final drivingVotes = recent.where(_isLikelyDriving).length;
		final workoutVotes = recent.where(_isLikelyRunningOrWorkout).length;
		final drivingConfidence = drivingVotes / recent.length;
		final workoutConfidence = workoutVotes / recent.length;

		final isDriving = _isLikelyDriving(latest) ||
			activity.contains('driving') ||
			activity.contains('car') ||
			activity.contains('vehicle');

		final isRunningOrWorkout = _isLikelyRunningOrWorkout(latest) ||
			activity.contains('running') ||
			activity.contains('jog') ||
			activity.contains('workout') ||
			activity.contains('exercise') ||
			activity.contains('cycling') ||
			activity.contains('bike');

		final lunchTime = await _storageService.loadSetting('lunch_time') ?? '12:30';
		final dinnerTime = await _storageService.loadSetting('dinner_time') ?? '19:00';
		final now = DateTime.now();
		final isMealWindow = _isWithinMealWindow(now: now, centerTime: lunchTime) ||
			_isWithinMealWindow(now: now, centerTime: dinnerTime);
		final lowInteraction = latest.screenUnlockCount <= 1 &&
			latest.appUsageMinutes <= 2 &&
			latest.idleMinutes <= 12;
		final eatingVotes = recent
			.where(
				(event) => event.screenUnlockCount <= 1 &&
					event.appUsageMinutes <= 2 &&
					event.idleMinutes <= 12,
			)
			.length;
		final eatingConfidence = isMealWindow ? (eatingVotes / recent.length) : 0.0;
		final isEatingLikely = !isDriving &&
			!isRunningOrWorkout &&
			isMealWindow &&
			lowInteraction;

		var delay = 0;
		var label = 'normal';
		var confidence = 0.25;
		if (isDriving) {
			delay = 20;
			label = 'driving';
			confidence = drivingConfidence < 0.55 ? 0.55 : drivingConfidence;
		} else if (isRunningOrWorkout) {
			delay = 20;
			label = 'workout';
			confidence = workoutConfidence < 0.55 ? 0.55 : workoutConfidence;
		} else if (isEatingLikely) {
			delay = 25;
			label = 'eating';
			confidence = eatingConfidence < 0.50 ? 0.50 : eatingConfidence;
		}

		return {
			'isDriving': isDriving,
			'isRunningOrWorkout': isRunningOrWorkout,
			'isEatingLikely': isEatingLikely,
			'recommendedDeferralMinutes': delay,
			'confidence': confidence.clamp(0.0, 1.0),
			'contextLabel': label,
		};
	}

	bool _isLikelyDriving(SensorUsageEvent event) {
		return event.activityState == 'driving' ||
				(event.accelerometerMagnitude > 1.1 &&
						event.gyroscopeMagnitude > 0.8 &&
						event.screenUnlockCount <= 2);
	}

	bool _isLikelyRunningOrWorkout(SensorUsageEvent event) {
		return event.accelerometerMagnitude >= 1.8 ||
			event.gyroscopeMagnitude >= 1.8;
	}

	bool _isWithinMealWindow({
		required DateTime now,
		required String centerTime,
	}) {
		final parts = centerTime.split(':');
		if (parts.length != 2) {
			return false;
		}
		final hour = int.tryParse(parts[0]);
		final minute = int.tryParse(parts[1]);
		if (hour == null || minute == null) {
			return false;
		}

		final center = DateTime(now.year, now.month, now.day, hour, minute);
		final diff = now.difference(center).inMinutes.abs();
		return diff <= 45;
	}

	String _normalize(String value) {
		return value
			.toLowerCase()
			.replaceAll('ı', 'i')
			.replaceAll('ğ', 'g')
			.replaceAll('ş', 's')
			.replaceAll('ö', 'o')
			.replaceAll('ü', 'u')
			.replaceAll('ç', 'c');
	}

	List<String> _topHours(Map<int, int> buckets) {
		final sorted = buckets.entries.toList()
			..sort((a, b) => b.value.compareTo(a.value));
		return sorted.take(4).map((entry) => '${entry.key.toString().padLeft(2, '0')}:00').toList();
	}
}
