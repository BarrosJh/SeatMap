import 'dart:js_interop';
import 'dart:js_interop_unsafe';

class CameraPermissionClientImpl {
  Future<bool> requestCameraPermission() async {
    try {
      if (!globalContext.has('SeatMapCamera')) return false;
      final bridge = globalContext['SeatMapCamera'] as JSObject?;
      if (bridge == null || !bridge.has('requestCameraPermission')) return false;

      final jsPromise = bridge.callMethod('requestCameraPermission'.toJS) as JSPromise<JSBoolean>;
      final jsResult = await jsPromise.toDart;
      return jsResult.toDart;
    } catch (_) {
      return false;
    }
  }
}

