import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';

// ---------------------------------------------------------------------------
//  Identité visuelle (palette "studio nocturne" : ambre chaud + teal cinéma)
// ---------------------------------------------------------------------------
const Color _bgTop = Color(0xFF0B141A);
const Color _bgBottom = Color(0xFF060A0E);
const Color _surface = Color(0xFF121A21);
const Color _surfaceHi = Color(0xFF1B2630);
const Color _amber = Color(0xFFF2A65A);
const Color _amberDeep = Color(0xFFE07B2E);
const Color _teal = Color(0xFF34D1C4);
const Color _tealDeep = Color(0xFF159C92);
const Color _text = Color(0xFFF3F6F8);
const Color _textDim = Color(0xFF8A98A3);

String _fmt(Duration d) {
  if (d.inMilliseconds < 0 || d == Duration.zero) return '0:00';
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    return '${d.inHours}:$m:$s';
  }
  return '$m:$s';
}

class Track {
  final String path;
  final String name;
  const Track(this.path, this.name);
}

// ---------------------------------------------------------------------------
//  Fond ambiant réutilisable (dégradé + deux halos colorés)
// ---------------------------------------------------------------------------
class _Ambient extends StatelessWidget {
  const _Ambient();
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
      ),
      Positioned(
        top: -120,
        left: -90,
        width: 320,
        height: 320,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [_amber.withValues(alpha: 0.16), Colors.transparent],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: -140,
        right: -100,
        width: 360,
        height: 360,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [_teal.withValues(alpha: 0.13), Colors.transparent],
            ),
          ),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
