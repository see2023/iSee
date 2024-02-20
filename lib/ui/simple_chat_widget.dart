import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_parsed_text/flutter_parsed_text.dart';
import 'package:get/get.dart';
import 'package:see_me_now/data/constants.dart';
import 'package:see_me_now/data/models/topic.dart';
import 'package:see_me_now/main.dart';
import 'package:see_me_now/data/db.dart';
import 'package:see_me_now/data/log.dart';
import 'package:see_me_now/tools/voice_assistant.dart';
import 'package:see_me_now/ui/home_page.dart';

class SimpleChatController extends GetxController {
  final messages = <types.Message>[].obs;
  final activeUser = ''.obs;
  final inputtingText = ''.obs;
  int topicId = 0;
  final newTopicName = ''.obs;
  String promtName = '';
  int promptIdUsed = 0;
  final apis = <ApiState>[].obs;
  final users = <String, types.User>{}.obs;
  final me = const types.User(
      id: SettingValueConstants.me, lastName: SettingValueConstants.me);
  List<types.TextMessage> pendingMessages = [];
  final Map<String, int> prefeatchAudioMessages = <String, int>{};

  Future<void> consumePendingMessages() async {
    if (pendingMessages.isEmpty) {
      await Future.delayed(Duration(milliseconds: 1));
      return;
    }
    types.TextMessage msg = pendingMessages.removeAt(0);
    Log.log.fine('start processing pending message: ${msg.text}');
    await pushNewMessage(msg);
  }

  bool pendingMessagesContainsAppMsg() {
    for (var msg in pendingMessages) {
      if (msg.author.id == me.id) {
        skipPendingMessagesPrefetch();

        return true;
      }
    }
    return false;
  }

  void skipPendingMessagesPrefetch() {
    int now = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
    for (var msg in pendingMessages) {
      prefeatchAudioMessages[msg.id] = now;
    }
  }

  void addPendingMessage(String text, {bool isMe = false}) {
    final textMessage = types.TextMessage(
      author: isMe ? me : users[activeUser.value]!,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: DB.uuid.v4(),
      text: text,
    );
    if (isMe) {
      pendingMessages.clear();
      prefeatchAudioMessages.clear();
      stopSpeech();
    }
    pendingMessages.add(textMessage);
  }

  SimpleChatController({required this.topicId}) {
    Log.log.fine('SimpleChatController created, topicId: $topicId');
    activeUser.value = SettingValueConstants.openai;
  }

  void updateTopicId(int id, {bool forceUpdate = false}) {
    if (id == topicId && forceUpdate == false) {
      return;
    }
    topicId = id;
    if (id == 0) {
      // clear chat history
      messages.clear();
      return;
    } else {
      // read chat history from db
      DB.getTopic(topicId).then((Topic topic) {
        promptIdUsed = topic.promptId ?? 0;
        Log.log
            .fine('building chat widget from db, get promptId: $promptIdUsed');
        if (promptIdUsed > 0) {
          promtName = DB.promptsMap[promptIdUsed]?.name ?? '';
          DB.azureProxy
              .setVoiceParams(DB.promptsMap[promptIdUsed]?.voiceName ?? '');
        }
        MyApp.changeHomeTitle(promtName);
        if (topic.apiStates != null && topic.apiStates!.isNotEmpty) {
          apis.clear();
          apis.addAll(topic.apiStates!);
          users.clear();
          for (var i = 0; i < topic.apiStates!.length; i++) {
            String id = topic.apiStates![i].apiId ?? '';
            users[id] = types.User(id: id, lastName: id);
          }
          activeUser.value = topic.apiStates!.first.apiId!;
        }
      });
      DB.getMessages(topicId: topicId, limit: 100).then((msgs) {
        Log.log.fine('building chat widget, get msgs: ${msgs.length}');
        messages.addAll(msgs);
      });
    }

    Log.log.fine('update topicId: $topicId');
    update();
  }

  late Timer consumingTimer;
  bool consumingEventRunning = false;
  late Timer prefetchTimer;
  bool prefetchEventRunning = false;

  Future<void> prefetchAudioMessage(types.TextMessage msg) async {
    if (prefeatchAudioMessages.containsKey(msg.id)) {
      return;
    }
    Log.log.fine('start prefetching audio message: ${msg.text}');
    int now = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
    // 遍历 prefeatchAudioMessages，删除10分钟之前的记录
    prefeatchAudioMessages
        .removeWhere((key, value) => (now - value) > (10 * 60));
    prefeatchAudioMessages[msg.id] = now;
    await DB.azureProxy.textToWavAndVisemes(msg.text, msg.id);
    Log.log.fine('end prefetching audio message: ${msg.text}');
  }

