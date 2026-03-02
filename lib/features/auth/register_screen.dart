import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/loading_overlay.dart';
import '../../core/tts/tts_service.dart';
import 'auth_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool loading = false;

  @override
  void initState() {
    super.initState();
    context.read<TtsService>().speak("Màn hình đăng ký. Nhập email và mật khẩu.");
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(title: const Text("Đăng ký")),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(controller: _email, decoration: const InputDecoration(labelText: "Email")),
                const SizedBox(height: 12),
                TextField(controller: _pass, decoration: const InputDecoration(labelText: "Mật khẩu (>=6)"), obscureText: true),
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
                        await auth.register(_email.text.trim(), _pass.text);
                        if (mounted) Navigator.pop(context); // back to login
                        if (mounted) Navigator.pop(context); // back to home
                      } catch (e) {
                        context.read<TtsService>().speak("Đăng ký thất bại.");
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
                      } finally {
                        if (mounted) setState(() => loading = false);
                      }
                    },
                    child: const Text("Đăng ký"),
                  ),
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