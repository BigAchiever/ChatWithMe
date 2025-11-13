import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

class OpenAIService {
  final String apiKey;
  final Dio _dio = Dio();

  OpenAIService(this.apiKey) {
    _dio.options.headers['Authorization'] = 'Bearer $apiKey';
    _dio.options.headers['Accept'] = 'application/json';
  }

  // Transcribe local audio file using Whisper (multipart/form-data)
  Future<String?> transcribeFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'audio.wav'),
      'model': 'whisper-1',
    });

    final resp = await _dio.post(
      'https://api.openai.com/v1/audio/transcriptions',
      data: formData,
      options: Options(
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      ),
    );

    if (resp.statusCode == 200) {
      return resp.data['text'] as String?;
    } else {
      throw Exception('Transcription failed: ${resp.statusCode} ${resp.data}');
    }
  }

  Future<Map<String, dynamic>> chatWithFunctionCalling({
  required List<dynamic> messages,
}) async {
  final resp = await _dio.post(
    "https://api.openai.com/v1/chat/completions",
    data: {
      "model": "gpt-4.1-mini",
      "functions": [
        {
          "name": "get_employee_leave",
          "description": "Get leave balance for an employee",
          "parameters": {
            "type": "object",
            "properties": {
              "employee_name": {"type": "string"},
            },
            "required": ["employee_name"]
          }
        }
      ],
      "function_call": "auto",
      "messages": messages.map((m) {
        return {
          "role": m.author.id == "user" ? "user" : "assistant",
          "content": (m as types.TextMessage).text
        };
      }).toList(),
    },
  );

  final data = resp.data;

  if (data["choices"][0]["message"]["function_call"] != null) {
    final fc = data["choices"][0]["message"]["function_call"];

    return {
      "type": "function_call",
      "function": {
        "name": fc["name"],
        "arguments": jsonDecode(fc["arguments"]),
      }
    };
  }

  return {
    "type": "text",
    "text": data["choices"][0]["message"]["content"],
  };
}


  // Call Chat Completions to get text reply (sends whole conversation)
  Future<String> chatReplyGetText({
    required List<Map<String, String>> messages,
    required String userMessage,
  }) async {
    // Build messages array (system + conversation + latest user)
    final body = {
      'model': 'gpt-4o-mini', // change as needed
      'messages': [
        {
          'role': 'system',
          'content': 'You are an HR assistant. Answer concisely.'
        },
        ...messages,
        {'role': 'user', 'content': userMessage}
      ],
      'temperature': 0.2,
      'max_tokens': 512,
    };

    final resp = await _dio.post(
      'https://api.openai.com/v1/chat/completions',
      data: jsonEncode(body),
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    final content = resp.data['choices'][0]['message']['content'];
    return content as String;
  }

  

  // Text -> speech (TTS). Returns bytes (wav/mp3).
  Future<Uint8List?> textToSpeech(String text) async {
    try {
      final body = {
        'model': 'gpt-4o-mini-tts', // example model name
        'voice': 'alloy',
        'input': text,
      };

      final resp = await _dio.post(
        'https://api.openai.com/v1/audio/speech',
        data: jsonEncode(body),
        options: Options(
          headers: {'Content-Type': 'application/json'},
          responseType: ResponseType.bytes,
        ),
      );

      // resp.data is bytes
      final bytes = resp.data as List<int>;
      return Uint8List.fromList(bytes);
    } catch (e) {
      debugPrint('TTS error: $e');
      return null;
    }
  }
}
