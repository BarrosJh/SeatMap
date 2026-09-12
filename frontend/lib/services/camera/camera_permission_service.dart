import 'camera_permission_stub.dart'
    if (dart.library.js_interop) 'camera_permission_web.dart';

class CameraPermissionService {
  static Future<bool> requestCameraPermission() async {
    final client = CameraPermissionClientImpl();
    return await client.requestCameraPermission();
  }
}

