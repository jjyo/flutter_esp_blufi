package com.kurvia.flutter_esp_blufi;

import android.Manifest;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.content.Context;
import android.content.pm.PackageManager;
import android.location.LocationManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.text.TextUtils;
import android.util.Log;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.core.location.LocationManagerCompat;


import org.json.JSONObject;

import java.util.LinkedList;
import java.util.List;
import java.util.Locale;

import blufi.espressif.BlufiCallback;
import blufi.espressif.BlufiClient;
import blufi.espressif.params.BlufiConfigureParams;
import blufi.espressif.params.BlufiParameter;
import blufi.espressif.response.BlufiScanResult;
import blufi.espressif.response.BlufiStatusResponse;
import blufi.espressif.response.BlufiVersionResponse;

import blufi.espressif.BlufiClient;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * FlutterEspBlufiPlugin
 */
public class FlutterEspBlufiPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private static final int REQUEST_FINE_LOCATION_PERMISSIONS = 1452;

    private static final long TIMEOUT_SCAN = 4000L;

    private static final int REQUEST_PERMISSION = 0x01;
    private static final int REQUEST_BLUFI = 0x10;

    private static final int MENU_SETTINGS = 0x01;

    private MethodChannel channel;
    private EventChannel eventChannel;
    private EventChannel.EventSink eventSink;
    private Context context;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private ActivityPluginBinding activityBinding;

    private List<ScanResult> mBleList;
    private Map<String, ScanResult> mDeviceMap;
    private volatile long mScanStartTime;
    private String mBlufiFilter;
    private ExecutorService mThreadPool;
    private Future<Boolean> mUpdateFuture;
    private ScanCallback mScanCallback;


    private BluetoothDevice mDevice;
    private BlufiClient mBlufiClient;
    private volatile boolean mConnected;


    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        context = flutterPluginBinding.getApplicationContext();
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "flutter_esp_blufi");
        channel.setMethodCallHandler(this);
        eventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), "flutter_esp_blufi.event");
        eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                eventSink = events;
            }

            @Override
            public void onCancel(Object arguments) {
                eventSink = null;
            }
        });

        mThreadPool = Executors.newSingleThreadExecutor();
        mBleList = new LinkedList<>();
        mDeviceMap = new HashMap<>();
        mScanCallback = new ScanCallback();
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        this.activityBinding = binding;
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {

    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {

    }

    @Override
    public void onDetachedFromActivity() {

    }

    private void sendEvent(String event, Object data) {
        if (eventSink != null) {

            Map payload = new HashMap<String, Object>();
            payload.put("event", event);
            payload.put("data", data);
            mainHandler.post(() -> {
                eventSink.success(payload);
            });
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        final String method = call.method;
        printDebugLog("onMethodCall " + call.method + " arguments " + call.arguments);
        if (method.equals("getPlatformVersion")) {
            result.success("Android " + android.os.Build.VERSION.RELEASE);
        } else if (method.equals("scanDevice")) {
            String filter = call.argument("filter");
            scanDevice(filter);
        } else if (method.equals("stopScan")) {
            stopScan();
        } else if (method.equals("connectDevice")) {
            String deviceAddress = call.argument("deviceAddress");
            connect(deviceAddress);
        } else if (method.equals("disconnectDevice")) {
            disconnectGatt();
        } else if (method.equals("negotiateSecurity")) {
            negotiateSecurity();
        } else if (method.equals("configure")) {
            String ssid = call.argument("ssid");
            String password = call.argument("password");
            configure(ssid, password);
        } else if (method.equals("requestDeviceStatus")) {
            requestDeviceStatus();
        } else if (method.equals("requestDeviceVersion")) {
            requestDeviceVersion();
        } else if (method.equals("requestDeviceWifiScan")) {
            requestDeviceWifiScan();
        } else if (method.equals("postCustomData")) {
            byte[] data = call.argument("data");
            postCustomData(data);
        } else {
            result.notImplemented();
        }
    }


    private void scanDevice(String filter) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
                != PackageManager.PERMISSION_GRANTED) {
            printDebugLog("ACCESS_FINE_LOCATION is not granted...scan will not be called");
            ActivityCompat.requestPermissions(
                    activityBinding.getActivity(),
                    new String[]{
                            Manifest.permission.ACCESS_FINE_LOCATION
                    },
                    REQUEST_FINE_LOCATION_PERMISSIONS);
        }
        mBlufiFilter = filter;
        BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();
        BluetoothLeScanner scanner = adapter.getBluetoothLeScanner();
        if (!adapter.isEnabled() || scanner == null) {
            Toast.makeText(context, "Bluetooth is disable", Toast.LENGTH_SHORT).show();
            return;
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            // Check location enable
            LocationManager locationManager = (LocationManager) context.getSystemService(Context.LOCATION_SERVICE);
            boolean locationEnable = locationManager != null && LocationManagerCompat.isLocationEnabled(locationManager);
            if (!locationEnable) {
                Toast.makeText(context, "Location is disable", Toast.LENGTH_SHORT).show();
                return;
            }
        }

        mDeviceMap.clear();
        mBleList.clear();
        mScanStartTime = SystemClock.elapsedRealtime();

        printDebugLog("Start scan ble");
        scanner.startScan(null, new ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(),
                mScanCallback);
        mUpdateFuture = mThreadPool.submit(() -> {
            while (!Thread.currentThread().isInterrupted()) {
                try {
                    Thread.sleep(1000);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                    break;
                }

                long scanCost = SystemClock.elapsedRealtime() - mScanStartTime;
                if (scanCost > TIMEOUT_SCAN) {
                    break;
                }

                onIntervalScanUpdate(false);
            }

            BluetoothLeScanner inScanner = BluetoothAdapter.getDefaultAdapter().getBluetoothLeScanner();
            if (inScanner != null) {
                inScanner.stopScan(mScanCallback);
            }
            onIntervalScanUpdate(true);
            printDebugLog("Scan ble thread is interrupted");
            return true;
        });
    }

    private void onIntervalScanUpdate(boolean over) {
        List<ScanResult> devices = new ArrayList<>(mDeviceMap.values());
        Collections.sort(devices, (dev1, dev2) -> {
            Integer rssi1 = dev1.getRssi();
            Integer rssi2 = dev2.getRssi();
            return rssi2.compareTo(rssi1);
        });
        mainHandler.post(() -> {
            mBleList.clear();
            mBleList.addAll(devices);
        });
    }

    private void stopScan() {
        BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();
        BluetoothLeScanner scanner = adapter.getBluetoothLeScanner();
        if (scanner != null) {
            scanner.stopScan(mScanCallback);
        }
        if (mUpdateFuture != null) {
            mUpdateFuture.cancel(true);
        }
        printDebugLog("Stop scan ble");
    }


    /**
     * Try to connect device
     */
    private void connect(String deviceAddress) {

        if (!mDeviceMap.containsKey(deviceAddress)) {
            printDebugLog("Device not found: " + deviceAddress);
            return;
        }

        ScanResult result = mDeviceMap.get(deviceAddress);
        mDevice = result.getDevice();

        if (mBlufiClient != null) {
            mBlufiClient.close();
            mBlufiClient = null;
        }

        mBlufiClient = new BlufiClient(context, mDevice);
        mBlufiClient.setGattCallback(new GattCallback());
        mBlufiClient.setBlufiCallback(new BlufiCallbackMain());
        mBlufiClient.setGattWriteTimeout(BlufiConstants.GATT_WRITE_TIMEOUT);
        mBlufiClient.connect();
    }

    private void disconnectGatt() {
        if (mBlufiClient != null) {
            mBlufiClient.requestCloseConnection();
        }
    }

    private void negotiateSecurity() {
        if (mBlufiClient != null) {
            mBlufiClient.negotiateSecurity();
        }
    }

    private void configure(String ssid, String password) {
        if (mBlufiClient != null) {
            BlufiConfigureParams params = new BlufiConfigureParams();
            params.setOpMode(1);
            byte[] ssidBytes = ssid.getBytes();
            params.setStaSSIDBytes(ssidBytes);
            params.setStaPassword(password);
            mBlufiClient.configure(params);
        }
    }

    /**
     * Request to get device current status
     */
    private void requestDeviceStatus() {
        if (mBlufiClient != null) {
            mBlufiClient.requestDeviceStatus();
        }
    }

    /**
     * Request to get device blufi version
     */
    private void requestDeviceVersion() {
        if (mBlufiClient != null) {
            mBlufiClient.requestDeviceVersion();
        }
    }

    private void requestDeviceWifiScan() {
        if (mBlufiClient != null) {
            mBlufiClient.requestDeviceWifiScan();
        }
    }

    private void postCustomData(byte[] data) {
        if (mBlufiClient != null) {
            mBlufiClient.postCustomData(data);
        }
    }

    private void printDebugLog(String msg) {
        Log.d("FlutterEspBlufiPlugin", msg);
    }


    private void onGattConnected() {
        mConnected = true;
    }

    private void onGattDisconnected() {
        mConnected = false;
    }

    private void onGattServiceCharacteristicDiscovered() {
    }


    private class ScanCallback extends android.bluetooth.le.ScanCallback {

        @Override
        public void onScanFailed(int errorCode) {
            super.onScanFailed(errorCode);
            printDebugLog("Scan failed, errorCode=" + errorCode);
            Map json = new HashMap();
            json.put("errorCode", errorCode);
            sendEvent("onScanFailed", json);
        }

        @Override
        public void onBatchScanResults(List<ScanResult> results) {
            printDebugLog("onBatchScanResults: " + results.size());
            List list = new ArrayList();
            for (ScanResult result : results) {
                String name = result.getDevice().getName();
                if (!TextUtils.isEmpty(mBlufiFilter)) {
                    if (name == null || !name.startsWith(mBlufiFilter)) {
                        continue;
                    }
                }
                onLeScan(result);
                list.add(scanResultToMap(result));
            }
            sendEvent("onBatchScanResults", list);
        }

        @Override
        public void onScanResult(int callbackType, ScanResult result) {
            String name = result.getDevice().getName();
            if (!TextUtils.isEmpty(mBlufiFilter)) {
                if (name == null || !name.startsWith(mBlufiFilter)) {
                    return;
                }
            }
            onLeScan(result);
        }

        private void onLeScan(ScanResult scanResult) {
            String name = scanResult.getDevice().getName();
            printDebugLog("onScanResult: " + scanResult.getDevice().getAddress() + " name: " + name);
            mDeviceMap.put(scanResult.getDevice().getAddress(), scanResult);
            sendEvent("onScanResult", scanResultToMap(scanResult));
        }

        private Map scanResultToMap(ScanResult scanResult) {
            Map json = new HashMap();
            json.put("address", scanResult.getDevice().getAddress());
            json.put("type", scanResult.getDevice().getType());
            json.put("name", scanResult.getDevice().getName());
            json.put("rssi", scanResult.getRssi());
            return json;
        }
    }

    private class GattCallback extends BluetoothGattCallback {
        @Override
        public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {
            String devAddr = gatt.getDevice().getAddress();
            printDebugLog(String.format(Locale.ENGLISH, "onConnectionStateChange addr=%s, status=%d, newState=%d",
                    devAddr, status, newState));
            Map json = new HashMap();
            json.put("status", status);
            json.put("newState", newState);
            sendEvent("onConnectionStateChange", json);
            if (status == BluetoothGatt.GATT_SUCCESS) {
                switch (newState) {
                    case BluetoothProfile.STATE_CONNECTED:
                        onGattConnected();
                        printDebugLog(String.format("Connected %s", devAddr));
                        break;
                    case BluetoothProfile.STATE_DISCONNECTED:
                        gatt.close();
                        onGattDisconnected();
                        printDebugLog(String.format("Disconnected %s", devAddr));
                        break;
                }
            } else {
                gatt.close();
                onGattDisconnected();
                printDebugLog(String.format(Locale.ENGLISH, "Disconnect %s, status=%d", devAddr, status));
            }
        }

        @Override
        public void onMtuChanged(BluetoothGatt gatt, int mtu, int status) {
            printDebugLog(String.format(Locale.ENGLISH, "onMtuChanged status=%d, mtu=%d", status, mtu));
            Map json = new HashMap();
            json.put("status", status);
            json.put("mtu", mtu);
            sendEvent("onMtuChanged", json);
            if (status == BluetoothGatt.GATT_SUCCESS) {
                //printDebugLog(String.format(Locale.ENGLISH, "Set mtu complete, mtu=%d ", mtu));
            } else {
                mBlufiClient.setPostPackageLengthLimit(20);
                //printDebugLog(String.format(Locale.ENGLISH, "Set mtu failed, mtu=%d, status=%d", mtu, status));
            }
            onGattServiceCharacteristicDiscovered();
        }

        @Override
        public void onServicesDiscovered(BluetoothGatt gatt, int status) {
            printDebugLog(String.format(Locale.ENGLISH, "onServicesDiscovered status=%d", status));
            Map json = new HashMap();
            json.put("status", status);
            sendEvent("onServicesDiscovered", json);
            if (status != BluetoothGatt.GATT_SUCCESS) {
                gatt.disconnect();
            }
        }

        @Override
        public void onDescriptorWrite(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status) {
            printDebugLog(String.format(Locale.ENGLISH, "onDescriptorWrite status=%d", status));
            if (descriptor.getUuid().equals(BlufiParameter.UUID_NOTIFICATION_DESCRIPTOR) &&
                    descriptor.getCharacteristic().getUuid().equals(BlufiParameter.UUID_NOTIFICATION_CHARACTERISTIC)) {
                String msg = String.format(Locale.ENGLISH, "Set notification enable %s", (status == BluetoothGatt.GATT_SUCCESS ? " complete" : " failed"));
                printDebugLog(msg);
            }
        }

        @Override
        public void onCharacteristicWrite(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                gatt.disconnect();
                printDebugLog(String.format(Locale.ENGLISH, "WriteChar error status %d", status));
            }
        }
    }

    private class BlufiCallbackMain extends BlufiCallback {
        @Override
        public void onGattPrepared(
                BlufiClient client,
                BluetoothGatt gatt,
                BluetoothGattService service,
                BluetoothGattCharacteristic writeChar,
                BluetoothGattCharacteristic notifyChar
        ) {
            if (service == null) {
                printDebugLog("Discover service failed");
                gatt.disconnect();
                return;
            }
            if (writeChar == null) {
                printDebugLog("Get write characteristic failed");
                gatt.disconnect();
                return;
            }
            if (notifyChar == null) {
                printDebugLog("Get notification characteristic failed");
                gatt.disconnect();
                return;
            }

            printDebugLog("Discover service and characteristics success");

            int mtu = BlufiConstants.DEFAULT_MTU_LENGTH;
            printDebugLog("Request MTU " + mtu);
            boolean requestMtu = gatt.requestMtu(mtu);
            if (!requestMtu) {
                printDebugLog("Request mtu failed");
                printDebugLog(String.format(Locale.ENGLISH, "Request mtu %d failed", mtu));
                onGattServiceCharacteristicDiscovered();
            }
        }

        @Override
        public void onNegotiateSecurityResult(BlufiClient client, int status) {
            Map json = new HashMap();
            json.put("status", status);
            sendEvent("onNegotiateSecurityResult", json);
            if (status == STATUS_SUCCESS) {
                printDebugLog("Negotiate security complete");
            } else {
                printDebugLog("Negotiate security failed， code=" + status);
            }
        }

        @Override
        public void onPostConfigureParams(BlufiClient client, int status) {
            Map json = new HashMap();
            json.put("status", status);
            sendEvent("onPostConfigureParams", json);
            if (status == STATUS_SUCCESS) {
                printDebugLog("Post configure params complete");
            } else {
                printDebugLog("Post configure params failed, code=" + status);
            }

        }

        @Override
        public void onDeviceStatusResponse(BlufiClient client, int status, BlufiStatusResponse response) {
            Map json = new HashMap();
            json.put("status", status);
            sendEvent("onDeviceStatusResponse", json);
            if (status == STATUS_SUCCESS) {
                json.put("response", response.generateValidInfo());
                printDebugLog(String.format("Receive device status response:\n%s", response.generateValidInfo()));
            } else {
                printDebugLog("Device status response error, code=" + status);
            }

        }

        @Override
        public void onDeviceScanResult(BlufiClient client, int status, List<BlufiScanResult> results) {
            Map json = new HashMap();
            json.put("status", status);
            if (status == STATUS_SUCCESS) {
                StringBuilder msg = new StringBuilder();
                msg.append("Receive device scan result:\n");
                List list = new ArrayList();
                for (BlufiScanResult scanResult : results) {
                    msg.append(scanResult.toString()).append("\n");
                    Map item = new HashMap<String, Object>();
                    item.put("ssid", scanResult.getSsid());
                    item.put("type", scanResult.getType());
                    item.put("rssi", scanResult.getRssi());
                    list.add(item);
                }
                json.put("results", list);
                printDebugLog(msg.toString());
            } else {
                printDebugLog("Device scan result error, code=" + status);
            }
            sendEvent("onDeviceScanResult", json);
        }

        @Override
        public void onDeviceVersionResponse(BlufiClient client, int status, BlufiVersionResponse response) {
            Map json = new HashMap();
            json.put("status", status);
            if (status == STATUS_SUCCESS) {
                json.put("response", response.getVersionString());
                printDebugLog(String.format("Receive device version: %s", response.getVersionString()));
            } else {
                printDebugLog("Device version error, code=" + status);
            }
            sendEvent("onDeviceVersionResponse", json);
        }

        @Override
        public void onPostCustomDataResult(BlufiClient client, int status, byte[] data) {
            String dataStr = new String(data);
            String format = "Post data %s %s";
            Map json = new HashMap();
            json.put("status", status);
            json.put("data", data);
            sendEvent("onPostCustomDataResult", json);
            if (status == STATUS_SUCCESS) {
                printDebugLog(String.format(format, dataStr, "complete"));
            } else {
                printDebugLog(String.format(format, dataStr, "failed"));
            }
        }

        @Override
        public void onReceiveCustomData(BlufiClient client, int status, byte[] data) {
            Map json = new HashMap();
            json.put("status", status);
            json.put("data", data);
            sendEvent("onReceiveCustomData", json);
            if (status == STATUS_SUCCESS) {
                String customStr = new String(data);
                printDebugLog(String.format("Receive custom data:\n%s", customStr));
            } else {
                printDebugLog("Receive custom data error, code=" + status);
            }
        }

        @Override
        public void onError(BlufiClient client, int errorCode) {
            printDebugLog(String.format(Locale.ENGLISH, "Receive error code %d", errorCode));
            Map json = new HashMap();
            json.put("errCode", errorCode);
            sendEvent("onError", json);
            if (errorCode == CODE_GATT_WRITE_TIMEOUT) {
                printDebugLog("Gatt write timeout");
                client.close();
                onGattDisconnected();
            } else if (errorCode == 11) {
                printDebugLog("Scan failed, please retry later");
            }
        }
    }
}
