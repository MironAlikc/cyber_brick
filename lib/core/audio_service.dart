import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'app_settings.dart';

enum Sfx {
  move,
  rotate,
  lock,
  drop,
  hold,
  line,
  tetris,
  gameOver,
  click,
  claim,
}

class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  static const Map<Sfx, String> _files = {
    Sfx.move: 'move.wav',
    Sfx.rotate: 'rotate.wav',
    Sfx.lock: 'lock.wav',
    Sfx.drop: 'drop.wav',
    Sfx.hold: 'hold.wav',
    Sfx.line: 'line.wav',
    Sfx.tetris: 'tetris.wav',
    Sfx.gameOver: 'gameover.wav',
    Sfx.click: 'click.wav',
    Sfx.claim: 'claim.wav',
  };

  static const String _musicFile = 'music.wav';

  final Map<Sfx, AudioPlayer> _players = {};
  AudioPlayer? _music;
  bool _ready = false;
  bool _musicStarted = false;

  Future<void> init() async {
    try {
      await AudioCache.instance.loadAll([
        ..._files.values.map((f) => 'audio/$f'),
        'audio/$_musicFile',
      ]);

      for (final sfx in _files.keys) {
        final player = AudioPlayer();
        await player.setPlayerMode(PlayerMode.lowLatency);
        _players[sfx] = player;
      }

      final music = AudioPlayer();
      await music.setReleaseMode(ReleaseMode.loop);
      await music.setVolume(0.4);
      _music = music;

      _ready = true;
    } catch (e) {
      debugPrint('AudioService init failed: $e');
    }
  }

  // ───────────────────────── Эффекты ─────────────────────────

  void play(Sfx sfx) {
    if (!_ready || !AppSettings.soundOn) return;
    final player = _players[sfx];
    if (player == null) return;
    unawaited(
      player.play(AssetSource('audio/${_files[sfx]}')).catchError((_) {}),
    );
  }

  // ───────────────────────── Музыка ─────────────────────────

  /// Приводит музыку в соответствие с настройкой MUSIC.
  Future<void> syncMusic() async {
    final music = _music;
    if (!_ready || music == null) return;
    try {
      if (AppSettings.musicOn) {
        if (!_musicStarted) {
          await music.play(AssetSource('audio/$_musicFile'));
          _musicStarted = true;
        } else if (music.state != PlayerState.playing) {
          await music.resume();
        }
      } else {
        await music.pause();
      }
    } catch (e) {
      debugPrint('syncMusic failed: $e');
    }
  }

  Future<void> pauseMusic() async {
    try {
      await _music?.pause();
    } catch (_) {}
  }
}
