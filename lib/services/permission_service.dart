import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> ensureTelemetryPermissions() async {
    var granted = true;

    try {
      final activity = await Permission.activityRecognition.request();
      granted = granted && activity.isGranted;
    } catch (_) {
      // Some platforms do not expose this permission.
    }

    return granted;
  }
}
