import 'dart:convert';

import 'package:get/get.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:see_me_now/api/see_proxy.dart';
import 'package:see_me_now/data/db.dart';
import 'package:see_me_now/data/log.dart';
import 'package:see_me_now/tools/bluetooth_control.dart';
import 'package:see_me_now/ui/simple_chat_widget.dart';

class LkChatData {
  /* data format: 
         {"id": "CtoVAxPJ8Tyu", "timestamp": 1706932676704, "message": "\u8c22\u8c22\u3002", "srcname": "lk-chat-member-app", 
         "deleted": false, "is_local": true, "duration": 1.1400001049041748, "language": "zh"}
      */
  String id = '';
  int timestamp = 0;
  String message = '';
  String srcname = '';
  bool deleted = false;
  bool isLocal = false;
  double duration = 0;
  String language = '';
  LkChatData fromJson(Map<String, dynamic> json) {
    id = json['id'];
    timestamp = json['timestamp'];
    message = json['message'];
    srcname = json['srcname'];
    deleted = json['deleted'] ?? false;
    isLocal = json['is_local'] ?? false;
    duration = json['duration'] ?? 0;
    language = json['language'] ?? '';
    return this;
  }
}

class LkMoveData {
  /* data format: 
         {"id": "CtoVAxPJ8Tyu", "timestamp": 1706932676704, "srcname": "assistant","cmd": "A"}
      */
  String id = '';
  int timestamp = 0;
  String srcname = '';
  String cmd = 'Z';
  LkMoveData fromJson(Map<String, dynamic> json) {
    id = json['id'];
    timestamp = json['timestamp'];
    srcname = json['srcname'];
    cmd = json['cmd'] ?? 'Z';
    return this;
  }
}

class LkAudioData {
  /* data format: 
         {"id": "CtoVAxPJ8Tyu", "timestamp": 1706932676704, "srcname": "app","text": "", "data": "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8="}
      */
  String id = '';
  int timestamp = 0;
  String srcname = '';
  String text = '';
  String data = '';
  LkAudioData fromJson(Map<String, dynamic> json) {
    id = json['id'];
    timestamp = json['timestamp'];
    srcname = json['srcname'];
    text = json['text'];
    data = json['data'];
    return this;
  }
}

class LivePushControl extends GetxController {
  static const roomOptions = RoomOptions(
    adaptiveStream: false,
    dynacast: false,
  );
  static const connectOptions = ConnectOptions(
      autoSubscribe: true,
      rtcConfiguration: RTCConfiguration(),
      protocolVersion: ProtocolVersion.v9,
      timeouts: Timeouts(
        connection: Duration(seconds: 10),
        debounce: Duration(milliseconds: 100),
        publish: Duration(seconds: 10),
        peerConnection: Duration(seconds: 10),
        iceRestart: Duration(seconds: 10),
      ));
  String roomName = 'my-room';
  final Room room =
      Room(connectOptions: connectOptions, roomOptions: roomOptions);
  String token = '';
  late final _listener = room.createListener();

  final CameraCaptureOptions cameraCaptureOptions = CameraCaptureOptions(
    cameraPosition: CameraPosition.front,
    maxFrameRate: 30,
    params: VideoParametersPresets.h720_43,
  );

  LivePushControl();

  Future<bool> init() async {
    Log.log.info('livekitcontrol init');
    bool rt = true;
    _listener.on<DataReceivedEvent>(onData);
    rt = await connect();
    return rt;
  }

  Future<bool> connect() async {
    try {
      bool rt = await getToken();
      if (!rt) {
        Log.log.warning('livekit getToken error');
        return false;
      }
      await room.connect(DB.setting.liveWsUrl, token);
      Log.log.info('livekit connect finish');
      Future.delayed(Duration(seconds: 1), () async {
        await publish();
      });
    } catch (e) {
      Log.log.warning('livekit connect error: $e');
      Get.snackbar('bluetooth_connect_error'.tr, 'check_blue_tooth'.tr);
      return false;
    }
    return true;
  }

  Future<bool> publish() async {
    try {
      // Turns camera track on
      room.localParticipant!
          .setCameraEnabled(true, cameraCaptureOptions: cameraCaptureOptions);

      // Turns microphone track on
      room.localParticipant!.setMicrophoneEnabled(true);

      Log.log.info('livekit publish ok');
    } catch (e) {
      Log.log.warning('livekit publish error: $e');
      return false;
    }

    return true;
  }

  Future<void> onData(DataReceivedEvent e) async {
    String? topic = e.topic;
    String? sender = e.participant?.identity;
    String strData = String.fromCharCodes(e.data);
    SimpleChatController chatController = Get.find<SimpleChatController>();
    BlueToothControl blueToothController = Get.find<BlueToothControl>();
    if ("lk-chat-topic" == topic) {
      // convert String to LkChatData
      LkChatData chatData = LkChatData();
      try {
        chatData.fromJson(jsonDecode(strData));
        chatController.addPendingMessage(chatData.message,
            isMe: chatData.srcname == 'app' ? true : false);
        Log.log.info(
            'livekit chat, sender: $sender, message: ${chatData.message}, srcname: ${chatData.srcname}');
      } catch (e) {
        Log.log
            .warning('livekit chat, jsonDecode error: $e, strData: $strData');
      }
      return Future.value();
    } else if ("lk-move-topic" == topic) {
      LkMoveData moveData = LkMoveData();
      try {
        moveData.fromJson(jsonDecode(strData));
        Log.log.info(
            'livekit move, sender: $sender, cmd: ${moveData.cmd}, srcname: ${moveData.srcname}');
        if (moveData.srcname == 'assistant' && moveData.cmd.isNotEmpty) {
          await blueToothController.writeDataString(moveData.cmd);
        }
      } catch (e) {
        Log.log
            .warning('livekit move, jsonDecode error: $e, strData: $strData');
      }
      return Future.value();
    } else if ("lk-audio-topic" == topic) {
    } else {
      Log.log.info(
          'livekit onData, unknown topic:${topic}, sender:{$sender}, data: ${strData}');
    }
    return Future.value();
  }

  Future<bool> getToken() async {
    final url = DB.setting.liveApiUrl + '/api/v1/live/getToken';
    ApiRes res = await SeeProxy.commonPost(url, roomName);
    if (res.status && res.text.isNotEmpty) {
      token = res.text;
      return true;
    }
    return false;
  }
}
