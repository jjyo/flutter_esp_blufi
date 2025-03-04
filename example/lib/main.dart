import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_esp_blufi/flutter_esp_blufi.dart';
import 'package:flutter_esp_blufi/flutter_esp_blufi_callback.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _flutterEspBlufiPlugin = FlutterEspBlufi();
  String? _address;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      // final status = await Permission.locationWhenInUse.request();
      // if(status == PermissionStatus.granted){
      //   return true;
      // }
      // return false;
      return true;
    }
    Map<Permission, PermissionStatus> status = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    if (status[Permission.bluetooth] == PermissionStatus.granted &&
        status[Permission.bluetoothScan] == PermissionStatus.granted &&
        status[Permission.location] == PermissionStatus.granted &&
        status[Permission.bluetoothConnect] == PermissionStatus.granted) {
      return true;
    }
    return false;
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion = await _flutterEspBlufiPlugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });

    FlutterEspBlufi.addCallback(
      FlutterEspBlufiCallback(
        onScanResult: (data) {
          _address = data['address'];
        },
        onReceiveCustomData: (status, data) {
          if (data != null) {
            final dataNoCrc = data.sublist(0, max(0, data.length - 1));
            final json = jsonDecode(utf8.decode(dataNoCrc));
            print('onReceiveCustomData: $status, $json');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Plugin example app'),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Running on: $_platformVersion\n'),
              Wrap(
                children: [
                  TextButton(
                      onPressed: () async {
                        final approved = await requestPermission();
                        print("Permission approved: $approved");
                        if (approved) {
                          FlutterEspBlufi.scanDevice(filterString: 'BLUFI');
                        }
                      },
                      child: Text('Start Scan')),
                  TextButton(
                    onPressed: () async {
                      FlutterEspBlufi.stopScan();
                    },
                    child: Text('Stop Scan'),
                  ),
                ],
              ),
              Wrap(
                children: [
                  TextButton(
                    onPressed: () async {
                      if (_address != null) {
                        FlutterEspBlufi.connectDevice(_address);
                      } else {
                        print('No device address');
                      }
                    },
                    child: Text('Connect'),
                  ),
                  TextButton(
                    onPressed: () async {
                      FlutterEspBlufi.disconnectDevice();
                    },
                    child: Text('Disconnect'),
                  ),
                  TextButton(
                    onPressed: () async {
                      FlutterEspBlufi.requestDeviceWifiScan();
                    },
                    child: Text('wifiScan'),
                  ),
                  TextButton(
                    onPressed: () async {
                      FlutterEspBlufi.configure(ssid: 'xxxx', password: 'xxxx');
                    },
                    child: Text('Configure'),
                  ),
                ],
              ),

            ],
          )),
    );
  }
}
