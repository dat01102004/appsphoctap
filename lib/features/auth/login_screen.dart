import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/tts/tts_service.dart';
import '../../core/widgets/hold_to_listen_layer.dart';
import '../../widgets/loading_overlay.dart';
import '../voice/voice_controller.dart';
import 'auth_controller.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();

  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();

  bool loading = false;
  bool _hidePassword = true;

  int _listenEpoch = 0;
  String _lastPromptNorm = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _announceIntro();
    });
  }

  @override
  void dispose() {
    _listenEpoch++;
    _email.dispose();
    _pass.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    context.read<VoiceController>().stop();
    super.dispose();
  }

  Future<void> _announceIntro() async {
    await _speak(
      'Màn hình đăng nhập. '
          'Bạn có thể chạm vào ô email hoặc mật khẩu để nhập tay. '
          'Bạn cũng có thể dùng giọng nói. '
          'Ví dụ: nói email dat a còng gmail chấm com, '
          'mật khẩu một hai ba bốn năm sáu, '
          'hoặc nói đăng nhập.',
    );
  }

  Future<void> _speak(String text) async {
    _lastPromptNorm = _norm(text);
    final tts = context.read<TtsService>();
    final voice = context.read<VoiceController>();
    await voice.stop();
    await tts.stop();
    await tts.speak(text);
  }

  Future<void> _startVoice() async {
    if (loading) return;
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
        if (normalized.isEmpty || _isPromptEcho(normalized)) {
          return;
        }

        await _handleVoiceCommand(text);
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

  Future<void> _handleVoiceCommand(String raw) async {
    final n = _norm(raw);

    if (n.contains('nhac lai') ||
        n.contains('doc lai') ||
        n.contains('huong dan') ||
        n.contains('tro giup')) {
      await _announceIntro();
      return;
    }

    if (n == 'quay lai' || n == 'tro lai' || n == 'thoat') {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (n.contains('mo dang ky') ||
        n.contains('sang dang ky') ||
        n.contains('tao tai khoan') ||
        n == 'dang ky') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RegisterScreen()),
      );
      return;
    }

    if (n.contains('xoa email')) {
      _email.clear();
      setState(() {});
      await _speak('Đã xóa email.');
      return;
    }

    if (n.contains('xoa mat khau')) {
      _pass.clear();
      setState(() {});
      await _speak('Đã xóa mật khẩu.');
      return;
    }

    if (n.contains('doc email')) {
      final value = _email.text.trim().isEmpty ? 'Email đang trống.' : 'Email hiện tại là ${_email.text.trim()}.';
      await _speak(value);
      return;
    }

    if (n.contains('doc mat khau')) {
      final value = _pass.text.trim().isEmpty
          ? 'Mật khẩu đang trống.'
          : 'Mật khẩu hiện có ${_pass.text.trim().length} ký tự.';
      await _speak(value);
      return;
    }

    final emailText = _extractByPrefixes(raw, const [
      'email',
      'thư điện tử',
      'thu dien tu',
      'nhập email',
      'dien email',
    ]);
    if (emailText != null && emailText.trim().isNotEmpty) {
      _email.text = _normalizeSpokenEmail(emailText);
      _emailFocus.requestFocus();
      setState(() {});
      await _speak('Đã điền email ${_email.text}.');
      return;
    }

    final passText = _extractByPrefixes(raw, const [
      'mật khẩu',
      'mat khau',
      'password',
      'nhập mật khẩu',
      'dien mat khau',
    ]);
    if (passText != null && passText.trim().isNotEmpty) {
      _pass.text = _normalizeSpokenPassword(passText);
      _passFocus.requestFocus();
      setState(() {});
      await _speak('Đã điền mật khẩu.');
      return;
    }

    if (n.contains('chon email') || n.contains('o email')) {
      _emailFocus.requestFocus();
      await _speak('Ô email đang được chọn. Bạn có thể nhập tay hoặc nói email cộng nội dung.');
      return;
    }

    if (n.contains('chon mat khau') || n.contains('o mat khau')) {
      _passFocus.requestFocus();
      await _speak('Ô mật khẩu đang được chọn. Bạn có thể nhập tay hoặc nói mật khẩu cộng nội dung.');
      return;
    }

    if (n.contains('dang nhap') || n == 'vao') {
      await _submit();
      return;
    }

    await _speak(
      'Mình chưa hiểu lệnh. '
          'Bạn có thể nói email cộng nội dung, '
          'mật khẩu cộng nội dung, đăng nhập, mở đăng ký, xóa email hoặc xóa mật khẩu.',
    );
  }

  String? _extractByPrefixes(String raw, List<String> prefixes) {
    final original = raw.trim();
    final lower = original.toLowerCase().trim();

    for (final prefix in prefixes) {
      if (lower.startsWith(prefix)) {
        return original.substring(prefix.length).trim();
      }
    }
    return null;
  }

  String _normalizeSpokenEmail(String raw) {
    String text = raw.toLowerCase().trim();

    final replacements = <String, String>{
      ' a còng ': '@',
      ' a cong ': '@',
      'acong': '@',
      ' còng ': '@',
      ' cong ': '@',
      ' a móc ': '@',
      ' a moc ': '@',
      ' chấm ': '.',
      ' cham ': '.',
      ' chấmcom ': '.com',
      ' chấm com ': '.com',
      ' cham com ': '.com',
      ' chấm nét ': '.net',
      ' cham net ': '.net',
      ' chấm vê en ': '.vn',
      ' cham vn ': '.vn',
      ' gờ meo ': 'gmail',
      ' go meo ': 'gmail',
      ' gi meo ': 'gmail',
      ' gmail ': 'gmail',
      ' i meo ': 'email',
      ' ích xì ': 'x',
      ' ích ': 'x',
      ' gạch dưới ': '_',
      ' gach duoi ': '_',
      ' gạch ngang ': '-',
      ' gach ngang ': '-',
    };

    text = ' $text ';
    replacements.forEach((k, v) {
      text = text.replaceAll(k, v);
    });

    text = text.replaceAll(' ', '');
    return text.trim();
  }

  String _normalizeSpokenPassword(String raw) {
    String text = raw.trim().toLowerCase();

    final map = <String, String>{
      'không': '0',
      'khong': '0',
      'một': '1',
      'mot': '1',
      'hai': '2',
      'ba': '3',
      'bốn': '4',
      'bon': '4',
      'tư': '4',
      'tu': '4',
      'năm': '5',
      'nam': '5',
      'lăm': '5',
      'lam': '5',
      'sáu': '6',
      'sau': '6',
      'bảy': '7',
      'bay': '7',
      'tám': '8',
      'tam': '8',
      'chín': '9',
      'chin': '9',
    };

    map.forEach((k, v) {
      text = text.replaceAll(RegExp('\\b$k\\b'), v);
    });

    text = text.replaceAll(' ', '');
    return text;
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

    s = s.replaceAll(RegExp(r'[^a-z0-9@\.\s_]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  Future<void> _submit() async {
    if (loading) return;

    final email = _email.text.trim();
    final pass = _pass.text;

    if (email.isEmpty) {
      _emailFocus.requestFocus();
      await _speak('Bạn chưa nhập email.');
      return;
    }

    if (pass.isEmpty) {
      _passFocus.requestFocus();
      await _speak('Bạn chưa nhập mật khẩu.');
      return;
    }

    setState(() => loading = true);

    try {
      await context.read<AuthController>().login(email, pass);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      await _speak('Đăng nhập thất bại. Vui lòng kiểm tra lại email hoặc mật khẩu.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Widget _fieldCard({
    required String title,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required bool obscure,
    VoidCallback? trailingTap,
    Widget? trailing,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    String? helper,
    VoidCallback? onTapCard,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTapCard,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                  if (trailing != null) trailing,
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                focusNode: focusNode,
                obscureText: obscure,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                onSubmitted: onSubmitted,
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.cardStroke),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.cardStroke),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.brandBrown,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              if (helper != null) ...[
                const SizedBox(height: 10),
                Text(
                  helper,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _voiceCard() {
    final voice = context.watch<VoiceController>();
    final listeningText = voice.isListening
        ? (voice.lastWords.trim().isEmpty ? 'Đang nghe...' : voice.lastWords.trim())
        : 'Nhấn mic hoặc giữ màn hình 2 giây để nói';

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
                    voice.isListening ? 'Đang nghe lệnh đăng nhập' : 'Điều khiển bằng giọng nói',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    listeningText,
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

  @override
  Widget build(BuildContext context) {
    return HoldToListenLayer(
      enabled: !loading,
      onTriggered: _startVoice,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đăng nhập'),
          actions: [
            IconButton(
              tooltip: 'Bật mic',
              onPressed: _startVoice,
              icon: const Icon(Icons.mic_none_rounded),
            ),
          ],
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Chào mừng quay lại',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Bạn có thể nhập tay hoặc dùng giọng nói để điền email, mật khẩu rồi nói “đăng nhập”.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.muted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _voiceCard(),
                const SizedBox(height: 12),
                _fieldCard(
                  title: 'Email',
                  hint: 'example@gmail.com',
                  controller: _email,
                  focusNode: _emailFocus,
                  icon: Icons.alternate_email_rounded,
                  obscure: false,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _passFocus.requestFocus(),
                  helper: 'Mẹo voice: nói “email dat a còng gmail chấm com”.',
                  onTapCard: () async {
                    _emailFocus.requestFocus();
                    await _speak('Ô email đang được chọn.');
                  },
                ),
                const SizedBox(height: 12),
                _fieldCard(
                  title: 'Mật khẩu',
                  hint: 'Nhập mật khẩu',
                  controller: _pass,
                  focusNode: _passFocus,
                  icon: Icons.lock_outline_rounded,
                  obscure: _hidePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  helper: 'Mẹo voice: nói “mật khẩu một hai ba bốn năm sáu”.',
                  trailing: IconButton(
                    onPressed: () {
                      setState(() => _hidePassword = !_hidePassword);
                    },
                    icon: Icon(
                      _hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.brandBrown,
                    ),
                  ),
                  onTapCard: () async {
                    _passFocus.requestFocus();
                    await _speak('Ô mật khẩu đang được chọn.');
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandBrown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: loading ? null : _submit,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text(
                      'Đăng nhập',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Chưa có tài khoản?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                            );
                          },
                          child: const Text('Đăng ký'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            LoadingOverlay(show: loading, text: 'Đang đăng nhập...'),
          ],
        ),
      ),
    );
  }
}