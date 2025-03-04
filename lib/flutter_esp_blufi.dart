import 'dart:typed_data';

import 'flutter_esp_blufi_callback.dart';
import 'flutter_esp_blufi_platform_interface.dart';

class FlutterEspBlufi {

  Future<String?> getPlatformVersion() {
    return FlutterEspBlufiPlatform.instance.getPlatformVersion();
  }

  static addCallback(FlutterEspBlufiCallback callback) {
    FlutterEspBlufiPlatform.instance.addCallback(callback);
  }

  static removeCallback(FlutterEspBlufiCallback callback) {
    FlutterEspBlufiPlatform.instance.removeCallback(callback);
  }


  static Future<void> scanDevice({String? filterString}) async {
    FlutterEspBlufiPlatform.instance.scanDevice(filterString: filterString);
  }

  static Future<void> stopScan() async {
    FlutterEspBlufiPlatform.instance.stopScan();
  }

  static Future<void> connectDevice(String? deviceAddress) async {
    FlutterEspBlufiPlatform.instance.connectDevice(deviceAddress);
  }

  static Future<void> disconnectDevice() async {
    FlutterEspBlufiPlatform.instance.disconnectDevice();
  }

  static Future<void> negotiateSecurity() async {
    FlutterEspBlufiPlatform.instance.negotiateSecurity();
  }

  static Future<void> configure({required String ssid, required String password}) async {
    FlutterEspBlufiPlatform.instance.configure(ssid: ssid, password: password);
  }

  static Future<void> requestDeviceStatus() async {
    FlutterEspBlufiPlatform.instance.requestDeviceStatus();
  }

  static Future<void> requestDeviceVersion() async {
    FlutterEspBlufiPlatform.instance.requestDeviceVersion();
  }

  static Future<void> requestDeviceWifiScan() async {
    FlutterEspBlufiPlatform.instance.requestDeviceWifiScan();
  }

  static Future<void> postCustomData(Uint8List bytes) async {
    FlutterEspBlufiPlatform.instance.postCustomData(bytes);
  }
}
