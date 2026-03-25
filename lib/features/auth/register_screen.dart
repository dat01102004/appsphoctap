import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/tts/tts_service.dart';
import '../../core/widgets/hold_to_listen_layer.dart';
import '../../widgets/loading_overlay.dart';
import '../voice/voice_controller.dart';
import 'auth_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();

  final _fullNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passFocus = FocusNode();

  bool loading = false;
  bool _hidePassword = true;
  int _listenEpoch = 0;
  String _lastPromptNorm = '';
  String? _errorText;

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
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    _fullNameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passFocus.dispose();
    context.read<VoiceController>().stop();
    super.dispose();
  }

  Future<void> _announceIntro() async {
    await _speak(
      'Màn hình đăng ký. '
          'Bạn cần nhập họ và tên, email, số điện thoại và mật khẩu. '
          'Bạn cũng có thể dùng giọng nói. '
          'Ví dụ: họ tên Nguyễn Văn A, email người dùng a còng gmail chấm com, '
          'số điện thoại 0 9 1 2 3 4 5 6 7 8, mật khẩu người dùng một hai ba, sau đó nói đăng ký.',
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
        if (normalized.isEmpty || _isPromptEcho(normalized)) return;
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

    if (n.contains('dang nhap') ||
        n.contains('mo dang nhap') ||
        n.contains('sang dang nhap')) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (n.contains('xoa ho ten')) {
      _fullName.clear();
      setState(() => _errorText = null);
      await _speak('Đã xóa họ và tên.');
      return;
    }

    if (n.contains('xoa email')) {
      _email.clear();
      setState(() => _errorText = null);
      await _speak('Đã xóa email.');
      return;
    }

    if (n.contains('xoa so dien thoai')) {
      _phone.clear();
      setState(() => _errorText = null);
      await _speak('Đã xóa số điện thoại.');
      return;
    }

    if (n.contains('xoa mat khau')) {
      _pass.clear();
      setState(() => _errorText = null);
      await _speak('Đã xóa mật khẩu.');
      return;
    }

    final fullNameText = _extractByPrefixes(raw, const [
      'họ tên',
      'ho ten',
      'tên',
      'ten',
      'họ và tên',
      'ho va ten',
      'nhập họ tên',
    ]);
    if (fullNameText != null && fullNameText.trim().isNotEmpty) {
      _fullName.text = _normalizeFullName(fullNameText);
      _fullNameFocus.requestFocus();
      setState(() => _errorText = null);
      await _speak('Đã điền họ và tên ${_fullName.text}.');
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
      setState(() => _errorText = null);
      await _speak('Đã điền email ${_email.text}.');
      return;
    }

    final phoneText = _extractByPrefixes(raw, const [
      'so dien thoai',
      'số điện thoại',
      'dien thoai',
      'nhập số điện thoại',
    ]);
    if (phoneText != null && phoneText.trim().isNotEmpty) {
      _phone.text = _normalizePhone(phoneText);
      _phoneFocus.requestFocus();
      setState(() => _errorText = null);
      await _speak('Đã điền số điện thoại ${_phone.text}.');
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
      setState(() => _errorText = null);
      await _speak('Đã điền mật khẩu.');
      return;
    }

    if (n.contains('chon ho ten') || n.contains('o ho ten')) {
      _fullNameFocus.requestFocus();
      await _speak('Ô họ và tên đang được chọn.');
      return;
    }

    if (n.contains('chon email') || n.contains('o email')) {
      _emailFocus.requestFocus();
      await _speak('Ô email đang được chọn.');
      return;
    }

    if (n.contains('chon so dien thoai') || n.contains('o so dien thoai')) {
      _phoneFocus.requestFocus();
      await _speak('Ô số điện thoại đang được chọn.');
      return;
    }

    if (n.contains('chon mat khau') || n.contains('o mat khau')) {
      _passFocus.requestFocus();
      await _speak('Ô mật khẩu đang được chọn.');
      return;
    }

    if (n.contains('dang ky') || n.contains('tao tai khoan')) {
      await _submit();
      return;
    }

    await _speak(
      'Mình chưa hiểu lệnh. '
          'Bạn có thể nói họ tên cộng nội dung, email cộng nội dung, số điện thoại cộng nội dung, mật khẩu cộng nội dung hoặc đăng ký.',
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

  String _stripVietnamese(String input) {
    var s = input.toLowerCase().trim();
    const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩ'
        'òóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiii'
        'ooooooooooooooooouuuuuuuuuuuyyyyyd';

    for (int i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    return s;
  }

  String _normalizeFullName(String raw) {
    return raw
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(' ')
        .map((e) {
      if (e.isEmpty) return e;
      final lower = e.toLowerCase();
      return lower[0].toUpperCase() + lower.substring(1);
    })
        .join(' ');
  }

  String _normalizeSpokenEmail(String raw) {
    String text = _stripVietnamese(raw);

    final replacements = <String, String>{
      ' a cong ': '@',
      'acong': '@',
      ' cong ': '@',
      ' a moc ': '@',
      ' cham ': '.',
      ' chamcom ': '.com',
      ' cham com ': '.com',
      ' cham net ': '.net',
      ' cham vn ': '.vn',
      ' go meo ': 'gmail',
      ' gi meo ': 'gmail',
      ' gach duoi ': '_',
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
    String text = _stripVietnamese(raw);

    final map = <String, String>{
      'khong': '0',
      'mot': '1',
      'hai': '2',
      'ba': '3',
      'bon': '4',
      'tu': '4',
      'nam': '5',
      'lam': '5',
      'sau': '6',
      'bay': '7',
      'tam': '8',
      'chin': '9',
      ' gach ngang ': '-',
      ' gach duoi ': '_',
      ' cham ': '.',
      ' a cong ': '@',
    };

    text = ' $text ';
    map.forEach((k, v) {
      text = text.replaceAll(k, v);
    });

    text = text.replaceAll(' ', '');
    return text.trim();
  }

  String _normalizePhone(String raw) {
    var s = _stripVietnamese(raw);
    final map = <String, String>{
      'khong': '0',
      'mot': '1',
      'hai': '2',
      'ba': '3',
      'bon': '4',
      'tu': '4',
      'nam': '5',
      'lam': '5',
      'sau': '6',
      'bay': '7',
      'tam': '8',
      'chin': '9',
    };

    s = ' $s ';
    map.forEach((k, v) {
      s = s.replaceAll(RegExp('\\b$k\\b'), v);
    });

    return s.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _friendlyRegisterError(Object error) {
    if (error is ApiException) {
      final msg = error.friendlyMessage().toLowerCase();
      if (msg.contains('email đã tồn tại') || msg.contains('email da ton tai')) {
        return 'Email này đã được đăng ký.';
      }
      if (msg.contains('số điện thoại đã tồn tại') ||
          msg.contains('so dien thoai da ton tai')) {
        return 'Số điện thoại này đã được đăng ký.';
      }
      return error.friendlyMessage();
    }
    return 'Đăng ký thất bại. Vui lòng thử lại.';
  }

  String _norm(String input) {
    var s = _stripVietnamese(input);
    s = s.replaceAll(RegExp(r'[^a-z0-9@\.\s_]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  Future<void> _submit() async {
    if (loading) return;

    final fullName = _normalizeFullName(_fullName.text);
    final email = _normalizeSpokenEmail(_email.text);
    final phone = _normalizePhone(_phone.text);
    final pass = _normalizeSpokenPassword(_pass.text);

    _fullName.text = fullName;
    _email.text = email;
    _phone.text = phone;
    _pass.text = pass;

    if (fullName.isEmpty) {
      _fullNameFocus.requestFocus();
      setState(() => _errorText = 'Bạn chưa nhập họ và tên.');
      await _speak('Bạn chưa nhập họ và tên.');
      return;
    }

    if (email.isEmpty) {
      _emailFocus.requestFocus();
      setState(() => _errorText = 'Bạn chưa nhập email.');
      await _speak('Bạn chưa nhập email.');
      return;
    }

    if (phone.isEmpty) {
      _phoneFocus.requestFocus();
      setState(() => _errorText = 'Bạn chưa nhập số điện thoại.');
      await _speak('Bạn chưa nhập số điện thoại.');
      return;
    }

    if (pass.isEmpty) {
      _passFocus.requestFocus();
      setState(() => _errorText = 'Bạn chưa nhập mật khẩu.');
      await _speak('Bạn chưa nhập mật khẩu.');
      return;
    }

    if (pass.length < 6) {
      _passFocus.requestFocus();
      setState(() => _errorText = 'Mật khẩu cần có ít nhất 6 ký tự.');
      await _speak('Mật khẩu cần có ít nhất 6 ký tự.');
      return;
    }

    setState(() {
      loading = true;
      _errorText = null;
    });

    try {
      await context.read<AuthController>().register(
        fullName: fullName,
        email: email,
        phone: phone,
        password: pass,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      final message = _friendlyRegisterError(e);
      if (!mounted) return;
      setState(() => _errorText = message);
      await _speak(message);
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
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    String? helper,
    Widget? trailing,
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
                    voice.isListening ? 'Đang nghe lệnh đăng ký' : 'Điều khiển bằng giọng nói',
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
          title: const Text('Đăng ký'),
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
                          'Tạo tài khoản mới',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Nhập họ và tên, email, số điện thoại và mật khẩu để bắt đầu lưu lịch sử sử dụng.',
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
                  title: 'Họ và tên',
                  hint: 'Nguyễn Văn A',
                  controller: _fullName,
                  focusNode: _fullNameFocus,
                  icon: Icons.person_outline_rounded,
                  obscure: false,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _emailFocus.requestFocus(),
                  helper: 'Mẹo voice: nói “họ tên Nguyễn Văn A”.',
                  onTapCard: () async {
                    _fullNameFocus.requestFocus();
                    await _speak('Ô họ và tên đang được chọn.');
                  },
                ),
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
                  onSubmitted: (_) => _phoneFocus.requestFocus(),
                  helper: 'Mẹo voice: nói “email người dùng a còng gmail chấm com”.',
                  onTapCard: () async {
                    _emailFocus.requestFocus();
                    await _speak('Ô email đang được chọn.');
                  },
                ),
                const SizedBox(height: 12),
                _fieldCard(
                  title: 'Số điện thoại',
                  hint: '0912345678',
                  controller: _phone,
                  focusNode: _phoneFocus,
                  icon: Icons.phone_outlined,
                  obscure: false,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _passFocus.requestFocus(),
                  helper: 'Mẹo voice: nói “số điện thoại 0 9 1 2 3 4 5 6 7 8”.',
                  onTapCard: () async {
                    _phoneFocus.requestFocus();
                    await _speak('Ô số điện thoại đang được chọn.');
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
                  helper: 'Mẹo voice: nói “mật khẩu người dùng một hai ba”.',
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
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFFFFF4F4),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorText!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text(
                      'Đăng ký',
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
                            'Đã có tài khoản?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Quay lại đăng nhập'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            LoadingOverlay(show: loading, text: 'Đang đăng ký...'),
          ],
        ),
      ),
    );
  }
}