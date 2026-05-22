import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'dart:convert';
import 'dart:io';

import '../../data/models/settings_model.dart';

class TtsProgress {
  final String text;
  final int start;
  final int end;
  final String word;

  const TtsProgress({
    required this.text,
    required this.start,
    required this.end,
    required this.word,
  });
}

class TtsService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 90),
    ),
  );

  bool _inited = false;
  int _apiAudioCounter = 0;

  double rate = 0.5;
  double pitch = 1.0;
  double volume = 1.0;
  String language = "vi-VN";
  String? voiceName;
  String? lastErrorMessage;
  TtsVoiceSource _voiceSource = TtsVoiceSource.system;

  final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);
  final ValueNotifier<TtsProgress?> progress = ValueNotifier<TtsProgress?>(
    null,
  );

  String _lastText = "";
  String get lastText => _lastText;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed ||
          state.processingState == ProcessingState.idle) {
        isSpeaking.value = false;
        progress.value = null;
      }
    });

    await _tts.setLanguage(language);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.setVolume(volume);
    await _tts.awaitSpeakCompletion(true);

    _tts.setStartHandler(() {
      isSpeaking.value = true;
      progress.value = null;
    });

    _tts.setCompletionHandler(() {
      isSpeaking.value = false;
      progress.value = null;
    });

    _tts.setCancelHandler(() {
      isSpeaking.value = false;
      progress.value = null;
    });

    _tts.setErrorHandler((_) {
      isSpeaking.value = false;
      progress.value = null;
    });

    _tts.setProgressHandler((text, start, end, word) {
      progress.value = TtsProgress(
        text: text,
        start: start,
        end: end,
        word: word,
      );
    });
  }

  Future<List<Map<String, dynamic>>> getVoices() async {
    await init();

    final v = await _tts.getVoices;
    final systemVoices = ((v as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return [
      ...systemVoices,
      ...ExternalTtsVoice.catalog.map((voice) => voice.toMap()),
    ];
  }

  Future<void> setRate(double v) async {
    await init();
    rate = v.clamp(SettingsModel.minRate, SettingsModel.maxRate).toDouble();
    await _tts.setSpeechRate(rate);
  }

  Future<void> setPitch(double v) async {
    await init();
    pitch = v.clamp(SettingsModel.minPitch, SettingsModel.maxPitch).toDouble();
    await _tts.setPitch(pitch);
  }

  Future<void> setVolume(double v) async {
    await init();
    volume = v.clamp(0.0, 1.0).toDouble();
    await _tts.setVolume(volume);
    await _audioPlayer.setVolume(volume);
  }

  Future<void> setLanguage(String v) async {
    await init();
    final next = v.trim().isEmpty ? 'vi-VN' : v.trim();
    language = next;
    await _tts.setLanguage(language);
  }

  Future<void> setVoice(Map<dynamic, dynamic> voice) async {
    await init();

    final mappedVoice = <String, String>{
      'name': (voice['name'] ?? '').toString(),
      'locale': (voice['locale'] ?? language).toString(),
    };

    voiceName = mappedVoice['name'];
    _voiceSource = TtsVoiceSource.system;

    await _tts.setVoice(mappedVoice);
  }

  Future<void> setVoiceName(String? name) async {
    await init();

    final value = name?.trim();
    if (value == null || value.isEmpty) {
      voiceName = null;
      _voiceSource = TtsVoiceSource.system;
      await _tts.setLanguage(language);
      return;
    }

    final external = ExternalTtsVoice.tryParse(value);
    if (external != null) {
      voiceName = external.id;
      _voiceSource = TtsVoiceSource.api;
      language = external.locale;
      return;
    }

    final voices = await getVoices();
    final matched = voices.cast<Map<dynamic, dynamic>>().firstWhere(
      (voice) => (voice['name'] ?? '').toString() == value,
      orElse: () => {'name': value, 'locale': language},
    );

    await setVoice(matched);
  }

  Future<void> configure({
    String? voice,
    required double rate,
    required double pitch,
    required double volume,
    required String language,
  }) async {
    await setLanguage(language);
    await setRate(rate);
    await setPitch(pitch);
    await setVolume(volume);
    await setVoiceName(voice);
  }

  Future<void> speak(String text) async {
    await init();

    final t = text.trim();
    if (t.isEmpty) return;

    _lastText = t;
    lastErrorMessage = null;
    progress.value = null;

    if (_voiceSource == TtsVoiceSource.api) {
      await _speakWithExternalVoice(t);
      return;
    }

    await _audioPlayer.stop();
    await _tts.stop();
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.setVolume(volume);
    await _tts.speak(t);
  }

  Future<void> stop() async {
    await init();
    await _tts.stop();
    await _audioPlayer.stop();
    isSpeaking.value = false;
    progress.value = null;
  }

  Future<void> _speakWithExternalVoice(String text) async {
    final voice = ExternalTtsVoice.tryParse(voiceName);
    if (voice == null) {
      await setVoiceName(null);
      await speak(text);
      return;
    }

    await _tts.stop();
    await _audioPlayer.stop();
    isSpeaking.value = true;
    progress.value = null;

    try {
      final source = await _createExternalAudioSource(voice, text);
      await _audioPlayer.setVolume(volume);
      await _audioPlayer.setAudioSource(source);
      await _audioPlayer.play();
    } catch (error) {
      lastErrorMessage = _friendlyError(error);
      isSpeaking.value = false;
      progress.value = null;
      rethrow;
    }
  }

  Future<AudioSource> _createExternalAudioSource(
    ExternalTtsVoice voice,
    String text,
  ) async {
    switch (voice.provider) {
      case ExternalTtsProvider.fpt:
        return AudioSource.file(
          await _writeTempAudio(await _synthesizeFpt(voice, text), 'mp3'),
        );
      case ExternalTtsProvider.viettel:
        return AudioSource.file(
          await _writeTempAudio(await _synthesizeViettel(voice, text), 'wav'),
        );
      case ExternalTtsProvider.azure:
        return AudioSource.file(
          await _writeTempAudio(await _synthesizeAzure(voice, text), 'mp3'),
        );
    }
  }

  Future<List<int>> _synthesizeFpt(ExternalTtsVoice voice, String text) async {
    final payload = text.trim();
    if (payload.isEmpty) {
      throw StateError('Văn bản gửi lên FPT đang trống.');
    }

    const key = String.fromEnvironment(
      'FPT_TTS_KEY',
      defaultValue: 'ciBm759h217L79qBJhe9bMKRChbSmTNH',
    );
    if (key.isEmpty) {
      throw StateError('Chua cau hinh FPT_TTS_KEY.');
    }

    final response = await _dio.post<Map<String, dynamic>>(
      'https://api.fpt.ai/hmi/tts/v5',
      data: payload,
      options: Options(
        headers: {
          'api-key': key,
          'api_key': key,
          'voice': voice.providerVoice,
          'speed': _fptSpeed.toString(),
          'format': 'mp3',
          'Cache-Control': 'no-cache',
        },
        contentType: Headers.textPlainContentType,
      ),
    );

    final data = response.data ?? const {};
    if (data['error'] != 0 || data['async'] == null) {
      throw StateError(
        'FPT không tạo được audio: '
        '${data['message'] ?? data['error'] ?? 'không rõ lỗi'}',
      );
    }
    return _downloadFptAudio(data['async'].toString());
  }

  Future<List<int>> _downloadFptAudio(String url) async {
    DioException? lastError;

    for (var attempt = 0; attempt < 20; attempt += 1) {
      await Future<void>.delayed(const Duration(seconds: 1));

      try {
        final response = await _dio.get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            validateStatus: (status) => status != null,
          ),
        );
        if ((response.statusCode ?? 0) >= 200 &&
            (response.statusCode ?? 0) < 300 &&
            (response.data?.isNotEmpty ?? false)) {
          return response.data!;
        }
      } on DioException catch (error) {
        lastError = error;
        // FPT can need a few seconds before the async URL becomes available.
      }
    }

    if (lastError != null) {
      throw StateError('FPT chưa trả file audio: ${_friendlyError(lastError)}');
    }
    throw StateError('FPT chưa trả file audio sau khi tạo yêu cầu.');
  }

  Future<List<int>> _synthesizeViettel(
    ExternalTtsVoice voice,
    String text,
  ) async {
    const token = String.fromEnvironment('VIETTEL_TTS_TOKEN');
    if (token.isEmpty) {
      throw StateError('Chua cau hinh VIETTEL_TTS_TOKEN.');
    }

    final response = await _dio.post<List<int>>(
      'https://viettelai.vn/tts/speech_synthesis',
      data: {
        'text': text,
        'voice': voice.providerVoice,
        'speed': _viettelSpeed,
        'token': token,
        'tts_return_option': 2,
        'without_filter': false,
      },
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Content-Type': 'application/json', 'accept': '*/*'},
      ),
    );

    return response.data ?? const [];
  }

  Future<List<int>> _synthesizeAzure(
    ExternalTtsVoice voice,
    String text,
  ) async {
    const key = String.fromEnvironment('AZURE_TTS_KEY');
    const region = String.fromEnvironment(
      'AZURE_TTS_REGION',
      defaultValue: 'southeastasia',
    );
    if (key.isEmpty) {
      throw StateError('Chua cau hinh AZURE_TTS_KEY.');
    }

    final ssml =
        "<speak version='1.0' xml:lang='${voice.locale}'>"
        "<voice xml:lang='${voice.locale}' name='${voice.providerVoice}'>"
        "<prosody rate='${_azureRatePercent}%' pitch='${_azurePitchPercent}%'>"
        "${_escapeXml(text)}"
        "</prosody></voice></speak>";

    final response = await _dio.post<List<int>>(
      'https://$region.tts.speech.microsoft.com/cognitiveservices/v1',
      data: ssml,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'Ocp-Apim-Subscription-Key': key,
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-24khz-96kbitrate-mono-mp3',
          'User-Agent': 'TalkSight',
        },
      ),
    );

    return response.data ?? const [];
  }

  Future<String> _writeTempAudio(List<int> bytes, String extension) async {
    if (bytes.isEmpty) throw StateError('TTS API returned empty audio.');

    final dir = await getTemporaryDirectory();
    _apiAudioCounter += 1;
    final file = File('${dir.path}/talksight_tts_$_apiAudioCounter.$extension');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  int get _fptSpeed {
    final normalized =
        ((rate - SettingsModel.minRate) /
                (SettingsModel.maxRate - SettingsModel.minRate))
            .clamp(0.0, 1.0);
    return ((normalized * 6) - 3).round().clamp(-3, 3);
  }

  double get _viettelSpeed {
    final normalized =
        ((rate - SettingsModel.minRate) /
                (SettingsModel.maxRate - SettingsModel.minRate))
            .clamp(0.0, 1.0);
    return double.parse((0.8 + normalized * 0.4).toStringAsFixed(1));
  }

  int get _azureRatePercent {
    final normalized =
        ((rate - SettingsModel.defaults.rate) /
                (SettingsModel.maxRate - SettingsModel.minRate))
            .clamp(-1.0, 1.0);
    return (normalized * 45).round();
  }

  int get _azurePitchPercent {
    final normalized =
        ((pitch - SettingsModel.defaults.pitch) /
                (SettingsModel.maxPitch - SettingsModel.minPitch))
            .clamp(-1.0, 1.0);
    return (normalized * 25).round();
  }

  String _escapeXml(String value) {
    return const HtmlEscape(HtmlEscapeMode.element).convert(value);
  }

  String _friendlyError(Object error) {
    if (error is StateError) return error.message;
    if (error is DioException) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      var message = error.message ?? 'không rõ lỗi mạng';
      if (data is Map) {
        message = (data['message'] ?? data['detail'] ?? message).toString();
      } else if (data is String && data.trim().isNotEmpty) {
        message = data.trim();
      }
      return status == null ? message : 'HTTP $status: $message';
    }
    return error.toString();
  }
}

enum TtsVoiceSource { system, api }

enum ExternalTtsProvider { fpt, viettel, azure }

class ExternalTtsVoice {
  static const prefix = 'api';

  final ExternalTtsProvider provider;
  final String providerVoice;
  final String locale;
  final String displayName;
  final String gender;

  const ExternalTtsVoice({
    required this.provider,
    required this.providerVoice,
    required this.locale,
    required this.displayName,
    required this.gender,
  });

  String get id => '$prefix:${provider.name}:$providerVoice';

  Map<String, dynamic> toMap() {
    return {
      'name': id,
      'locale': locale,
      'displayName': displayName,
      'gender': gender,
      'source': provider.name,
    };
  }

  static ExternalTtsVoice? tryParse(String? id) {
    final value = id?.trim();
    if (value == null || value.isEmpty) return null;
    for (final voice in catalog) {
      if (voice.id == value) return voice;
    }
    return null;
  }

  static const catalog = <ExternalTtsVoice>[
    ExternalTtsVoice(
      provider: ExternalTtsProvider.azure,
      providerVoice: 'vi-VN-HoaiMyNeural',
      locale: 'vi-VN',
      displayName: 'Microsoft/Edge Hoài My',
      gender: 'female',
    ),
    ExternalTtsVoice(
      provider: ExternalTtsProvider.azure,
      providerVoice: 'vi-VN-NamMinhNeural',
      locale: 'vi-VN',
      displayName: 'Microsoft/Edge Nam Minh',
      gender: 'male',
    ),
    ExternalTtsVoice(
      provider: ExternalTtsProvider.fpt,
      providerVoice: 'banmai',
      locale: 'vi-VN',
      displayName: 'FPT Ban Mai - nữ miền Bắc',
      gender: 'female',
    ),
    ExternalTtsVoice(
      provider: ExternalTtsProvider.fpt,
      providerVoice: 'lannhi',
      locale: 'vi-VN',
      displayName: 'FPT Lan Nhi - nữ miền Nam',
      gender: 'female',
    ),
    ExternalTtsVoice(
      provider: ExternalTtsProvider.fpt,
      providerVoice: 'leminh',
      locale: 'vi-VN',
      displayName: 'FPT Lê Minh - nam miền Bắc',
      gender: 'male',
    ),
    ExternalTtsVoice(
      provider: ExternalTtsProvider.fpt,
      providerVoice: 'myan',
      locale: 'vi-VN',
      displayName: 'FPT Mỹ An - nữ miền Trung',
      gender: 'female',
    ),
    ExternalTtsVoice(
      provider: ExternalTtsProvider.fpt,
      providerVoice: 'thuminh',
      locale: 'vi-VN',
      displayName: 'FPT Thu Minh - nữ miền Bắc',
      gender: 'female',
    ),
    ExternalTtsVoice(
      provider: ExternalTtsProvider.fpt,
      providerVoice: 'giahuy',
      locale: 'vi-VN',
      displayName: 'FPT Gia Huy - nam miền Trung',
      gender: 'male',
    ),
    ExternalTtsVoice(
      provider: ExternalTtsProvider.fpt,
      providerVoice: 'linhsan',
      locale: 'vi-VN',
      displayName: 'FPT Linh San - nữ miền Nam',
      gender: 'female',
    ),
    ExternalTtsVoice(
      provider: ExternalTtsProvider.viettel,
      providerVoice: 'hn-quynhanh',
      locale: 'vi-VN',
      displayName: 'Viettel Quỳnh Anh - nữ Hà Nội',
      gender: 'female',
    ),
    ExternalTtsVoice(
      provider: ExternalTtsProvider.viettel,
      providerVoice: 'hn-thanhtung',
      locale: 'vi-VN',
      displayName: 'Viettel Thanh Tùng - nam Hà Nội',
      gender: 'male',
    ),
    ExternalTtsVoice(
      provider: ExternalTtsProvider.viettel,
      providerVoice: 'hue-maingoc',
      locale: 'vi-VN',
      displayName: 'Viettel Mai Ngọc - nữ Huế',
      gender: 'female',
    ),
    ExternalTtsVoice(
      provider: ExternalTtsProvider.viettel,
      providerVoice: 'hcm-minhquan',
      locale: 'vi-VN',
      displayName: 'Viettel Minh Quân - nam Sài Gòn',
      gender: 'male',
    ),
  ];
}
