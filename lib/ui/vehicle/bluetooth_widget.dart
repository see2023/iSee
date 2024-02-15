// 蓝牙保存列表、上次使用的蓝牙设备， 蓝牙搜索、连接、pincode输入、连接成功、断开连接、蓝牙状态监听
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:see_me_now/data/log.dart';
import 'package:see_me_now/tools/bluetooth_control.dart';

class BlueToothWidget extends StatefulWidget {
  @override
  _BlueToothWidgetState createState() => _BlueToothWidgetState();
}

class _BlueToothWidgetState extends State<BlueToothWidget> {
  final _bluetoothController = Get.find<BlueToothControl>();
  List<BluetoothDevice> _systemDevices = [];
  List<BluetoothDevice> _scannedDevices = [];
  List<BluetoothDevice> _connectedDevices = [];

  void freshDevices() {
    _bluetoothController.getSystemDevices().then((value) => setState(() {
          Log.log.fine('BlueToothWidget getSystemDevices: $value');
          _systemDevices = value;
        }));
    _bluetoothController.getConnectedDevices().then((value) => setState(() {
          Log.log.fine('BlueToothWidget connectedDevices: $value');
          _connectedDevices = value;
        }));
  }

  bool _isConnected(String id) {
    for (BluetoothDevice d in _connectedDevices) {
      if (d.remoteId.toString() == id) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    freshDevices();
  }

  @override
  Widget build(BuildContext context) {
    Log.log.fine('build BlueToothWidget');
    return GetBuilder<BlueToothControl>(builder: (blueToothControl) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'bluetooth'.tr,
            ),
            // 两列，第一列是 系统蓝牙标签 和 列表，第二列 搜索蓝牙 按钮 和 新搜索到的蓝牙列表
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  // 第一列
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        // 系统蓝牙标签
                        ElevatedButton(
                          onPressed: () async {
                            freshDevices();
                          },
                          child: Text('system_bluetooth'.tr),
                        ),
                        // 断开连接 按钮
                        ElevatedButton(
                          onPressed: () async {
                            await blueToothControl.disconnect();
                            freshDevices();
                          },
                          child: Text('disconnect_bluetooth'.tr),
                        ),
                        // 列表
                        Expanded(
                          child: ListView.builder(
                            itemCount: _systemDevices.length,
                            itemBuilder: (BuildContext context, int index) {
                              return ListTile(
                                title: Text(_systemDevices[index].platformName),
                                // if _isConnected, show connected
                                subtitle: _isConnected(_systemDevices[index]
                                        .remoteId
                                        .toString())
                                    ? Text('connected'.tr)
                                    : null,
                                onTap: () async {
                                  bool rt = await blueToothControl.connect(
                                      _systemDevices[index]
                                          .remoteId
                                          .toString());
                                  if (!rt) {
                                    Get.snackbar('bluetooth_connect_error'.tr,
                                        'check_blue_tooth'.tr);
                                  }
                                  freshDevices();
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 第二列
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        // 搜索蓝牙 按钮
                        ElevatedButton(
                          onPressed: () async {
                            _scannedDevices = await blueToothControl.scan();
                            freshDevices();
                          },
                          child: Text('search_bluetooth'.tr),
                        ),
                        // 新搜索到的蓝牙列表
                        Expanded(
                          child: ListView.builder(
                            itemCount: _scannedDevices.length,
                            itemBuilder: (BuildContext context, int index) {
                              return ListTile(
                                  title:
                                      Text(_scannedDevices[index].platformName),
                                  // if _isConnected, show connected
                                  subtitle: _isConnected(_scannedDevices[index]
                                          .remoteId
                                          .toString())
                                      ? Text('connected'.tr)
                                      : null,
                                  onTap: () async {
                                    bool rt = await blueToothControl.connect(
                                        _scannedDevices[index]
                                            .remoteId
                                            .toString());
                                    if (!rt) {
                                      Get.snackbar('bluetooth_connect_error'.tr,
                                          'check_blue_tooth'.tr);
                                    }
                                    freshDevices();
                                  });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
