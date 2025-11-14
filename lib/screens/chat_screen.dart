import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/input_bar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _showClearConfirmation(ChatProvider chat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.delete_forever, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Clear Chat History?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This will delete all messages in the current conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      chat.clearMessages();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 12),
                              Text('Chat cleared'),
                            ],
                          ),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Clear'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = Provider.of<ChatProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 72,
        backgroundColor: isDark ? const Color(0xFF0E0E0F) : Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.15),
                width: 1,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            // Avatar / AI Icon Card
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF764BA2).withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child:
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
            ),

            const SizedBox(width: 14),

            // Title + Subtitle block
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Text(
                      "AI Voice Assistant",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Real-time listening indicator (only visible in voice mode)
                    if (chat.voiceMode)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.6),
                              blurRadius: 10,
                              spreadRadius: 1.5,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    (chat.sheetRowCount > 0
                            ? "${chat.sheetRowCount} employees loaded"
                            : "Ready to assist"),
                    key: ValueKey(chat.voiceMode ? "voice" : "text"),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          //voice mode toggle button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: chat.voiceMode
                  ? const Color(0xFF667EEA).withOpacity(0.15)
                  : Colors.transparent,
              border: Border.all(
                color: chat.voiceMode
                    ? const Color(0xFF667EEA)
                    : Colors.grey.withOpacity(0.25),
                width: 1.4,
              ),
            ),
            child: IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  chat.voiceMode ? Icons.hearing : Icons.mic_none,
                  key: ValueKey(chat.voiceMode),
                  color: chat.voiceMode
                      ? const Color(0xFF667EEA)
                      : Colors.grey[700],
                  size: 26,
                ),
              ),
              onPressed: () async {
                if (chat.voiceMode) {
                  await chat.stopVoiceMode();
                } else {
                  await chat.startVoiceMode();
                }
              },
            ),
          ),

          // Clear 
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.delete_forever_outlined, size: 26),
              color: Colors.grey[700],
              tooltip: 'Clear chat',
              onPressed: () => _showClearConfirmation(chat),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status Banner
            if (chat.voiceMode)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: chat.isAISpeaking
                        ? [const Color(0xFF764BA2), const Color(0xFF667EEA)]
                        : [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667EEA).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    //  indicator
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      builder: (context, value, child) {
                        return Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(value * 0.8),
                                blurRadius: value * 16,
                                spreadRadius: value * 4,
                              ),
                            ],
                          ),
                        );
                      },
                      onEnd: () {
                        // Restart animation 
                        if (mounted && chat.voiceMode) {
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        chat.isAISpeaking
                            ? '🔊 AI is speaking...'
                            : '🎤 Listening...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (chat.currentTranscript.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Transcribing...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // Partial transcript display
            if (chat.voiceMode && chat.currentTranscript.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: isDark
                    ? const Color(0xFF1A1A1A).withOpacity(0.5)
                    : Colors.grey[100],
                child: Row(
                  children: [
                    Icon(
                      Icons.mic,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chat.currentTranscript,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            //  Messages
            Expanded(
              child: chat.messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF667EEA).withOpacity(0.2),
                                  const Color(0xFF764BA2).withOpacity(0.2),
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline,
                              size: 60,
                              color: Color(0xFF667EEA),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Start a conversation',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Type a message or use voice mode to begin',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (chat.sheetRowCount > 0) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF667EEA).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      const Color(0xFF667EEA).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.table_chart,
                                    size: 16,
                                    color: Color(0xFF667EEA),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${chat.sheetRowCount} rows loaded from Sheets',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF667EEA),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F0F0F)
                            : const Color(0xFFF5F5F5),
                      ),
                      child: Chat(
                        messages: chat.messages,
                        onPreviewDataFetched: (_, __) {},

                        // disable the built-in input
                        onSendPressed: (_) {},
                        inputOptions: InputOptions(enabled: false),
                        user: chat.user,
                        theme: DefaultChatTheme(
                          backgroundColor: isDark
                              ? const Color(0xFF0F0F0F)
                              : const Color(0xFFF5F5F5),
                          primaryColor: const Color(0xFF667EEA),
                          secondaryColor:
                              isDark ? const Color(0xFF1A1A1A) : Colors.white,
                          inputBackgroundColor: Colors.transparent,
                          inputTextColor:
                              isDark ? Colors.white : Colors.black87,
                          receivedMessageBodyTextStyle: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 15,
                            height: 1.5,
                          ),
                          sentMessageBodyTextStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.5,
                          ),
                          messageBorderRadius: 16,
                          messageInsetsVertical: 12,
                          messageInsetsHorizontal: 16,
                        ),
                        showUserAvatars: true,
                        showUserNames: false,
                        
                      ),
                    ),
            ),

            // Input Bar 
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                  const InputBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
