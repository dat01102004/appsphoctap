class SettingsModel {
  static const double minRate = 0.3;
  static const double maxRate = 1.0;
  static const double minPitch = 0.5;
  static const double maxPitch = 2.0;

  final String? voice;
  final double rate;
  final double pitch;
  final double volume;
  final String language;

  const SettingsModel({
    required this.voice,
    required this.rate,
    required this.pitch,
    required this.volume,
    required this.language,
  });

  static const defaults = SettingsModel(
    voice: null,
    rate: 0.5,
    pitch: 1.0,
    volume: 1.0,
    language: 'vi-VN',
  );

  factory SettingsModel.normalized(SettingsModel settings) {
    return SettingsModel(
      voice: _nullableString(settings.voice),
      rate: settings.rate.clamp(minRate, maxRate).toDouble(),
      pitch: settings.pitch.clamp(minPitch, maxPitch).toDouble(),
      volume: settings.volume.clamp(0.0, 1.0).toDouble(),
      language: _stringValue(settings.language, defaults.language),
    );
  }

  factory SettingsModel.fromJson(Map json) {
    return SettingsModel(
      voice: _nullableString(json['voice']),
      rate: _doubleValue(json['rate'], defaults.rate),
      pitch: _doubleValue(json['pitch'], defaults.pitch),
      volume: _doubleValue(json['volume'], defaults.volume),
      language: _stringValue(json['language'], defaults.language),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'voice': voice,
      'rate': rate,
      'pitch': pitch,
      'volume': volume,
      'language': language,
    };
  }

  SettingsModel copyWith({
    String? voice,
    bool clearVoice = false,
    double? rate,
    double? pitch,
    double? volume,
    String? language,
  }) {
    return SettingsModel(
      voice: clearVoice ? null : (voice ?? this.voice),
      rate: rate ?? this.rate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      language: language ?? this.language,
    );
  }

  static String _stringValue(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static double _doubleValue(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
