import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_service.dart';

class VideoCallScreen extends StatefulWidget {
  final CallState initialState;
  const VideoCallScreen({super.key, this.initialState = CallState.connected});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _isMuted = false;
  bool _isVideoOff = false;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  StreamSubscription<MediaStream?>? _localSub;
  StreamSubscription<MediaStream?>? _remoteSub;

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    _localSub = WebRTCService.localStream.listen((stream) {
      if (mounted) {
        setState(() {
          _localRenderer.srcObject = stream;
        });
      }
    });

    _remoteSub = WebRTCService.remoteStream.listen((stream) {
      if (mounted) {
        setState(() {
          _remoteRenderer.srcObject = stream;
        });
      }
    });
  }

  @override
  void dispose() {
    _localSub?.cancel();
    _remoteSub?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<CallState>(
        stream: WebRTCService.callState,
        initialData: widget.initialState,
        builder: (context, stateSnapshot) {
          final state = stateSnapshot.data ?? CallState.idle;
          if (state == CallState.calling) {
            return _buildCallingUI();
          }
          if (state == CallState.incoming) {
            return _buildIncomingUI();
          }
          if (state == CallState.rejected || state == CallState.ended || state == CallState.failed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            });
          }
          return _buildCallUI(state);
        },
      ),
    );
  }

  Widget _buildCallingUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 120),
        const CircularProgressIndicator(color: Colors.white),
        const SizedBox(height: 32),
        const Text('正在呼叫...', style: TextStyle(color: Colors.white, fontSize: 20)),
        const Spacer(),
        _buildHangUpButton(),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildIncomingUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.videocam, size: 80, color: Colors.white),
        const SizedBox(height: 32),
        const Text('收到视频通话', style: TextStyle(color: Colors.white, fontSize: 20)),
        const SizedBox(height: 16),
        const Text('对方邀请你进行视频通话', style: TextStyle(color: Colors.white70, fontSize: 14)),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildRoundButton(
              icon: Icons.call_end,
              color: Colors.red,
              label: '拒绝',
              onTap: () => WebRTCService.rejectCall(),
            ),
            const SizedBox(width: 48),
            _buildRoundButton(
              icon: Icons.call,
              color: const Color(0xFF07C160),
              label: '接听',
              onTap: () => WebRTCService.acceptCall(),
            ),
          ],
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildCallUI(CallState state) {
    return Stack(
      children: [
        // 远程视频（全屏）
        Positioned.fill(
          child: _remoteRenderer.srcObject != null
            ? RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            : const Center(
                child: Text('等待对方连接...', style: TextStyle(color: Colors.white70)),
              ),
        ),
        // 本地视频（小窗口，右上角）
        Positioned(
          top: 48,
          right: 16,
          child: Container(
            width: 120,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white30, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _localRenderer.srcObject != null
                ? RTCVideoView(
                    _localRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    mirror: true,
                  )
                : const Center(
                    child: Icon(Icons.videocam_off, color: Colors.white30),
                  ),
            ),
          ),
        ),
        // 顶部状态栏
        Positioned(
          top: 48,
          left: 16,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                state == CallState.connecting ? '连接中...' : '通话中',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),
        // 底部控制栏
        Positioned(
          bottom: 48,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildControlButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  label: _isMuted ? '取消静音' : '静音',
                  onTap: () async {
                    await WebRTCService.toggleMute();
                    setState(() => _isMuted = !_isMuted);
                  },
                ),
                const SizedBox(width: 24),
                _buildControlButton(
                  icon: Icons.switch_camera,
                  label: '切换',
                  onTap: () => WebRTCService.switchCamera(),
                ),
                const SizedBox(width: 24),
                _buildControlButton(
                  icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                  label: _isVideoOff ? '开启视频' : '关闭视频',
                  onTap: () async {
                    await WebRTCService.toggleVideo();
                    setState(() => _isVideoOff = !_isVideoOff);
                  },
                ),
                const SizedBox(width: 24),
                _buildHangUpButton(small: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildHangUpButton({bool small = false}) {
    final size = small ? 52.0 : 64.0;
    return GestureDetector(
      onTap: () => WebRTCService.endCall(),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.call_end, color: Colors.white, size: small ? 24 : 32),
      ),
    );
  }
}
