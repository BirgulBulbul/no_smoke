import '../models/sensor_usage_event.dart';
import 'storage_service.dart';

/// Stores coarse sensor and usage telemetry used by adaptive behavior analysis.
class SensorService {
	static const _lastCaptureKey = 'sensor_last_capture_at';
	static const Duration _minCaptureInterval = Duration(minutes: 20);
	static const double _motionDeltaThreshold = 0.35;

	final StorageService _storageService;

	SensorService({StorageService? storageService})
			: _storageService = storageService ?? StorageService();

	/// Saves a normalized sensor sample only when there is meaningful change.
	/// Returns true if a new sample is persisted.
	Future<bool> logSensorSample({
		required String activityState,
		required double accelerometerMagnitude,
		required double gyroscopeMagnitude,
		required int screenUnlockCount,
		required int appUsageMinutes,
		required int idleMinutes,
		required bool charging,
	}) async {
		final now = DateTime.now();
		final lastCaptureRaw = await _storageService.loadSetting(_lastCaptureKey);
		final lastCaptureTime =
				lastCaptureRaw == null ? null : DateTime.tryParse(lastCaptureRaw);

		if (lastCaptureTime != null &&
				now.difference(lastCaptureTime) < _minCaptureInterval) {
			return false;
		}

		final recent = await _storageService.loadRecentSensorUsage(limit: 1);
		final previous = recent.isEmpty ? null : recent.last;
		if (previous != null &&
				!_isSignificantChange(
					previous: previous,
					activityState: activityState,
					accelerometerMagnitude: accelerometerMagnitude,
					gyroscopeMagnitude: gyroscopeMagnitude,
					screenUnlockCount: screenUnlockCount,
					appUsageMinutes: appUsageMinutes,
					charging: charging,
				)) {
			return false;
		}

		final event = SensorUsageEvent(
			id: 'sensor_${now.microsecondsSinceEpoch}',
			createdAt: now,
			activityState: activityState,
			accelerometerMagnitude: accelerometerMagnitude,
			gyroscopeMagnitude: gyroscopeMagnitude,
			screenUnlockCount: screenUnlockCount,
			appUsageMinutes: appUsageMinutes,
			idleMinutes: idleMinutes,
			charging: charging,
		);

		await _storageService.saveSensorUsageEvent(event);
		await _storageService.saveSetting(_lastCaptureKey, now.toIso8601String());
		return true;
	}

	bool _isSignificantChange({
		required SensorUsageEvent previous,
		required String activityState,
		required double accelerometerMagnitude,
		required double gyroscopeMagnitude,
		required int screenUnlockCount,
		required int appUsageMinutes,
		required bool charging,
	}) {
		if (previous.activityState != activityState) {
			return true;
		}
		if (previous.charging != charging) {
			return true;
		}
		if ((previous.accelerometerMagnitude - accelerometerMagnitude).abs() >=
				_motionDeltaThreshold) {
			return true;
		}
		if ((previous.gyroscopeMagnitude - gyroscopeMagnitude).abs() >=
				_motionDeltaThreshold) {
			return true;
		}
		if ((previous.screenUnlockCount - screenUnlockCount).abs() >= 5) {
			return true;
		}
		if ((previous.appUsageMinutes - appUsageMinutes).abs() >= 10) {
			return true;
		}
		return false;
	}
}
