import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import '../openai_key.dart';

class RealtimeVoiceService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RTCDataChannel? _dataChannel;

  bool _isStreaming = false;

  // Buffers for accumulating transcripts
  String _userTranscriptBuffer = '';
  String _assistantTranscriptBuffer = '';

  void Function(String)? onTranscriptionComplete; // user finished speaking
  void Function(String)? onPartialTranscript; // user partial transcript updates

  void Function(String)? onAssistantPartial; // assistant delta chunks
  void Function(String)? onAssistantComplete; // assistant final text
  void Function()? onStart;
  void Function()? onStop;
  void Function(String)? onError;

  /// Start WebRTC session with OpenAI Realtime API
  Future<void> start({String? systemInstructions}) async {
    if (_isStreaming) return;

    try {
      // 1. Create ephemeral token with optional system instructions
      final token =
          await _createEphemeralToken(systemInstructions: systemInstructions);

      // 2. Get user media (microphone)
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'sampleRate': 24000,
        },
        'video': false,
      });

      // 3. Create peer connection
      final config = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'}
        ],
      };

      _peerConnection = await createPeerConnection(config);

      // 4. Add audio track
      _localStream!.getAudioTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // 5. Create data channel for text responses
      _dataChannel = await _peerConnection!.createDataChannel(
        'oai-events',
        RTCDataChannelInit()..ordered = true,
      );

      _dataChannel!.onMessage = (RTCDataChannelMessage message) {
        _handleDataChannelMessage(message.text);
      };

      // 6. Handle incoming audio track
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'audio') {
          print('Receiving audio from OpenAI');
        }
      };

      // 7. Create offer
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // 8. Send offer to OpenAI and get answer
      final answer = await _sendOfferToOpenAI(offer.sdp!, token);

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(answer, 'answer'),
      );

      _isStreaming = true;
      onStart?.call();
    } catch (e, st) {
      _isStreaming = false;
      onError?.call("Failed to start: $e");
      print("RealtimeVoiceService.start error: $e\n$st");
      await dispose();
    }
  }

  /// Stop the session
  Future<void> stop() async {
    if (!_isStreaming) return;
    _isStreaming = false;

    try {
      _dataChannel?.send(RTCDataChannelMessage(jsonEncode({
        'type': 'response.cancel',
      })));

      await Future.delayed(const Duration(milliseconds: 500));
      await dispose();
      onStop?.call();
    } catch (e) {
      onError?.call("Stop error: $e");
      print("RealtimeVoiceService.stop error: $e");
    }
  }

  /// Dispose all resources
  Future<void> dispose() async {
    try {
      await _dataChannel?.close();
      _dataChannel = null;

      await _localStream?.dispose();
      _localStream = null;

      await _peerConnection?.close();
      _peerConnection = null;
    } catch (e) {
      print("Dispose error: $e");
    }
    _isStreaming = false;
  }

  // INTERNAL: Create ephemeral token
  Future<String> _createEphemeralToken({String? systemInstructions}) async {
    final body = <String, dynamic>{
      'model': 'gpt-4o-realtime-preview-2024-12-17',
      'voice': 'verse',
    };

    if (systemInstructions != null && systemInstructions.isNotEmpty) {
      body['instructions'] = systemInstructions;
    }

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/realtime/sessions'),
      headers: {
        'Authorization': 'Bearer $OPENAI_API_KEY',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create session: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['client_secret']['value'];
  }

  // INTERNAL: Send SDP offer to OpenAI
  Future<String> _sendOfferToOpenAI(String sdp, String token) async {
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/realtime'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/sdp',
      },
      body: sdp,
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to connect: ${response.body}');
    }

    return response.body;
  }

  // INTERNAL: Handle data channel messages
  void _handleDataChannelMessage(String message) {
    try {
      final event = jsonDecode(message);
      final type = event['type'] as String?;

      print('OpenAI event: $type');

      switch (type) {
        // User's speech transcription events
        case 'conversation.item.input_audio_transcription.delta':
          // Accumulate user transcript deltas
          final delta = event['delta'] as String?;
          if (delta != null) {
            _userTranscriptBuffer += delta;
            onPartialTranscript?.call(_userTranscriptBuffer);
          }
          break;

        case 'conversation.item.input_audio_transcription.completed':
          // User finished speaking - send complete transcript
          final transcript = event['transcript'] as String?;
          if (transcript != null && transcript.isNotEmpty) {
            onTranscriptionComplete?.call(transcript);
          }
          _userTranscriptBuffer = ''; // Clear buffer
          break;

        // AI's response transcription events
        case 'response.audio_transcript.delta':
          // AI response streaming delta - forward to onAssistantPartial
          final delta = event['delta'] as String?;
          if (delta != null) {
            // Keep a buffer as fallback,
            _assistantTranscriptBuffer += delta;
            onAssistantPartial?.call(delta);
          }
          break;

        case 'response.audio_transcript.done':
          // AI finished responding - send complete transcript
          final transcript = event['transcript'] as String?;
          if (transcript != null && transcript.isNotEmpty) {
            onAssistantComplete?.call(transcript);
          } else if (_assistantTranscriptBuffer.isNotEmpty) {
            // Use buffered content if transcript field is empty
            onAssistantComplete?.call(_assistantTranscriptBuffer);
          }
          _assistantTranscriptBuffer = ''; // Clear buffer
          break;

        case 'response.done':
          print('Response completed');
          // Fallback: if we still have buffered content, send it as assistant complete
          if (_assistantTranscriptBuffer.isNotEmpty) {
            onAssistantComplete?.call(_assistantTranscriptBuffer);
            _assistantTranscriptBuffer = '';
          }
          break;

        case 'error':
          final error = event['error'];
          onError?.call('API Error: ${error.toString()}');
          break;
      }
    } catch (e) {
      print('Failed to parse event: $e');
    }
  }

  /// Send a text message 
  void sendText(String text) {
    if (_dataChannel == null) return;

    try {
      _dataChannel!.send(RTCDataChannelMessage(jsonEncode({
        'type': 'conversation.item.create',
        'item': {
          'type': 'message',
          'role': 'user',
          'content': [
            {
              'type': 'input_text',
              'text': text,
            }
          ],
        },
      })));

      _dataChannel!.send(RTCDataChannelMessage(jsonEncode({
        'type': 'response.create',
      })));
    } catch (e) {
      print('Failed to send text: $e');
    }
  }
}
