import 'dart:async';
import 'dart:io';

import 'package:ai_voice_chat/services/google_sheets_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:just_audio/just_audio.dart';
import '../openai_key.dart';
import '../services/openai_service.dart';

class ChatProvider extends ChangeNotifier {
  final types.User user = const types.User(id: 'user');
  final types.User bot = const types.User(id: 'bot');

  final List<types.Message> messages = [];
  final textController = TextEditingController();

  final Record _recorder = Record();
  final AudioPlayer _player = AudioPlayer();
  final OpenAIService _openaiService = OpenAIService(OPENAI_API_KEY);
  final GoogleSheetService sheetService = GoogleSheetService(
    "https://docs.google.com/spreadsheets/d/1bWomGsgCloUiRM2ClhFs36JrVRUN5MpFOO9HzJFJdrU/export?format=csv",
  );

  bool isRecording = false;
  bool voiceMode = false; // continuous voice mode on/off
  bool isProcessing = false;
  bool _pushToTalkActive = false;

  Timer? _silenceTimer;
  DateTime? _lastVoiceTimestamp;
  List<String> _localRecordedPaths = [];

  ChatProvider() {
    // initial greeting
    _insertBotMessage(
        "Hello — ask me about employee leave or speak using the mic.");
  }

  void _insertBotMessage(String text) {
    final msg = types.TextMessage(
      author: bot,
      id: const Uuid().v4(),
      text: text,
    );
    messages.insert(0, msg);
    notifyListeners();
  }

  void clearMessages() {
    messages.clear();
    _insertBotMessage("Conversation cleared.");
  }

  // Send typed text
  Future<void> sendText(String text) async {
    final msg =
        types.TextMessage(author: user, id: const Uuid().v4(), text: text);
    messages.insert(0, msg);
    textController.clear();
    notifyListeners();
    await _sendToAiAndPlay(text);
  }

  // Push-to-talk start (tap down)
  Future<void> startPushToTalk() async {
    if (_pushToTalkActive) return;
    _pushToTalkActive = true;
    await _startRecording();
  }

  // Push-to-talk stop (tap up)
  Future<void> stopPushToTalk() async {
    if (!_pushToTalkActive) return;
    _pushToTalkActive = false;
    await _stopRecordingAndProcess();
  }

  // Start continuous voice-mode (tap once)
  Future<void> startVoiceMode() async {
    if (voiceMode) return;
    voiceMode = true;
    notifyListeners();
    await _startRecording();
    // Start a periodic timer to check silence
    _startSilenceWatcher();
  }

  Future<void> stopVoiceMode() async {
    if (!voiceMode) return;
    voiceMode = false;
    notifyListeners();
    _stopSilenceWatcher();
    // stop recorder and finalize any pending
    if (isRecording) {
      await _stopRecordingAndProcess();
    }
  }

