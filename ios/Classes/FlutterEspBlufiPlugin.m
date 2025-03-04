#import "FlutterEspBlufiPlugin.h"
#import "BlufiClient.h"
#import "ESPPeripheral.h"
#import "ESPFBYBLEHelper.h"
#import "ESPDataConversion.h"

#import <CoreLocation/CoreLocation.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface FlutterEspBlufiPlugin ()<CBCentralManagerDelegate, CBPeripheralDelegate, BlufiDelegate, FlutterStreamHandler>

@property(nonatomic, strong) ESPFBYBLEHelper *espFBYBleHelper;
@property(nonatomic, copy) NSMutableDictionary *peripheralDictionary;
@property(nonatomic, strong) NSString *filterContent;
@property(strong, nonatomic)ESPPeripheral *device;
@property(strong, nonatomic)BlufiClient *blufiClient;
@property(assign, atomic)BOOL connected;
@property (nonatomic, strong) FlutterEventSink eventSink;
@end


@implementation FlutterEspBlufiPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"flutter_esp_blufi"
                                     binaryMessenger:[registrar messenger]];
    FlutterEspBlufiPlugin* instance = [[FlutterEspBlufiPlugin alloc] init];
    FlutterEventChannel* eventChannel = [FlutterEventChannel eventChannelWithName:@"flutter_esp_blufi.event"
                                                                  binaryMessenger:[registrar messenger]];
    [eventChannel setStreamHandler:instance];
    
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.espFBYBleHelper = [ESPFBYBLEHelper share];
        self.filterContent = [ESPDataConversion loadBlufiScanFilter];
    }
    return self;
}

- (NSMutableDictionary *) dataDictionary {
    if (!_peripheralDictionary) {
        _peripheralDictionary = [[NSMutableDictionary alloc] init];
    }
    return _peripheralDictionary;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    }
    else if([@"scanDevice" isEqualToString:call.method]){
        NSString *filter = call.arguments[@"filter"];
                if (filter != nil) {
                    self.filterContent = filter;
                }
                [self scanDeviceInfo];
    }
    else if([@"stopScan" isEqualToString:call.method]){
        [self stopScan];
    }
    else if([@"connectDevice" isEqualToString:call.method]){
        NSString *deviceAddress = call.arguments[@"deviceAddress"];
        ESPPeripheral *perripheral = [[self dataDictionary] objectForKey:deviceAddress];
        if(perripheral){
            [self connectPeripheral: perripheral];
        }
    }
    else if([@"disconnectDevice" isEqualToString:call.method]){
        [self requestCloseConnection];
    }
    else if([@"negotiateSecurity" isEqualToString:call.method]){
        [self negotiateSecurity];
    }
    else if([@"configure" isEqualToString:call.method]){
        NSString *ssid = call.arguments[@"ssid"];
        NSString *password = call.arguments[@"password"];
        [self configProvisionWithSSID:ssid password:password];
    }
    else if([@"requestDeviceStatus" isEqualToString:call.method]){
        [self requestDeviceStatus];
    }
    else if([@"requestDeviceVersion" isEqualToString:call.method]){
        [self requestDeviceVersion];
    }
    else if([@"requestDeviceWifiScan" isEqualToString:call.method]){
        [self requestDeviceWifiScan];
    }
    else if([@"postCustomData" isEqualToString:call.method]){
        NSData *data = ((FlutterStandardTypedData *)call.arguments[@"data"]).data;
        [self postCustomData:data];
    }
    else {
        result(FlutterMethodNotImplemented);
    }
}

- (FlutterError *)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
    self.eventSink = eventSink;
    //    [self sendEvent:@"来自 iOS 的回调事件"];
    return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments {
    self.eventSink = nil;
    return nil;
}

- (void)sendEvent:(NSString *)event withData:(id)data {
    if (self.eventSink) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.eventSink(@{
                @"event": event,
                @"data": data,
            });
        });
        
    }
}

