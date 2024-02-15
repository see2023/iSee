import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:see_me_now/data/db.dart';
import 'package:see_me_now/data/log.dart';
import 'package:see_me_now/main.dart';
import 'package:see_me_now/ui/simple_chat_widget.dart';

class HomeController extends GetxController {
  bool inSubWindow = false;
  int changeIndex = 0;
  int topicId = 0;
  //0: new topic; >0 topic detail
  String reminderTxt = '';
  bool isOpacity = true;

  HomeController() {
    Log.log
        .fine('in HomeController, intializing..., self.ptr: ${this.hashCode}');
  }

  @override
  void onInit() async {
    super.onInit();
    Log.log.fine('in HomeController, onInit called');
    topicId = await DB.getLastTopicId();
    Log.log.fine('in HomeController, topicId: $topicId');
    update();
    SimpleChatController chatController = Get.find<SimpleChatController>();
    chatController.updateTopicId(topicId);
  }

  bool isInSubWindowOrSubPage() {
    return MyApp.appPaused ||
        inSubWindow ||
        topicId >= 0 ||
        Get.currentRoute != '/home';
  }

  Future<int> setInSubWindow(bool value, {int index = 0}) async {
    if (index > 0 && index != changeIndex) {
      return -1;
    }
    Log.log.fine(
        'in HomeController, inSubWindow changed to $value, index: $index, $changeIndex');
    changeIndex++;
    if (value == true && isInSubWindowOrSubPage()) {
      // go back to home page
      if (inSubWindow || Get.currentRoute != '/home') {
        inSubWindow = value;
        Get.back();
      } else if (topicId >= 0) {
        inSubWindow = value;
        setTopicId(-1);
      }
    } else {
      inSubWindow = value;
      MyApp.refreshHome();
    }
    return changeIndex;
  }

  void setTopicId(int value) {
    topicId = value;
    if (topicId <= 0) {
      MyApp.changeHomeTitle(DB.getDefaultPromptName());
    }
    // update(); // not work ??
    Log.log.fine('in HomeController, topicId changed to $value');
    SimpleChatController chatController = Get.find<SimpleChatController>();
    chatController.topicId = value;
    MyApp.refreshHome();
  }
  // change topicId to -1 when no input continuously for 120 seconds
  // when topicId is -1, and task is active, show task list for 30 seconds

  void setReminderTxt(String value) {
    Log.log.info('in HomeController, reminderTxt changed to $value');
    reminderTxt = value;
    MyApp.refreshHome();
    // update();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);
  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin<HomePage> {
  @override
  bool get wantKeepAlive => true;
  DateTime _lastPressedAt =
      DateTime.now().subtract(const Duration(seconds: 10));
  final HomeController c = Get.put(HomeController());
  String appBarTitle = DB.getDefaultPromptName();
  float chatOpacity = 0.5;
  void changeOpacity(bool isOpacity, {bool refresh = true}) {
    c.isOpacity = isOpacity;
    chatOpacity = isOpacity ? 0.5 : 0.3;
    if (refresh) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    Log.log.fine('in HomePageState, initState called');
    Get.put(SimpleChatController(topicId: c.topicId));
  }

  @override
  void dispose() {
    Log.log.fine('in HomePageState, dispose called');
    Get.delete<SimpleChatController>();
    super.dispose();
  }

  void changeTitle(String title, {bool refresh = true}) {
    if (title != appBarTitle) {
      if (!refresh) {
        appBarTitle = title;
        return;
      }
      Future.delayed(Duration.zero, () {
        setState(() {
          appBarTitle = title;
          Log.log.fine('in HomePageState, title changed to $title');
        });
      });
    }
  }

  void refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // get global state
    super.build(context);
    Log.log.fine(
        'building home page, topicId: ${c.topicId}, AppName: $appBarTitle');
    // ignore: deprecated_member_use
    return WillPopScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text(appBarTitle),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: GestureDetector(
                onTap: () async {
                  await Get.toNamed('/vehicle');
                },
                child: const Icon(Icons.car_repair),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: GestureDetector(
                onTap: () async {
                  c.setTopicId(0);
                },
                child: const Icon(Icons.chat),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: GestureDetector(
                onTap: () async {
                  await Get.toNamed('/prompts');
                  c.setTopicId(0);
                  setState(() {
                    appBarTitle = DB.getDefaultPromptName();
                    Log.log.fine(
                        'back from prompts page, title changed to $appBarTitle');
                  });
                },
                child: const Icon(Icons.emoji_people),
              ),
            ),
            Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: GestureDetector(
                  onTap: () async {
                    await Get.toNamed('/setting');
                    setState(() {});
                  },
                  child: const Icon(Icons.more_vert),
                )),
          ],
        ),
        body: GetBuilder<HomeController>(builder: (controller) {
          return Container(
            padding: const EdgeInsets.all(0),
            child: Stack(children: [
              MyApp.glbViewer,
              c.inSubWindow
                  ? const SizedBox()
                  : Opacity(
                      opacity: chatOpacity,
                      child: Column(
                        children: [
                          Flexible(flex: 1, child: Container()),
                          Flexible(
                              flex: 1,
                              child:
                                  SimpleChatWidget(chatId: controller.topicId)),
                        ],
                      )),
              // show reminderTxt
            ]),
          );
        }),
      ),
      onWillPop: () async {
        if (c.topicId >= 0) {
          // c.setTopicId(-1);
          return false;
        }
        if (DateTime.now().difference(_lastPressedAt) >
            const Duration(seconds: 2)) {
          _lastPressedAt = DateTime.now();
          // show tips
          Get.snackbar('Press again to exit', '',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.black54,
              colorText: Colors.white,
              margin: const EdgeInsets.all(20),
              borderRadius: 20,
              duration: const Duration(seconds: 2));
          return false;
        }
        return true;
      },
    );
  }
}
