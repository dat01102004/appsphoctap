import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/tts/tts_service.dart';
import '../../../core/voice/global_voice_command_service.dart';
import '../../../core/widgets/hold_to_listen_layer.dart';
import '../../../data/models/settings_model.dart';
import '../../auth/auth_controller.dart';
import '../../auth/edit_profile_screen.dart';
import '../../auth/login_screen.dart';
import '../../auth/register_screen.dart';
import '../../settings/settings_controller.dart';
import '../../voice/voice_controller.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  List<Map<String, dynamic>> _voices = const [];
  bool _loadingVoices = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadVoices();
      if (!mounted) return;
      await context.read<SettingsController>().loadForCurrentAuth();
    });
  }

  @override
  void dispose() {
    context.read<VoiceController>().stop();
    super.dispose();
  }

  Future<void> _loadVoices() async {
    if (_loadingVoices) return;

    setState(() {
      _loadingVoices = true;
    });

    try {
      final raw = await context.read<TtsService>().getVoices();
      final filtered = raw.where((voice) {
        final locale = (voice['locale'] ?? '').toString().toLowerCase();
        final name = (voice['name'] ?? '').toString().toLowerCase();
        return locale.contains('vi') ||
            locale.contains('vn') ||
            name.contains('vi') ||
            name.contains('vietnam');
      }).toList();

      if (!mounted) return;
      setState(() {
        _voices = filtered.isNotEmpty ? filtered : raw;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _voices = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingVoices = false;
        });
      } else {
        _loadingVoices = false;
      }
    }
  }

  Future<void> _startVoice() async {
    final voice = context.read<VoiceController>();
    final tts = context.read<TtsService>();

    await tts.stop();
    await voice.stop();

    await voice.start(
      onFinal: (text) async {
        if (!mounted) return;
        await _handleVoiceCommand(text);
      },
    );
  }

  Future<void> _handleVoiceCommand(String raw) async {
    final text = _normalize(raw);
    final settings = context.read<SettingsController>();
    final voice = context.read<VoiceController>();
    final tts = context.read<TtsService>();

    if (text.contains('nghe thu') || text.contains('doc thu')) {
      await _previewVoice();
      return;
    }

    if (text.contains('dung doc') || text.contains('tat doc')) {
      await tts.stop();
      return;
    }

    if (await context.read<GlobalVoiceCommandService>().handle(
      raw,
      speak: (message, title) => _speak(message),
    )) {
      return;
    }

    if (text.contains('am luong lon')) {
      await settings.setVolume(1.0);
      await _speak('Đã chỉnh âm lượng lớn.');
      return;
    }

    if (text.contains('am luong nho')) {
      await settings.setVolume(0.5);
      await _speak('Đã chỉnh âm lượng nhỏ.');
      return;
    }

    if (text.contains('luu cai dat')) {
      await _saveSettings();
      return;
    }

    if (text.contains('dang nhap')) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    if (text.contains('dang ky') || text.contains('dang ki')) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RegisterScreen()),
      );
      return;
    }

    if (text.contains('dang xuat')) {
      await context.read<AuthController>().logout();
      return;
    }

    await voice.stop();
    await _speak(
      'Mình chưa hiểu lệnh. Bạn có thể nói nghe thử, tốc độ nhanh, tốc độ chậm, âm lượng lớn, lưu cài đặt hoặc đăng xuất.',
    );
  }

  Future<void> _saveSettings() async {
    final auth = context.read<AuthController>();
    if (!auth.loggedIn) {
      _showSnack('Bạn cần đăng nhập để lưu cài đặt giọng đọc.');
      await _speak('Bạn cần đăng nhập để lưu cài đặt giọng đọc.');
      return;
    }

    try {
      await context.read<SettingsController>().saveCurrent();
      _showSnack('Đã lưu cài đặt giọng đọc.');
      await _speak('Đã lưu cài đặt giọng đọc.');
    } catch (_) {
      _showSnack('Không lưu được cài đặt. Vui lòng thử lại.');
      await _speak('Không lưu được cài đặt. Vui lòng thử lại.');
    }
  }

  Future<void> _previewVoice() async {
    final settings = context.read<SettingsController>().current;
    try {
      await _speak(
        'Tốc độ ${settings.rate.toStringAsFixed(2)}. '
        'Âm lượng ${settings.volume.toStringAsFixed(2)}. '
        'Cao độ ${settings.pitch.toStringAsFixed(2)}.',
      );
    } catch (error) {
      final message =
          context.read<TtsService>().lastErrorMessage ?? error.toString();
      _showSnack('Chưa phát được giọng API: $message');
    }
  }

  Future<void> _speak(String text) async {
    final tts = context.read<TtsService>();
    final voice = context.read<VoiceController>();
    await voice.stop();
    await tts.stop();
    await tts.speak(text);
  }

  Future<void> _openProfile() async {
    final auth = context.read<AuthController>();
    if (!auth.loggedIn) {
      await _speak('Bạn cần đăng nhập trước khi đổi thông tin tài khoản.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _displayVoiceName(Map<dynamic, dynamic> voice, int index) {
    final name = (voice['name'] ?? '').toString().trim();
    final locale = (voice['locale'] ?? '').toString().trim();
    final displayName = (voice['displayName'] ?? '').toString().trim();
    final source = (voice['source'] ?? '').toString().trim();
    final key = name.toLowerCase();

    if (displayName.isNotEmpty && source.isNotEmpty) {
      return '$displayName - API';
    }

    const knownVoices = {
      'vi-vn-language': 'Giọng tiếng Việt mặc định',
      'vi-vn-x-gft-network': 'Giọng nữ 1 - trực tuyến',
      'vi-vn-x-gft-local': 'Giọng nữ 1 - trên máy',
      'vi-vn-x-vic-network': 'Giọng nữ 2 - trực tuyến',
      'vi-vn-x-vic-local': 'Giọng nữ 2 - trên máy',
      'vi-vn-x-vif-network': 'Giọng nữ 3 - trực tuyến',
      'vi-vn-x-vif-local': 'Giọng nữ 3 - trên máy',
      'vi-vn-x-vie-network': 'Giọng nam 1 - trực tuyến',
      'vi-vn-x-vie-local': 'Giọng nam 1 - trên máy',
      'vi-vn-x-vid-network': 'Giọng nam 2 - trực tuyến',
      'vi-vn-x-vid-local': 'Giọng nam 2 - trên máy',
      'vi-vn-x-gan-local': 'Giọng nam 3 - trên máy',
    };

    final known = knownVoices[key];
    if (known != null) return known;

    if (name.isEmpty) return 'Giọng đọc ${index + 1}';
    if (locale.toLowerCase().startsWith('vi')) {
      return 'Giọng tiếng Việt ${index + 1}';
    }
    return 'Giọng đọc ${index + 1}';
  }

  int? _currentVoiceIndex(String? voiceName) {
    if (voiceName == null || voiceName.isEmpty) return null;
    for (var i = 0; i < _voices.length; i++) {
      if ((_voices[i]['name'] ?? '').toString() == voiceName) return i;
    }
    return null;
  }

  String _avatarLetter(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'K';
    return text.characters.first.toUpperCase();
  }

  String _normalize(String input) {
    var text = input.toLowerCase().trim();
    const from =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩ'
        'òóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const to =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiii'
        'ooooooooooooooooouuuuuuuuuuuyyyyyd';
    for (var i = 0; i < from.length; i++) {
      text = text.replaceAll(from[i], to[i]);
    }
    return text.replaceAll(RegExp(r'\s+'), ' ');
  }

  Widget _heroCard(AuthController auth) {
    final loggedIn = auth.loggedIn;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFA67A2D), Color(0xFF7B551C)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                child: Center(
                  child: Text(
                    _avatarLetter(auth.displayName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loggedIn ? 'Xin chào,' : 'Chế độ khách',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      loggedIn ? auth.displayName : 'Bạn chưa đăng nhập',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            loggedIn
                ? 'TalkSight đã sẵn sàng hỗ trợ bạn bằng giọng nói, đọc chữ, mô tả hình ảnh và lưu lịch sử sử dụng.'
                : 'Đăng nhập để lưu lịch sử, đồng bộ thông tin và dùng đầy đủ tính năng của TalkSight.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.94),
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (!loggedIn)
            Row(
              children: [
                Expanded(
                  child: _PrimaryActionButton(
                    icon: Icons.login_rounded,
                    label: 'Đăng nhập',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _OutlineActionButton(
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Đăng ký',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _voiceControlCard(VoiceController voice) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.bgBeige,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                voice.isListening
                    ? Icons.mic_rounded
                    : Icons.record_voice_over_rounded,
                color: AppColors.brandBrown,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voice.isListening
                        ? 'Đang nghe cài đặt'
                        : 'Điều khiển bằng giọng nói',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    voice.isListening
                        ? (voice.lastWords.trim().isEmpty
                              ? 'Đang nghe...'
                              : voice.lastWords.trim())
                        : 'Nhấn mic hoặc giữ màn hình 2 giây để điều khiển. Có thể nói: nghe thử, tốc độ nhanh, âm lượng lớn, lưu cài đặt.',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.muted,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () async {
                if (voice.isListening) {
                  await voice.stop();
                } else {
                  await _startVoice();
                }
              },
              icon: Icon(
                voice.isListening
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outline_rounded,
                color: AppColors.brandBrown,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountCard(AuthController auth) {
    if (!auth.loggedIn) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tài khoản',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Bạn đang dùng chế độ khách. Hãy đăng nhập để lưu lịch sử và cá nhân hóa trải nghiệm.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _BrownButton(
                      icon: Icons.login_rounded,
                      label: 'Đăng nhập',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BorderButton(
                      icon: Icons.person_add_alt_1_rounded,
                      label: 'Đăng ký',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tài khoản của bạn',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              auth.displayName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            if ((auth.email ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(auth.email!, style: const TextStyle(color: AppColors.muted)),
            ],
            if ((auth.phone ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(auth.phone!, style: const TextStyle(color: AppColors.muted)),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _BrownButton(
                    icon: Icons.edit_rounded,
                    label: 'Đổi thông tin',
                    onPressed: _openProfile,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 58,
                  height: 50,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandBrown,
                      side: const BorderSide(color: AppColors.cardStroke),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () => auth.logout(),
                    child: const Icon(Icons.logout_rounded),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _speechSettingsCard(SettingsController controller) {
    final settings = controller.current;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Giọng đọc',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Điều chỉnh tốc độ, âm lượng và chọn giọng đọc phù hợp.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            _SliderRow(
              icon: Icons.speed_rounded,
              title: 'Tốc độ đọc',
              valueText: settings.rate.toStringAsFixed(2),
              value: settings.rate,
              min: SettingsModel.minRate,
              max: SettingsModel.maxRate,
              onChanged: controller.setRate,
            ),
            const SizedBox(height: 10),
            _SliderRow(
              icon: Icons.volume_up_rounded,
              title: 'Âm lượng',
              valueText: settings.volume.toStringAsFixed(2),
              value: settings.volume,
              min: 0.0,
              max: 1.0,
              onChanged: controller.setVolume,
            ),
            const SizedBox(height: 10),
            _SliderRow(
              icon: Icons.graphic_eq_rounded,
              title: 'Cao độ giọng đọc',
              valueText: settings.pitch.toStringAsFixed(2),
              value: settings.pitch,
              min: SettingsModel.minPitch,
              max: SettingsModel.maxPitch,
              onChanged: controller.setPitch,
            ),
            const SizedBox(height: 16),
            if (_voices.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgBeige,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardStroke),
                ),
                child: Row(
                  children: [
                    Icon(
                      _loadingVoices
                          ? Icons.hourglass_top_rounded
                          : Icons.voice_over_off_rounded,
                      color: AppColors.brandBrown,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _loadingVoices
                            ? 'Đang tải danh sách giọng đọc...'
                            : 'Chưa tải được danh sách giọng đọc.',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<int>(
                initialValue: _currentVoiceIndex(settings.voice),
                isExpanded: true,
                menuMaxHeight: 360,
                decoration: _inputDecoration(
                  label: 'Chọn giọng đọc',
                  icon: Icons.record_voice_over_rounded,
                ),
                items: List.generate(_voices.length, (index) {
                  return DropdownMenuItem<int>(
                    value: index,
                    child: Text(
                      _displayVoiceName(_voices[index], index),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
                selectedItemBuilder: (context) {
                  return List.generate(_voices.length, (index) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _displayVoiceName(_voices[index], index),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    );
                  });
                },
                onChanged: (index) {
                  if (index == null) return;
                  final voice = _voices[index];
                  controller.setVoice(
                    (voice['name'] ?? '').toString(),
                    locale: (voice['locale'] ?? settings.language).toString(),
                  );
                },
              ),
            const SizedBox(height: 16),
            _BrownButton(
              icon: Icons.play_arrow_rounded,
              label: 'Nghe thử giọng đọc',
              onPressed: _previewVoice,
            ),
            if (controller.message != null) ...[
              const SizedBox(height: 12),
              Text(
                controller.message!,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 54,
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandBrown,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: controller.loading || controller.saving
                    ? null
                    : _saveSettings,
                icon: controller.saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  controller.saving ? 'Đang lưu...' : 'Lưu cài đặt',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.brandBrown),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.cardStroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.brandBrown, width: 1.3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final voice = context.watch<VoiceController>();
    final settings = context.watch<SettingsController>();

    return HoldToListenLayer(
      holdDuration: const Duration(seconds: 2),
      onTriggered: _startVoice,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heroCard(auth),
              const SizedBox(height: 16),
              _voiceControlCard(voice),
              const SizedBox(height: 16),
              _accountCard(auth),
              const SizedBox(height: 16),
              _speechSettingsCard(settings),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.icon,
    required this.title,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.bgBeige,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardStroke),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.brandBrown, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.cardStroke),
                ),
                child: Text(
                  valueText,
                  style: const TextStyle(
                    color: AppColors.brandBrown,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            activeColor: AppColors.brandBrown,
            inactiveColor: AppColors.cardStroke,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _BrownButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _BrownButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandBrown,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _BorderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _BorderButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandBrown,
          side: const BorderSide(color: AppColors.cardStroke),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.brandBrown,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _OutlineActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.8),
            width: 1.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}
