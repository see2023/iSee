import 'package:just_audio/just_audio.dart';
import 'package:see_me_now/data/log.dart';
import 'package:see_me_now/main.dart';

class VoiceAssistant {
  static final player = AudioPlayer();
  static final playlist = ConcatenatingAudioSource(
    useLazyPreparation: true,
    children: [],
  );

  static void setListener() {
    Future.delayed(Duration(milliseconds: 1000), () {
      player.playerStateStream.listen((state) {
        Log.log.fine('player state: $state');
        if (state.processingState == ProcessingState.completed ||
            (state.processingState == ProcessingState.idle)) {
          if (MyApp.homePageStateKey.currentState != null) {
            if (state.processingState == ProcessingState.completed) {
              MyApp.homePageStateKey.currentState!.changeOpacity(true);
            } else {
              MyApp.homePageStateKey.currentState!
                  .changeOpacity(true, refresh: false);
            }
          }
        }
      });
    });
  }

  static Future<void> play(
    String url,
  ) async {
    try {
      if (playlist.children.isEmpty) {
        Log.log.fine('add first source');
        await playlist.add(AudioSource.uri(Uri.parse(url)));
        await player.setLoopMode(LoopMode.off);
        await player.setAudioSource(playlist,
            preload: true,
            initialIndex: 0,
            initialPosition: Duration(seconds: 0));
        player.play();
      } else {
        Log.log.fine('add source');
        await playlist.add(AudioSource.uri(Uri.parse(url)));
      }
    } catch (e) {
      Log.log.warning('play exception: $e');
    }
  }

  static Future<void> stop() async {
    Log.log.fine('stop play');
    await player.stop();
    await playlist.clear();
    MyApp.homePageStateKey.currentState!.changeOpacity(true);
  }
}
