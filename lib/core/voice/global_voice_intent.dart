enum GlobalVoiceIntent {
  home,
  back,
  stopReading,
  repeatReading,
  speedUp,
  speedDown,
  speedDefault,
  settings,
  history,
  caption,
  ocr,
  news,
  camera,
  none,
}

class GlobalVoiceIntentParser {
  const GlobalVoiceIntentParser._();

  static GlobalVoiceIntent parse(String raw) {
    final text = normalize(raw);

    if (text.isEmpty) return GlobalVoiceIntent.none;

    if (_isStopReading(text)) return GlobalVoiceIntent.stopReading;
    if (_isRepeatReading(text)) return GlobalVoiceIntent.repeatReading;
    if (_isSpeedDefault(text)) return GlobalVoiceIntent.speedDefault;
    if (_isSpeedUp(text)) return GlobalVoiceIntent.speedUp;
    if (_isSpeedDown(text)) return GlobalVoiceIntent.speedDown;
    if (_isHome(text)) return GlobalVoiceIntent.home;
    if (_isBack(text)) return GlobalVoiceIntent.back;
    if (_isSettings(text)) return GlobalVoiceIntent.settings;
    if (_isHistory(text)) return GlobalVoiceIntent.history;
    if (_isCamera(text)) return GlobalVoiceIntent.camera;
    if (_isCaption(text)) return GlobalVoiceIntent.caption;
    if (_isOcr(text)) return GlobalVoiceIntent.ocr;
    if (_isNews(text)) return GlobalVoiceIntent.news;

    return GlobalVoiceIntent.none;
  }

  static bool isGlobalCommand(String raw) {
    return parse(raw) != GlobalVoiceIntent.none;
  }

  static String normalize(String input) {
    var s = input.toLowerCase().trim();

    const withDia =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩ'
        'òóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
        'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨ'
        'ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';

    const without =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiii'
        'ooooooooooooooooouuuuuuuuuuuyyyyyd'
        'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIII'
        'OOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';

    for (int i = 0; i < withDia.length; i++) {
      s = s.replaceAll(withDia[i], without[i]);
    }

    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    return s;
  }

  static bool _hasPhrase(String text, String phrase) {
    return ' $text '.contains(' $phrase ');
  }

  static bool _isHome(String text) {
    return _hasPhrase(text, 'trang chu') ||
        _hasPhrase(text, 've trang chu') ||
        _hasPhrase(text, 'mo trang chu') ||
        _hasPhrase(text, 'quay ve trang chu') ||
        _hasPhrase(text, 'home') ||
        _hasPhrase(text, 've home');
  }

  static bool _isBack(String text) {
    return _hasPhrase(text, 'quay lai') ||
        _hasPhrase(text, 'tro lai') ||
        _hasPhrase(text, 'tro ve') ||
        _hasPhrase(text, 'thoat') ||
        _hasPhrase(text, 'dong lai') ||
        _hasPhrase(text, 'back');
  }

  static bool _isStopReading(String text) {
    return _hasPhrase(text, 'dung doc') ||
        _hasPhrase(text, 'ngung doc') ||
        _hasPhrase(text, 'tat doc') ||
        _hasPhrase(text, 'dung lai') ||
        _hasPhrase(text, 'im lang') ||
        _hasPhrase(text, 'stop') ||
        _hasPhrase(text, 'tam dung');
  }

  static bool _isRepeatReading(String text) {
    return _hasPhrase(text, 'doc lai') ||
        _hasPhrase(text, 'nghe lai') ||
        _hasPhrase(text, 'lap lai') ||
        _hasPhrase(text, 'noi lai') ||
        _hasPhrase(text, 'repeat');
  }

  static bool _isSpeedUp(String text) {
    return _hasPhrase(text, 'tang toc do doc len') ||
        _hasPhrase(text, 'tang toc do doc') ||
        _hasPhrase(text, 'tang toc doc len') ||
        _hasPhrase(text, 'tang toc doc') ||
        _hasPhrase(text, 'tang len mot xiu') ||
        _hasPhrase(text, 'tang len 1 xiu') ||
        _hasPhrase(text, 'nhanh hon mot xiu') ||
        _hasPhrase(text, 'nhanh hon 1 xiu') ||
        _hasPhrase(text, 'doc nhanh hon') ||
        _hasPhrase(text, 'doc nhanh len') ||
        _hasPhrase(text, 'noi nhanh hon') ||
        _hasPhrase(text, 'toc do nhanh hon') ||
        _hasPhrase(text, 'toc do nhanh');
  }

