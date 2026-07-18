import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_service.dart';

class WebRTCService {
  static RTCPeerConnection? _peerConnection;
  static MediaStream? _localStream;
  static MediaStream? _remoteStream;
  static final _localStreamController = StreamController<MediaStream?>.broadcast();
  static final _remoteStreamController = StreamController<MediaStream?>.broadcast();
  static final _callStateController = StreamController<CallState>.broadcast();
  static String? _targetSocketId;
  static bool _isCaller = false;
  static final List<StreamSubscription> _subscriptions = [];

  static Stream<MediaStream?> get localStream => _localStreamController.stream;
  static Stream<MediaStream?> get remoteStream => _remoteStreamController.stream;
  static Stream<CallState> get callState => _callStateController.stream;

  static CallState _currentState = CallState.idle;
  static CallState get currentState => _currentState;

  static bool get isInCall => _currentState == CallState.connected || _currentState == CallState.connecting;

  static void _setState(CallState state) {
    _currentState = state;
    _callStateController.add(state);
  }

  static Future<void> initListeners() async {
    _disposeSubscriptions();

    _subscriptions.add(SocketService.onIncomingCall.listen((data) async {
      if (_currentState == CallState.idle) {
        _targetSocketId = data['fromSocketId'] as String?;
        _isCaller = false;
        _setState(CallState.incoming);
      }
    }));

    _subscriptions.add(SocketService.onCallAccepted.listen((data) async {
      if (_currentState == CallState.calling && _isCaller) {
        _targetSocketId = data['socketId'] as String?;
        await _createPeerConnection();
        final offer = await _peerConnection!.createOffer({});
        await _peerConnection!.setLocalDescription(offer);
        SocketService.sendWebrtcOffer(_targetSocketId!, offer.toMap());
        _setState(CallState.connecting);
      }
    }));

    _subscriptions.add(SocketService.onCallRejected.listen((data) {
      if (_currentState == CallState.calling) {
        _setState(CallState.rejected);
        _cleanup();
      }
    }));

    _subscriptions.add(SocketService.onCallEnded.listen((data) {
      _setState(CallState.ended);
      _cleanup();
    }));

    _subscriptions.add(SocketService.onWebrtcOffer.listen((data) async {
      if (!_isCaller && _currentState == CallState.incoming) {
        await _createPeerConnection();
        final offer = RTCSessionDescription(
          data['offer']['sdp'] as String?,
          data['offer']['type'] as String?,
        );
        await _peerConnection!.setRemoteDescription(offer);
        final answer = await _peerConnection!.createAnswer({});
        await _peerConnection!.setLocalDescription(answer);
        SocketService.sendWebrtcAnswer(_targetSocketId!, answer.toMap());
        _setState(CallState.connecting);
      }
    }));

    _subscriptions.add(SocketService.onWebrtcAnswer.listen((data) async {
      if (_isCaller && _currentState == CallState.connecting) {
        final answer = RTCSessionDescription(
          data['answer']['sdp'] as String?,
          data['answer']['type'] as String?,
        );
        await _peerConnection!.setRemoteDescription(answer);
      }
    }));

    _subscriptions.add(SocketService.onWebrtcIceCandidate.listen((data) async {
      if (_peerConnection != null) {
        final candidate = RTCIceCandidate(
          data['candidate']['candidate'] as String?,
          data['candidate']['sdpMid'] as String?,
          data['candidate']['sdpMLineIndex'] as int?,
        );
        await _peerConnection!.addCandidate(candidate);
      }
    }));
  }

  static Future<void> _createPeerConnection() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
    };

    _peerConnection = await createPeerConnection(config);

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'},
    });

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    _localStreamController.add(_localStream);

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        _remoteStreamController.add(_remoteStream);
        _setState(CallState.connected);
      }
    };

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate != null && _targetSocketId != null) {
        SocketService.sendWebrtcIceCandidate(_targetSocketId!, candidate.toMap());
      }
    };

    _peerConnection!.onConnectionState = (state) {
      print('WebRTC connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _setState(CallState.failed);
        _cleanup();
      }
    };
  }

  static Future<void> startCall(String targetUserId) async {
    if (_currentState != CallState.idle) return;
    _isCaller = true;
    _setState(CallState.calling);
    SocketService.callRequest(targetUserId);
  }

  static Future<void> acceptCall() async {
    if (_currentState != CallState.incoming || _targetSocketId == null) return;
    SocketService.callAccept(_targetSocketId!);
  }

  static Future<void> rejectCall() async {
    if (_targetSocketId != null) {
      SocketService.callReject(_targetSocketId!);
    }
    _setState(CallState.rejected);
    _cleanup();
  }

  static Future<void> endCall() async {
    if (_targetSocketId != null) {
      SocketService.callEnd(_targetSocketId!);
    }
    _setState(CallState.ended);
    _cleanup();
  }

  static Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!
          .getVideoTracks()
          .firstWhere((t) => t.kind == 'video');
      await Helper.switchCamera(videoTrack);
    }
  }

  static Future<void> toggleMute() async {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().firstOrNull;
      if (audioTrack != null) {
        audioTrack.enabled = !audioTrack.enabled;
      }
    }
  }

  static Future<void> toggleVideo() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        videoTrack.enabled = !videoTrack.enabled;
      }
    }
  }

  static void _cleanup() {
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;
    _remoteStream = null;
    _peerConnection?.close();
    _peerConnection = null;
    _targetSocketId = null;
    _isCaller = false;
    _localStreamController.add(null);
    _remoteStreamController.add(null);
    Future.delayed(const Duration(milliseconds: 500), () {
      _setState(CallState.idle);
    });
  }

  static void _disposeSubscriptions() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  static void dispose() {
    _cleanup();
    _disposeSubscriptions();
    _localStreamController.close();
    _remoteStreamController.close();
    _callStateController.close();
  }
}

enum CallState {
  idle,
  calling,
  incoming,
  connecting,
  connected,
  rejected,
  ended,
  failed,
}