- (void)scanDeviceInfo {
    [self updateMessage: @"scan deivces"];
    [self.espFBYBleHelper startScan:^(ESPPeripheral * _Nonnull device) {
        if([self shouldAddToSource:device]){
            [[self dataDictionary] setObject:device forKey:device.uuid.UUIDString];
            [self sendEvent:@"onScanResult" withData:@{
                @"address": device.uuid.UUIDString,
                @"rssi": @(device.rssi),
                @"name": device.name
            }];
        }
    }];
}

-(void)stopScan {
    [self.espFBYBleHelper stopScan];
}

- (BOOL)shouldAddToSource:(ESPPeripheral *)device {

    // Check filter
    if (_filterContent && _filterContent.length > 0) {
        if (!device.name || ![device.name hasPrefix:_filterContent]) {
            // The device name has no filter prefix
            return NO;
        }
    }
    
    // Check exist
    NSDictionary *dict = [self dataDictionary];
    if([dict valueForKey:device.uuid.UUIDString]){
        return NO;
    }

    return YES;
}

- (void)connectPeripheral:(ESPPeripheral *)perripheral {
    if (_blufiClient) {
        [_blufiClient close];
        _blufiClient = nil;
    }
    _device = perripheral;
    _blufiClient = [[BlufiClient alloc] init];
    _blufiClient.centralManagerDelete = self;
    _blufiClient.peripheralDelegate = self;
    _blufiClient.blufiDelegate = self;
    [_blufiClient connect:_device.uuid.UUIDString];
}

- (void)requestCloseConnection {
    if (_blufiClient) {
        [_blufiClient requestCloseConnection];
    }
}

- (void)requestDeviceWifiScan {
    if (_blufiClient) {
        [_blufiClient requestDeviceScan];
    }
}

-(void)negotiateSecurity {
    if (_blufiClient) {
        [_blufiClient negotiateSecurity];
    }
}

-(void) requestDeviceVersion {
    if (_blufiClient) {
        [_blufiClient requestDeviceVersion];
    }
}

-(void)configProvisionWithSSID: (NSString *)ssid password:(NSString *)password {
    BlufiConfigureParams *params = [[BlufiConfigureParams alloc] init];
    params.opMode = OpModeSta;
    params.staSsid = ssid;
    params.staPassword = password;

    if (_blufiClient && _connected) {
        [_blufiClient configure:params];
    }
}

-(void)requestDeviceStatus {
    if (_blufiClient) {
        [_blufiClient requestDeviceStatus];
    }
}

- (void)didSetParams:(BlufiConfigureParams *)params {
    if (_blufiClient && _connected) {
        [_blufiClient configure:params];
    }
}

- (void)postCustomData:(NSData *)data{
    [self.blufiClient postCustomData:data];
}

- (void)onDisconnected {
    if (_blufiClient) {
        [_blufiClient close];
    }
    [self sendEvent:@"onConnectionStateChange" withData:@{
        @"newState": @0
    }];
}



- (void)onBlufiPrepared {
   
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    [self updateMessage:@"Connected device"];
    [self sendEvent:@"onConnectionStateChange" withData:@{
        @"newState": @2
    }];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self updateMessage:@"Connet device failed"];
    self.connected = NO;
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self onDisconnected];
    [self updateMessage:@"Disconnected device"];
    self.connected = NO;
}

- (void)blufi:(BlufiClient *)client gattPrepared:(BlufiStatusCode)status service:(CBService *)service writeChar:(CBCharacteristic *)writeChar notifyChar:(CBCharacteristic *)notifyChar {
    [self updateMessage:[NSString stringWithFormat:@"Blufi gattPrepared status:%d", status]];
    if (status == StatusSuccess) {
        self.connected = YES;
        [self updateMessage:@"BluFi connection has prepared"];
        [self onBlufiPrepared];
    } else {
        [self onDisconnected];
        if (!service) {
            [self updateMessage:@"Discover service failed"];
        } else if (!writeChar) {
            [self updateMessage:@"Discover write char failed"];
        } else if (!notifyChar) {
            [self updateMessage:@"Discover notify char failed"];
        }
    }
}

