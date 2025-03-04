import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_esp_blufi/flutter_esp_blufi_callback.dart';

import 'flutter_esp_blufi_platform_interface.dart';

/// An implementation of [FlutterEspBlufiPlatform] that uses method channels.
class MethodChannelFlutterEspBlufi extends FlutterEspBlufiPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final _methodChannel = const MethodChannel('flutter_esp_blufi');
  @visibleForTesting
  final _eventChannel = const EventChannel('flutter_esp_blufi.event');

  final _callbacks = <FlutterEspBlufiCallback>[];

  MethodChannelFlutterEspBlufi() {
    _eventChannel
        .receiveBroadcastStream()
        .listen(_eventListener, onError: (Object obj) => throw obj as PlatformException);
  }

  @override
  void addCallback(FlutterEspBlufiCallback callback) {
    _callbacks.add(callback);
  }

  @override
  void removeCallback(FlutterEspBlufiCallback callback) {
    _callbacks.remove(callback);
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = await _methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<void> scanDevice({String? filterString}) async {
    final json = {
      'filter': filterString,
    };
    await _methodChannel.invokeMethod('scanDevice', json);
  }

  @override
  Future<void> stopScan() async {
    await _methodChannel.invokeMethod('stopScan');
  }

  @override
  Future<void> connectDevice(String? deviceAddress) async {
    final json = {
      'deviceAddress': deviceAddress,
    };
    await _methodChannel.invokeMethod('connectDevice', json);
  }

  @override
  Future<void> disconnectDevice() async {
    await _methodChannel.invokeMethod('disconnectDevice');
  }

  @override
  Future<void> negotiateSecurity() async {
    await _methodChannel.invokeMethod('negotiateSecurity');
  }

  @override
  Future<void> configure({required String ssid, required String password}) async {
    final params = {
      'ssid': ssid,
      'password': password,
    };
    await _methodChannel.invokeMethod('configure', params);
  }

  @override
  Future<void> requestDeviceStatus() async {
    await _methodChannel.invokeMethod('requestDeviceStatus');
  }

  @override
  Future<void> requestDeviceVersion() async {
    await _methodChannel.invokeMethod('requestDeviceVersion');
  }

  @override
  Future<void> requestDeviceWifiScan() async {
    await _methodChannel.invokeMethod('requestDeviceWifiScan');
  }

  @override
  Future<void> postCustomData(Uint8List data) async {
    final json = {
      'data': data,
    };
    await _methodChannel.invokeMethod('postCustomData', json);
  }

  void _eventListener(dynamic payload) {
    if (kDebugMode) {
      log("event listener: $payload");
    }
    final json = payload.cast<String, dynamic>();
    final String event = json['event'];
    final data = json['data'];
    for (final callback in _callbacks) {
      if (event == 'onScanResult') {
        callback.onScanResult?.call(data?.cast<String, dynamic>());
      } else if (event == 'onBatchScanResults') {
        final array = data as List;
        final List<Map<String, dynamic>> results = array.cast<Map<String, dynamic>>();
        callback.onBatchScanResults?.call(results);
      } else if (event == 'onScanFailed') {
        callback.onScanFailed?.call(data['errorCode']);
      } else if (event == 'onNegotiateSecurityResult') {
        callback.onNegotiateSecurityResult?.call(data['status']);
      } else if (event == 'onPostConfigureParams') {
        callback.onPostConfigureParams?.call(data['status']);
      } else if (event == 'onDeviceStatusResponse') {
        callback.onDeviceStatusResponse?.call(data['status'], data['response']);
      } else if (event == 'onConnectionStateChange') {
        callback.onConnectionStateChange?.call(data['status'], data['newState']);
      } else if (event == 'onWifiScanResults') {
        final array = data['results'] as List;
        final List<Map<String, dynamic>> results = array.cast<Map<String, dynamic>>();
        callback.onWifiScanResults?.call(data['status'], results);
      } else if (event == 'onReceiveCustomData') {
        callback.onReceiveCustomData?.call(data['status'], data['data']);
      } else if (event == 'onError') {
        callback.onError?.call(data['errorCode']);
      }
    }
  }
}
