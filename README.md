# mp3_mp4_player

Minimal local media player (audio & video) built with Flutter.

## Features
- Pick a local audio (`mp3`, `wav`, `aac`, `m4a`, `ogg`, `flac`) or video (`mp4`, `mov`, `mkv`, `webm`, `avi`) file using a native file picker.
- Automatic detection of media type (audio vs video).
- Simple controls:
  - Audio: play / pause, seek slider, time display.
  - Video: play / pause, stop (reset), looping.
- Works on mobile (Android/iOS), desktop, and web (where supported by browser).

## Getting Started
1. Ensure Flutter SDK is installed.
2. Get dependencies:
	```bash
	flutter pub get
	```
3. Run the app:
	```bash
	flutter run
	```

## Usage
1. Tap the floating + button.
2. Choose a media file from local storage.
3. Playback starts automatically.
4. For audio: drag the slider to seek.
5. For video: use pause/play or stop to reset.

## Notes & Permissions
- Android 13+ may require user permission for broader media access; `file_picker` uses the system picker which generally handles this.
- iOS uses a document picker sandbox; ensure the file is accessible via Files app.
- Some formats may not play on the web depending on browser codec support.

## Next Steps / Ideas
- Add playlist support.
- Background audio with notification controls (`just_audio_background`).
- Volume & playback speed controls.
- Better error messages and unsupported codec handling.

## License
You can adapt and extend freely for personal or commercial use.
