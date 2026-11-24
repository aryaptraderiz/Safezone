import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ReportVideoPlayer extends StatefulWidget {
  final String? url;
  final File? file;
  final VoidCallback? onExpand;
  final VideoPlayerController? controller;
  final bool disposeController;

  const ReportVideoPlayer({
    super.key,
    this.url,
    this.file,
    this.onExpand,
    this.controller,
    this.disposeController = true,
  });

  @override
  State<ReportVideoPlayer> createState() => _ReportVideoPlayerState();
}

class _ReportVideoPlayerState extends State<ReportVideoPlayer> {
  late VideoPlayerController _controller;
  late final bool _ownsController;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        (widget.file != null
            ? VideoPlayerController.file(widget.file!)
            : VideoPlayerController.networkUrl(Uri.parse(widget.url!)));
    if (_ownsController) _initializeController();
    _controller.addListener(_handleControllerUpdate);
  }

  Future<void> _initializeController() async {
    try {
      await _controller.initialize();
    } catch (_) {
      _failed = true;
    }
    if (mounted) setState(() {});
  }

  void _handleControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerUpdate);
    if (_ownsController && widget.disposeController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _controller.value.isInitialized
          ? _controller.value.aspectRatio
          : 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: _failed
            ? const Center(
                child: Icon(Icons.videocam_off_outlined,
                    color: Colors.white70, size: 36),
              )
            : _controller.value.isInitialized
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(_controller),
                      IconButton.filled(
                        onPressed: () => setState(() {
                          _controller.value.isPlaying
                              ? _controller.pause()
                              : _controller.play();
                        }),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0x99000000),
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(_controller.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded),
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 2,
                        child: VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Colors.redAccent,
                            bufferedColor: Colors.white54,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      ),
                      if (widget.onExpand != null)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: IconButton.filled(
                            tooltip: 'Perbesar video',
                            onPressed: widget.onExpand,
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0x99000000),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.fullscreen_rounded),
                          ),
                        ),
                    ],
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
      ),
    );
  }
}
