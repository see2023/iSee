import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:see_me_now/data/db.dart';
import 'package:see_me_now/data/log.dart';
import 'package:see_me_now/data/setting.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> checkAndRequestPermission() async {
  final permission = Permission.bluetoothScan;
  final status = await permission.status;
  if (status == PermissionStatus.denied) {
    await permission.request();
  } else if (status == PermissionStatus.permanentlyDenied) {
    await openAppSettings();
  }
}

// 蓝牙控制器，使用 flutter_blue_plus 完成蓝牙搜索、连接、断开连接、蓝牙状态监听等功能
class BlueToothControl extends GetxController {
  var subscription = null;
  int writeCount = 0;
  List<BluetoothDevice> scannedDevices = [];
  List<BluetoothDevice> systemDevices = [];
  List<BluetoothDevice> connectedDevices = [];
  String lastDeviceId = '';
  BluetoothDevice? deviceUsing;
  BluetoothCharacteristic? readCharacteristic;
  BluetoothCharacteristic? writeCharacteristic;
  int timeout = 5;
  String SERVICE_UUID = "0000ffe0-0000-1000-8000-00805f9b34fb";
  String READ_CHARACTERISTIC_UUID = "0000ffe1-0000-1000-8000-00805f9b34fb";
  String WRITE_CHARACTERISTIC_UUID = "0000ffe2-0000-1000-8000-00805f9b34fb";
  late Timer timer;