- (void)blufi:(BlufiClient *)client didNegotiateSecurity:(BlufiStatusCode)status {
    if (status == StatusSuccess) {
        [self updateMessage:@"Negotiate security complete"];
    } else {
        [self updateMessage:[NSString stringWithFormat:@"Negotiate security failed: %d", status]];
    }
    [self sendEvent:@"onNegotiateSecurityResult" withData:@{
        @"status": @(status)
    }];
}

- (void)blufi:(BlufiClient *)client didReceiveDeviceVersionResponse:(BlufiVersionResponse *)response status:(BlufiStatusCode)status {
    if (status == StatusSuccess) {
        [self updateMessage:[NSString stringWithFormat:@"Receive device version: %@", response.getVersionString]];
    } else {
        [self updateMessage:[NSString stringWithFormat:@"Receive device version error: %d", status]];
    }
    [self sendEvent:@"onDeviceVersionResponse" withData:@{
        @"status": @(status),
        @"response": response.description
    }];
}

- (void)blufi:(BlufiClient *)client didPostConfigureParams:(BlufiStatusCode)status {
    if (status == StatusSuccess) {
        [self updateMessage:@"Post configure params complete"];
    } else {
        [self updateMessage:[NSString stringWithFormat:@"Post configure params failed: %d", status]];
    }
    [self sendEvent:@"onPostConfigureParams" withData:@{
        @"status": @(status),
    }];
}

- (void)blufi:(BlufiClient *)client didReceiveDeviceStatusResponse:(BlufiStatusResponse *)response status:(BlufiStatusCode)status {
    if (status == StatusSuccess) {
        [self updateMessage:[NSString stringWithFormat:@"Receive device status:\n%@", response.getStatusInfo]];
    } else {
        [self updateMessage:[NSString stringWithFormat:@"Receive device status error: %d", status]];
    }
    [self sendEvent:@"onDeviceStatusResponse" withData:@{
        @"status": @(status),
        @"response": response.description
    }];
}

- (void)blufi:(BlufiClient *)client didReceiveDeviceScanResponse:(NSArray<BlufiScanResponse *> *)scanResults status:(BlufiStatusCode)status {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    NSMutableArray *array = [NSMutableArray array];
    json[@"status"] = @(status);
    if (status == StatusSuccess) {
        NSMutableString *info = [[NSMutableString alloc] init];
        [info appendString:@"Receive device scan results:\n"];
        for (BlufiScanResponse *response in scanResults) {
            [info appendFormat:@"SSID: %@, RSSI: %d\n", response.ssid, response.rssi];
            [array addObject:@{
                @"ssid": response.ssid,
                @"type": @(response.type),
                @"rssi": @(response.rssi)
            }];
        }
        [self updateMessage:info];
        json[@"results"] = array;
    } else {
        [self updateMessage:[NSString stringWithFormat:@"Receive device scan results error: %d", status]];
    }
    [self sendEvent:@"onDeviceScanResult" withData:json];
}

- (void)blufi:(BlufiClient *)client didPostCustomData:(nonnull NSData *)data status:(BlufiStatusCode)status {
    if (status == StatusSuccess) {
        [self updateMessage:@"Post custom data complete"];
    } else {
        [self updateMessage:[NSString stringWithFormat:@"Post custom data failed: %d", status]];
    }
    [self sendEvent:@"onPostCustomDataResult" withData:@{
        @"status": @(status),
        @"data": data
    }];
}

- (void)blufi:(BlufiClient *)client didReceiveCustomData:(NSData *)data status:(BlufiStatusCode)status {
    NSString *customString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [self updateMessage:[NSString stringWithFormat:@"Receive device custom data: %@", customString]];
    [self sendEvent:@"onReceiveCustomData" withData:@{
        @"status": @(status),
        @"data": data
    }];
}

- (void) updateMessage:(NSString *)msg{
    NSLog(@"FlutterEspBlufiPlugin: %@", msg);
}

@end
