// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:ui';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:video_player/video_player.dart';

class CustomChewieControls extends StatefulWidget {
  final bool hasPreviousVideo;
  final bool hasNextVideo;
  final VoidCallback? onPreviousVideo;
  final VoidCallback? onNextVideo;
  final Color primaryColor;
  final bool showQualitySelector;
  final List<String>? availableQualities;
  final Function(String)? onQualityChanged;
  final String? currentQuality;

  const CustomChewieControls({
    super.key,
    this.hasPreviousVideo = false,
    this.hasNextVideo = false,
    this.onPreviousVideo,
    this.onNextVideo,
    this.primaryColor = AppColors.buttonPrimary,
    this.showQualitySelector = false,
    this.availableQualities,
    this.onQualityChanged,
    this.currentQuality,
  });

  @override
  State<CustomChewieControls> createState() => _CustomChewieControlsState();
}

class _CustomChewieControlsState extends State<CustomChewieControls>
    with SingleTickerProviderStateMixin {
  // Animation and control variables
  late AnimationController _controlsAnimationController;
  bool _controlsVisible = true;
  late VideoPlayerValue _latestValue;
  Timer? _bufferingTimer;
  bool _displayBufferingIndicator = false;
  bool _dragging = false;

  // Track tapped position on progress bar for more accurate seeking
  double? _seekPos;

  // Playback speeds
  final List<double> _playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  // Controller references
  ChewieController? _chewieController;

  // Quality options with Auto as default
  List<String> get _qualityOptions {
    if (widget.availableQualities == null ||
        widget.availableQualities!.isEmpty) {
      return ['Auto'];
    }
    final List<String> qualities = ['Auto'];
    for (String quality in widget.availableQualities!) {
      if (quality != 'Auto') {
        qualities.add(quality);
      }
    }
    return qualities;
  }

  @override
  void initState() {
    super.initState();
    _controlsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Delay hiding controls to give user time to interact
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _hideControls();
      }
    });
  }

  @override
  void dispose() {
    _bufferingTimer?.cancel();
    _controlsAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chewieController = ChewieController.of(context);
    if (_chewieController != null &&
        _chewieController!.videoPlayerController.value.isInitialized) {
      _latestValue = _chewieController!.videoPlayerController.value;
      _chewieController!.videoPlayerController.addListener(_updateState);
    }
  }

  void _updateState() {
    if (!mounted) return;

    final newValue = _chewieController!.videoPlayerController.value;
    final isBuffering = _latestValue.isBuffering != newValue.isBuffering;

    if (isBuffering) {
      _displayBufferingIndicator = true;
      _bufferingTimer?.cancel();
      _bufferingTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _displayBufferingIndicator = false);
        }
      });
    }

    // Reset hide timer when playing starts
    if (!_latestValue.isPlaying && newValue.isPlaying) {
      _cancelAndRestartTimer();
    }

    setState(() {
      _latestValue = newValue;
    });
  }

  void _cancelAndRestartTimer() {
    _controlsAnimationController.forward();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _controlsVisible && !_dragging) {
        _hideControls();
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
      if (_controlsVisible) {
        _controlsAnimationController.forward();
        _cancelAndRestartTimer();
      } else {
        _controlsAnimationController.reverse();
      }
    });
  }

  void _hideControls() {
    if (_dragging) return;
    setState(() {
      _controlsVisible = false;
      _controlsAnimationController.reverse();
    });
  }

  void _showControls() {
    setState(() {
      _controlsVisible = true;
      _controlsAnimationController.forward();
    });
    _cancelAndRestartTimer();
  }

  @override
  Widget build(BuildContext context) {
    // For responsive UI
    final mediaSize = MediaQuery.of(context).size;
    final bool isSmallScreen = mediaSize.width < 480;
    final bool isFullScreen = _chewieController?.isFullScreen ?? false;

    // Size multiplier based on screen and mode
    final sizeFactor = isFullScreen ? 1.0 : (isSmallScreen ? 0.8 : 0.9);

    if (_chewieController == null ||
        !_chewieController!.videoPlayerController.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: widget.primaryColor),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Video layer
            Center(
              child: AspectRatio(
                aspectRatio:
                    _chewieController!.videoPlayerController.value.aspectRatio,
                child: VideoPlayer(_chewieController!.videoPlayerController),
              ),
            ),

            // Buffering indicator
            if (_displayBufferingIndicator) _buildBufferingIndicator(),

            // Controls overlay with animation
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 1000),
              child: AbsorbPointer(
                absorbing: !_controlsVisible,
                child: Stack(
                  children: [
                    // Dark gradient overlay
                    // _buildGradientOverlay(),

                    // Improve layout structure to avoid overlapping
                    Column(
                      children: [
                        // Top controls (fullscreen, title)
                        Align(
                          alignment: Alignment.topCenter,
                          child: _buildTopControls(sizeFactor, isFullScreen),
                        ),
                        // SizedBox(height: 10),

                        Spacer(),
                        // Add expanded space to push center and bottom apart

                        // Center controls (play/pause, next/prev)
                        _buildCenterControls(sizeFactor, isFullScreen),

                        // Add more space between center and bottom controls
                        // SizedBox(height: 10),
                        Spacer(),

                        // Bottom control bar
                        _buildBottomControls(sizeFactor, isFullScreen),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.6),
            Colors.transparent.withOpacity(0.1),
            Colors.transparent.withOpacity(0.1),
            Colors.black.withOpacity(0.6),
          ],
          stops: const [0.0, 0.25, 0.75, 1.0],
        ),
      ),
    );
  }

  Widget _buildBufferingIndicator() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(widget.primaryColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls(double sizeFactor, bool isFullScreen) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 8 * sizeFactor,
            vertical: 4 * sizeFactor,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.6),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            children: [
              if (isFullScreen)
                GestureDetector(
                  onTap: () {
                    _chewieController!.toggleFullScreen();
                    _cancelAndRestartTimer();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.fullscreen_exit,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  _chewieController!.toggleFullScreen();
                  _cancelAndRestartTimer();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.white,
                    size: 20 * sizeFactor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterControls(double sizeFactor, bool isFullScreen) {
    final buttonSize = 48.0 * sizeFactor;
    final iconSize = 24.0 * sizeFactor;
    final arrowIconSize = 20.0 * sizeFactor;
    final playButtonSize = 64.0 * sizeFactor;
    final playIconSize = 32.0 * sizeFactor;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Using a Stack with fixed-width Row to ensure center alignment
          SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Main play/pause button always centered
                _buildRoundButton(
                  icon: _latestValue.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  onTap: _togglePlay,
                  size: playButtonSize,
                  iconSize: playIconSize,
                  tooltip: _latestValue.isPlaying ? 'Pause' : 'Play',
                  color: widget.primaryColor,
                ),
              ],
            ),
          ),

          // Place previous/next buttons as positioned overlays
          // This ensures they don't affect the positioning of the center button
          Positioned(
            left: widget.hasPreviousVideo ? 200 * sizeFactor : null,
            child: widget.hasPreviousVideo
                ? _buildRoundButton(
                    icon: Icons.skip_previous_rounded,
                    onTap: widget.onPreviousVideo,
                    size: buttonSize,
                    iconSize: arrowIconSize,
                    tooltip: 'Previous Video',
                    color: widget.primaryColor.withOpacity(0.5),
                  )
                : const SizedBox.shrink(),
          ),

          Positioned(
            right: widget.hasNextVideo ? 200 * sizeFactor : null,
            child: widget.hasNextVideo
                ? _buildRoundButton(
                    icon: Icons.skip_next_rounded,
                    onTap: widget.onNextVideo,
                    size: buttonSize,
                    iconSize: arrowIconSize,
                    tooltip: 'Next Video',
                    color: widget.primaryColor.withOpacity(0.5),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required VoidCallback? onTap,
    required double size,
    required double iconSize,
    required String tooltip,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          onTap();
          _cancelAndRestartTimer();
        }
      },
      child: Tooltip(
        message: tooltip,
        child: Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(double sizeFactor, bool isFullScreen) {
    final textSize = 12.0 * sizeFactor;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: 0 * sizeFactor,
              vertical: isFullScreen
                  ? 0 * sizeFactor
                  : 0 * sizeFactor), // Reduced padding for non-fullscreen mode
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withOpacity(0.6),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress bar
              _buildProgressBar(sizeFactor),

              const SizedBox(height: 0), // Reduced spacing

              // Time and controls row
              Row(
                children: [
                  // Time indicators
                  Text(
                    _formatDuration(_latestValue.position),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: textSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    ' / ${_formatDuration(_latestValue.duration)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: textSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const Spacer(),

                  // Control buttons
                  _buildAdvancedControls(sizeFactor, isFullScreen),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedControls(double sizeFactor, bool isFullScreen) {
    final iconSize = 20.0 * sizeFactor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Skip backward button
        _buildControlButton(
          icon: Icons.replay_10_rounded,
          onTap: () => _skipDuration(-10),
          size: iconSize,
          tooltip: 'Skip back 10s',
        ),

        // Skip forward button
        _buildControlButton(
          icon: Icons.forward_10_rounded,
          onTap: () => _skipDuration(10),
          size: iconSize,
          tooltip: 'Skip forward 10s',
        ),

        // Speed control
        _buildPopupButton(
          icon: Icons.speed_rounded,
          items: _playbackSpeeds.map((speed) {
            return PopupMenuItem<double>(
              value: speed,
              child: Row(
                children: [
                  Text('${speed}x'),
                  const SizedBox(width: 4),
                  if (speed == _latestValue.playbackSpeed)
                    Icon(Icons.check, color: widget.primaryColor, size: 14),
                ],
              ),
            );
          }).toList(),
          onSelected: (double speed) {
            _chewieController!.videoPlayerController.setPlaybackSpeed(speed);
            _cancelAndRestartTimer();
          },
          size: iconSize,
          tooltip: 'Playback speed',
        ),

        // Quality control (if enabled)
        if (widget.showQualitySelector)
          _buildPopupButton(
            icon: Icons.hd_rounded,
            items: _qualityOptions.map((quality) {
              return PopupMenuItem<String>(
                value: quality,
                child: Row(
                  children: [
                    Text(quality),
                    const SizedBox(width: 4),
                    if (quality == (widget.currentQuality ?? 'Auto'))
                      Icon(Icons.check, color: widget.primaryColor, size: 14),
                  ],
                ),
              );
            }).toList(),
            onSelected: (String quality) {
              if (widget.onQualityChanged != null) {
                widget.onQualityChanged!(quality);
              }
              _cancelAndRestartTimer();
            },
            size: iconSize,
            tooltip: 'Video quality',
          ),

        // Volume control
        _buildControlButton(
          icon: _latestValue.volume > 0
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          onTap: _toggleMute,
          size: iconSize,
          tooltip: _latestValue.volume > 0 ? 'Mute' : 'Unmute',
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required double size,
    required String tooltip,
  }) {
    return GestureDetector(
      onTap: () {
        onTap();
        _cancelAndRestartTimer();
      },
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            icon,
            color: Colors.white,
            size: size,
          ),
        ),
      ),
    );
  }

  Widget _buildPopupButton<T>({
    required IconData icon,
    required List<PopupMenuItem<T>> items,
    required Function(T) onSelected,
    required double size,
    required String tooltip,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(
        // Pop-up menu theme customization
        popupMenuTheme: PopupMenuThemeData(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.grey[900],
          textStyle: TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ),
      child: PopupMenuButton<T>(
        tooltip: tooltip,
        icon: Icon(
          icon,
          color: Colors.white,
          size: size,
        ),
        onSelected: onSelected,
        offset: const Offset(0, -100),
        itemBuilder: (context) => items,
      ),
    );
  }

  Widget _buildProgressBar(double sizeFactor) {
    final barHeight = 4.0 * sizeFactor;
    final thumbSize = 12.0 * sizeFactor;

    return GestureDetector(
      onHorizontalDragStart: (DragStartDetails details) {
        _dragging = true;

        if (!_controlsVisible) {
          _showControls();
        }
      },
      onHorizontalDragUpdate: (DragUpdateDetails details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final Offset position = box.globalToLocal(details.globalPosition);
        final double rel = position.dx / box.size.width;

        // Set seek position between 0 and 1
        _seekPos = rel.clamp(0.0, 1.0);

        setState(() {
          // Update UI immediately for better feedback
        });
      },
      onHorizontalDragEnd: (DragEndDetails details) {
        if (_seekPos != null) {
          final Duration seekPosition = Duration(
            milliseconds:
                (_seekPos! * _latestValue.duration.inMilliseconds).round(),
          );
          _chewieController!.seekTo(seekPosition);

          _seekPos = null;
          _dragging = false;

          _cancelAndRestartTimer();
        }
      },
      onTapDown: (TapDownDetails details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final Offset tapPosition = box.globalToLocal(details.globalPosition);
        final double rel = tapPosition.dx / box.size.width;

        // Using different variable name to avoid conflict
        final Duration seekPosition = Duration(
          milliseconds: (rel * _latestValue.duration.inMilliseconds).round(),
        );
        _chewieController!.seekTo(seekPosition);

        _cancelAndRestartTimer();
      },
      child: Container(
        // height: max(barHeight * 3, 5), // Increase touch target
        color: Colors.transparent,
        child: Center(
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Background track
              Container(
                height: barHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(barHeight / 2),
                ),
              ),

              // Buffered progress
              LayoutBuilder(
                builder: (context, constraints) {
                  final double maxWidth = constraints.maxWidth;
                  double bufferWidth = 0.0;

                  if (_latestValue.buffered.isNotEmpty) {
                    final int bufferedEndMs =
                        _latestValue.buffered.last.end.inMilliseconds;
                    final int totalDurationMs =
                        _latestValue.duration.inMilliseconds;

                    if (totalDurationMs > 0) {
                      // Calculate buffer percentage and convert to width
                      bufferWidth = maxWidth * bufferedEndMs / totalDurationMs;
                    }
                  }

                  return Container(
                    height: barHeight,
                    width: bufferWidth,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(barHeight / 2),
                    ),
                  );
                },
              ),

              // Played progress
              LayoutBuilder(
                builder: (context, constraints) {
                  final double maxWidth = constraints.maxWidth;
                  double playedWidth;

                  // If user is currently dragging, use drag position
                  if (_seekPos != null) {
                    playedWidth = maxWidth * _seekPos!;
                  } else {
                    playedWidth = maxWidth *
                        _latestValue.position.inMilliseconds /
                        _latestValue.duration.inMilliseconds;
                  }

                  // Ensure width is valid
                  playedWidth = playedWidth.isNaN || playedWidth.isInfinite
                      ? 0.0
                      : playedWidth;

                  return Container(
                    height: barHeight,
                    width: playedWidth,
                    decoration: BoxDecoration(
                      color: widget.primaryColor,
                      borderRadius: BorderRadius.circular(barHeight / 2),
                      boxShadow: [
                        BoxShadow(
                          color: widget.primaryColor.withOpacity(0.5),
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Thumb
              LayoutBuilder(
                builder: (context, constraints) {
                  final double maxWidth = constraints.maxWidth;
                  double playedWidth;

                  // If user is currently dragging, use drag position
                  if (_seekPos != null) {
                    playedWidth = maxWidth * _seekPos!;
                  } else {
                    playedWidth = maxWidth *
                        _latestValue.position.inMilliseconds /
                        _latestValue.duration.inMilliseconds;
                  }

                  // Ensure width is valid
                  playedWidth = playedWidth.isNaN || playedWidth.isInfinite
                      ? 0.0
                      : playedWidth;

                  if (playedWidth > maxWidth) playedWidth = maxWidth;

                  return Positioned(
                    left: playedWidth - (thumbSize / 2),
                    child: Container(
                      height: thumbSize,
                      width: thumbSize,
                      decoration: BoxDecoration(
                        color: widget.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to format duration as mm:ss or hh:mm:ss
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds'
        : '$twoDigitMinutes:$twoDigitSeconds';
  }

  // Action methods
  void _togglePlay() {
    if (_latestValue.isPlaying) {
      _chewieController!.pause();
    } else {
      _chewieController!.play();
    }
    _cancelAndRestartTimer();
  }

  void _toggleMute() {
    if (_latestValue.volume > 0) {
      _chewieController!.setVolume(0);
    } else {
      _chewieController!.setVolume(1.0);
    }
    _cancelAndRestartTimer();
  }

  void _skipDuration(int seconds) {
    final position = _latestValue.position;
    final duration = _latestValue.duration;
    final newPosition = position + Duration(seconds: seconds);

    if (newPosition < Duration.zero) {
      _chewieController!.seekTo(Duration.zero);
    } else if (newPosition > duration) {
      _chewieController!.seekTo(duration);
    } else {
      _chewieController!.seekTo(newPosition);
    }

    _cancelAndRestartTimer();
  }

  // Create a helper function to get max value
  double max(double a, double b) => a > b ? a : b;
}
