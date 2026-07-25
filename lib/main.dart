import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const LecteurMultimediaApp());
}

class LecteurMultimediaApp extends StatelessWidget {
  const LecteurMultimediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lecteur Multimédia',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LecteurMultimediaPage(),
    );
  }
}

class LecteurMultimediaPage extends StatefulWidget {
  const LecteurMultimediaPage({super.key});
  @override
  State<LecteurMultimediaPage> createState() => _LecteurMultimediaPageState();
}

class _LecteurMultimediaPageState extends State<LecteurMultimediaPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  VideoPlayerController? _videoController;

  String? _currentFilePath;
  bool _isVideo = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  bool _isVideoFile(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.avi') ||
        p.endsWith('.mkv');
  }

  Future<void> _stopAll() async {
    await _audioPlayer.stop();
    if (_videoController != null) {
      await _videoController!.dispose();
      _videoController = null;
    }
  }

  Future<void> _pickFile() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'mp4', 'mov', 'avi', 'mkv'],
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        await _stopAll();
        setState(() {
          _currentFilePath = path;
          _isVideo = _isVideoFile(path);
          _isLoading = false;
        });
        _playCurrent();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _playCurrent() async {
    if (_currentFilePath == null) return;
    if (_isVideo) {
      await _playVideo(_currentFilePath!);
    } else {
      await _playAudio(_currentFilePath!);
    }
  }

  Future<void> _playAudio(String path) async {
    try {
      await _audioPlayer.setFilePath(path); // API correcte pour un fichier local
      await _audioPlayer.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur audio : $e')));
      }
    }
  }

  Future<void> _playVideo(String path) async {
    try {
      final controller = VideoPlayerController.file(File(path));
      _videoController = controller;
      await controller.initialize();
      if (mounted) setState(() {});
      await controller.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur vidéo : $e')));
      }
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecteur Multimédia'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Sélectionner un fichier'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
            ],
            if (_currentFilePath != null) ...[
              const SizedBox(height: 30),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(_isVideo ? Icons.videocam : Icons.audiotrack,
                          color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _currentFilePath!.split(Platform.pathSeparator).last,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                  child: _isVideo ? _buildVideoView() : _buildAudioView()),
            ] else
              const Expanded(
                child: Center(
                  child: Text(
                    'Aucun fichier sélectionné.\nClique sur le bouton ci-dessus.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoView() {
    final c = _videoController;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio,
        child: VideoPlayer(c),
      ),
    );
  }

  Widget _buildAudioView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.music_note, size: 100, color: Colors.blue),
        const SizedBox(height: 30),
        StreamBuilder<Duration>(
          stream: _audioPlayer.positionStream,
          builder: (context, posSnap) {
            final position = posSnap.data ?? Duration.zero;
            return StreamBuilder<Duration?>(
              stream: _audioPlayer.durationStream,
              builder: (context, durSnap) {
                final duration = durSnap.data ?? Duration.zero;
                final max = duration.inMilliseconds.toDouble();
                final current = position.inMilliseconds
                    .toDouble()
                    .clamp(0.0, max > 0 ? max : 1.0);
                return Column(
                  children: [
                    Slider(
                      value: current,
                      min: 0,
                      max: max > 0 ? max : 1,
                      onChanged: (v) => _audioPlayer
                          .seek(Duration(milliseconds: v.toInt())),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(position)),
                          Text(_fmt(duration)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 20),
        StreamBuilder<PlayerState>(
          stream: _audioPlayer.playerStateStream,
          builder: (context, snap) {
            final playing = snap.data?.playing ?? false;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10, size: 36),
                  onPressed: () async {
                    final p = _audioPlayer.position;
                    await _audioPlayer.seek(Duration(
                        milliseconds: p.inMilliseconds - 10000));
                  },
                ),
                IconButton(
                  icon: Icon(
                      playing
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      size: 64,
                      color: Colors.blue),
                  onPressed: () async {
                    if (playing) {
                      await _audioPlayer.pause();
                    } else {
                      await _audioPlayer.play();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.forward_10, size: 36),
                  onPressed: () async {
                    final p = _audioPlayer.position;
                    await _audioPlayer.seek(Duration(
                        milliseconds: p.inMilliseconds + 10000));
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}