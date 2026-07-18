import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_config.dart';
import '../models/message.dart';
import 'auth_service.dart';

class SocketService {
  static io.Socket? _socket;
  static final _messageController = StreamController<Message>.broadcast();
  static final _readController = StreamController<Map<String, dynamic>>.broadcast();
  static final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  static final _onlineController = StreamController<Map<String, dynamic>>.broadcast();
  static final _recallController = StreamController<Map<String, dynamic>>.broadcast();
  static final _locationController = StreamController<Map<String, dynamic>>.broadcast();

  // WebRTC 事件流
  static final _incomingCallController = StreamController<Map<String, dynamic>>.broadcast();
  static final _callAcceptedController = StreamController<Map<String, dynamic>>.broadcast();
  static final _callRejectedController = StreamController<Map<String, dynamic>>.broadcast();
  static final _callEndedController = StreamController<Map<String, dynamic>>.broadcast();
  static final _webrtcOfferController = StreamController<Map<String, dynamic>>.broadcast();
  static final _webrtcAnswerController = StreamController<Map<String, dynamic>>.broadcast();
  static final _webrtcIceCandidateController = StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Message> get onNewMessage => _messageController.stream;
  static Stream<Map<String, dynamic>> get onRead => _readController.stream;
  static Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  static Stream<Map<String, dynamic>> get onOnline => _onlineController.stream;
  static Stream<Map<String, dynamic>> get onRecall => _recallController.stream;
  static Stream<Map<String, dynamic>> get onLocationUpdate => _locationController.stream;

  // WebRTC 事件流 getter
  static Stream<Map<String, dynamic>> get onIncomingCall => _incomingCallController.stream;
  static Stream<Map<String, dynamic>> get onCallAccepted => _callAcceptedController.stream;
  static Stream<Map<String, dynamic>> get onCallRejected => _callRejectedController.stream;
  static Stream<Map<String, dynamic>> get onCallEnded => _callEndedController.stream;
  static Stream<Map<String, dynamic>> get onWebrtcOffer => _webrtcOfferController.stream;
  static Stream<Map<String, dynamic>> get onWebrtcAnswer => _webrtcAnswerController.stream;
  static Stream<Map<String, dynamic>> get onWebrtcIceCandidate => _webrtcIceCandidateController.stream;

  static bool get isConnected => _socket?.connected ?? false;

  static void connect() {
    if (_socket != null) return;
    _socket = io.io(ApiConfig.wsUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'auth': {'token': AuthService.token},
    });

    _socket!.onConnect((_) {
      print('Socket connected');
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
    });

    _socket!.on('new_message', (data) {
      _messageController.add(Message.fromJson(data));
    });

    _socket!.on('message_read', (data) {
      _readController.add(data);
    });

    _socket!.on('message_recalled', (data) {
      _recallController.add(data);
    });

    _socket!.on('location_update', (data) {
      _locationController.add(data);
    });

    _socket!.on('typing', (data) {
      _typingController.add(data);
    });

    _socket!.on('stop_typing', (data) {
      _typingController.add({...data, 'stop': true});
    });

    _socket!.on('user_online', (data) {
      _onlineController.add({...data, 'online': true});
    });

    _socket!.on('user_offline', (data) {
      _onlineController.add({...data, 'online': false});
    });

    // WebRTC 事件监听
    _socket!.on('incoming_call', (data) {
      _incomingCallController.add(data);
    });

    _socket!.on('call_accepted', (data) {
      _callAcceptedController.add(data);
    });

    _socket!.on('call_rejected', (data) {
      _callRejectedController.add(data);
    });

    _socket!.on('call_ended', (data) {
      _callEndedController.add(data);
    });

    _socket!.on('webrtc_offer', (data) {
      _webrtcOfferController.add(data);
    });

    _socket!.on('webrtc_answer', (data) {
      _webrtcAnswerController.add(data);
    });

    _socket!.on('webrtc_ice_candidate', (data) {
      _webrtcIceCandidateController.add(data);
    });

    _socket!.connect();
  }

  // 支持附件（type + attachment）
  static void sendMessage(String to, String content, {String type = 'text', Map<String, dynamic>? attachment}) {
    _socket?.emit('private_message', {
      'to': to,
      'content': content,
      'type': type,
      'attachment': attachment,
    });
  }

  // 撤回消息
  static void recallMessage(String messageId) {
    _socket?.emit('recall_message', {'messageId': messageId});
  }

  static void sendTyping(String to) {
    _socket?.emit('typing', {'to': to});
  }

  static void sendStopTyping(String to) {
    _socket?.emit('stop_typing', {'to': to});
  }

  static void markRead(String messageId) {
    _socket?.emit('mark_read', {'messageId': messageId});
  }

  static void emitLocationUpdate(Map<String, dynamic> data) {
    _socket?.emit('location_update', data);
  }

  // WebRTC 信令方法
  static void callRequest(String toUserId) {
    _socket?.emit('call_request', {'to': toUserId});
  }

  static void callAccept(String toSocketId) {
    _socket?.emit('call_accept', {'toSocketId': toSocketId});
  }

  static void callReject(String toSocketId) {
    _socket?.emit('call_reject', {'toSocketId': toSocketId});
  }

  static void callEnd(String toSocketId) {
    _socket?.emit('call_end', {'toSocketId': toSocketId});
  }

  static void sendWebrtcOffer(String toSocketId, dynamic offer) {
    _socket?.emit('webrtc_offer', {'toSocketId': toSocketId, 'offer': offer});
  }

  static void sendWebrtcAnswer(String toSocketId, dynamic answer) {
    _socket?.emit('webrtc_answer', {'toSocketId': toSocketId, 'answer': answer});
  }

  static void sendWebrtcIceCandidate(String toSocketId, dynamic candidate) {
    _socket?.emit('webrtc_ice_candidate', {'toSocketId': toSocketId, 'candidate': candidate});
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  static void dispose() {
    disconnect();
    _messageController.close();
    _readController.close();
    _recallController.close();
    _locationController.close();
    _typingController.close();
    _onlineController.close();

    _incomingCallController.close();
    _callAcceptedController.close();
    _callRejectedController.close();
    _callEndedController.close();
    _webrtcOfferController.close();
    _webrtcAnswerController.close();
    _webrtcIceCandidateController.close();
  }
}
