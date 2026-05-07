import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/tts/tts_service.dart';
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
  List<Map<String, dynamic>> _voices = const [];
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
            ? List<Map<String, dynamic>>.from(filtered)
            : List<Map<String, dynamic>>.from(raw);
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
    _lastPromptNorm = _norm(text);
    final tts = context.read<TtsService>();
    final voice = context.read<VoiceController>();
    await voice.stop();
    await tts.stop();
    await tts.speak(text);
  }

  Future<void> _announceByState() async {
    final auth = context.read<AuthController>();
    final mode = auth.loggedIn ? 'logged_in' : 'guest';

    if (_lastAnnounceMode == mode) return;
    _lastAnnounceMode = mode;

    if (auth.loggedIn) {
      await _speak(
        'Màn hình cài đặt. '
            'Bạn có thể đổi người dùng, chỉnh sửa họ tên, email, số điện thoại, '
            'điều chỉnh tốc độ đọc, độ cao giọng, chọn giọng đọc, nghe thử hoặc đăng xuất. '
            'Có thể nói: đổi người dùng, sửa thông tin, tốc độ nhanh, giọng thấp.',
      );
    } else {
      await _speak(
        'Màn hình cài đặt. '
            'Bạn đang ở chế độ khách. '
            'Bạn có thể đăng nhập, đăng ký, điều chỉnh giọng đọc và nghe thử. '
            'Sau khi đăng nhập, bạn có thể đổi người dùng và sửa thông tin hồ sơ.',
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
    final n = _norm(raw);
    final auth = context.read<AuthController>();
    final tts = context.read<TtsService>();

    if (n.contains('nhac lai') ||
        n.contains('doc lai') ||
        n.contains('huong dan') ||
        n.contains('tro giup')) {
      await _announceByState();
      return;
    }

    if (n.contains('doi nguoi dung') ||
        n.contains('thay doi nguoi dung') ||
        n.contains('sua thong tin') ||
        n.contains('chinh sua thong tin') ||
        n.contains('chinh sua tai khoan') ||
        n.contains('cap nhat thong tin') ||
        n.contains('mo ho so')) {
      await _openChangeUser();
      return;
    }

    if (n.contains('doi tai khoan') ||
        n.contains('tai khoan khac') ||
        n.contains('dang nhap tai khoan khac')) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (!mounted) return;
      setState(() {});
      return;
    }

    if (n.contains('nghe thu') ||
        n.contains('doc thu') ||
        n.contains('test giong')) {
      await _previewVoice();
      return;
    }

    if (n.contains('dung doc') || n.contains('tat doc') || n == 'stop') {
      await tts.stop();
      return;
    }

    if (n.contains('dang nhap')) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (!mounted) return;
      setState(() {});
      return;
    }

    if (n.contains('dang ky') || n.contains('tao tai khoan')) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RegisterScreen()),
      );
      if (!mounted) return;
      setState(() {});
      return;
    }

    if (n.contains('dang xuat') || n.contains('log out')) {
      if (!auth.loggedIn) {
        await _speak('Bạn đang ở chế độ khách.');
        return;
      }
      await auth.logout();
      if (!mounted) return;
      setState(() {});
      return;
    }

    if (n.contains('toc do mac dinh')) {
      await _setRate(0.45, speakBack: true);
      return;
    }

    if (n.contains('giong mac dinh') || n.contains('do cao mac dinh')) {
      await _setPitch(1.0, speakBack: true);
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
      final clamped = rateValue.clamp(0.2, 0.8);
      await _setRate(clamped, speakBack: true);
      return;
    }

    final pitchValue = _extractDecimalValue(n);
    if (pitchValue != null &&
        (n.contains('do cao') || n.contains('pitch') || n.contains('giong'))) {
      final clamped = pitchValue.clamp(0.7, 1.5);
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
          'Bạn có thể nói: đổi người dùng, sửa thông tin, nghe thử, tốc độ nhanh, giọng thấp, '
          'chọn giọng 1, đăng nhập, đăng ký hoặc đăng xuất.',
    );
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

  String _displayVoiceName(Map voice, int index) {
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
      await _speak('Đã đặt tốc độ đọc ${value.toStringAsFixed(2)}');
    }
  }

  Future<void> _setPitch(double value, {bool speakBack = false}) async {
    final tts = context.read<TtsService>();
    await tts.setPitch(value);
    if (!mounted) return;
    setState(() {});
    if (speakBack) {
      await _speak('Đã đặt độ cao giọng ${value.toStringAsFixed(2)}');
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
    await _speak('Đã chọn $displayName');
  }

  Future<void> _previewVoice() async {
    final tts = context.read<TtsService>();
    final voiceName = tts.voiceName;
    final rate = tts.rate.toStringAsFixed(2);
    final pitch = tts.pitch.toStringAsFixed(2);

    await _speak(
      'Đây là giọng đọc thử của TalkSight. '
          'Tốc độ hiện tại là $rate. '
          'Độ cao giọng là $pitch. '
          '${voiceName != null && voiceName.isNotEmpty ? "Tên giọng hiện tại là $voiceName." : ""}',
    );
  }

  String _norm(String input) {
    var s = input.toLowerCase().trim();

    const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩ'
        'òóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
        'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨ'
        'ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiii'
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

  Widget _changeUserCard() {
    final auth = context.watch<AuthController>();
    final subtitle = auth.loggedIn
        ? '${auth.fullName?.trim().isNotEmpty == true ? auth.fullName!.trim() : auth.email ?? "Người dùng TalkSight"}'
        '${(auth.phone ?? '').trim().isNotEmpty ? '\n${auth.email ?? ''} • ${auth.phone ?? ''}' : '\n${auth.email ?? ''}'}'
        : 'Đăng nhập để cập nhật họ tên, email và số điện thoại của người dùng.';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: auth.loggedIn
            ? _openChangeUser
            : () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
          if (!mounted) return;
          setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thay đổi người dùng',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgBeige,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.record_voice_over_rounded,
                          size: 16,
                          color: AppColors.brandBrown,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Nói: đổi người dùng',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandBrown,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    auth.loggedIn
                        ? Icons.edit_outlined
                        : Icons.login_rounded,
                    color: AppColors.brandBrown,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCard() {
    final auth = context.watch<AuthController>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cài đặt',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1.2,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              auth.loggedIn
                  ? 'Bạn đang đăng nhập với ${auth.email ?? "tài khoản TalkSight"}.'
                  : 'Bạn đang ở chế độ khách. Có thể đăng nhập để đồng bộ lịch sử sử dụng.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.muted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _voiceCard() {
    final voice = context.watch<VoiceController>();
    final subtitle = voice.isListening
        ? (voice.lastWords.trim().isEmpty ? 'Đang nghe...' : voice.lastWords.trim())
        : 'Nhấn mic hoặc giữ màn hình 2 giây để điều khiển cài đặt. '
        'Có thể nói: đổi người dùng, sửa thông tin, tốc độ nhanh, giọng thấp.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.bgBeige,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                voice.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
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
                        ? 'Đang nghe lệnh cài đặt'
                        : 'Điều khiển bằng giọng nói',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
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
                    : Icons.play_circle_outline,
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
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.bgBeige,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.brandBrown,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: auth.loggedIn
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.fullName?.trim().isNotEmpty == true
                            ? auth.fullName!.trim()
                            : (auth.email ?? 'Đã đăng nhập'),
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        auth.email ?? '',
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.muted,
                        ),
                      ),
                      if ((auth.phone ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          auth.phone!.trim(),
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ],
                  )
                      : const Text(
                    'Bạn đang ở chế độ khách',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (auth.loggedIn) ...[
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandBrown,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: _openChangeUser,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text(
                          'Chỉnh sửa',
                          style: TextStyle(fontWeight: FontWeight.w800),
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
                          foregroundColor: AppColors.brandBrown,
                          side: const BorderSide(color: AppColors.cardStroke),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () async {
                          await auth.logout();
                          if (!mounted) return;
                          setState(() {});
                        },
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text(
                          'Đăng xuất',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandBrown,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
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
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.brandBrown,
                          side: const BorderSide(color: AppColors.cardStroke),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          );
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
          ],
        ),
      ),
    );
  }

  Widget _ttsControlsCard() {
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
            const SizedBox(height: 8),
            const Text(
              'Bạn có thể kéo thanh trượt hoặc dùng giọng nói: “tốc độ nhanh”, “giọng thấp”, “nghe thử”.',
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            _SliderRow(
              icon: Icons.speed_rounded,
              label: 'Tốc độ đọc',
              valueText: tts.rate.toStringAsFixed(2),
              child: Slider(
                value: tts.rate.clamp(0.2, 0.8),
                min: 0.2,
                max: 0.8,
                divisions: 12,
                onChanged: (value) => _setRate(value),
              ),
            ),
            const SizedBox(height: 8),
            _SliderRow(
              icon: Icons.graphic_eq_rounded,
              label: 'Độ cao giọng',
              valueText: tts.pitch.toStringAsFixed(2),
              child: Slider(
                value: tts.pitch.clamp(0.7, 1.5),
                min: 0.7,
                max: 1.5,
                divisions: 16,
                onChanged: (value) => _setPitch(value),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: AppColors.bgBeige,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Giọng hiện tại: ${tts.voiceName?.trim().isNotEmpty == true ? tts.voiceName!.trim() : "Mặc định"}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_loadingVoices)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              )
            else if (_voices.isNotEmpty) ...[
              const Text(
                'Chọn giọng đọc',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                  _voices.length > 8 ? 8 : _voices.length,
                      (index) {
                    final voice = _voices[index];
                    final label = _displayVoiceName(voice, index);
                    final selected = (tts.voiceName ?? '').trim() ==
                        (voice['name'] ?? '').toString().trim();

                    return ChoiceChip(
                      selected: selected,
                      label: Text(label),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.brandBrown,
                      ),
                      selectedColor: AppColors.brandBrown,
                      backgroundColor: AppColors.bgBeige,
                      side: const BorderSide(color: AppColors.cardStroke),
                      onSelected: (_) => _setVoiceByIndex(index),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandBrown,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _previewVoice,
                      icon: const Icon(Icons.volume_up_rounded),
                      label: const Text(
                        'Nghe thử',
                        style: TextStyle(fontWeight: FontWeight.w800),
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
                        foregroundColor: AppColors.brandBrown,
                        side: const BorderSide(color: AppColors.cardStroke),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        await context.read<TtsService>().stop();
                      },
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text(
                        'Dừng đọc',
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

  @override
  Widget build(BuildContext context) {
    return HoldToListenLayer(
      holdDuration: const Duration(seconds: 2),
      onTriggered: _startVoice,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 140),
        children: [
          _changeUserCard(),
          const SizedBox(height: 12),
          _headerCard(),
          const SizedBox(height: 12),
          _voiceCard(),
          const SizedBox(height: 12),
          _accountCard(),
          const SizedBox(height: 12),
          _ttsControlsCard(),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valueText;
  final Widget child;

  const _SliderRow({
    required this.icon,
    required this.label,
    required this.valueText,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardStroke),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.brandBrown, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Text(
                valueText,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandBrown,
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}