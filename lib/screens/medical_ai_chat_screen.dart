import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:just_audio/just_audio.dart';
import 'package:medicare_ai/models/chat_message.dart';
import 'package:medicare_ai/services/chat_history_service.dart';
import 'package:medicare_ai/services/openrouter_medical_ai_service.dart';
import 'package:medicare_ai/services/sarvam_tts_service.dart';
import 'package:medicare_ai/theme/portal_extension.dart';
import 'package:medicare_ai/widgets/theme_mode_toggle.dart';

class MedicalAiChatScreen extends StatefulWidget {
  const MedicalAiChatScreen({super.key});

  @override
  State<MedicalAiChatScreen> createState() => _MedicalAiChatScreenState();
}

class _MedicalAiChatScreenState extends State<MedicalAiChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final OpenRouterMedicalAiService _service = OpenRouterMedicalAiService();
  final SarvamTtsService _ttsService = SarvamTtsService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  final List<_UiMessage> _messages = <_UiMessage>[];
  final ChatHistoryService _chatHistoryService = ChatHistoryService.instance;

  bool _isSending = false;
  bool _isSpeaking = false;
  String? _playingAudioPath;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  String _selectedLanguage = 'English';
  final bool _voiceOnlyReplies = true;

  static const List<String> _indianLanguages = <String>[
    'English',
    'Hindi',
    'Bengali',
    'Telugu',
    'Marathi',
    'Tamil',
    'Urdu',
    'Gujarati',
    'Kannada',
    'Odia',
    'Malayalam',
    'Punjabi',
    'Assamese',
    'Maithili',
    'Santali',
    'Kashmiri',
    'Nepali',
    'Konkani',
    'Sindhi',
    'Dogri',
    'Manipuri',
    'Bodo',
    'Sanskrit',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      final playing = state.playing;
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _isSpeaking = false;
          _playingAudioPath = null;
          _currentPosition = Duration.zero;
        });
        return;
      }
      setState(() => _isSpeaking = playing);
    });
    _audioPlayer.positionStream.listen((position) {
      if (!mounted) return;
      setState(() => _currentPosition = position);
    });
    _audioPlayer.durationStream.listen((duration) {
      if (!mounted || duration == null) return;
      setState(() => _currentDuration = duration);
    });
  }

  Future<void> _loadHistory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final history = await _chatHistoryService.loadMessages(uid);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(history.map(_toUiMessage));
      });
      _scrollToBottom();
    } catch (_) {}
  }

  _UiMessage _toUiMessage(ChatMessageModel m) {
    final role = switch (m.role) {
      'user' => _UiRole.user,
      'error' => _UiRole.error,
      _ => _UiRole.assistant,
    };
    return _UiMessage(role: role, text: m.content);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _send({String? rawOverride, bool fromVoice = false}) async {
    final raw = (rawOverride ?? _inputController.text).trim();
    if (raw.isEmpty || _isSending) return;
    final userText = raw;

    setState(() {
      _messages.add(
        _UiMessage(
          role: _UiRole.user,
          text: raw,
          isVoiceOrigin: fromVoice,
        ),
      );
      _isSending = true;
      if (!fromVoice) {
        _inputController.clear();
      }
    });
    _scrollToBottom();
    await _persistMessage(role: 'user', content: userText);

    try {
      final history = _messages
          .where((m) => m.role != _UiRole.error)
          .map((m) => MedicalChatMessage(
                role: m.role == _UiRole.user ? 'user' : 'assistant',
                content: m.text,
              ))
          .toList();

      final answer = await _service.ask(
        history: history,
        outputLanguage: _selectedLanguage,
      );
      if (!mounted) return;
      final shouldUseIntro =
          _messages.where((m) => m.role == _UiRole.user).length == 1 &&
          _isGreeting(userText);
      final displayAnswer = shouldUseIntro
          ? _introByLanguage(_selectedLanguage)
          : answer;
      String? audioPath;
      try {
        audioPath = await _ttsService.synthesizeToFile(
          text: displayAnswer.trim(),
          language: _selectedLanguage,
        );
      } catch (_) {
        audioPath = null;
      }

      if (!mounted) return;
      setState(() {
        _messages.add(
          _UiMessage(
            role: _UiRole.assistant,
            text:
                (fromVoice && _voiceOnlyReplies) ? 'Voice response' : displayAnswer,
            audioPath: audioPath,
            isVoiceOnly: fromVoice && _voiceOnlyReplies,
          ),
        );
        _isSending = false;
      });
      // Voice note is available in the bubble; play only on user tap.
      await _persistMessage(role: 'assistant', content: displayAnswer);
    } catch (e) {
      if (!mounted) return;
      final message = e is SocketException
          ? 'Network error: unable to reach OpenRouter. Check internet/DNS and try again.'
          : 'Unable to get a medical response right now.\n$e';
      setState(() {
        _messages.add(_UiMessage(
          role: _UiRole.error,
          text: message,
        ));
        _isSending = false;
      });
      await _persistMessage(role: 'error', content: message);
    }

    _scrollToBottom();
  }

  Future<void> _persistMessage({
    required String role,
    required String content,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _chatHistoryService.appendMessage(
        uid: uid,
        role: role,
        content: content,
        language: _selectedLanguage,
      );
    } catch (_) {}
  }

  Future<void> _playAudioPath(String path) async {
    try {
      if (_playingAudioPath == path && _audioPlayer.playing) {
        await _audioPlayer.pause();
        if (!mounted) return;
        setState(() => _playingAudioPath = null);
        return;
      }

      if (_playingAudioPath != path) {
        await _audioPlayer.setFilePath(path);
      }
      await _audioPlayer.play();
      if (!mounted) return;
      setState(() => _playingAudioPath = path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to play voice response right now.')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.medicareColorScheme;
    final px = context.portalX;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Medical AI Chatbot',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            Text(
              'Language: $_selectedLanguage',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          _buildLanguageSelector(context),
          const SizedBox(width: 6),
          const ThemeModeIconButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'This assistant provides general medical information only. It does not replace licensed clinical care.',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Start a conversation by typing a message.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                final m = _messages[index];
                final isUser = m.role == _UiRole.user;
                final isError = m.role == _UiRole.error;
                final bubbleColor = isUser
                    ? px.ctaEnd
                    : isError
                        ? cs.errorContainer
                        : cs.surface;
                final textColor = isUser
                    ? Colors.white
                    : isError
                        ? cs.onErrorContainer
                        : cs.onSurface;
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.55),
                        ),
                      ),
                      child: isUser
                          ? Text(
                              m.text,
                              style: TextStyle(
                                color: textColor,
                                height: 1.35,
                                fontSize: 14,
                              ),
                            )
                          : m.isVoiceOnly
                              ? _VoiceOnlyAssistantCard(
                                  isPlaying:
                                      _playingAudioPath == m.audioPath && _isSpeaking,
                                  progress: (_playingAudioPath == m.audioPath &&
                                          _currentDuration.inMilliseconds > 0)
                                      ? (_currentPosition.inMilliseconds /
                                              _currentDuration.inMilliseconds)
                                          .clamp(0.0, 1.0)
                                      : 0,
                                  durationLabel: _formatDuration(
                                    _playingAudioPath == m.audioPath
                                        ? _currentPosition
                                        : Duration.zero,
                                    total: _playingAudioPath == m.audioPath
                                        ? _currentDuration
                                        : null,
                                  ),
                                  onTap: m.audioPath == null
                                      ? null
                                      : () => _playAudioPath(m.audioPath!),
                                )
                              : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _AssistantMarkdown(
                                  text: m.text,
                                  isError: isError,
                                ),
                                if (!isError && m.audioPath != null) ...[
                                  const SizedBox(height: 8),
                                  _VoiceNoteBubble(
                                    isPlaying: _playingAudioPath == m.audioPath && _isSpeaking,
                                    progress: (_playingAudioPath == m.audioPath &&
                                            _currentDuration.inMilliseconds > 0)
                                        ? (_currentPosition.inMilliseconds /
                                                _currentDuration.inMilliseconds)
                                            .clamp(0.0, 1.0)
                                        : 0,
                                    durationLabel: _formatDuration(
                                      _playingAudioPath == m.audioPath
                                          ? _currentPosition
                                          : Duration.zero,
                                      total: _playingAudioPath == m.audioPath
                                          ? _currentDuration
                                          : null,
                                    ),
                                    onTap: () => _playAudioPath(m.audioPath!),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ),
                );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask a medical question...',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      onPressed: _isSending ? null : _send,
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _isSpeaking ? Icons.volume_up_rounded : Icons.send_rounded,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration value, {Duration? total}) {
    String mmss(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    if (total == null || total == Duration.zero) return mmss(value);
    return '${mmss(value)} / ${mmss(total)}';
  }

  Widget _buildLanguageSelector(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _showLanguagePopup(context),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.secondaryContainer.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.language_rounded,
          color: cs.onSurface,
          size: 22,
        ),
      ),
    );
  }

  Future<void> _showLanguagePopup(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select answer language'),
          content: SizedBox(
            width: 360,
            height: 420,
            child: ListView.builder(
              itemCount: _indianLanguages.length,
              itemBuilder: (context, index) {
                final language = _indianLanguages[index];
                final isSelected = language == _selectedLanguage;
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(language),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded, color: cs.primary)
                      : null,
                  onTap: () => Navigator.pop(context, language),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (!mounted || selected == null || selected == _selectedLanguage) return;
    setState(() => _selectedLanguage = selected);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Answer language set to $selected'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _isGreeting(String text) {
    final t = text.trim().toLowerCase();
    const greetings = <String>{
      'hi',
      'hello',
      'hey',
      'hii',
      'namaste',
      'namaskar',
      'yo',
      'hola',
      'salam',
      'vanakkam',
      'kem cho',
      'sat sri akal',
    };
    return greetings.contains(t);
  }

  String _introByLanguage(String language) {
    switch (language) {
      case 'Hindi':
        return 'नमस्ते, मैं मेडिकेयर एआई हूँ। मैं आपकी कैसे मदद कर सकता/सकती हूँ?';
      case 'Bengali':
        return 'নমস্কার, আমি মেডিকেয়ার এআই। আমি কীভাবে আপনাকে সাহায্য করতে পারি?';
      case 'Telugu':
        return 'నమస్తే, నేను మెడికేర్ ఏఐను. మీకు నేను ఎలా సహాయం చేయగలను?';
      case 'Marathi':
        return 'नमस्कार, मी मेडिकेअर एआय आहे. मी तुम्हाला कशी मदत करू शकतो/शकते?';
      case 'Tamil':
        return 'வணக்கம், நான் மெடிகேர் ஏஐ. உங்களுக்கு நான் எப்படி உதவலாம்?';
      case 'Urdu':
        return 'السلام علیکم، میں میڈیکیئر اے آئی ہوں۔ میں آپ کی کیسے مدد کر سکتا/سکتی ہوں؟';
      case 'Gujarati':
        return 'નમસ્તે, હું મેડીકેર એઆઈ છું. હું તમને કેવી રીતે મદદ કરી શકું?';
      case 'Kannada':
        return 'ನಮಸ್ಕಾರ, ನಾನು ಮೆಡಿಕೇರ್ ಎಐ. ನಿಮಗೆ ನಾನು ಹೇಗೆ ಸಹಾಯ ಮಾಡಲಿ?';
      case 'Odia':
        return 'ନମସ୍କାର, ମୁଁ ମେଡିକେୟାର ଏଆଇ। ମୁଁ ଆପଣଙ୍କୁ କିପରି ସହଯୋଗ କରିପାରିବି?';
      case 'Malayalam':
        return 'നമസ്കാരം, ഞാൻ മെഡികെയർ എഐ ആണ്. നിങ്ങളെ എങ്ങനെ സഹായിക്കാം?';
      case 'Punjabi':
        return 'ਸਤ ਸ੍ਰੀ ਅਕਾਲ, ਮੈਂ ਮੈਡੀਕੇਅਰ ਏਆਈ ਹਾਂ। ਮੈਂ ਤੁਹਾਡੀ ਕਿਵੇਂ ਮਦਦ ਕਰ ਸਕਦਾ/ਸਕਦੀ ਹਾਂ?';
      case 'Assamese':
        return 'নমস্কাৰ, মই মেডিকেয়াৰ এআই। মই আপোনাক কেনেকৈ সহায় কৰিব পাৰোঁ?';
      case 'Nepali':
        return 'नमस्ते, म मेडिकेयर एआई हुँ। म तपाईंलाई कसरी मद्दत गर्न सक्छु?';
      case 'English':
      default:
        return 'Hello, I am Medicare AI. How can I help you today?';
    }
  }
}

enum _UiRole { user, assistant, error }

class _UiMessage {
  const _UiMessage({
    required this.role,
    required this.text,
    this.audioPath,
    this.isVoiceOnly = false,
    this.isVoiceOrigin = false,
  });

  final _UiRole role;
  final String text;
  final String? audioPath;
  final bool isVoiceOnly;
  final bool isVoiceOrigin;
}

class _VoiceOnlyAssistantCard extends StatelessWidget {
  const _VoiceOnlyAssistantCard({
    required this.isPlaying,
    required this.progress,
    required this.durationLabel,
    required this.onTap,
  });

  final bool isPlaying;
  final double progress;
  final String durationLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Voice reply',
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        _VoiceNoteBubble(
          isPlaying: isPlaying,
          progress: progress,
          durationLabel: durationLabel,
          onTap: onTap,
        ),
      ],
    );
  }
}

