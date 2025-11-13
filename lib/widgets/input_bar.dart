import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

class InputBar extends StatefulWidget {
  const InputBar({super.key});

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  @override
  Widget build(BuildContext context) {
    final chat = Provider.of<ChatProvider>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey[900],
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: chat.textController,
              textInputAction: TextInputAction.send,
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  chat.sendText(text.trim());
                }
              },
              decoration: InputDecoration(
                hintText: 'Ask anything...',
                filled: true,
                fillColor: Colors.black26,
                prefixIcon: const Icon(Icons.add, color: Colors.white70),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // mic button inside
          GestureDetector(
            onTapDown: (_) async {
              // start a single-turn recording (press & hold alternative)
              await chat.startPushToTalk();
            },
            onTapUp: (_) async {
              await chat.stopPushToTalk();
            },
            onLongPress: () async {
              // long-press can toggle continuous VAD-mode as well
              if (!chat.voiceMode) {
                await chat.startVoiceMode();
              }
            },
            child: CircleAvatar(
              radius: 24,
              backgroundColor:
                  chat.isRecording ? Colors.red : Colors.deepOrange,
              child: Icon(
                chat.isRecording ? Icons.mic : Icons.mic_none,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
