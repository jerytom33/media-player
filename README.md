# mp3_mp4_player

Minimal local media player (audio & video) built with Flutter.

## Features
- **Automatic Media Detection**: Scans your device storage for supported audio and video files
- **Media Library**: Browse all detected media files in an organized list view
- **Search & Filter**: Quickly find media files using the built-in search functionality
- **Manual File Picker**: Still includes the option to manually pick files
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
1. The app automatically scans for media files on startup
2. Browse the media library and tap any file to play it
3. Use the search bar to filter files by name
4. Pull down to refresh the media library
5. Alternatively, tap the + button to manually pick a file
6. Playback starts automatically when you select a file
7. For audio: drag the slider to seek.
8. For video: use pause/play or stop to reset.
9. Tap the back arrow to return to the media library

## Supported Directories
The app scans the following directories for media files:
- **Android**: Music, Movies, Download, DCIM, Documents, and app-specific directories
- **iOS**: App documents and downloads directories
- **Desktop** (Windows/Mac/Linux): Music, Videos, Downloads, and Documents folders

## Notes & Permissions
- **Android 13+**: Requires `READ_MEDIA_AUDIO` and `READ_MEDIA_VIDEO` permissions
- **Android 12 and below**: Requires `READ_EXTERNAL_STORAGE` permission
- The app requests these permissions automatically on first use
- iOS uses a document picker sandbox; ensure the file is accessible via Files app.
- Some formats may not play on the web depending on browser codec support.

## Next Steps / Ideas
- Add playlist support.
- Background audio with notification controls (`just_audio_background`).
- Volume & playback speed controls.
- Better error messages and unsupported codec handling.
- Sort options (by name, date, size, type)
- Favorites/recently played tracking

## License
You can adapt and extend freely for personal or commercial use.
