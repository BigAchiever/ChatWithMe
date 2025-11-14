# ChatWithMe

ChatWithMe is a Flutter-based AI voice and text chat application. It uses OpenAI's Whisper for speech-to-text, GPT for generating responses, and a Text-to-Speech (TTS) service to voice the AI's replies.

## Features

- **Voice-to-Text:** Speak to the app and have your words transcribed in real-time.
- **Text-to-Speech:** Hear the AI's responses in a natural-sounding voice.
- **Text-based Chat:** You can also type your messages to the AI.
- **Dark Mode:** The app uses a dark theme for a comfortable user experience.

## Getting Started

Follow these instructions to get a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- An OpenAI API Key. You can get one from the [OpenAI platform](https://platform.openai.com/).

### Installation

1.  Clone the repository:
    ```bash
    git clone https://github.com/BigAchiever/ChatWithMe.git
    ```
2.  Navigate to the project directory:
    ```bash
    cd ChatWithMe
    ```
3.  Install the dependencies:
    ```bash
    flutter pub get
    ```

### Configuration

1.  Create a file named `.env` in the root of the project.
2.  Add your OpenAI API key to the `.env` file as follows:
    ```
    OPENAI_API_KEY=your_api_key_here
    ```
3.  The `lib/openai_key.dart` file is configured to read the API key from this `.env` file.

## Usage

1.  Run the app on your connected device or emulator:
    ```bash
    flutter run
    ```
2.  The app will start on the chat screen. You can either type a message or tap the microphone icon to start speaking.

## Dependencies

The project uses the following key dependencies:

- `provider`: For state management.
- `dio`: For making HTTP requests to the OpenAI API.
- `flutter_chat_ui`: For the chat interface.
- `record`: For recording audio.
- `web_socket_channel`: For real-time communication.
- `just_audio`: For playing audio.
- `path_provider`: For accessing the device's file system.
- `flutter_webrtc`: For WebRTC support.
- `flutter_sound`: For audio recording and playback.
- `http`: For making HTTP requests.
- `flutter_dotenv`: For loading environment variables from a `.env` file.

For a full list of dependencies, see the `pubspec.yaml` file.

## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue if you have any suggestions or find any bugs.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.