import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/tts/tts_service.dart';
import '../voice/voice_controller.dart';

class OcrCameraScreen extends StatefulWidget {
  const OcrCameraScreen({super.key});

  @override
  State<OcrCameraScreen> createState() => _OcrCameraScreenState();
}

class _OcrCameraScreenState extends State<OcrCameraScreen> {
  CameraController? _camera;
  bool _initializing = true;
  bool _capturing = false;
  bool _autoShotTriggered = false;
  int _listenEpoch = 0;
  String _lastPromptNorm = '';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _listenEpoch++;
    context.read<VoiceController>().stop();
    _camera?.dispose();
    super.dispose();
  }
  void _watchAutoShot(String words) {
    final n = _norm(words);
    if (_autoShotTriggered) return;

    if (n.contains('chup') || n.contains('bam chup')) {
      _autoShotTriggered = true;
      Future.microtask(() async {
        await _takePicture();
      });
    }
  }
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        await context.read<TtsService>().speak(
          "Thiết bị này chưa có camera khả dụng.",
        );
        Navigator.pop(context);
        return;
      }

      final selected = cameras.firstWhere(
            (e) => e.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) return;

      setState(() {
        _camera = controller;
        _initializing = false;
      });

      await _askReadyToCapture();
    } catch (_) {
      if (!mounted) return;
      await context.read<TtsService>().speak(
        "Không mở được camera. Bạn kiểm tra lại quyền camera nhé.",
      );
      Navigator.pop(context);
    }
  }

  Future<void> _askReadyToCapture() async {
    await _promptAndListen(
      "Bạn muốn mình bấm nút chụp chưa? Khi sẵn sàng, bạn nói chụp.",
      _handleCaptureUtterance,
      settleMs: 1400,
    );
  }

  Future<void> _promptAndListen(
      String prompt,
      Future<void> Function(String raw) onFinal, {
        int settleMs = 1200,
      }) async {
    final tts = context.read<TtsService>();
    final voice = context.read<VoiceController>();
    final epoch = ++_listenEpoch;

    await voice.stop();
    await tts.stop();

    _lastPromptNorm = _norm(prompt);
    await tts.speak(prompt);
    await Future.delayed(Duration(milliseconds: settleMs));

    if (!mounted || epoch != _listenEpoch) return;

    await voice.start(
      onFinal: (text) async {
        if (!mounted || epoch != _listenEpoch) return;
        final n = _norm(text);

        if (n.isEmpty || _isEcho(n)) {
          await Future.delayed(const Duration(milliseconds: 350));
          if (!mounted || epoch != _listenEpoch) return;
          await _askReadyToCapture();
          return;
        }

        await onFinal(text);
      },
    );
  }

  bool _isEcho(String n) {
    return n == 'ban muon minh bam nut chup chua khi san sang ban noi chup' ||
        n == 'khi san sang ban noi chup';
  }

  Future<void> _handleCaptureUtterance(String raw) async {
    final n = _norm(raw);

    if (n.contains('chup') ||
        n.contains('bam chup') ||
        n.contains('chot') ||
        n.contains('roi') ||
        n.contains('san sang') ||
        n == 'ok') {
      await context.read<TtsService>().stop();
      await _takePicture();
      return;
    }

    if (n.contains('chua') || n.contains('khoan')) {
      await context.read<TtsService>().speak(
        'Ok, khi sẵn sàng bạn nói chụp.',
      );
      await Future.delayed(const Duration(milliseconds: 350));
      await _askReadyToCapture();
      return;
    }

    await context.read<TtsService>().speak(
      'Mình chưa hiểu. Khi sẵn sàng, bạn nói chụp.',
    );
    await Future.delayed(const Duration(milliseconds: 350));
    await _askReadyToCapture();
  }

  Future<void> _takePicture() async {
    if (_capturing) return;
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;

    setState(() => _capturing = true);

    try {
      await context.read<VoiceController>().stop();
      await context.read<TtsService>().stop();

      final file = await camera.takePicture();

      if (!mounted) return;
      Navigator.pop(context, file.path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _capturing = false);
      await context.read<TtsService>().speak(
        "Mình chưa chụp được ảnh. Bạn thử lại nhé.",
      );
      await Future.delayed(const Duration(milliseconds: 400));
      await _askReadyToCapture();
    }
  }

  String _norm(String s) {
    s = s.toLowerCase().trim();

    const withDia =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const without =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

    for (int i = 0; i < withDia.length; i++) {
      s = s.replaceAll(withDia[i], without[i]);
    }

    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceController>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Chụp ảnh OCR"),
        backgroundColor: AppColors.brandBrown,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _askReadyToCapture,
            icon: Icon(
              voice.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
            ),
          ),
        ],
      ),
      body: _initializing
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : Stack(
        children: [
          Positioned.fill(
            child: CameraPreview(_camera!),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 18,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                voice.isListening
                    ? (voice.lastWords.trim().isEmpty
                    ? "Đang nghe lệnh chụp..."
                    : "Đang nghe: ${voice.lastWords}")
                    : "Nói “chụp” để mình tự bấm nút chụp.",
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: Center(
              child: GestureDetector(
                onTap: _capturing ? null : _takePicture,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.22),
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}