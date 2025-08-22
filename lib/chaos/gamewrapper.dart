import 'package:flutter/material.dart';
import 'package:startup/chaos/tries_manager.dart';
// import 'package:startup/services/tries_manager.dart';

class GameWrapper extends StatelessWidget {
  final Widget child;

  const GameWrapper({super.key, required this.child});

  Future<void> _checkTriesAndProceed(BuildContext context) async {
    final allowed = await GameTriesManager.incrementTry();
    if (!allowed) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.black,
          title: const Text("Limit Reached", style: TextStyle(color: Colors.amber)),
          content: const Text("You’ve used all 5 tries.", style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK", style: TextStyle(color: Colors.amber)),
            ),
          ],
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => child),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () => _checkTriesAndProceed(context),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700]),
        child: const Text("Start Game", style: TextStyle(color: Colors.black)),
      ),
    );
  }
}
