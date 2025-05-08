import 'dart:typed_data';

class FlutterEspBlufiCallback {
  static const STATE_CONNECTED = 2;
  static const STATE_CONNECTING = 1;
  static const STATE_DISCONNECTED = 0;
  static const STATE_DISCONNECTING = 3;


  final Function(List<Map<String, dynamic>>? results)? onBatchScanResults;
  final Function(Map<String, dynamic> results)? onScanResult;
  final Function(int errorCode)? onScanFailed;
  final Function(int status, int newState)? onConnectionStateChange;
  final Function(int status)? onNegotiateSecurityResult;
  final Function(int status)? onPostConfigureParams;
  final Function(int status, Map<String, dynamic>? response)? onDeviceStatusResponse;
  final Function(int status, List<Map<String, dynamic>>? results)? onWifiScanResults;
  final Function(int status, Uint8List data)? onReceiveCustomData;
  final Function(int errorCode)? onError;

  final Function(int status, int mtu)? onGattMtuChanged;
  final Function(int status)? onGattServicesDiscovered;
  final Function(bool service, bool writeChar, bool notifyChar)? onGattPrepared;


  FlutterEspBlufiCallback({
    this.onBatchScanResults,
    this.onScanResult,
    this.onScanFailed,
    this.onConnectionStateChange,
    this.onNegotiateSecurityResult,
    this.onPostConfigureParams,
    this.onDeviceStatusResponse,
    this.onGattPrepared,
    this.onGattMtuChanged,
    this.onGattServicesDiscovered,
    this.onWifiScanResults,
    this.onReceiveCustomData,
    this.onError,
  });
}