//  Tuile de liste avec apparition en cascade (fade + glissement)
// ---------------------------------------------------------------------------
class _Reveal extends StatefulWidget {
  final int index;
  final Widget child;
  const _Reveal({required this.index, required this.child});
  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  bool _show = false;
  @override
  void initState() {
    super.initState();
    final delay = (widget.index * 35).clamp(0, 320);
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _show ? 1 : 0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(16 * (1 - t), 0),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
//  Application
// ---------------------------------------------------------------------------
class LecteurMultimediaApp extends StatelessWidget {
  const LecteurMultimediaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lecteur Multimédia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bgBottom,
        colorScheme: const ColorScheme.dark(
          primary: _amber,
          secondary: _teal,
          surface: _surface,
        ),
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
//  Écran d'accueil : deux catégories, sélecteur glissant, bannière en haut
// ---------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _cat = 0; // 0 = Musique, 1 = Vidéo
  final List<Track> _audio = [];
  final List<Track> _video = [];

  Color get _accent => _cat == 0 ? _amber : _teal;

  Future<void> _pick() async {
    final type = _cat == 0 ? FileType.audio : FileType.video;
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowMultiple: true,
    );
    if (result == null) return;
    final added = <Track>[];
    for (final f in result.files) {
      final p = f.path;
      if (p != null) added.add(Track(p, f.name));
    }
    if (added.isEmpty || !mounted) return;
    setState(() {
      (_cat == 0 ? _audio : _video).addAll(added);
    });
  }

  void _open(int i) {
    if (_cat == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MusicScreen(tracks: _audio, index: i)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VideoScreen(tracks: _video, index: i)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _cat == 0 ? _audio : _video;
    final accent = _accent;

    return Scaffold(
      body: Stack(children: [
        const _Ambient(),
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBanner(accent, list.length),
              _buildSelector(accent),
              const SizedBox(height: 8),
              Expanded(
                child: list.isEmpty
                    ? _buildEmpty(accent)
                    : _buildList(list, accent),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildBanner(Color accent, int count) {
    final other = _cat == 0 ? _video.length : _audio.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BIBLIOTHÈQUE LOCALE',
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Lecteur',
                style: TextStyle(
                  color: _text,
                  fontSize: 38,
                  height: 1.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 10),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 350),
                style: TextStyle(
                  color: accent,
                  fontSize: 38,
                  height: 1.0,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -1,
                ),
                child: const Text('Multimédia'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 350),
            style: const TextStyle(color: _textDim, fontSize: 13),
            child: Text(
              _cat == 0
                  ? '$count morceau${count > 1 ? 's' : ''} • $other vidéo${other > 1 ? 's' : ''} en file'
                  : '$count vidéo${count > 1 ? 's' : ''} • $other morceau${other > 1 ? 's' : ''} en file',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelector(Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 4),
      child: SizedBox(
        height: 54,
        child: Stack(children: [
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _surfaceHi, width: 1),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            left: _cat == 0 ? 5 : null,
            right: _cat == 1 ? 5 : null,
            top: 5,
            bottom: 5,
            width: (MediaQuery.of(context).size.width - 44 - 10) / 2,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: _cat == 0
                      ? [_amber, _amberDeep]
                      : [_teal, _tealDeep],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),
          Row(children: [
            _tabLabel(0, Icons.music_note_rounded, 'Musique'),
            _tabLabel(1, Icons.movie_rounded, 'Vidéo'),
          ]),
        ]),
      ),
    );
  }

  Widget _tabLabel(int i, IconData icon, String label) {
    final active = _cat == i;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _cat = i),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: active ? _bgBottom : _textDim),
            const SizedBox(width: 8),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                color: active ? _bgBottom : _textDim,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(Color accent) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _cat == 0 ? Icons.library_music_outlined : Icons.video_library_outlined,
              size: 64,
              color: accent.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 18),
            Text(
              _cat == 0
                  ? 'Aucun morceau pour l’instant'
                  : 'Aucune vidéo pour l’instant',
              style: const TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _cat == 0
                  ? 'Ajoute des fichiers audio : seuls les sons apparaîtront ici.'
                  : 'Ajoute des fichiers vidéo : seuls les films apparaîtront ici.',
              style: const TextStyle(color: _textDim, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 26),
            _addButton(accent, large: true),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Track> list, Color accent) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 100),
      itemCount: list.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) return _addButton(accent, large: false);
        final t = list[i - 1];
        return _Reveal(
          index: i,
          child: _Tile(
            track: t,
            accent: accent,
            isAudio: _cat == 0,
            onTap: () => _open(i - 1),
          ),
        );
      },
    );
  }

  Widget _addButton(Color accent, {required bool large}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _pick,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: large ? 56 : 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: accent, size: 22),
              const SizedBox(width: 10),
              Text(
                _cat == 0 ? 'Ajouter de la musique' : 'Ajouter des vidéos',
                style: TextStyle(
                  color: accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final Track track;
  final Color accent;
  final bool isAudio;
  final VoidCallback onTap;
  const _Tile({
    required this.track,
    required this.accent,
    required this.isAudio,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _surfaceHi, width: 1),
          ),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent.withValues(alpha: 0.22), accent.withValues(alpha: 0.06)],
                ),
              ),
              child: Icon(
                isAudio ? Icons.music_note_rounded : Icons.movie_rounded,
                color: accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _textDim, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.play_circle_outline_rounded, color: accent.withValues(alpha: 0.8), size: 30),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Écran MUSIQUE : bannière (disque qui tourne) + progression + prev / next
// ---------------------------------------------------------------------------
class MusicScreen extends StatefulWidget {
  final List<Track> tracks;
  final int index;
  const MusicScreen({super.key, required this.tracks, required this.index});
  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  late AnimationController _spin;
  int _index = 0;
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _drag = false;

