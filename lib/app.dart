import 'dart:async';
import 'package:flutter/material.dart';
import 'providers/message_provider.dart';
import 'providers/online_provider.dart';
import 'providers/socket_listener.dart';
import 'providers/typing_provider.dart';
import 'providers/unread_provider.dart';
import 'providers/user_provider.dart';
import 'screens/login_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/video_call_screen.dart';
import 'services/auth_service.dart';
import 'services/location_service.dart';
import 'services/webrtc_service.dart';
import 'package:provider/provider.dart';

class ChatApp extends StatefulWidget {
  const ChatApp({super.key});

  @override
  State<ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends State<ChatApp> {
  StreamSubscription<CallState>? _callSub;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void dispose() {
    _callSub?.cancel();
    super.dispose();
  }

  void _initCallListener() {
    _callSub?.cancel();
    _callSub = WebRTCService.callState.listen((state) {
      final nav = _navigatorKey.currentState;
      if (nav == null) return;

      switch (state) {
        case CallState.incoming:
          nav.push(MaterialPageRoute(
            builder: (_) => const VideoCallScreen(initialState: CallState.incoming),
          ));
          break;
        case CallState.calling:
          nav.push(MaterialPageRoute(
            builder: (_) => const VideoCallScreen(initialState: CallState.calling),
          ));
          break;
        case CallState.rejected:
        case CallState.ended:
        case CallState.failed:
          if (nav.canPop()) nav.pop();
          break;
        default:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => MessageProvider()),
        ChangeNotifierProvider(create: (_) => TypingProvider()),
        ChangeNotifierProvider(create: (_) => OnlineProvider()),
        ChangeNotifierProvider(create: (_) => UnreadProvider()),
      ],
      child: MaterialApp(
        title: '二人聊天',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF07C160),
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFEDEDED),
            foregroundColor: Color(0xFF181818),
            elevation: 0.5,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF181818),
            ),
          ),
          scaffoldBackgroundColor: const Color(0xFFEDEDED),
        ),
        home: FutureBuilder(
          future: AuthService.init(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final loggedIn = AuthService.isLoggedIn;
            if (loggedIn) {
              // 初始化所有 Provider
              _initProviders(context);
              // 启动后台位置记录
              LocationService.startSharing();
              // 初始化 WebRTC 监听
              WebRTCService.initListeners();
              _initCallListener();
            }
            return loggedIn ? const ChatListScreen() : const LoginScreen();
          },
        ),
      ),
    );
  }

  void _initProviders(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final messageProvider = context.read<MessageProvider>();
    final typingProvider = context.read<TypingProvider>();
    final onlineProvider = context.read<OnlineProvider>();
    final unreadProvider = context.read<UnreadProvider>();

    userProvider.init().then((_) {
      typingProvider.setOtherUserId(userProvider.otherUserId);
      onlineProvider.setOtherUserId(userProvider.otherUserId);
      messageProvider.loadMessages().then((_) {
        unreadProvider.calculateFromMessages(messageProvider.messages);
      });
      SocketListener.init(
        messageProvider: messageProvider,
        typingProvider: typingProvider,
        onlineProvider: onlineProvider,
        unreadProvider: unreadProvider,
        userProvider: userProvider,
      );
    });
  }
}
