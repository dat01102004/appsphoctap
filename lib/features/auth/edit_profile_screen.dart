import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/error_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../core/tts/tts_service.dart';
import '../../core/widgets/hold_to_listen_layer.dart';
import '../voice/voice_controller.dart';
import 'auth_controller.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameCtl;
  late final TextEditingController _emailCtl;
  late final TextEditingController _phoneCtl;

  int _listenEpoch = 0;
  String _lastPromptNorm = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _fullNameCtl = TextEditingController(text: auth.fullName ?? '');
    _emailCtl = TextEditingController(text: auth.email ?? '');
    _phoneCtl = TextEditingController(text: auth.phone ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _announce();
    });
  }

  @override
  void dispose() {
    _listenEpoch++;
    _fullNameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    context.read<VoiceController>().stop();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    _lastPromptNorm = _norm(text);
    final tts = context.read<TtsService>();
    final voice = context.read<VoiceController>();
    await voice.stop();
    await tts.stop();
    await tts.speak(text);
  }

  Future<void> _announce() async {
    await _speak(
      'Màn hình thay đổi người dùng. '
      'Bạn có thể sửa họ tên, email và số điện thoại. '
      'Có thể nhập bằng tay hoặc giữ màn hình hai giây để nói lệnh. '
      'Ví dụ: họ tên Nguyễn Văn A, email abc a còng gmail chấm com, '
      'số điện thoại 0 9 0 1 2 3 4 5 6 7, hoặc nói lưu thay đổi.',
    );
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

    if (n.contains('nhac lai') ||
        n.contains('doc lai') ||
        n.contains('huong dan') ||
        n.contains('tro giup')) {
      await _announce();
      return;
    }

    if (n.contains('quay lai') ||
        n.contains('tro lai') ||
        n.contains('huy') ||
        n == 'thoat') {
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    if (n.contains('doc thong tin') ||
        n.contains('xem thong tin') ||
        n.contains('nhac thong tin')) {
      await _speak(
        'Họ tên hiện tại là ${_fullNameCtl.text.trim().isEmpty ? "chưa có" : _fullNameCtl.text.trim()}. '
        'Email hiện tại là ${_emailCtl.text.trim().isEmpty ? "chưa có" : _emailCtl.text.trim()}. '
        'Số điện thoại hiện tại là ${_phoneCtl.text.trim().isEmpty ? "chưa có" : _phoneCtl.text.trim()}.',
      );
      return;
    }

    if (n.contains('luu') || n.contains('cap nhat') || n.contains('xac nhan')) {
      await _submit();
      return;
    }

    final nameValue = _extractVoiceValue(
      raw,
      patterns: const [r'^(họ tên|ho ten)\s+', r'^(tên|ten)\s+'],
    );
    if (nameValue != null && nameValue.trim().isNotEmpty) {
      _fullNameCtl.text = _normalizeHumanName(nameValue);
      setState(() {});
      await _speak('Đã cập nhật họ tên.');
      return;
    }

    final emailValue = _extractVoiceValue(
      raw,
      patterns: const [r'^(email|e mail)\s+', r'^(gmail)\s+'],
    );
    if (emailValue != null && emailValue.trim().isNotEmpty) {
      _emailCtl.text = _normalizeSpokenEmail(emailValue);
      setState(() {});
      await _speak('Đã cập nhật email.');
      return;
    }

    final phoneValue = _extractVoiceValue(
      raw,
      patterns: const [
        r'^(số điện thoại|so dien thoai)\s+',
        r'^(điện thoại|dien thoai)\s+',
        r'^(số máy|so may)\s+',
        r'^(số|so)\s+',
      ],
    );
    if (phoneValue != null && phoneValue.trim().isNotEmpty) {
      _phoneCtl.text = _normalizeSpokenPhone(phoneValue);
      setState(() {});
      await _speak('Đã cập nhật số điện thoại.');
      return;
    }

    await _speak(
      'Mình chưa hiểu lệnh. '
      'Bạn có thể nói: họ tên Nguyễn Văn A, email abc a còng gmail chấm com, '
      'số điện thoại 0 9 0 1 2 3 4 5 6 7, lưu thay đổi hoặc quay lại.',
    );
  }

  String? _extractVoiceValue(String raw, {required List<String> patterns}) {
    final value = raw.trim();
    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false, unicode: true);
      final match = regex.firstMatch(value);
      if (match != null) {
        final result = value.substring(match.end).trim();
        if (result.isNotEmpty) return result;
      }
    }
    return null;
  }

  String _normalizeHumanName(String input) {
    final raw = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (raw.isEmpty) return raw;

    return raw
        .split(' ')
        .map((part) {
          if (part.isEmpty) return part;
          return part[0].toUpperCase() + part.substring(1);
        })
        .join(' ');
  }

  String _normalizeSpokenEmail(String input) {
    var value = input.toLowerCase().trim();

    value = value
        .replaceAll(' a còng ', '@')
        .replaceAll(' a cong ', '@')
        .replaceAll(' at ', '@')
        .replaceAll(' chấm ', '.')
        .replaceAll(' cham ', '.')
        .replaceAll(' dot ', '.')
        .replaceAll(' gạch dưới ', '_')
        .replaceAll(' gach duoi ', '_')
        .replaceAll(' gạch ngang ', '-')
        .replaceAll(' gach ngang ', '-');

    value = value.replaceAll(' ', '');
    return value;
  }

  String _normalizeSpokenPhone(String input) {
    final normalized = _norm(input);
    final parts = normalized.split(' ');

    const map = {
      'khong': '0',
      'linh': '0',
      'mot': '1',
      'một': '1',
      'hai': '2',
      'ba': '3',
      'bon': '4',
      'bốn': '4',
      'tu': '4',
      'tư': '4',
      'nam': '5',
      'năm': '5',
      'lam': '5',
      'lăm': '5',
      'sau': '6',
      'sáu': '6',
      'bay': '7',
      'bảy': '7',
      'tam': '8',
      'tám': '8',
      'chin': '9',
      'chín': '9',
    };

    final buf = StringBuffer();
    for (final part in parts) {
      if (part.isEmpty) continue;
      if (RegExp(r'^\d+$').hasMatch(part)) {
        buf.write(part);
        continue;
      }
      final mapped = map[part];
      if (mapped != null) {
        buf.write(mapped);
      }
    }
    return buf.toString();
  }

  Future<void> _submit() async {
    if (_saving) return;

    final fullName = _fullNameCtl.text.trim();
    final email = _emailCtl.text.trim().toLowerCase();
    final phone = _phoneCtl.text.trim();

    if (!_formKey.currentState!.validate()) {
      await _speak('Thông tin chưa hợp lệ. Hãy kiểm tra lại.');
      return;
    }

    setState(() => _saving = true);

    try {
      await context.read<AuthController>().updateProfile(
        fullName: fullName,
        email: email,
        phone: phone,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      final message = _errorText(e);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      if (e is! AuthFriendlyException) {
        await _speak(message);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _errorText(Object error) {
    if (error is AuthFriendlyException) {
      return error.message;
    }
    return friendlyApiMessage(error, feature: 'auth');
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

    s = s.replaceAll(RegExp(r'[^a-z0-9\s\.,@_-]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceController>();

    return HoldToListenLayer(
      holdDuration: const Duration(seconds: 2),
      onTriggered: _startVoice,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F0E7),
        appBar: AppBar(
          backgroundColor: AppColors.brandBrown,
          foregroundColor: Colors.white,
          title: const Text(
            'Thay đổi người dùng',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.bgBeige,
                            borderRadius: BorderRadius.circular(14),
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
                                    ? 'Đang nghe chỉnh sửa hồ sơ'
                                    : 'Điều chỉnh bằng giọng nói',
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
                                    : 'Giữ màn hình 2 giây rồi nói: họ tên..., email..., số điện thoại..., lưu thay đổi.',
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
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thông tin người dùng',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sửa thông tin rồi nhấn lưu. Có thể nhập tay hoặc dùng giọng nói.',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: AppColors.muted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _ProfileField(
                            controller: _fullNameCtl,
                            label: 'Họ và tên',
                            hint: 'Nhập họ và tên',
                            icon: Icons.badge_outlined,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return 'Vui lòng nhập họ và tên';
                              }
                              if (text.length < 2) {
                                return 'Họ tên quá ngắn';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _ProfileField(
                            controller: _emailCtl,
                            label: 'Email',
                            hint: 'Nhập email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              final text = (value ?? '').trim().toLowerCase();
                              if (text.isEmpty) {
                                return 'Vui lòng nhập email';
                              }
                              final ok = RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(text);
                              if (!ok) {
                                return 'Email chưa đúng định dạng';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _ProfileField(
                            controller: _phoneCtl,
                            label: 'Số điện thoại',
                            hint: 'Nhập số điện thoại',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            validator: (value) {
                              final text = (value ?? '').trim();
                              if (text.isEmpty) {
                                return 'Vui lòng nhập số điện thoại';
                              }
                              final digits = text.replaceAll(RegExp(r'\D'), '');
                              if (digits.length < 8 || digits.length > 15) {
                                return 'Số điện thoại chưa hợp lệ';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: _saving ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.brandBrown,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    icon: _saving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.save_outlined),
                                    label: Text(
                                      _saving ? 'Đang lưu...' : 'Lưu thay đổi',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SizedBox(
                                  height: 50,
                                  child: OutlinedButton.icon(
                                    onPressed: _saving
                                        ? null
                                        : () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.brandBrown,
                                      side: const BorderSide(
                                        color: AppColors.cardStroke,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    icon: const Icon(Icons.close_rounded),
                                    label: const Text(
                                      'Hủy',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  const _ProfileField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.brandBrown),
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.3),
            ),
          ),
        ),
      ],
    );
  }
}