class _VoiceNoteBubble extends StatelessWidget {
  const _VoiceNoteBubble({
    required this.isPlaying,
    required this.progress,
    required this.durationLabel,
    required this.onTap,
  });

  final bool isPlaying;
  final double progress;
  final String durationLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              color: cs.primary,
              size: 26,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: Stack(
                children: [
                  Row(
                    children: List.generate(18, (index) {
                      final h = 6 + ((index % 5) * 3);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Container(
                            height: h.toDouble(),
                            decoration: BoxDecoration(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: Row(
                          children: List.generate(18, (index) {
                            final h = 6 + ((index % 5) * 3);
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 1),
                                child: Container(
                                  height: h.toDouble(),
                                  decoration: BoxDecoration(
                                    color: cs.primary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              durationLabel,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantMarkdown extends StatelessWidget {
  const _AssistantMarkdown({
    required this.text,
    required this.isError,
  });

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final normal = isError ? cs.onErrorContainer : cs.onSurface;
    final accent = isError ? cs.error : cs.primary;
    final subtle = isError ? cs.onErrorContainer : cs.onSurfaceVariant;

    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          color: normal,
          fontSize: 14,
          height: 1.4,
        ),
        strong: TextStyle(
          color: accent,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
        listBullet: TextStyle(
          color: accent,
          fontWeight: FontWeight.w700,
        ),
        blockSpacing: 8,
        h1: TextStyle(
          color: accent,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        h2: TextStyle(
          color: accent,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
        h3: TextStyle(
          color: accent,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
        em: TextStyle(
          color: subtle,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

