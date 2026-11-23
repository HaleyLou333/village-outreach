import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../localization/app_language.dart';

/// Optional device speech recognition.
///
/// Recognized speech is never added to the request description
/// until the user reviews and explicitly accepts the transcript.
class ReviewedVoiceInput extends StatefulWidget {
  const ReviewedVoiceInput({
    super.key,
    required this.onAccepted,
    this.enabled = true,
  });

  final ValueChanged<String> onAccepted;
  final bool enabled;

  @override
  State<ReviewedVoiceInput> createState() => _ReviewedVoiceInputState();
}

class _ReviewedVoiceInputState extends State<ReviewedVoiceInput> {
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _listening = false;
  bool _busy = false;
  String _transcript = '';

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Future<void> _record() async {
    if (_busy || _listening || !widget.enabled) return;

    setState(() => _busy = true);

    try {
      final available = await _speech.initialize();

      if (!mounted) return;

      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).voiceUnavailable)),
        );
        return;
      }

      _transcript = '';

      setState(() => _listening = true);

      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;

          setState(() {
            _transcript = result.recognizedWords;
          });
        },
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).voicePermissionFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _stopAndReview() async {
    if (_busy || !_listening) return;

    setState(() => _busy = true);

    try {
      await _speech.stop();

      if (!mounted) return;

      setState(() {
        _listening = false;
      });

      final accepted = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return _TranscriptReviewDialog(initialTranscript: _transcript);
        },
      );

      if (!mounted) return;

      if (accepted != null && accepted.trim().isNotEmpty) {
        widget.onAccepted(accepted.trim());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).voicePermissionFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Semantics(
      label: _listening
          ? strings.voiceStopSemantics
          : strings.voiceStartSemantics,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: OutlinedButton.icon(
          onPressed: !widget.enabled || _busy
              ? null
              : _listening
              ? _stopAndReview
              : _record,
          icon: Icon(_listening ? Icons.stop_circle_outlined : Icons.mic_none),
          label: Text(
            _listening
                ? strings.voiceStopAndReview
                : strings.voiceDictateDescription,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Owns the transcript controller for the entire lifetime
/// of the review dialog.
///
/// This prevents the controller from being disposed while
/// the dialog's TextField is still mounted.
class _TranscriptReviewDialog extends StatefulWidget {
  const _TranscriptReviewDialog({required this.initialTranscript});

  final String initialTranscript;

  @override
  State<_TranscriptReviewDialog> createState() =>
      _TranscriptReviewDialogState();
}

class _TranscriptReviewDialogState extends State<_TranscriptReviewDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.initialTranscript);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _acceptTranscript() {
    final transcript = _controller.text.trim();

    Navigator.of(context).pop(transcript);
  }

  void _discardTranscript() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return AlertDialog(
      title: Text(strings.voiceReviewTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          maxLength: 4000,
          decoration: InputDecoration(
            labelText: strings.voiceEditTranscript,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _discardTranscript,
          child: Text(strings.voiceDiscard),
        ),
        FilledButton(
          onPressed: _acceptTranscript,
          child: Text(strings.voiceAddDescription),
        ),
      ],
    );
  }
}