  @override
  void initState() {
    super.initState();
    _index = widget.index.clamp(0, widget.tracks.length - 1);
    _spin = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
    _player.positionStream.listen((p) {
      if (!_drag && mounted) setState(() => _pos = p);
    });
    _player.durationStream.listen((d) {
      if (mounted) setState(() => _dur = d ?? Duration.zero);
    });
    _player.playingStream.listen((pl) {
      if (mounted) setState(() => _playing = pl);
    });
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) _next();
    });
    _load(_index, autoplay: true);
  }

  Future<void> _load(int i, {bool autoplay = false}) async {
    if (widget.tracks.isEmpty) return;
    final i2 = i % widget.tracks.length;
    try {
      await _player.setFilePath(widget.tracks[i2].path);
      if (!mounted) return;
      setState(() {
        _index = i2;
        _pos = Duration.zero;
      });
      if (autoplay) await _player.play();
    } catch (_) {
      if (!mounted) return;
      setState(() => _index = i2);
    }
  }

  void _next() => _load(_index + 1, autoplay: true);
  void _prev() => _load(_index - 1 + widget.tracks.length, autoplay: true);

  @override
  void dispose() {
    _spin.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tracks[_index];
    final maxMs = _dur.inMilliseconds < 1 ? 1.0 : _dur.inMilliseconds.toDouble();
    return Scaffold(
      body: Stack(children: [
        const _Ambient(),
        SafeArea(
          child: Column(children: [
            _topBar('En lecture'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(children: [
                  const SizedBox(height: 8),
                  TickerMode(
                    enabled: _playing,
                    child: RotationTransition(
                      turns: _spin,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: 230,
                        height: 230,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [_surfaceHi, _surface, _bgBottom],
                            stops: [0.0, 0.6, 1.0],
                          ),
                          border: Border.all(
                            color: _amber.withValues(alpha: 0.35),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _amber.withValues(alpha: _playing ? 0.4 : 0.12),
                              blurRadius: _playing ? 40 : 18,
                              spreadRadius: _playing ? 2 : 0,
                            ),
                          ],
                        ),
                        child: Stack(alignment: Alignment.center, children: [
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _text.withValues(alpha: 0.06),
                                width: 1,
                              ),
                            ),
                          ),
                          Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [_amber, _amberDeep],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _amberDeep.withValues(alpha: 0.5),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: _bgBottom,
                            ),
                          ),
                          Positioned(
                            top: 30,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _text.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    t.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Piste ${_index + 1} / ${widget.tracks.length}',
                    style: const TextStyle(
                      color: _textDim,
                      fontSize: 12,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 26),
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      activeTrackColor: _amber,
                      inactiveTrackColor: _surfaceHi,
                      thumbColor: _amber,
                      overlayColor: _amber.withValues(alpha: 0.18),
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: _pos.inMilliseconds.toDouble().clamp(0, maxMs),
                      min: 0,
                      max: maxMs,
                      onChanged: (v) {
                        setState(() {
                          _drag = true;
                          _pos = Duration(milliseconds: v.round());
                        });
                      },
                      onChangeStart: (_) => setState(() => _drag = true),
                      onChangeEnd: (v) {
                        _player.seek(Duration(milliseconds: v.round()));
                        setState(() => _drag = false);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(_pos),
                            style: const TextStyle(color: _textDim, fontSize: 12)),
                        Text(_fmt(_dur),
                            style: const TextStyle(color: _textDim, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ctrlBtn(Icons.skip_previous_rounded, _prev, 38, _amber),
                      const SizedBox(width: 30),
                      _playPause(),
                      const SizedBox(width: 30),
                      _ctrlBtn(Icons.skip_next_rounded, _next, 38, _amber),
                    ],
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _playPause() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _playing ? _player.pause() : _player.play(),
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [_amber, _amberDeep]),
            boxShadow: [
              BoxShadow(
                color: _amber.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey(_playing),
              color: _bgBottom,
              size: 44,
            ),
          ),
        ),
      ),
    );
  }

  Widget _ctrlBtn(IconData icon, VoidCallback onTap, double size, Color c) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: c, size: size),
        ),
      ),
    );
  }

  Widget _topBar(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _text),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: _text,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const Spacer(),
        const Icon(Icons.music_note_rounded, color: _amber, size: 22),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
//  Écran VIDÉO : bannière (lecteur) + progression + prev / next
// ---------------------------------------------------------------------------
class VideoScreen extends StatefulWidget {
  final List<Track> tracks;
  final int index;
  const VideoScreen({super.key, required this.tracks, required this.index});
  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  VideoPlayerController? _ctrl;
  int _index = 0;
  bool _ready = false;
  bool _err = false;

  @override
  void initState() {
    super.initState();
    _index = widget.index.clamp(0, widget.tracks.length - 1);
    _load(_index);
  }

