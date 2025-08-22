// integration/anonymous_chat_integration.dart

import 'package:flutter/material.dart';
import 'package:startup/home_components/anonymous_chat_landing.dart';
import 'package:startup/home_components/chat_history.dart';
import 'package:startup/home_components/chat_service.dart';

// Example of how to integrate the anonymous chat system into your app

class AnonymousChatNavigator {
  static final ChatService _chatService = ChatService();

  // Navigate to anonymous chat from any part of your app
  static void navigateToAnonymousChat(
    BuildContext context, {
    required String communityId,
    required String userId,
    required String username,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnonymousChatLanding(
          communityId: communityId,
          userId: userId,
          username: username,
        ),
      ),
    );
  }

  // Check if user is currently in a chat session
  static bool isUserInChat() {
    return _chatService.isInChat;
  }

  // Get current session details
  static String? getCurrentSessionId() {
    return _chatService.currentSessionId;
  }

  // Navigate directly to chat history
  static void navigateToChatHistory(
    BuildContext context, {
    required String communityId,
    required String userId,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatHistoryScreen(
          communityId: communityId,
          userId: userId,
        ),
      ),
    );
  }

  // Handle app lifecycle - cleanup when user logs out
  static void handleUserLogout() {
    _chatService.reset();
  }

  // Handle app background/foreground state
  static void handleAppStateChange(AppLifecycleState state) {
    // You can implement logic here to handle when app goes to background
    // For example, update user's online status
  }
}

// Example widget showing how to add anonymous chat to your app
class CommunityHomePage extends StatelessWidget {
  final String communityId;
  final String userId;
  final String username;

  const CommunityHomePage({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Community Home'),
        actions: [
          // Chat history button
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () {
              AnonymousChatNavigator.navigateToChatHistory(
                context,
                communityId: communityId,
                userId: userId,
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Your existing community features...
            
            const SizedBox(height: 40),
            
            // Anonymous Chat Feature Card
            Card(
              margin: const EdgeInsets.all(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.face_retouching_natural,
                      size: 48,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Anonymous Chat',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connect with community members anonymously. Identities revealed only after mutual consent.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        AnonymousChatNavigator.navigateToAnonymousChat(
                          context,
                          communityId: communityId,
                          userId: userId,
                          username: username,
                        );
                      },
                      child: Text('Start Anonymous Chat'),
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
}

// FIXED: Example of app-level integration with proper home screen
class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AnonymousChatNavigator.handleAppStateChange(state);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anonymous Chat Demo',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        brightness: Brightness.dark,
      ),
      // FIXED: Use a proper home screen or login screen
      home: LoginScreen(), // Replace with your actual login/home screen
      routes: {
        '/community': (context) => CommunityHomePage(
          communityId: 'your_community_id',
          userId: 'current_user_id',
          username: 'current_username',
        ),
        '/chat-history': (context) => ChatHistoryScreen(
          communityId: 'your_community_id',
          userId: 'current_user_id',
        ),
      },
    );
  }
}

// Example login screen that you can replace with your actual implementation
class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Login to your account'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // After successful login, navigate to community
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CommunityHomePage(
                      communityId: 'demo_community_id', // Replace with actual values
                      userId: 'demo_user_id',           // Replace with actual values
                      username: 'demo_username',        // Replace with actual values
                    ),
                  ),
                );
              },
              child: Text('Login (Demo)'),
            ),
          ],
        ),
      ),
    );
  }
}

// Alternative: Direct navigation to anonymous chat (for testing)
class DirectChatApp extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;

  const DirectChatApp({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<DirectChatApp> createState() => _DirectChatAppState();
}

class _DirectChatAppState extends State<DirectChatApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AnonymousChatNavigator.handleAppStateChange(state);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anonymous Chat Demo',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        brightness: Brightness.dark,
      ),
      // Direct navigation to anonymous chat (for testing purposes)
      home: AnonymousChatLanding(
        communityId: widget.communityId,
        userId: widget.userId,
        username: widget.username,
      ),
    );
  }
}

// Example usage in main.dart:
/*
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Option 1: Use the full app with login
  runApp(MyApp());
  
  // Option 2: Direct to anonymous chat for testing
  // runApp(DirectChatApp(
  //   communityId: 'your_community_id',
  //   userId: 'your_user_id', 
  //   username: 'your_username',
  // ));
}
*/

// Example of adding to existing community screen:
class ExistingCommunityWidget extends StatelessWidget {
  final String communityId;
  final String userId;
  final String username;

  const ExistingCommunityWidget({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Your existing widgets (posts, members, etc.)
        
        // Add anonymous chat section
        ListTile(
          leading: Icon(Icons.face_retouching_natural),
          title: Text('Anonymous Chat'),
          subtitle: Text('Connect anonymously with community members'),
          trailing: Icon(Icons.arrow_forward_ios),
          onTap: () {
            AnonymousChatNavigator.navigateToAnonymousChat(
              context,
              communityId: communityId,
              userId: userId,
              username: username,
            );
          },
        ),
        
        // Chat history option
        ListTile(
          leading: Icon(Icons.history),
          title: Text('Chat History'),
          subtitle: Text('View your past anonymous conversations'),
          trailing: Icon(Icons.arrow_forward_ios),
          onTap: () {
            AnonymousChatNavigator.navigateToChatHistory(
              context,
              communityId: communityId,
              userId: userId,
            );
          },
        ),
      ],
    );
  }
}

// Example of how to handle notifications when user gets paired
class ChatNotificationService {
  static void setupNotificationListeners(String communityId, String userId) {
    final chatService = ChatService();
    
    chatService.listenToUserStatus(communityId, userId).listen((userStatus) {
      if (userStatus?.status == 'paired') {
        // Show local notification
        _showPairingNotification();
      }
    });
  }
  
  static void _showPairingNotification() {
    // Implement your notification logic here
    // Could use flutter_local_notifications package
  }
}