import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/tts/tts_service.dart';
import '../../../core/widgets/hold_to_listen_layer.dart';
import '../../auth/auth_controller.dart';
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
      _announceByState();
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

      setState(() {
        _voices = filtered.isNotEmpty ? filtered : raw;
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
    final loggedIn = context.read<AuthController>().loggedIn;
    final mode = loggedIn ? 'logged_in' : 'guest';
    if (_lastAnnounceMode == mode) return;
    _lastAnnounceMode = mode;

    if (loggedIn) {
      await _speak(
        'Màn hình cài đặt. '
            'Bạn có thể điều chỉnh tốc độ đọc, độ cao giọng, chọn giọng đọc, '
            'nghe thử, đăng xuất hoặc đăng nhập lại.',
      );
    } else {
      await _speak(
        'Màn hình cài đặt. '
            'Bạn đang ở chế độ khách. '
            'Bạn có thể đăng nhập, đăng ký, điều chỉnh giọng đọc và nghe thử.',
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

    if (n.contains('nghe thu') || n.contains('doc thu') || n.contains('test giong')) {
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
      return;
    }

    if (n.contains('dang ky') || n.contains('tao tai khoan')) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RegisterScreen()),
      );
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
      await _setPitch(0.9, speakBack: true);
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
        (n.contains('chon giong') || n.contains('giong so') || n.contains('voice'))) {
      await _setVoiceByIndex(voiceIndex - 1);
      return;
    }

    await _speak(
      'Mình chưa hiểu lệnh. '
          'Bạn có thể nói nghe thử, tốc độ nhanh, tốc độ chậm, giọng cao, giọng thấp, '
          'chọn giọng 1, đăng nhập, đăng ký hoặc đăng xuất.',
    );
  }
  String _displayVoiceName(Map<dynamic, dynamic> voice, int index) {
    final rawName = (voice['name'] ?? '').toString().toLowerCase();
    final locale = (voice['locale'] ?? '').toString();

    const manualMap = <String, String>{
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

    const map = <String, int>{
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
        : 'Nhấn mic hoặc giữ màn hình 2 giây để điều khiển cài đặt';

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
                    voice.isListening ? 'Đang nghe lệnh cài đặt' : 'Điều khiển bằng giọng nói',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: voice.isListening ? 'Dừng nghe' : 'Bắt đầu nghe',
              onPressed: () async {
                if (voice.isListening) {
                  _listenEpoch++;
                  await voice.stop();
                } else {
                  await _startVoice();
                }
              },
              icon: Icon(
                voice.isListening ? Icons.stop_circle_outlined : Icons.play_circle_outline,
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
                  child: Text(
                    auth.loggedIn
                        ? (auth.email ?? 'Đã đăng nhập')
                        : 'Guest mode',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (auth.loggedIn)
              SizedBox(
                width: double.infinity,
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
              )
            else
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
                      height: 50,
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
            const SizedBox(height: 16),
            _sliderTile(
              title: 'Tốc độ đọc',
              valueText: tts.rate.toStringAsFixed(2),
              value: tts.rate,
              min: 0.20,
              max: 0.80,
              divisions: 12,
              icon: Icons.speed_rounded,
              onChanged: (v) async {
                await tts.setRate(v);
                if (!mounted) return;
                setState(() {});
              },
              onTapHeader: () async {
                await _speak(
                  'Thiết lập tốc độ đọc. Hiện tại là ${tts.rate.toStringAsFixed(2)}. '
                      'Bạn có thể nói tốc độ chậm, tốc độ nhanh hoặc kéo thanh trượt.',
                );
              },
            ),
            const SizedBox(height: 12),
            _sliderTile(
              title: 'Độ cao giọng',
              valueText: tts.pitch.toStringAsFixed(2),
              value: tts.pitch,
              min: 0.70,
              max: 1.50,
              divisions: 16,
              icon: Icons.tune_rounded,
              onChanged: (v) async {
                await tts.setPitch(v);
                if (!mounted) return;
                setState(() {});
              },
              onTapHeader: () async {
                await _speak(
                  'Thiết lập độ cao giọng. Hiện tại là ${tts.pitch.toStringAsFixed(2)}. '
                      'Bạn có thể nói giọng cao, giọng thấp hoặc kéo thanh trượt.',
                );
              },
            ),
            const SizedBox(height: 16),
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

  Widget _sliderTile({
    required String title,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required IconData icon,
    required Future<void> Function(double) onChanged,
    required Future<void> Function() onTapHeader,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardStroke),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTapHeader,
            child: Row(
              children: [
                Icon(icon, color: AppColors.brandBrown),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Text(
                  valueText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandBrown,
                  ),
                ),
              ],
            ),
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppColors.brandBrown,
            inactiveColor: AppColors.cardStroke,
            onChanged: (v) async {
              await onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _voiceListCard() {
    final tts = context.watch<TtsService>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chọn giọng đọc',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bạn có thể chạm để chọn hoặc nói “chọn giọng 1”, “chọn giọng 2”.',
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingVoices)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_voices.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardStroke),
                ),
                child: const Text(
                  'Chưa lấy được danh sách giọng đọc từ thiết bị.',
                  style: TextStyle(
                    color: AppColors.muted,
                    height: 1.5,
                  ),
                ),
              )
            else
              ...List.generate(_voices.length.clamp(0, 8), (index) {
                final voice = _voices[index];
                final rawName = (voice['name'] ?? 'Voice ${index + 1}').toString();
                final displayName = _displayVoiceName(voice, index);
                final locale = (voice['locale'] ?? '').toString();
                final selected = tts.voiceName == rawName;

                return Padding(
                  padding: EdgeInsets.only(bottom: index == _voices.length - 1 ? 0 : 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      await context.read<TtsService>().setVoice(voice);
                      if (!mounted) return;
                      setState(() {});
                      await _speak('Đã chọn $displayName');
                    },
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.bgBeige : AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected ? AppColors.brandBrown : AppColors.cardStroke,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppColors.brandBrown,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                if (locale.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    locale,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.brandBrown,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _quickHelpCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Lệnh giọng nói gợi ý',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 12),
            _HelpLine('“Nghe thử”'),
            _HelpLine('“Tốc độ nhanh” / “Tốc độ chậm”'),
            _HelpLine('“Giọng cao” / “Giọng thấp”'),
            _HelpLine('“Chọn giọng 1”'),
            _HelpLine('“Đăng nhập” / “Đăng ký” / “Đăng xuất”'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthController>();

    return HoldToListenLayer(
      onTriggered: _startVoice,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _headerCard(),
          const SizedBox(height: 12),
          _voiceCard(),
          const SizedBox(height: 12),
          _accountCard(),
          const SizedBox(height: 12),
          _ttsControlsCard(),
          const SizedBox(height: 12),
          _voiceListCard(),
          const SizedBox(height: 12),
          _quickHelpCard(),
        ],
      ),
    );
  }
}

class _HelpLine extends StatelessWidget {
  final String text;
  const _HelpLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(
              Icons.mic_none_rounded,
              size: 16,
              color: AppColors.brandBrown,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}