  Future<bool> init() async {
    if (await FlutterBluePlus.isSupported == false) {
      Get.snackbar('bluetooth_connect_error'.tr, 'check_blue_tooth'.tr);
      return false;
    }
    subscription =
        FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      if (state == BluetoothAdapterState.off) {
        Log.log.info('bluetooth is off');
        Get.snackbar('bluetooth_connect_error'.tr, 'check_blue_tooth'.tr);
      } else {
        Log.log.info('bluetooth is on');
      }
    });
    lastDeviceId = DB.setting.lastBluetoothDeviceId;
    await checkAndRequestPermission();
    if (lastDeviceId.isNotEmpty) {
      try {
        await getSystemDevices();
        bool rt = await connect(lastDeviceId);
        if (rt == false) {
          Get.snackbar('bluetooth_connect_error'.tr, 'check_blue_tooth'.tr);
        } else {
          Get.snackbar('bluetooth_connect_ok'.tr, 'bluetooth_connect_ok'.tr);
        }
      } catch (e) {
        Log.log.warning('connect last bluetooth failed: $e');
      }
    }
    bool timerChecking = false;
    timer = Timer.periodic(Duration(milliseconds: 100), (timer) async {
      if (timerChecking) {
        return;
      }
      timerChecking = true;
      if (deviceUsing != null) {
        await stopCar();
      }
      timerChecking = false;
    });
    return true;
  }

  Future<bool> destroy() async {
    if (subscription != null) {
      await subscription.cancel();
    }
    return true;
  }

  void addToDeviceList(BluetoothDevice device, List<BluetoothDevice> list) {
    // check dumplicate
    for (BluetoothDevice d in list) {
      if (d.remoteId.toString() == device.remoteId.toString()) {
        return;
      }
    }
    list.add(device);
  }

  // scan for devices
  Future<List<BluetoothDevice>> scan() async {
    await FlutterBluePlus.startScan(timeout: Duration(seconds: timeout));
    scannedDevices.clear();
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.platformName.isNotEmpty) {
          addToDeviceList(r.device, scannedDevices);
        }
      }
    });
    await FlutterBluePlus.isScanning.where((val) => val == false).first;
    return scannedDevices;
  }

  // get system devices, ios: system connected devices, android: bonded devices
  Future<List<BluetoothDevice>> getSystemDevices() async {
    systemDevices.clear();
    // if is android
    List<BluetoothDevice> devices = [];
    try {
      /*
      I/flutter (14863): ⚠️ WARNING 2024-02-05 00:22:11.844169 [package:see_me_now/tools/bluetooth_control.dart 103:15 in BlueToothControl.getSystemDevices] getSystemDevices failed: PlatformException(androidException, java.lang.SecurityException: 
      Need android.permission.BLUETOOTH_CONNECT permission
       for android.content.AttributionSource@4d4b2358: AdapterService getBondedDevices, java.lang.SecurityException: Need android.permission.BLUETOOTH_CONNECT permission for android.content.AttributionSource@4d4b2358: AdapterService getBondedDevices


      */
      // always request permission

      if (GetPlatform.isAndroid) {
        devices = await FlutterBluePlus.bondedDevices;
      } else {
        devices = await FlutterBluePlus.systemDevices;
      }
      for (BluetoothDevice device in devices) {
        if (device.platformName.isNotEmpty) {
          systemDevices.add(device);
        }
      }
    } catch (e) {
      Log.log.warning('getSystemDevices failed: $e');
    }
    return systemDevices;
  }

  // connectedDevices
  Future<List<BluetoothDevice>> getConnectedDevices() async {
    connectedDevices = await FlutterBluePlus.connectedDevices;
    return connectedDevices;
  }

  Future<bool> connect(String deviceId) async {
    if (deviceId.isEmpty) {
      return false;
    }
    if (deviceUsing != null) {
      await deviceUsing!.disconnect();
      deviceUsing = null;
    }
    // check in system devices, if found, connect
    for (BluetoothDevice device in systemDevices) {
      if (device.remoteId.toString() == deviceId) {
        try {
          Log.log.info('connecting to system bluetooth: $deviceId');
          await device.connect(timeout: Duration(seconds: timeout));
          deviceUsing = device;
          Log.log.info('connect system bluetooth success: $deviceId');
          discoverService();
          lastDeviceId = deviceId;
          DB.setting.changeSetting(
              SettingKeyConstants.lastBluetoothDeviceId, lastDeviceId);
          return true;
        } catch (e) {
          Log.log.warning('connect system bluetooth failed: $deviceId, $e');
        }
        break;
      }
    }

    bool foundInScannedDevices = false;
    // check in scanned devices, if found, createbond and connect
    for (BluetoothDevice device in scannedDevices) {
      if (device.remoteId.toString() == deviceId) {
        foundInScannedDevices = true;
        try {
          Log.log.info('connecting to new bluetooth: $deviceId');
          await device.connect(timeout: Duration(seconds: timeout));
          // await device.createBond();
          deviceUsing = device;
          Log.log.info('connect new bluetooth success: $deviceId');
          discoverService();
          return true;
        } catch (e) {
          Log.log.warning('connect new bluetooth failed: $deviceId, $e');
        }
      }
    }

    if (foundInScannedDevices == false) {
      Log.log.info(deviceId + ' not found in scanned devices');
      return false;
    }

    return true;
  }

  Future<bool> disconnect() async {
    // disconnect
    if (deviceUsing != null) {
      // send Z to reset
      await writeData([0x43]);
      await Future.delayed(Duration(milliseconds: 100));
      await writeData([0x5a]);
      await Future.delayed(Duration(milliseconds: 100));
      await deviceUsing!.disconnect();
      deviceUsing = null;
    }
    return true;
  } // disconnect

  Future<bool> discoverService() async {
    if (deviceUsing == null) {
      return false;
    }
    List<BluetoothService> services =
        await deviceUsing!.discoverServices(); // 获取服务列表
    for (BluetoothService service in services) {
      // 遍历服务列表
      var service_uuid = service.uuid.str128.toLowerCase();
      Log.log.info("Service uuid: ${service_uuid}");
      if (service_uuid == SERVICE_UUID) {
        // 如果找到目标服务
        var characteristics = service.characteristics; // 获取特征列表
        for (BluetoothCharacteristic c in characteristics) {
          var characteristic_uuid = c.uuid.str128.toLowerCase();
          // 遍历特征列表
          Log.log.info("Characteristic uuid: ${characteristic_uuid}");
          if (characteristic_uuid == READ_CHARACTERISTIC_UUID) {
            // 如果找到目标特征
            readCharacteristic = c; // 保存特征
            subscribeData();
          } else if (characteristic_uuid == WRITE_CHARACTERISTIC_UUID) {
            // 如果找到目标特征
            writeCharacteristic = c; // 保存特征
          }
        }
      }
    }
    return true;
  } // discoverService

  void subscribeData() async {
    await readCharacteristic!.setNotifyValue(true); // 订阅特征的通知
    readCharacteristic!.onValueReceived.listen((value) {
      Log.log.fine('characteristic onValueReceived: $value');
    });
  }

  void readData() async {
    List<int> value = await readCharacteristic!.read();
    // print hex list
    Log.log.fine('characteristic readData: $value');
  }

  void writeDataTest() async {
    // List<int> value = ['A', 'A', 'Z'];
    writeCount++;
    List<int> values = [0x41, 0x41, 0x5a];
    // AAZ
    if (writeCount % 2 == 0) {
      //EEZ
      values = [0x45, 0x45, 0x5a];
    }
    // send each value
    for (int value in values) {
      await writeCharacteristic!.write([value]);
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  int lastSendCmdTime = 0;
  Future<bool> writeData(List<int> values) async {
    // send each value
    lastSendCmdTime = DateTime.now().millisecondsSinceEpoch;
    if (writeCharacteristic == null || values.isEmpty || deviceUsing == null) {
      Log.log.fine('writeCharacteristic is null or values is empty');
      return false;
    }
    try {
      await writeCharacteristic!.write(values);
      return true;
    } catch (e) {
      Log.log.warning('writeCharacteristic failed: $e');
      return false;
    }
  }

  Future<bool> writeDataString(String data) async {
    // 检测字符串都是大写字母
    Log.log.fine('writeDataString: $data');
    if (lastSendCmdTime == 0) {
      Log.log.fine('send reduce speed first');
      data = "Y";
    }
    if (data.toUpperCase() == data) {
      List<int> values = [];
      for (int i = 0; i < data.length; i++) {
        values.add(data.codeUnitAt(i));
      }
      return await writeData(values);
    } else {
      Log.log.fine('writeDataString failed, data is not all uppercase');
      return false;
    }
  }

  double sum_dx = 0;
  double sum_dy = 0;
  // 发送阈值
  double threshold = 0.5;
  void onDirectionChanged(double dx, double dy, bool isReset) async {
    // dx dy 取3位小数, 取值范围 -1.0 ~ 1.0
    // limit to -1 ~ 1
    dx = dx.clamp(-1.0, 1.0);
    dx = double.parse(dx.toStringAsFixed(3));
    dy = dy.clamp(-1.0, 1.0);
    dy = double.parse(dy.toStringAsFixed(3));
    // Log.log.fine('now offset------------> dx: $dx, dy: $dy, isReset: $isReset');

    // 每100ms接受一次数据, 累积到sum_dx, sum_dy.  如果超过阈值, 发送数据
    // 如果isReset, 则发送 'Z'
    // 加速 'X',  减速 'Y'
    // dy > threshold &&  |dx| < threshold, 向前 'A'
    // dy > threshold &&  dx  > threshold, 向右前 'B'
    // |dy| < threshold &&  dx  > threshold, 向右 'C'
    // dy < -threshold &&  dx  > threshold, 向右后 'D'
    // dy < -threshold &&  |dx| < threshold, 向后 'E'
    // dy < -threshold &&  dx  < -threshold, 向左后 'F'
    // |dy| < threshold &&  dx  < -threshold, 向左 'G'
    // dy > threshold &&  dx  < -threshold, 向左前 'H'
    int value = 0x5a;
    if (isReset) {
      value = 0x5a;
    } else {
      sum_dx += dx;
      sum_dy += dy;
      if (sum_dx.abs() < threshold && sum_dy.abs() < threshold) {
        return;
      }
      if (sum_dy > threshold && sum_dx.abs() < threshold) {
        value = 0x41;
      } else if (sum_dy > threshold && sum_dx > threshold) {
        value = 0x42;
      } else if (sum_dy.abs() < threshold && sum_dx > threshold) {
        value = 0x43;
      } else if (sum_dy < -threshold && sum_dx > threshold) {
        value = 0x44;
      } else if (sum_dy < -threshold && sum_dx.abs() < threshold) {
        value = 0x45;
      } else if (sum_dy < -threshold && sum_dx < -threshold) {
        value = 0x46;
      } else if (sum_dy.abs() < threshold && sum_dx < -threshold) {
        value = 0x47;
      } else if (sum_dy > threshold && sum_dx < -threshold) {
        value = 0x48;
      }
    }
    sum_dx = 0;
    sum_dy = 0;
    String data = String.fromCharCode(value);
    Log.log.info('write value: $value, data: $data');
    writeData([value]);
  }

  Future<bool> stopCar() async {
    int now = DateTime.now().millisecondsSinceEpoch;
    bool rt = false;
    if (lastSendCmdTime + 500 < now) {
      lastSendCmdTime = now;
      // send Z
      rt = await writeData([0x5a]);
      await Future.delayed(Duration(milliseconds: 100));
      // send Y
      await writeData([0x59]);
      Log.log.info('stopCar =====');
    }
    return rt;
  }
}
