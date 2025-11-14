import 'package:ai_voice_chat/services/voice_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';
import '../services/google_sheets_service.dart';
import '../services/openai_service.dart';
import '../openai_key.dart';

class ChatProvider extends ChangeNotifier {
  final types.User user = const types.User(id: 'user');
  final types.User bot = const types.User(id: 'bot');

  final List<types.Message> messages = [];
  final TextEditingController textController = TextEditingController();

  // (WebRTC)
  final RealtimeVoiceService realtime = RealtimeVoiceService();

  // OpenAI service
  final OpenAIService _openaiService = OpenAIService(OPENAI_API_KEY, {});

  // Google Sheet service
  final GoogleSheetService sheetService = GoogleSheetService(
    "https://docs.google.com/spreadsheets/d/1bWomGsgCloUiRM2ClhFs36JrVRUN5MpFOO9HzJFJdrU/export?format=csv",
  );

  bool voiceMode = false;
  String _currentTranscript = '';
  String _currentAssistantResponse = '';
  List<Map<String, String>> _sheetData = []; // Changed to match your service
  bool _isLoadingSheet = false;
  bool isAISpeaking = false;

  // Getters for UI
  String get currentTranscript => _currentTranscript;
  String get currentAssistantResponse => _currentAssistantResponse;
  int get sheetRowCount => _sheetData.length; // Already excludes headers

  ChatProvider() {
    _insertBotMessage(
        "Hello! you can type or talk to me in realtime voice mode.");

    // Load Google Sheets data on initialization
    _loadSheetData();

    // Set up realtime callbacks
    realtime.onTranscriptionComplete = (transcript) {
      _handleUserTranscript(transcript);
    };

    realtime.onPartialTranscript = (partial) {
      // Show partial transcripts in UI (user speaking)
      _currentTranscript = partial;
      notifyListeners();
    };

    // Assistant streaming callbacks
    realtime.onAssistantPartial = (partial) {
      // Append partial text
      if (partial.trim().isEmpty) return;
      _currentAssistantResponse =
          '$_currentAssistantResponse ${partial.trim()}'.trim();
      isAISpeaking = true;
      notifyListeners();
    };

    realtime.onAssistantComplete = (finalText) {
      if (finalText.trim().isEmpty) return;
      _insertBotMessage(finalText.trim());
      _currentAssistantResponse = '';
      isAISpeaking = false;
      notifyListeners();
    };

    realtime.onError = (error) {
      _insertBotMessage("Error: $error");
    };

    realtime.onStart = () {
      print('Voice mode started');
    };

    realtime.onStop = () {
      print('Voice mode stopped');
    };
  }

  // Insert bot message into UI
  void _insertBotMessage(String text) {
    final msg = types.TextMessage(
      author: bot,
      id: const Uuid().v4(),
      text: text,
    );
    messages.insert(0, msg);
    notifyListeners();
  }

  // Insert user message into UI
  void _insertUserMessage(String text) {
    final msg = types.TextMessage(
      author: user,
      id: const Uuid().v4(),
      text: text,
    );
    messages.insert(0, msg);
    notifyListeners();
  }

  // Handle completed user transcript
  void _handleUserTranscript(String transcript) {
    if (transcript.trim().isEmpty) return;
    _insertUserMessage(transcript);
    _currentTranscript = '';
    isAISpeaking = true;
    notifyListeners();
  }

  // Load Google Sheets data
  Future<void> _loadSheetData() async {
    if (_isLoadingSheet) return;
    _isLoadingSheet = true;

    try {
      _sheetData = await sheetService.fetchEmployees();
      print('Loaded ${_sheetData.length} rows from Google Sheets');
      _isLoadingSheet = false;
    } catch (e) {
      print('Failed to load sheet data: $e');
      _isLoadingSheet = false;
      // Continue without data if loading fails
      _sheetData = [];
    }
  }