  static bool _isSpeedDown(String text) {
    return _hasPhrase(text, 'giam toc do doc xuong') ||
        _hasPhrase(text, 'giam toc do doc') ||
        _hasPhrase(text, 'giam toc doc xuong') ||
        _hasPhrase(text, 'giam toc doc') ||
        _hasPhrase(text, 'giam xuong mot xiu') ||
        _hasPhrase(text, 'giam xuong 1 xiu') ||
        _hasPhrase(text, 'cham lai mot xiu') ||
        _hasPhrase(text, 'cham lai 1 xiu') ||
        _hasPhrase(text, 'doc cham lai') ||
        _hasPhrase(text, 'doc cham hon') ||
        _hasPhrase(text, 'noi cham lai') ||
        _hasPhrase(text, 'toc do cham lai') ||
        _hasPhrase(text, 'toc do cham');
  }

  static bool _isSpeedDefault(String text) {
    return _hasPhrase(text, 'toc do doc mac dinh') ||
        _hasPhrase(text, 'toc doc mac dinh') ||
        _hasPhrase(text, 'dua toc do doc ve mac dinh') ||
        _hasPhrase(text, 'dua toc doc ve mac dinh') ||
        _hasPhrase(text, 'doc nhu binh thuong') ||
        _hasPhrase(text, 'noi nhu binh thuong') ||
        _hasPhrase(text, 'toc do binh thuong') ||
        _hasPhrase(text, 'doc binh thuong') ||
        _hasPhrase(text, 'binh thuong lai');
  }

  static bool _isSettings(String text) {
    return _hasPhrase(text, 'mo cai dat') ||
        _hasPhrase(text, 'cai dat') ||
        _hasPhrase(text, 'vao cai dat') ||
        _hasPhrase(text, 'setting') ||
        _hasPhrase(text, 'settings');
  }

  static bool _isHistory(String text) {
    return _hasPhrase(text, 'mo lich su') ||
        _hasPhrase(text, 'xem lich su') ||
        _hasPhrase(text, 'vao lich su') ||
        _hasPhrase(text, 'lich su') ||
        _hasPhrase(text, 'history');
  }

  static bool _isCaption(String text) {
    return _hasPhrase(text, 'mo ta anh') ||
        _hasPhrase(text, 'mo ta hinh anh') ||
        _hasPhrase(text, 'mo ta canh vat') ||
        _hasPhrase(text, 'mo ta') ||
        _hasPhrase(text, 'nhin giup') ||
        _hasPhrase(text, 'xem giup') ||
        _hasPhrase(text, 'caption');
  }

  static bool _isCamera(String text) {
    return _hasPhrase(text, 'mo ta truc tiep') ||
        _hasPhrase(text, 'mo ta xung quanh') ||
        _hasPhrase(text, 'xung quanh') ||
        _hasPhrase(text, 'chup nhanh') ||
        _hasPhrase(text, 'live vision');
  }

  static bool _isOcr(String text) {
    return _hasPhrase(text, 'doc chu') ||
        _hasPhrase(text, 'quet chu') ||
        _hasPhrase(text, 'doc van ban') ||
        _hasPhrase(text, 'quet van ban') ||
        _hasPhrase(text, 'ocr') ||
        _hasPhrase(text, 'o c r');
  }

  static bool _isNews(String text) {
    return _hasPhrase(text, 'doc bao') ||
        _hasPhrase(text, 'mo doc bao') ||
        _hasPhrase(text, 'tin tuc') ||
        _hasPhrase(text, 'tin moi') ||
        _hasPhrase(text, 'bao moi') ||
        _hasPhrase(text, 'doc tin') ||
        _hasPhrase(text, 'news');
  }
}
