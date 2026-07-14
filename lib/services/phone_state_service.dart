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

	bool _isLikelyDriving(SensorUsageEvent event) {
		return event.activityState == 'driving' ||
				(event.accelerometerMagnitude > 1.1 &&
						event.gyroscopeMagnitude > 0.8 &&
						event.screenUnlockCount <= 2);
	}

	List<String> _topHours(Map<int, int> buckets) {
		final sorted = buckets.entries.toList()
			..sort((a, b) => b.value.compareTo(a.value));
		return sorted.take(4).map((entry) => '${entry.key.toString().padLeft(2, '0')}:00').toList();
	}
}