  // Build system instructions with sheet data
  String _buildSystemInstructions() {
    if (_sheetData.isEmpty) {
      return '''You are a helpful AI assistant with voice capabilities. 
You can have natural conversations with users and respond with voice.
Be concise and conversational in your responses.''';
    }

    // Format sheet data as context
    final List<String> headers =
        _sheetData.isNotEmpty ? _sheetData[0].keys.toList() : <String>[];
    final dataRows =
        _sheetData.length > 1 ? _sheetData.sublist(1) : <Map<String, String>>[];

    final sheetContext = StringBuffer();
    sheetContext.writeln('You have access to the following data:');
    sheetContext.writeln('');

    if (headers.isNotEmpty) {
      sheetContext.writeln('Columns: ${headers.join(", ")}');
      sheetContext.writeln('');
    }

    if (dataRows.isNotEmpty) {
      sheetContext.writeln('Data rows (first 50):');
      final rowsToShow = dataRows.take(50);
      for (var i = 0; i < rowsToShow.length; i++) {
        final row = rowsToShow.elementAt(i);
        // Join values in header order for consistent output
        final values = headers.map((h) => row[h] ?? '').toList();
        sheetContext.writeln('Row ${i + 1}: ${values.join(", ")}');
      }
    }

    return '''You are a helpful AI assistant with voice capabilities and access to structured data.

$sheetContext

When users ask questions, you can refer to this data to provide accurate answers.
Be conversational and natural in your responses since you're communicating via voice.
Keep responses concise but informative.''';
  }

  // Clear chat & reset
  void clearMessages() {
    messages.clear();
    _insertBotMessage("Hi, How can I assist you today?");
  }

  //  SEND NORMAL TEXT
  Future<void> sendText(String text) async {
    if (text.trim().isEmpty) return;

    _insertUserMessage(text);
    textController.clear();
    notifyListeners();

    // If in voice mode, send via data channel
    if (voiceMode) {
      realtime.sendText(text);
    } else {
      // Text-mode: call OpenAI with function-calling support
      try {
        // Build conversation messages in chronological order
        final conv = messages.reversed.toList();
        final resp =
            await _openaiService.chatWithFunctionCalling(messages: conv);

        if (resp['type'] == 'function_call') {
          final func = resp['function'] as Map<String, dynamic>;
          final fname = func['name'] as String? ?? '';
          final args = func['arguments'] as Map<String, dynamic>?;

          if (fname == 'get_employee_leave' && args != null) {
            final employeeName = (args['employee_name'] as String?) ?? '';
            if (employeeName.trim().isEmpty) {
              _insertBotMessage('Which employee would you like me to check?');
            } else {
              final found = await sheetService.searchEmployee(employeeName);
              if (found == null) {
                _insertBotMessage(
                    'I could not find an employee named "$employeeName" in the sheet.');
              } else {
                // Try to find a leave-related field (case-insensitive)
                String? leaveField;
                for (final k in found.keys) {
                  if (k.toLowerCase().contains('leave')) {
                    leaveField = k;
                    break;
                  }
                }

                if (leaveField != null &&
                    (found[leaveField] ?? '').trim().isNotEmpty) {
                  _insertBotMessage(
                      '${found['Employee Name'] ?? employeeName} has ${found[leaveField]} remaining (${leaveField}).');
                } else {
                  // Fallback: show full row summary
                  final pairs = found.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join('; ');
                  _insertBotMessage('Employee data: $pairs');
                }
              }
            }
          } else {
            _insertBotMessage('Requested function "$fname" is not supported.');
          }
        } else if (resp['type'] == 'text') {
          final textResp = resp['text'] as String? ?? '';
          _insertBotMessage(textResp);
        } else {
          _insertBotMessage(
              'I did not understand the response from the assistant.');
        }
      } catch (e) {
        _insertBotMessage('AI error: ${e.toString()}');
      }
    }
  }

  // ===========================================================================
  // REALTIME VOICE MODE (WebRTC)

  Future<void> startVoiceMode() async {
    if (voiceMode) return;

    // Ensure sheet data is loaded
    if (_sheetData.isEmpty && !_isLoadingSheet) {
      await _loadSheetData();
    }

    try {
      // Build system instructions with sheet data
      final instructions = _buildSystemInstructions();

      await realtime.start(systemInstructions: instructions);
      voiceMode = true;
      notifyListeners();

      final dataInfo = _sheetData.isEmpty
          ? ""
          : " I have access to your Google Sheets data with ${_sheetData.length - 1} rows.";
      _insertBotMessage(
          "🎤 Voice mode activated! I'm listening and will respond with voice.$dataInfo");
    } catch (e) {
      _insertBotMessage("❌ Failed to start voice mode: $e");
      print("Voice mode error: $e");
    }
  }

  Future<void> stopVoiceMode() async {
    if (!voiceMode) return;

    try {
      await realtime.stop();
      voiceMode = false;
      _currentTranscript = '';
      notifyListeners();

      _insertBotMessage("Voice mode stopped.");
    } catch (e) {
      _insertBotMessage("Failed to stop voice mode: $e");
    }
  }

  @override
  void dispose() {
    realtime.dispose();
    textController.dispose();
    super.dispose();
  }
}
