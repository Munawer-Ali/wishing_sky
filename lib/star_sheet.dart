import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'look.dart';
import 'sky_data.dart';

class WishResult {
  WishResult(this.text, this.lightYears);

  final String text;
  final double? lightYears;
}

Future<WishResult?> showStarSheet(
  BuildContext context,
  ExplodingStar star,
  Telescope telescope, {
  String? name,
  required ValueChanged<String> onRename,
}) {
  return showModalBottomSheet<WishResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black45,
    builder: (_) => _StarSheet(star: star, telescope: telescope, name: name, onRename: onRename),
  );
}

class _StarSheet extends StatefulWidget {
  const _StarSheet({required this.star, required this.telescope, required this.name, required this.onRename});

  final ExplodingStar star;
  final Telescope telescope;
  final String? name;
  final ValueChanged<String> onRename;

  @override
  State<_StarSheet> createState() => _StarSheetState();
}

class _StarSheetState extends State<_StarSheet> {
  final _wish = TextEditingController();
  final _speech = SpeechToText();
  late final Future<double?> _distance = widget.telescope.lightYearsAway(widget.star.id);
  late String? _name = widget.name;
  double? _lightYears;
  bool _listening = false;
  String _textBeforeListening = '';

  @override
  void initState() {
    super.initState();
    _wish.addListener(() => setState(() {}));
    _distance.then((value) => _lightYears = value);
  }

  @override
  void dispose() {
    _speech.stop();
    _wish.dispose();
    super.dispose();
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final ready = await _speech.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && mounted) {
          setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!mounted) return;
    if (!ready) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Voice isn't available here. You can still write your wish.")));
      return;
    }
    _textBeforeListening = _wish.text.trim();
    setState(() => _listening = true);
    await _speech.listen(
      onResult: _onSpeech,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  void _onSpeech(SpeechRecognitionResult result) {
    final spoken = result.recognizedWords;
    _wish.text = _textBeforeListening.isEmpty ? spoken : '$_textBeforeListening $spoken';
    _wish.selection = TextSelection.collapsed(offset: _wish.text.length);
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: paper,
        title: const Text('name this star', style: TextStyle(color: ink, fontSize: 24)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: ink, fontSize: 20),
          cursorColor: crayonPink,
          onSubmitted: (value) => Navigator.pop(context, value),
          decoration: const InputDecoration(
            hintText: 'star name',
            hintStyle: TextStyle(color: pencil),
            counterStyle: TextStyle(color: pencil),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('save', style: TextStyle(color: ink, fontSize: 18)),
          ),
        ],
      ),
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    setState(() => _name = trimmed);
    widget.onRename(trimmed);
  }

  void _send() {
    final text = _wish.text.trim();
    if (text.isEmpty) return;
    _speech.stop();
    Navigator.pop(context, WishResult(text, _lightYears));
  }

  @override
  Widget build(BuildContext context) {
    final star = widget.star;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: CustomPaint(
            painter: const RuledPaperPainter(firstLine: 62, gap: 31.5),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(46, 18, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _rename,
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              _name ?? star.id,
                              style: const TextStyle(color: ink, fontSize: 28, height: 1.3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.edit, color: pencil, size: 18),
                        ],
                      ),
                    ),
                    if (_name != null) Text(star.id, style: const TextStyle(color: pencil, fontSize: 15)),
                    _Line(label: 'seen', value: timeAgo(star.firstSeen)),
                    FutureBuilder<double?>(
                      future: _distance,
                      builder: (context, snapshot) {
                        final ly = snapshot.data;
                        final loading = snapshot.connectionState == ConnectionState.waiting;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Line(
                              label: 'how far',
                              value: loading ? '…' : (ly == null ? 'very far' : '${lightYearsText(ly)} light-years'),
                            ),
                            Text(
                              loading
                                  ? 'it blew up …'
                                  : ly == null
                                  ? 'it blew up a long time ago'
                                  : 'it blew up ${lightYearsText(ly)} years ago',
                              style: const TextStyle(color: crayonPink, fontSize: 18, height: 1.75),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text('Dear star,', style: TextStyle(color: ink, fontSize: 22, height: 1.4)),
                    TextField(
                      controller: _wish,
                      maxLength: 120,
                      minLines: 2,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(color: ink, fontSize: 20, height: 1.55),
                      cursorColor: crayonPink,
                      decoration: const InputDecoration(
                        hintText: 'I wish…',
                        hintStyle: TextStyle(color: pencil, fontSize: 20),
                        counterText: '',
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _MicButton(listening: _listening, onTap: _toggleVoice),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _listening ? 'listening…' : 'or say it',
                            style: TextStyle(color: _listening ? crayonPink : pencil, fontSize: 16),
                          ),
                        ),
                        _SendSticker(enabled: _wish.text.trim().isNotEmpty, onTap: _send),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(color: pencil),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(color: ink),
          ),
        ],
      ),
      style: const TextStyle(fontSize: 18, height: 1.75),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.listening, required this.onTap});

  final bool listening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: listening ? crayonPink : ink.withValues(alpha: 0.08),
          boxShadow: listening ? [BoxShadow(color: crayonPink.withValues(alpha: 0.5), blurRadius: 14)] : null,
        ),
        child: Icon(listening ? Icons.mic : Icons.mic_none, color: listening ? Colors.white : ink),
      ),
    );
  }
}

class _SendSticker extends StatelessWidget {
  const _SendSticker({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1 : 0.4,
        child: Transform.rotate(
          angle: -0.05,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: stickerYellow,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2))],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, color: ink, size: 20),
                SizedBox(width: 6),
                Text('send my wish', style: TextStyle(color: ink, fontSize: 18)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
