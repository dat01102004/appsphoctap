import 'package:flutter/material.dart';

class PlayerController extends ChangeNotifier {
  bool isPlaying = false;
  bool isListening = false;
  bool repeat = false;

  String title = 'Mắt Nói';
  String subtitle = 'Sẵn sàng';

  /// Nội dung đầy đủ đang đọc / đang nghe
  String details = '';

  bool get hasDetails => details.trim().isNotEmpty;

  String get replayText {
    final full = details.trim();
    if (full.isNotEmpty) return full;

    final preview = subtitle.trim();
    if (preview.isNotEmpty) return preview;

    return title.trim();
  }

  void setPlaying(bool value) {
    if (isPlaying == value) return;
    isPlaying = value;
    notifyListeners();
  }

  void setListening(bool value) {
    if (isListening == value) return;
    isListening = value;
    notifyListeners();
  }

  void toggleRepeat() {
    repeat = !repeat;
    notifyListeners();
  }

  void setRepeat(bool value) {
    if (repeat == value) return;
    repeat = value;
    notifyListeners();
  }

  void setNow(String newTitle, String newSubtitle, {String? newDetails}) {
    title = newTitle;
    subtitle = newSubtitle;

    if (newDetails != null) {
      details = newDetails;
    } else if (details.trim().isEmpty) {
      details = newSubtitle;
    }

    notifyListeners();
  }

  void clear() {
    isPlaying = false;
    isListening = false;
    repeat = false;
    title = 'Mắt Nói';
    subtitle = 'Sẵn sàng';
    details = '';
    notifyListeners();
  }
}