  @override
  void onInit() {
    super.onInit();
    Log.log.fine('SimpleChatController onInit, topicId: $topicId');
    initApis();

    consumingTimer =
        Timer.periodic(const Duration(milliseconds: 10), (timer) async {
      if (pendingMessages.isEmpty || consumingEventRunning) {
        return;
      }
      consumingEventRunning = true;
      await consumePendingMessages();
      consumingEventRunning = false;
    });

    prefetchTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (pendingMessages.length < 2 || prefetchEventRunning) {
        return;
      }
      prefetchEventRunning = true;
      for (int i = 0; i < pendingMessages.length; i++) {
        await prefetchAudioMessage(pendingMessages[i]);
      }
      prefetchEventRunning = false;
    });
  }

  @override
  void onClose() {
    Log.log.fine('SimpleChatController closed');
    consumingTimer.cancel();
    prefetchTimer.cancel();
    super.onClose();
  }

  Future<void> pushNewMessage(types.TextMessage msg) async {
    if (msg.author.id == me.id) {
      // simulating sending message
      // inputtingText.value = text;
      // update();
      // await Future.delayed(Duration(seconds: 3));
      // inputtingText.value = '';
      await addMessageText(msg);
    } else {
      await addMessageText(msg);
    }
  }

  Future<void> addMessageText(types.TextMessage msg) async {
    bool firstMessage = messages.isEmpty;
    if (firstMessage) {
      promptIdUsed = DB.defaultPromptId;
      newTopicName.value =
          '[${DB.promptsMap[promptIdUsed]?.name ?? 'Assistant'}] ${msg.text}';
      DB.azureProxy
          .setVoiceParams(DB.promptsMap[promptIdUsed]?.voiceName ?? '');
      Log.log.fine('first message, got promptId: $promptIdUsed');
    }
    Log.log.fine('add message: ${msg.text}, user: ${msg.author.id}');
    addMessage(msg);
    await processMessage(msg, speech: msg.author.id != me.id);
  }

  void addMessage(types.Message message) {
    messages.insert(0, message);
    update();
  }

  void handleSendPressed(types.PartialText message) async {}

  void initApis() {
    apis.clear();
    var openai = ApiState();
    openai.apiId = SettingValueConstants.openai;
    openai.enabled = true;
    apis.add(openai);
  }

  void next() {
    activeUser.value = SettingValueConstants.openai;
  }

  Future<int> processMessage(types.TextMessage message,
      {String parentMessageId = '', bool speech = false}) async {
    if (parentMessageId.isNotEmpty) {
      apis[0].parentMessageId = parentMessageId;
    }
    int ret = await DB.saveMessage(topicId, message, apis,
        promptId: promptIdUsed, topicName: newTopicName.value);
    if (topicId == 0) {
      topicId = ret;
      await MyApp.latestTopics.refreshFromDB();
      await MyApp.allTopics.refreshFromDB();
      HomeController homeControl = Get.find<HomeController>();
      homeControl.setTopicId(topicId);
    } else {
      await MyApp.latestTopics.refreshFromDB();
      MyApp.allTopics.update(topicId, message.text);
    }
    if (DB.setting.autoPlayVoice && speech) {
      await playSpeech(message);
    }
    return ret;
  }

  Future<void> playSpeech(types.TextMessage message) async {
    if (message.id.isNotEmpty && message.text.isNotEmpty) {
      var rt =
          await DB.azureProxy.textToWavAndVisemes(message.text, message.id);
      if (rt.status) {
        Log.log.fine(
            'start sending visemes to webview, ${rt.visemesText.length} visemes');
        MyApp.glbViewerStateKey.currentState!.appendVisemes(rt.visemesText);
        MyApp.homePageStateKey.currentState!.changeOpacity(false);
        await VoiceAssistant.play(rt.wavFilePath);
        Log.log.fine('end playing speech: ${message.text}');
      }
    }
  }

  Future<void> stopSpeech() async {
    MyApp.glbViewerStateKey.currentState!.clearVisemes();
    await VoiceAssistant.stop();
    MyApp.homePageStateKey.currentState!.changeOpacity(true);
  }
}

class SimpleChatWidget extends StatefulWidget {
  const SimpleChatWidget({super.key, this.chatId = 0});

  final int chatId;

  @override
  State<StatefulWidget> createState() => _SimpleChatWidgetState();
}

class _SimpleChatWidgetState extends State<SimpleChatWidget> {
  bool disposed = false;

  TextEditingController _textEditingController = TextEditingController();

  _SimpleChatWidgetState() {}

  @override
  void initState() {
    super.initState();
    Log.log.fine('creating simple chat widget, id: ${widget.chatId}');
  }

  @override
  void dispose() {
    disposed = true;
    Log.log.fine('chat widget dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SimpleChatController>(builder: (controller) {
      Log.log.info('building chat widget');
      return Chat(
        emptyState: Center(
          child: Text('请说吧'),
        ),
        theme: const DarkChatTheme(
          backgroundColor: Colors.transparent,
          primaryColor: Colors.transparent,
          secondaryColor: Colors.transparent,
          inputBackgroundColor: Colors.transparent,
          inputTextColor: Colors.black,
          // inputBorderRadius: BorderRadius.zero,
          inputPadding: EdgeInsets.zero,
          messageInsetsHorizontal: 5,
          messageInsetsVertical: 5,
        ),
        messages: controller.messages,
        onSendPressed: _handleSendPressed,
        user: controller.me,
        inputOptions: InputOptions(
          inputClearMode: InputClearMode.never,
          enabled: false,
          textEditingController: _textEditingController,
          sendButtonVisibilityMode: SendButtonVisibilityMode.hidden,
        ),
        showUserNames: true,
        showUserAvatars: false,
        onMessageDoubleTap: onMessageTap,
        onMessageTap: onMessageTap,
        textMessageOptions: TextMessageOptions(matchers: [
          MatchText(
            pattern: '```[^`]+```',
            style: PatternStyle.code.textStyle,
            renderText: ({required String str, required String pattern}) => {
              'display': str.replaceAll(
                '```',
                '',
              ),
            },
          ),
        ]),
      );
    });
  }

  void _handleSendPressed(types.PartialText message) async {}

  void onMessageTap(context, types.Message message) async {
    Log.log.fine('onMessageTap / DoubleTap: ${message.id}');
    if (DB.setting.tapPlayVoice && message is types.TextMessage) {
      SimpleChatController controller = Get.find<SimpleChatController>();
      controller.playSpeech(message);
    }
  }
}
