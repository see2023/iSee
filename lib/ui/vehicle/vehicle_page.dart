// 小车控制和调试页面，包括蓝牙搜索、连接、断开， 小车控制，信息查看等功能

import 'package:flutter/material.dart';
import 'package:see_me_now/ui/vehicle/bluetooth_widget.dart';
import 'package:see_me_now/ui/vehicle/joystick.dart';

class VehiclePage extends StatefulWidget {
  const VehiclePage({Key? key}) : super(key: key);

  @override
  _VehiclePageState createState() => _VehiclePageState();
}

class _VehiclePageState extends State<VehiclePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vehicle Page'),
      ),
      body: Column(
        children: [
          // BlueToothWidget 占据 1/3 的高度
          Expanded(
            flex: 1,
            child: BlueToothWidget(),
          ),
          // JoystickWidget 占据 2/3 的高度
          Expanded(
              flex: 2,
              child: JoystickWidget(
                size: 200,
              )),
        ],
      ),
    );
  }
}
