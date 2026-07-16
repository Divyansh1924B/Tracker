import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlaybackState {
  final bool isPlaying;
  final int currentIndex;
  final double speed;

  PlaybackState({
    required this.isPlaying,
    required this.currentIndex,
    required this.speed,
  });

  PlaybackState copyWith({
    bool? isPlaying,
    int? currentIndex,
    double? speed,
  }) {
    return PlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      currentIndex: currentIndex ?? this.currentIndex,
      speed: speed ?? this.speed,
    );
  }
}

class PlaybackController extends StateNotifier<PlaybackState> {
  Timer? _timer;
  int _maxIndex = 0;

  PlaybackController() : super(PlaybackState(isPlaying: false, currentIndex: 0, speed: 1.0));

  void setMaxIndex(int maxIndex) {
    _maxIndex = maxIndex;
    if (state.currentIndex >= _maxIndex) {
      state = state.copyWith(currentIndex: 0);
    }
  }

  void play() {
    if (state.isPlaying) return;
    state = state.copyWith(isPlaying: true);
    _startTimer();
  }

  void pause() {
    _timer?.cancel();
    state = state.copyWith(isPlaying: false);
  }

  void stop() {
    _timer?.cancel();
    state = state.copyWith(isPlaying: false, currentIndex: 0);
  }

  void setSpeed(double newSpeed) {
    state = state.copyWith(speed: newSpeed);
    if (state.isPlaying) {
      _timer?.cancel();
      _startTimer();
    }
  }

  void setIndex(int index) {
    if (index >= 0 && index <= _maxIndex) {
      state = state.copyWith(currentIndex: index);
    }
  }

  void _startTimer() {
    final intervalMs = (1000 / state.speed).round();
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (state.currentIndex < _maxIndex) {
        state = state.copyWith(currentIndex: state.currentIndex + 1);
      } else {
        pause();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final playbackControllerProvider =
    StateNotifierProvider.autoDispose<PlaybackController, PlaybackState>((ref) {
  return PlaybackController();
});
