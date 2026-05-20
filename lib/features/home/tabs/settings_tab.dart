import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/tts/tts_service.dart';
import '../../../core/voice/global_voice_intent.dart';
import '../../../core/widgets/hold_to_listen_layer.dart';
import '../../auth/auth_controller.dart';
import '../../auth/edit_profile_screen.dart';
import '../../auth/login_screen.dart';
import '../../auth/register_screen.dart';
import '../../voice/voice_controller.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  int _listenEpoch = 0;
  String _lastPromptNorm = '';
  String _lastAnnounceMode = '';
  List<Map<dynamic, dynamic>> _voices = const [];
  bool _loadingVoices = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadVoices();
      if (!mounted) return;
      await _announceByState();
    });
  }

  @override
  void dispose() {
    _listenEpoch++;
    context.read<VoiceController>().stop();
    super.dispose();
  }

  Future<void> _loadVoices() async {
    if (_loadingVoices) return;

    _loadingVoices = true;

    try {
      final tts = context.read<TtsService>();
      final raw = await tts.getVoices();

      final filtered = raw.where((v) {
        final locale = (v['locale'] ?? '').toString().toLowerCase();
        final name = (v['name'] ?? '').toString().toLowerCase();

        return locale.contains('vi') ||
            locale.contains('vn') ||
            name.contains('vi') ||
            name.contains('vietnam');
      }).toList();

      if (!mounted) return;

      setState(() {
        _voices = filtered.isNotEmpty
            ? List<Map<dynamic, dynamic>>.from(filtered)
            : List<Map<dynamic, dynamic>>.from(raw);
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _voices = const [];
      });
    } finally {
      _loadingVoices = false;
    }
  }

  Future<void> _speak(String text) async {
    final value = text.trim();
    if (value.isEmpty) return;

    _lastPromptNorm = _norm(value);

    final tts = context.read<TtsService>();
    final voice = context.read<VoiceController>();

    await voice.stop();
    await tts.stop();
    await tts.speak(value);
  }

  Future<void> _announceByState() async {
    final auth = context.read<AuthController>();
    final mode = auth.loggedIn ? 'logged_in' : 'guest';

    if (_lastAnnounceMode == mode) return;

    _lastAnnounceMode = mode;

    if (auth.loggedIn) {
      await _speak(
        'Màn hình cài đặt. '
        'Xin chào ${auth.displayName}. '
        'Bạn có thể đổi thông tin người dùng, chỉnh tốc độ đọc, độ cao giọng, '
        'chọn giọng đọc, nghe thử hoặc đăng xuất. '
        'Có thể nói: đổi thông tin, nghe thử, tốc độ nhanh, giọng thấp, đăng xuất.',
      );
    } else {
      await _speak(
        'Màn hình cài đặt. '
        'Bạn đang ở chế độ khách. '
        'Bạn có thể đăng nhập, đăng ký, chỉnh tốc độ đọc, chọn giọng đọc và nghe thử.',
      );
    }
  }

  Future<void> _startVoice() async {
    final voice = context.read<VoiceController>();
    final tts = context.read<TtsService>();
    final epoch = ++_listenEpoch;

    await tts.stop();
    await voice.stop();
    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted || epoch != _listenEpoch) return;

    await voice.start(
      onFinal: (text) async {
        if (!mounted || epoch != _listenEpoch) return;

        final normalized = _norm(text);

        if (normalized.isEmpty || _isPromptEcho(normalized)) return;

        await _handleVoice(text);
      },
    );
  }

  bool _isPromptEcho(String normalized) {
    if (_lastPromptNorm.isEmpty || normalized.isEmpty) return false;
    if (normalized == _lastPromptNorm) return true;

    if (normalized.length >= 24 && _lastPromptNorm.contains(normalized)) {
      return true;
    }

    return false;
  }

  Future<void> _handleVoice(String raw) async {
    final handledGlobal = await _handleGlobalVoiceIntent(raw);
    if (handledGlobal) return;

    final n = _norm(raw);
    final auth = context.read<AuthController>();
    final tts = context.read<TtsService>();

    if (n.contains('nhac lai') ||
        n.contains('doc lai') ||
        n.contains('huong dan') ||
        n.contains('tro giup')) {
      _lastAnnounceMode = '';
      await _announceByState();
      return;
    }

    if (n.contains('doi nguoi dung') ||
        n.contains('thay doi nguoi dung') ||
        n.contains('doi thong tin') ||
        n.contains('sua thong tin') ||
        n.contains('chinh sua thong tin') ||
        n.contains('cap nhat thong tin') ||
        n.contains('mo ho so') ||
        n.contains('tai khoan cua toi')) {
      await _openChangeUser();
      return;
    }

    if (n.contains('dang nhap') ||
        n.contains('login') ||
        n.contains('tai khoan khac')) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );

      if (!mounted) return;
      setState(() {});
      _lastAnnounceMode = '';
      return;
    }

    if (n.contains('dang ky') ||
        n.contains('dang ki') ||
        n.contains('tao tai khoan') ||
        n.contains('register')) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RegisterScreen()),
      );

      if (!mounted) return;
      setState(() {});
      _lastAnnounceMode = '';
      return;
    }

    if (n.contains('dang xuat') ||
        n.contains('thoat tai khoan') ||
        n.contains('log out') ||
        n.contains('logout')) {
      if (!auth.loggedIn) {
        await _speak('Bạn đang ở chế độ khách.');
        return;
      }

      await auth.logout();

      if (!mounted) return;
      setState(() {});
      _lastAnnounceMode = '';
      return;
    }

    if (n.contains('nghe thu') ||
        n.contains('doc thu') ||
        n.contains('test giong') ||
        n.contains('thu giong')) {
      await _previewVoice();
      return;
    }

    if (n.contains('dung doc') ||
        n.contains('tat doc') ||
        n.contains('ngung doc') ||
        n == 'stop') {
      await tts.stop();
      return;
    }

    if (n.contains('toc do mac dinh')) {
      await _setRate(0.45, speakBack: true);
      return;
    }

    if (n.contains('toc do cham') || n.contains('doc cham')) {
      await _setRate(0.35, speakBack: true);
      return;
    }

    if (n.contains('toc do vua') || n.contains('doc vua')) {
      await _setRate(0.45, speakBack: true);
      return;
    }

    if (n.contains('toc do nhanh') || n.contains('doc nhanh')) {
      await _setRate(0.60, speakBack: true);
      return;
    }

    if (n.contains('giong mac dinh') || n.contains('do cao mac dinh')) {
      await _setPitch(1.0, speakBack: true);
      return;
    }

    if (n.contains('giong thap') || n.contains('do cao thap')) {
      await _setPitch(0.90, speakBack: true);
      return;
    }

    if (n.contains('giong vua') || n.contains('do cao vua')) {
      await _setPitch(1.0, speakBack: true);
      return;
    }

    if (n.contains('giong cao') || n.contains('do cao cao')) {
      await _setPitch(1.15, speakBack: true);
      return;
    }

    final rateValue = _extractDecimalValue(n);

    if (rateValue != null &&
        (n.contains('toc do') || n.contains('rate') || n.contains('van toc'))) {
      final clamped = rateValue.clamp(0.2, 0.8).toDouble();
      await _setRate(clamped, speakBack: true);
      return;
    }

    final pitchValue = _extractDecimalValue(n);

    if (pitchValue != null &&
        (n.contains('do cao') || n.contains('pitch') || n.contains('giong'))) {
      final clamped = pitchValue.clamp(0.7, 1.5).toDouble();
      await _setPitch(clamped, speakBack: true);
      return;
    }

    if (n.contains('giong 1') ||
        n.contains('giong mot') ||
        n.contains('chon giong 1') ||
        n.contains('chon giong mot')) {
      await _setVoiceByIndex(0);
      return;
    }

    final voiceIndex = _extractIndex(n);

    if (voiceIndex != null &&
        (n.contains('chon giong') ||
            n.contains('giong so') ||
            n.contains('voice'))) {
      await _setVoiceByIndex(voiceIndex - 1);
      return;
    }

    await _speak(
      'Mình chưa hiểu lệnh. '
      'Bạn có thể nói: đổi thông tin, nghe thử, tốc độ nhanh, giọng thấp, '
      'chọn giọng 1, đăng nhập, đăng ký hoặc đăng xuất.',
    );
  }

  Future<bool> _handleGlobalVoiceIntent(String raw) async {
    final intent = GlobalVoiceIntentParser.parse(raw);
    final tts = context.read<TtsService>();
    final voice = context.read<VoiceController>();

    switch (intent) {
      case GlobalVoiceIntent.stopReading:
        await voice.stop();
        await tts.stop();
        return true;
      case GlobalVoiceIntent.repeatReading:
        _lastAnnounceMode = '';
        await _announceByState();
        return true;
      case GlobalVoiceIntent.home:
      case GlobalVoiceIntent.back:
        await voice.stop();
        await tts.stop();
        await _speak(
          'Báº¡n cĂ³ thá»ƒ dĂ¹ng thanh Ä‘iá»u hÆ°á»›ng Ä‘á»ƒ vá» trang chá»§.',
        );
        return true;
      case GlobalVoiceIntent.settings:
        _lastAnnounceMode = '';
        await _announceByState();
        return true;
      case GlobalVoiceIntent.history:
      case GlobalVoiceIntent.caption:
      case GlobalVoiceIntent.ocr:
      case GlobalVoiceIntent.news:
        await voice.stop();
        await tts.stop();
        await _speak(
          'Báº¡n cĂ³ thá»ƒ dĂ¹ng thanh Ä‘iá»u hÆ°á»›ng hoáº·c vá» trang chá»§ Ä‘á»ƒ má»Ÿ chá»©c nÄƒng nĂ y.',
        );
        return true;
      case GlobalVoiceIntent.none:
        return false;
    }
  }

  Future<void> _openChangeUser() async {
    final auth = context.read<AuthController>();

    if (!auth.loggedIn) {
      await _speak(
        'Bạn đang ở chế độ khách. '
        'Hãy đăng nhập trước để thay đổi thông tin người dùng.',
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );

    if (!mounted) return;

    setState(() {});
    _lastAnnounceMode = '';
  }

  String _displayVoiceName(Map<dynamic, dynamic> voice, int index) {
    final rawName = (voice['name'] ?? '').toString().toLowerCase();
    final locale = (voice['locale'] ?? '').toString();

    const manualMap = {
      'vi-vn-language': 'Giọng tiếng Việt mặc định',
      'vi-vn-x-gft-network': 'Giọng nữ 1',
      'vi-vn-x-vie-network': 'Giọng nữ 2',
      'vi-vn-x-vid-local': 'Giọng nam 1',
      'vi-vn-x-vic-local': 'Giọng nữ 3',
      'vi-vn-x-gft-local': 'Giọng nữ 4',
      'vi-vn-x-vie-local': 'Giọng nam 2',
      'vi-vn-x-gan-local': 'Giọng nam 3',
    };

    final mapped = manualMap[rawName];
    if (mapped != null) return mapped;

    if (rawName.contains('gft')) return 'Giọng nữ ${index + 1}';
    if (rawName.contains('vie')) return 'Giọng nam ${index + 1}';
    if (rawName.contains('vic')) return 'Giọng nữ ${index + 1}';
    if (rawName.contains('vid')) return 'Giọng nam ${index + 1}';
    if (rawName.contains('language')) return 'Giọng tiếng Việt mặc định';

    if (locale.toLowerCase().contains('vi')) {
      return 'Giọng tiếng Việt ${index + 1}';
    }

    return 'Giọng ${index + 1}';
  }

  int? _extractIndex(String normalized) {
    final digit = RegExp(r'\b(\d+)\b').firstMatch(normalized);

    if (digit != null) {
      return int.tryParse(digit.group(1)!);
    }

    const map = {
      'mot': 1,
      'hai': 2,
      'ba': 3,
      'bon': 4,
      'tu': 4,
      'nam': 5,
      'sau': 6,
      'bay': 7,
      'tam': 8,
      'chin': 9,
      'muoi': 10,
    };

    for (final entry in map.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }

    return null;
  }

  double? _extractDecimalValue(String normalized) {
    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(normalized);

    if (match == null) return null;

    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }

  Future<void> _setRate(double value, {bool speakBack = false}) async {
    final tts = context.read<TtsService>();

    await tts.setRate(value);

    if (!mounted) return;

    setState(() {});

    if (speakBack) {
      await _speak('Đã đặt tốc độ đọc ${value.toStringAsFixed(2)}.');
    }
  }

  Future<void> _setPitch(double value, {bool speakBack = false}) async {
    final tts = context.read<TtsService>();

    await tts.setPitch(value);

    if (!mounted) return;

    setState(() {});

    if (speakBack) {
      await _speak('Đã đặt độ cao giọng ${value.toStringAsFixed(2)}.');
    }
  }

  Future<void> _setVoiceByIndex(int index) async {
    if (_voices.isEmpty) {
      await _speak('Hiện chưa tải được danh sách giọng đọc.');
      return;
    }

    if (index < 0 || index >= _voices.length) {
      await _speak('Không tìm thấy giọng đọc đó.');
      return;
    }

    final tts = context.read<TtsService>();
    final voice = _voices[index];

    await tts.setVoice(voice);

    if (!mounted) return;

    setState(() {});

    final displayName = _displayVoiceName(voice, index);

    await _speak('Đã chọn $displayName.');
  }

  Future<void> _previewVoice() async {
    final tts = context.read<TtsService>();

    final voiceName = tts.voiceName;
    final rate = tts.rate.toStringAsFixed(2);
    final pitch = tts.pitch.toStringAsFixed(2);

    await _speak(
      'Đây là giọng đọc thử của Mắt Nói. '
      'Tốc độ hiện tại là $rate. '
      'Độ cao giọng là $pitch. '
      '${voiceName != null && voiceName.isNotEmpty ? "Tên giọng hiện tại là $voiceName." : ""}',
    );
  }

  String _norm(String input) {
    var s = input.toLowerCase().trim();

    const from =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩ'
        'òóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
        'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨ'
        'ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';

    const to =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiii'
        'ooooooooooooooooouuuuuuuuuuuyyyyyd'
        'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIII'
        'OOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';

    for (int i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }

    s = s.replaceAll(RegExp(r'[^a-z0-9\s\.,]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    return s;
  }

  String _avatarLetter(String value) {
    final name = value.trim();
    if (name.isEmpty) return 'M';

    return name.substring(0, 1).toUpperCase();
  }

  Widget _heroCard() {
    final auth = context.watch<AuthController>();
    final loggedIn = auth.loggedIn;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFA67A2D), Color(0xFF7B551C)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B551C).withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -36,
            top: -36,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -54,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.48),
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
                      ? 'Mắt Nói đã sẵn sàng hỗ trợ bạn bằng giọng nói, đọc chữ, mô tả hình ảnh và lưu lịch sử sử dụng.'
                      : 'Đăng nhập để lưu lịch sử, đồng bộ thông tin và dùng đầy đủ tính năng của Mắt Nói.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.94),
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                if (loggedIn)
                  Row(
                    children: [
                      Expanded(
                        child: _GlassInfoPill(
                          icon: Icons.mail_outline_rounded,
                          text: auth.email ?? 'Chưa có email',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _GlassInfoPill(
                          icon: Icons.phone_rounded,
                          text: auth.phone ?? 'Chưa có SĐT',
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
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
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );

                              if (!mounted) return;
                              setState(() {});
                              _lastAnnounceMode = '';
                            },
                            icon: const Icon(Icons.login_rounded),
                            label: const Text(
                              'Đăng nhập',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
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
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );

                              if (!mounted) return;
                              setState(() {});
                              _lastAnnounceMode = '';
                            },
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text(
                              'Đăng ký',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _voiceControlCard() {
    final voice = context.watch<VoiceController>();

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
                        : 'Nhấn mic hoặc giữ màn hình 2 giây để điều khiển. Có thể nói: đổi thông tin, nghe thử, tốc độ nhanh, giọng thấp.',
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
                  _listenEpoch++;
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

  Widget _accountCard() {
    final auth = context.watch<AuthController>();

    if (!auth.loggedIn) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandBrown,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );

                          if (!mounted) return;
                          setState(() {});
                          _lastAnnounceMode = '';
                        },
                        icon: const Icon(Icons.login_rounded),
                        label: const Text(
                          'Đăng nhập',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.brandBrown,
                          side: const BorderSide(color: AppColors.cardStroke),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );

                          if (!mounted) return;
                          setState(() {});
                          _lastAnnounceMode = '';
                        },
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text(
                          'Đăng ký',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgBeige,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardStroke),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.brandBrown,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text(
                        _avatarLetter(auth.displayName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          auth.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13.5,
                          ),
                        ),
                        if ((auth.phone ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            auth.phone!,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandBrown,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: _openChangeUser,
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text(
                        'Đổi thông tin',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
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
                    onPressed: () async {
                      await auth.logout();

                      if (!mounted) return;

                      setState(() {});
                      _lastAnnounceMode = '';
                    },
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

  Widget _speechSettingsCard() {
    final tts = context.watch<TtsService>();

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
              'Điều chỉnh tốc độ, độ cao và chọn giọng đọc phù hợp.',
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
              valueText: tts.rate.toStringAsFixed(2),
              value: tts.rate,
              min: 0.2,
              max: 0.8,
              onChanged: (value) {
                _setRate(value);
              },
            ),
            const SizedBox(height: 10),
            _SliderRow(
              icon: Icons.graphic_eq_rounded,
              title: 'Độ cao giọng',
              valueText: tts.pitch.toStringAsFixed(2),
              value: tts.pitch,
              min: 0.7,
              max: 1.5,
              onChanged: (value) {
                _setPitch(value);
              },
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
                value: _currentVoiceIndex(tts.voiceName),
                decoration: InputDecoration(
                  labelText: 'Chọn giọng đọc',
                  prefixIcon: const Icon(
                    Icons.record_voice_over_rounded,
                    color: AppColors.brandBrown,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.cardStroke),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.brandBrown,
                      width: 1.3,
                    ),
                  ),
                ),
                items: List.generate(_voices.length, (index) {
                  return DropdownMenuItem<int>(
                    value: index,
                    child: Text(_displayVoiceName(_voices[index], index)),
                  );
                }),
                onChanged: (index) {
                  if (index == null) return;
                  _setVoiceByIndex(index);
                },
              ),
            const SizedBox(height: 16),
            SizedBox(
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
                onPressed: _previewVoice,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text(
                  'Nghe thử giọng đọc',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int? _currentVoiceIndex(String? voiceName) {
    if (voiceName == null || voiceName.isEmpty) return null;

    for (int i = 0; i < _voices.length; i++) {
      final name = (_voices[i]['name'] ?? '').toString();

      if (name == voiceName) return i;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
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
              _heroCard(),
              const SizedBox(height: 16),
              _voiceControlCard(),
              const SizedBox(height: 16),
              _accountCard(),
              const SizedBox(height: 16),
              _speechSettingsCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassInfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _GlassInfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
