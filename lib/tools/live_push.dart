import 'dart:convert';
import 'dart:typed_data';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;

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
  String text_id = '';
  double visemes_fps = 60;
  List<List<int>> visemes = [];
  Uint8List audio_data = Uint8List(0);

  LkAudioData.fromMsgPack(Uint8List data) {
    var decoded = msgpack.deserialize(data) as Map;

    text_id = decoded['text_id'];
    visemes_fps = decoded['visemes_fps'];
    visemes =
        List<List<int>>.from(decoded['visemes'].map((x) => List<int>.from(x)));
    audio_data = Uint8List.fromList(List<int>.from(decoded['audio_data']));
  }
}

class LkAudioChunk {
  //  int chunk_count, int chunk_index, data
  int chunk_count = 0;
  int chunk_index = 0;
  Uint8List data = Uint8List(0);
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
  final audioChunkMap = <String, List<LkAudioChunk>>{};
  int lastAudioReceivedTime = 0;

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

  // recieve audio data chunk, assemble it to a complete audio file
  LkAudioData? onAudioData(
      Uint8List data, String id, int chunk_count, int chunk_index) {
    Log.log.fine(
        "livekit debug got audio data, id: $id, chunk_count: $chunk_count, chunk_index: $chunk_index");
    LkAudioChunk audioChunkData = LkAudioChunk()
      ..chunk_count = chunk_count
      ..chunk_index = chunk_index
      ..data = data;
    int now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastAudioReceivedTime > 1000 * 600) {
      // clean up all audio chunk map if no audio data received for 10 minutes
      audioChunkMap.clear();
    }
    lastAudioReceivedTime = now;
    if (audioChunkMap.containsKey(id)) {
      // 按chunk_index顺序合并音频数据, 先找出audioChunkData该插入的位置chunk_index
      int insert_index = audioChunkMap[id]!.length;
      for (int i = insert_index - 1; i >= 0; i--) {
        if (audioChunkMap[id]![i].chunk_index < audioChunkData.chunk_index) {
          insert_index = i + 1;
          break;
        }
      }
      audioChunkMap[id]!.insert(insert_index, audioChunkData);
    } else {
      audioChunkMap[id] = [audioChunkData];
    }
    if (audioChunkMap[id]!.length == chunk_count) {
      try {
        List<int> audioRawData = [];
        for (LkAudioChunk chunk in audioChunkMap[id]!) {
          for (int byte in chunk.data) {
            audioRawData.add(byte);
          }
        }
        audioChunkMap.remove(id);
        LkAudioData audioData =
            LkAudioData.fromMsgPack(Uint8List.fromList(audioRawData));
        Log.log.info(
            'livekit audio, id: $id, text_id: ${audioData.text_id}, audio time: ${audioData.visemes.length / audioData.visemes_fps}');
        return audioData;
      } catch (e) {
        Log.log.warning('livekit audio deserialize error: $e');
      }
    }
    return null;
  }

  Future<void> onData(DataReceivedEvent e) async {
    String? topic = e.topic;
    String? sender = e.participant?.identity;
    SimpleChatController chatController = Get.find<SimpleChatController>();
    BlueToothControl blueToothController = Get.find<BlueToothControl>();
    if (sender == null || topic == null) {
      Log.log.warning('livekit onData, invalid data, no sender or topic');
      return Future.value();
    }
    if ("lk-chat-topic" == topic) {
      String strData = String.fromCharCodes(e.data);
      // convert String to LkChatData
      LkChatData chatData = LkChatData();
      try {
        chatData.fromJson(jsonDecode(strData));
        chatController.addPendingMessage(chatData.message, chatData.id,
            isMe: chatData.srcname == 'app' ? true : false);
        Log.log.info(
            'livekit chat, sender: $sender, message: ${chatData.message}, srcname: ${chatData.srcname}, id: ${chatData.id}');
      } catch (e) {
        Log.log
            .warning('livekit chat, jsonDecode error: $e, strData: $strData');
      }
      return Future.value();
    } else if ("lk-move-topic" == topic) {
      String strData = String.fromCharCodes(e.data);
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
    } else if (topic.startsWith("lk-audio-topic")) {
      //topic format: lk-audio-topic/{id}/{chunk_count}/{chunk_index}(start from 1)}
      // get id, chunk_count, chunk_index from topic
      List<String> topicList = topic.split('/');
      if (topicList.length < 4) {
        Log.log.warning('livekit audio, invalid topic: $topic');
        return Future.value();
      }
      String id = topicList[1];
      int chunk_count = int.parse(topicList[2]);
      int chunk_index = int.parse(topicList[3]);
      if (id.isEmpty ||
          chunk_count == 0 ||
          chunk_index == 0 ||
          chunk_index > chunk_count ||
          e.data.isEmpty) {
        Log.log
            .warning('livekit audio, invalid id or chunk_count or chunk_index');
        return Future.value();
      }
      LkAudioData? audioData =
          onAudioData(Uint8List.fromList(e.data), id, chunk_count, chunk_index);
      if (audioData != null) {
        await chatController.addWavAndVisemes(id, audioData.text_id,
            audioData.audio_data, audioData.visemes, audioData.visemes_fps);
      }

      return Future.value();
    } else {
      Log.log.info('livekit onData, unknown topic:${topic}, sender:{$sender}');
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