  // Internal: start recording to temp file
  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _insertBotMessage("Microphone permission required.");
      return;
    }

    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/${const Uuid().v4()}.wav';
    await _recorder.start(
      path: filePath,
      encoder: AudioEncoder.wav,
      bitRate: 128000,
      samplingRate: 16000,
    );

    isRecording = true;
    notifyListeners();

    // Reset silence timer
    _lastVoiceTimestamp = DateTime.now();
  }

  // Stop recording and process audio (single-turn)
  Future<void> _stopRecordingAndProcess() async {
    if (!isRecording) return;
    final path = await _recorder.stop();
    isRecording = false;
    notifyListeners();

    if (path == null) return;

    _localRecordedPaths.add(path);

    // Send to Whisper and then to AI
    await _processAudioFile(path);

    // Remove file after processing
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
  }

  // Internal: periodically check amplitude-based silence detection
  void _startSilenceWatcher() {
    _silenceTimer?.cancel();
    _silenceTimer =
        Timer.periodic(const Duration(milliseconds: 600), (_) async {
      if (!(await _recorder.isRecording())) return;
      // amplitude is not directly available via record package; attempt to get decibel
      try {
        final amp = await _recorder
            .getAmplitude(); // returns Amplitude object in recent versions
        // amplitude.current: double ~0-? ; choose threshold empirically
        final current = amp.current;
        // print('amp: $current');
        if (current > 0.01) {
          _lastVoiceTimestamp = DateTime.now();
        } else {
          // if there has been silence for > 900 ms consider utterance ended
          if (_lastVoiceTimestamp != null &&
              DateTime.now().difference(_lastVoiceTimestamp!).inMilliseconds >
                  900) {
            // finalize chunk
            await _stopRecordingAndProcess();
            // if still in voiceMode, restart recording to listen for next utterance
            if (voiceMode) {
              await _startRecording();
            }
          }
        }
      } catch (e) {
        // If getAmplitude not available on some platforms, fallback to conservative behavior
      }
    });
  }

  void _stopSilenceWatcher() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  // Process recorded file: STT -> Chat -> TTS -> Play
  Future<void> _processAudioFile(String path) async {
    if (isProcessing) return;
    isProcessing = true;
    notifyListeners();

    try {
      final text = await _openaiTranscribe(path);
      if (text == null || text.trim().isEmpty) {
        _insertBotMessage("I couldn't transcribe the audio.");
        isProcessing = false;
        notifyListeners();
        return;
      }

      // Insert user message
      final userMsg =
          types.TextMessage(author: user, id: const Uuid().v4(), text: text);
      messages.insert(0, userMsg);
      notifyListeners();

      // Send to LLM and play reply
      await _sendToAiAndPlay(text);
    } catch (e) {
      _insertBotMessage("Audio processing error: ${e.toString()}");
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }

  // Transcribe via OpenAI Whisper
  Future<String?> _openaiTranscribe(String path) async {
    try {
      return await _openaiService.transcribeFile(path);
    } catch (e) {
      debugPrint('transcribe error $e');
      return null;
    }
  }

  Future<String> _handleFunctionResult(Map reply) async {
    if (reply["type"] == "function_call") {
      final func = reply["function"];

      if (func["name"] == "get_employee_leave") {
        final name = func["arguments"]["employee_name"];
        final record = await sheetService.searchEmployee(name);

        if (record == null) {
          return "I could not find any employee named $name.";
        }

        return "${record['Employee Name']} has ${record['Leave Balance']} leave days remaining.";
      }
    }

    return reply["text"]; // normal LLM text
  }

  // Send to LLM and play TTS
  Future<void> _sendToAiAndPlay(String userText) async {
    try {
      final reply = await _openaiService.chatWithFunctionCalling(
        messages: messages,
      );

      final replyText = await _handleFunctionResult(reply);

      // Append assistant message
      final botMsg = types.TextMessage(
          author: bot, id: const Uuid().v4(), text: replyText);
      messages.insert(0, botMsg);
      notifyListeners();

      // Request TTS and play
      final bytes = await _openaiService.textToSpeech(replyText);
      if (bytes != null) {
        // write bytes to temp file and play via file path to avoid
        // depending on a BytesSource symbol that may not exist in all versions
        try {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/${const Uuid().v4()}.mp3');
          await file.writeAsBytes(bytes);
          await _player.setFilePath(file.path);
          _player.play();
          // optionally delete after a small delay or when next playback occurs
        } catch (e) {
          debugPrint('TTS playback error: $e');
        }
      }
    } catch (e) {
      _insertBotMessage("AI error: ${e.toString()}");
    }
  }

  // low-level start/stop voice mode helpers (exposed for UI)
  Future<void> startVoiceModeDirect() async {
    await startVoiceMode();
  }

  Future<void> disposeProvider() async {
    _silenceTimer?.cancel();
    await _recorder.stop();
    await _player.dispose();
    super.dispose();
  }
}
