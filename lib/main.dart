import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/chat_provider.dart';
import 'screens/chat_screen.dart';

void main() {
  runApp(const AiVoiceChatApp());
}

class AiVoiceChatApp extends StatelessWidget {
  const AiVoiceChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(),
      child: MaterialApp(
        title: 'AI Voice Chat',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.deepOrange,
            secondary: Colors.orangeAccent,
          ),
        ),
        home: const ChatScreen(),
      ),
    );
  }
}
