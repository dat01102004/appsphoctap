import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/loading_overlay.dart';
import '../../core/tts/tts_service.dart';
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
  bool loading = false;

  @override
  void initState() {
    super.initState();
    context.read<TtsService>().speak("Màn hình đăng nhập. Nhập email và mật khẩu.");
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(title: const Text("Đăng nhập")),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(controller: _email, decoration: const InputDecoration(labelText: "Email")),
                const SizedBox(height: 12),
                TextField(controller: _pass, decoration: const InputDecoration(labelText: "Mật khẩu"), obscureText: true),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: loading
                        ? null
                        : () async {
                      setState(() => loading = true);
                      try {
                        await auth.login(_email.text.trim(), _pass.text);
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        context.read<TtsService>().speak("Đăng nhập thất bại.");
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
                      } finally {
                        if (mounted) setState(() => loading = false);
                      }
                    },
                    child: const Text("Đăng nhập"),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: const Text("Chưa có tài khoản? Đăng ký"),
                ),
              ],
            ),
          ),
          LoadingOverlay(show: loading),
        ],
      ),
    );
  }
}