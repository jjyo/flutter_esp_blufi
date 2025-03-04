import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_esp_blufi_callback.dart';
import 'flutter_esp_blufi_method_channel.dart';

abstract class FlutterEspBlufiPlatform extends PlatformInterface {
  /// Constructs a FlutterEspBlufiPlatform.
  FlutterEspBlufiPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterEspBlufiPlatform _instance = MethodChannelFlutterEspBlufi();

  /// The default instance of [FlutterEspBlufiPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterEspBlufi].
  static FlutterEspBlufiPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterEspBlufiPlatform] when
  /// they register themselves.
  static set instance(FlutterEspBlufiPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }


  void addCallback(FlutterEspBlufiCallback callback) {
    throw UnimplementedError('addCallback() has not been implemented.');
  }

  void removeCallback(FlutterEspBlufiCallback callback) {
    throw UnimplementedError('removeCallback() has not been implemented.');
  }

  Future<void> scanDevice({String? filterString}) async {
    throw UnimplementedError('scanDevice() has not been implemented.');
  }

  Future<void> stopScan() async {
    throw UnimplementedError('stopScan() has not been implemented.');
  }

  Future<void> connectDevice(String? deviceAddress) async {
    throw UnimplementedError('connectPeripheral() has not been implemented.');
  }

  Future<void> disconnectDevice() async {
    throw UnimplementedError('disconnectDevice() has not been implemented.');
  }

  Future<void> negotiateSecurity() async {
    throw UnimplementedError('negotiateSecurity() has not been implemented.');
  }

  Future<void> configure({required String ssid, required String password}) async {
    throw UnimplementedError('configure() has not been implemented.');
  }

  Future<void> requestDeviceStatus() async {
    throw UnimplementedError('requestDeviceStatus() has not been implemented.');
  }

  Future<void> requestDeviceVersion() async {
    throw UnimplementedError('requestDeviceVersion() has not been implemented.');
  }

  Future<void> requestDeviceWifiScan() async {
    throw UnimplementedError('requestDeviceWifiScan() has not been implemented.');
  }

  Future<void> postCustomData(Uint8List bytes) async {
    throw UnimplementedError('postCustomData() has not been implemented.');
  }
}
