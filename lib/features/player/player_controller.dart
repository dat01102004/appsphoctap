import 'package:flutter/material.dart';

class PlayerController extends ChangeNotifier {
  bool isPlaying = false;    // đang đọc TTS
  bool isListening = false;  // mic đang nghe (STT)
  bool repeat = false;

  String title = "TalkSight";
  String subtitle = "Sẵn sàng";

  void setPlaying(bool v) {
    isPlaying = v;
    notifyListeners();
  }

  void setListening(bool v) {
    isListening = v;
    notifyListeners();
  }

  void toggleRepeat() {
    repeat = !repeat;
    notifyListeners();
  }

  void setNow(String t, String s) {
    title = t;
    subtitle = s;
    notifyListeners();
  }
}