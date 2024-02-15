import 'package:get/get.dart';

class Messages extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': {
          'askUserForTasks': 'What do you need to do today about @name ?',
          'MathHomework': 'Math homework',
          'EnglishHomework': 'English homework',
          'ChineseHomework': 'Chinese homework',
          'SportAndRelax': 'Sports and relaxation',
          'ReplyLanguage': 'Please reply in English.',
          'ShowAnswer': 'Show answer',
          'MyAnswer': 'My answer',
          'UserProfile': 'Profile',
          'UserNickname': 'nickname',
          'UserDescription': 'description',
          'SitStraight': 'Sit up straight',
          'CameraObserver': 'Camera Observer',
          'Camera': 'Camera',
          'PoseReminder': 'Pose Reminder',
          'PoseAIReply': 'Pose AI Reply',
          'VoiceReply': 'Voice Reply',
          'AutoPlay': 'Auto Play',
          'TaptoPlay': 'Tap to Play',
          'GoalName': 'Goal',
          'GoalDescription': 'Description',
          'GoalPriority': 'priority',
          'GoalExperience': 'Experience',
          'ReservedPrompt': 'Used by auto-reminder',
          'Language': 'Language',
          'Animation': 'Animation',
          'AIReplyWithMotion': 'AI Motion',
          'Evaluation': 'Evaluation',
          'QuizResult':
              'Question: @question\n\nAnswer: @answer\n\nYour answer: @userAnswer\n\nScore: @score\n\nEvaluate: @evaluate\n\nNext review: @nextReview days later',
          'Discard': 'Discard',
          'bluetooth': 'Bluetooth',
          'system_bluetooth': 'System Bluetooth',
          'search_bluetooth': 'Search Bluetooth',
          'disconnect_bluetooth': 'Disconnect Bluetooth',
          'bluetooth_connect_error': 'Bluetooth connect error',
          'bluetooth_connect_ok': 'Bluetooth connect ok',
          'check_blue_tooth': 'Please check your bluetooth',
          'live_push_error': 'Live push error',
        },
        'zh_CN': {
          'askUserForTasks': '你今天有什么@name的计划吗?',
          'MathHomework': '数学作业',
          'EnglishHomework': '英语作业',
          'ChineseHomework': '语文作业',
          'SportAndRelax': '运动与放松',
          'ReplyLanguage': 'Please reply in Chinese.',
          'ShowAnswer': '显示答案',
          'MyAnswer': '我的答案',
          'UserProfile': '个人资料',
          'UserNickname': '昵称',
          'UserDescription': '描述',
          'SitStraight': '坐直了!',
          'CameraObserver': '摄像头提醒',
          'Camera': '摄像头',
          'PoseReminder': '姿势提醒',
          'PoseAIReply': 'AI回复',
          'VoiceReply': '语音回复',
          'AutoPlay': '自动播放',
          'TaptoPlay': '点击播放',
          'GoalName': '目标',
          'GoalDescription': '描述',
          'GoalPriority': '优先级',
          'GoalExperience': '经验',
          'ReservedPrompt': '自动提醒回复使用',
          'Language': '语言',
          'Animation': '动画',
          'AIReplyWithMotion': 'AI动作',
          'Evaluation': '评价',
          'QuizResult':
              '问题: @question\n\n答案: @answer\n\n你的答案: @userAnswer\n\n分数: @score\n\n评价: @evaluate\n\n下次复习: @nextReview 天后',
          'Discard': '废弃',
          'bluetooth': '蓝牙',
          'system_bluetooth': '系统蓝牙',
          'search_bluetooth': '搜索蓝牙',
          'disconnect_bluetooth': '断开蓝牙',
          'bluetooth_connect_error': '蓝牙连接错误',
          'bluetooth_connect_ok': '蓝牙连接成功',
          'check_blue_tooth': '请检查设备蓝牙是否打开',
          'live_push_error': '推流错误',
        },
      };
}

class LangInfo {
  String langCode = 'zh';
  String countryCode = 'CN';
  String langName = '中文';
}

class LangMap {
  static Map<String, LangInfo> langMap = {
    'zh_CN': LangInfo(),
    'en_US': LangInfo()
      ..langCode = 'en'
      ..countryCode = 'US'
      ..langName = 'English',
  };
}