  Future<void> _load(int i) async {
    if (widget.tracks.isEmpty) return;
    final i2 = i % widget.tracks.length;
    final old = _ctrl;
    _ctrl = null;
    _ready = false;
    _err = false;
    if (mounted) setState(() => _index = i2);
    await old?.dispose();
    final c = VideoPlayerController.file(File(widget.tracks[i2].path));
    _ctrl = c;
    c.addListener(_tick);
    try {
      await c.initialize();
      if (!mounted || _ctrl != c) return;
      setState(() => _ready = true);
      await c.play();
    } catch (_) {
      if (!mounted || _ctrl != c) return;
      setState(() => _err = true);
    }
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  void _next() => _load(_index + 1);
  void _prev() => _load(_index - 1 + widget.tracks.length);

  @override
  void dispose() {
    _ctrl?.removeListener(_tick);
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tracks[_index];
    final c = _ctrl;
    final initialized = _ready && c != null && c.value.isInitialized;
    final playing = initialized && c.value.isPlaying;
    final pos = initialized ? c.value.position : Duration.zero;
    final dur = initialized && c.value.duration.inMilliseconds > 0
        ? c.value.duration
        : const Duration(milliseconds: 1);

    return Scaffold(
      body: Stack(children: [
        const _Ambient(),
        SafeArea(
          child: Column(children: [
            _topBar('Lecture vidéo'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(children: [
                  const SizedBox(height: 6),
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _teal.withValues(alpha: 0.4), width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: _teal.withValues(alpha: 0.25),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        alignment: Alignment.center,
                        children: [
                          Container(color: Colors.black),
                          if (initialized)
                            Center(
                              child: AspectRatio(
                                aspectRatio: c.value.aspectRatio == 0
                                    ? 16 / 9
                                    : c.value.aspectRatio,
                                child: VideoPlayer(c),
                              ),
                            ),
                          if (_err)
                            const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline_rounded,
                                    color: _textDim, size: 40),
                                SizedBox(height: 8),
                                Text('Lecture impossible',
                                    style: TextStyle(color: _textDim)),
                              ],
                            )
                          else if (!initialized)
                            const CircularProgressIndicator(color: _teal),
                          if (initialized)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => playing ? c.pause() : c.play(),
                                child: AnimatedOpacity(
                                  opacity: playing ? 0.0 : 1.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withValues(alpha: 0.45),
                                    ),
                                    child: const Icon(Icons.play_arrow_rounded,
                                        color: _teal, size: 44),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    t.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Vidéo ${_index + 1} / ${widget.tracks.length}',
                    style: const TextStyle(
                      color: _textDim,
                      fontSize: 12,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      activeTrackColor: _teal,
                      inactiveTrackColor: _surfaceHi,
                      thumbColor: _teal,
                      overlayColor: _teal.withValues(alpha: 0.18),
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: pos.inMilliseconds
                          .toDouble()
                          .clamp(0, dur.inMilliseconds.toDouble()),
                      min: 0,
                      max: dur.inMilliseconds.toDouble(),
                      onChanged: initialized
                          ? (v) => c.seekTo(Duration(milliseconds: v.round()))
                          : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(pos),
                            style: const TextStyle(color: _textDim, fontSize: 12)),
                        Text(_fmt(initialized ? c.value.duration : Duration.zero),
                            style: const TextStyle(color: _textDim, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ctrlBtn(Icons.skip_previous_rounded, _prev, 38),
                      const SizedBox(width: 30),
                      _playPause(playing, initialized),
                      const SizedBox(width: 30),
                      _ctrlBtn(Icons.skip_next_rounded, _next, 38),
                    ],
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _playPause(bool playing, bool initialized) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: initialized
            ? () => playing ? _ctrl!.pause() : _ctrl!.play()
            : null,
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [_teal, _tealDeep]),
            boxShadow: [
              BoxShadow(
                color: _teal.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey(playing),
              color: _bgBottom,
              size: 44,
            ),
          ),
        ),
      ),
    );
  }

  Widget _ctrlBtn(IconData icon, VoidCallback onTap, double size) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: _teal, size: size),
        ),
      ),
    );
  }

  Widget _topBar(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _text),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: _text,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const Spacer(),
        const Icon(Icons.movie_rounded, color: _teal, size: 22),
      ]),
    );
  }
}