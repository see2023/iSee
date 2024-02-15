import 'package:get/get.dart';
import 'package:see_me_now/data/log.dart';
import 'package:see_me_now/tools/bluetooth_control.dart';
import 'package:see_me_now/tools/live_push.dart';

class Devices {
  final BlueToothControl blueToothControl = Get.put(BlueToothControl());
  final LivePushControl livePushControl = Get.put(LivePushControl());

  Future<bool> init() async {
    Log.log.info('in Devices, init');
    Future.delayed(Duration(seconds: 5), () async {
      await blueToothControl.init();
      await Future.delayed(Duration(milliseconds: 2000));
      await livePushControl.init();
    });
    return true;
  }
}
