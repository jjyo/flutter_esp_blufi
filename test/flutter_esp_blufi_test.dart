import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_esp_blufi/flutter_esp_blufi.dart';
import 'package:flutter_esp_blufi/flutter_esp_blufi_platform_interface.dart';
import 'package:flutter_esp_blufi/flutter_esp_blufi_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterEspBlufiPlatform
    with MockPlatformInterfaceMixin
    implements FlutterEspBlufiPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterEspBlufiPlatform initialPlatform = FlutterEspBlufiPlatform.instance;

  test('$MethodChannelFlutterEspBlufi is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterEspBlufi>());
  });

  test('getPlatformVersion', () async {
    FlutterEspBlufi flutterEspBlufiPlugin = FlutterEspBlufi();
    MockFlutterEspBlufiPlatform fakePlatform = MockFlutterEspBlufiPlatform();
    FlutterEspBlufiPlatform.instance = fakePlatform;

    expect(await FlutterEspBlufi.getPlatformVersion(), '42');
  });
}
