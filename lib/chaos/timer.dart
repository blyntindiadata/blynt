import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

void main() {
  runApp(const MaterialApp(
    home: TapToWin(),
    debugShowCheckedModeBanner: false,
  ));
}

class TapToWin extends StatefulWidget {
  const TapToWin({super.key});

  @override
  State<TapToWin> createState() => _TapToWinState();
}

class _TapToWinState extends State<TapToWin> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  double _elapsedSeconds = 0.0;
  String _message = "🎯 Tap 'Start' then 'Stop' when you think 10.00 seconds have reached. Be careful, you have only one chance per week!";
  bool _gameStarted = false;
  bool _gameEnded = false;
  bool _playedThisWeek = false;

  final Color goldColor = const Color(0xFFFFD700);
  final Color bgColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _checkIfPlayedThisWeek();

    // Automatically re-check every 3 seconds to refresh UI
    Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _checkIfPlayedThisWeek();
    });
  }

int _triesThisWeek = 0;

Future<void> _checkIfPlayedThisWeek() async {
  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now().millisecondsSinceEpoch;
  final tries = prefs.getStringList('tapToWinTries') ?? [];

  tries.removeWhere((ts) {
    final diff = now - int.parse(ts);
    return diff > Duration(days: 7).inMilliseconds;
  });

  _triesThisWeek = tries.length;

  if (_triesThisWeek >= 3) {
    if (!_playedThisWeek) {
      setState(() {
        _playedThisWeek = true;
        _message = "🚫 You've used all 3 tries this week!\nTry again next week or unlock more attempts below.";
      });
    }
  } else {
    if (_playedThisWeek) {
      setState(() {
        _playedThisWeek = false;
        _message = "🎯 Tap 'Start' then 'Stop' when you feel 10.00 seconds have passed!\nTries used: $_triesThisWeek / 3";
      });
    } else {
      setState(() {
        _message = "🎯 Tap 'Start' then 'Stop' when you feel 10.00 seconds have passed!\nTries used: $_triesThisWeek / 3";
      });
    }
  }

  await prefs.setStringList('tapToWinTries', tries);
}

Future<void> _markPlayedNow() async {
  final prefs = await SharedPreferences.getInstance();
  final tries = prefs.getStringList('tapToWinTries') ?? [];
  tries.add(DateTime.now().millisecondsSinceEpoch.toString());
  await prefs.setStringList('tapToWinTries', tries);
}


  // Future<void> _markPlayedNow() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setInt('lastPlayedTapToWin', DateTime.now().millisecondsSinceEpoch);
  // }

  void _start() {
    _stopwatch.reset();
    _stopwatch.start();
    _gameStarted = true;
    _gameEnded = false;

    setState(() {
      _message = "⏱ Timer started... Tap Stop when you're ready!";
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      setState(() {
        _elapsedSeconds = _stopwatch.elapsedMicroseconds / 1000000.0;
      });
    });
  }

  void _stop() {
    _stopwatch.stop();
    _timer?.cancel();
    _gameEnded = true;
    _markPlayedNow();

    double diff = (_elapsedSeconds - 10.0).abs();
    String result;

    if (diff == 0) {
      result = "💯 PERFECT! You get 100% OFF!";
    } else if (diff < 0.1) {
      result = "🎉 Incredible! You get 80% OFF!";
    } else if (diff < 0.3) {
      result = "👏 Great! You get 60% OFF!";
    } else if (diff < 0.5) {
      result = "👍 Good! You get 40% OFF!";
    } else {
      result = "😅 Too far off. Try again next week!";
    }

    setState(() {
      _playedThisWeek = true;
      _message = "⏳ You stopped at: ${_elapsedSeconds.toStringAsFixed(2)} sec\n$result";
    });
  }

  void _retry() {
    setState(() {
      _elapsedSeconds = 0.0;
      _message = "🎯 Tap 'Start' then 'Stop' when you think 10.00 seconds have passed.";
      _gameEnded = false;
      _gameStarted = false;
    });
  }

  
  Widget _metallicCard(String time) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2A2A), Color(0xFF0F0F0F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: goldColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: goldColor.withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          time,
          style: GoogleFonts.poppins(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: goldColor,
            letterSpacing: 1.5,
            shadows: [
              Shadow(
                blurRadius: 18,
                color: goldColor.withOpacity(0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glowingGradientButton(String text, VoidCallback? onTap, {bool isRed = false}) {
    final List<Color> gradientColors = isRed
        ? [Colors.redAccent.shade200, Colors.deepOrangeAccent]
        : [const Color(0xFFFFD700), const Color(0xFFFF8000)];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: onTap == null
              ? null
              : LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: onTap == null ? Colors.grey.shade800 : null,
          borderRadius: BorderRadius.circular(22),
          boxShadow: onTap == null
              ? []
              : [
                  BoxShadow(
                    color: gradientColors.last.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: onTap == null ? Colors.white30 : Colors.black,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

Widget _discountSlabsCard() {
  return Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1C1C1C), Color(0xFF2A2A2A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: goldColor, width: 1.2),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: goldColor.withOpacity(0.08),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            "🎁 Discount Slabs",
            style: GoogleFonts.poppins(
              fontSize: 17,
              color: goldColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...[
          _slabCard("⏱ Exact 10.00 sec", "💯 100% OFF"),
          _divider(),
          _slabCard("± 0.10 sec", "🎉 80% OFF"),
          _divider(),
          _slabCard("± 0.30 sec", "👏 60% OFF"),
          _divider(),
          _slabCard("± 0.50 sec", "👍 40% OFF"),
          _divider(),
          _slabCard("> ± 0.50 sec", "😅 No Discount"),
        ],
      ],
    ),
  );
}

Widget _slabCard(String time, String reward) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          time,
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
        ),
        Text(
          reward,
          style: GoogleFonts.poppins(
              color: goldColor, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
    ),
  );
}

Widget _divider() => Divider(
      color: Colors.white24,
      thickness: 0.8,
      height: 8,
    );


  Widget _slabRow(String range, String reward) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(range, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
          Text(reward, style: GoogleFonts.poppins(color: goldColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _ruleBook() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "📖 Game Rules & Info",
            style: GoogleFonts.poppins(
              fontSize: 17,
              color: goldColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _ruleItem("• You can only play this game once every 7 days."),
          _ruleItem("• Tap Start and then Stop when you feel 10.00s have passed."),
          _ruleItem("• Your precision decides your discount percentage."),
          _ruleItem("• Discounts apply only on eligible bookings."),
          _ruleItem("• In case of exact timing, you win 100% off!"),
        ],
      ),
    );
  }

Widget _ruleItem(String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      text,
      style: GoogleFonts.poppins(
        color: Colors.white70,
        fontSize: 14,
        height: 1.4,
      ),
    ),
  );
}


  Widget _animatedMessage() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        _message,
        key: ValueKey(_message),
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 15.5,
          color: Colors.white70,
          height: 1.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: goldColor),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFF9B233), Color(0xFFFF8008)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Text(
            'Tap to Win 🎯',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _metallicCard("⏱ ${_elapsedSeconds.toStringAsFixed(2)} sec"),
                const SizedBox(height: 30),
                _animatedMessage(),
                const SizedBox(height: 35),
                if (!_playedThisWeek && !_gameStarted && !_gameEnded)
                  _glowingGradientButton("Start", _start),
                if (_gameStarted && !_gameEnded)
                  _glowingGradientButton("Stop", _stop, isRed: true),
                if (_playedThisWeek && _gameEnded)
                  _glowingGradientButton("Retry", _retry),
                    if (_playedThisWeek && !_gameEnded && _triesThisWeek >= 3) ...[
    const SizedBox(height: 12),
    Text(
      "🎟 You've used all 3 weekly tries!",
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: Colors.white70,
      ),
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: 16),
    _glowingGradientButton("🔓 Unlock 1 Try – ₹7", () {
      // handle purchase logic
    }),
    _glowingGradientButton("🔓 Unlock 3 Tries – ₹15", () {
      // handle purchase logic
    }),
  ],

                const SizedBox(height: 35),
                _discountSlabsCard(),
                const SizedBox(height: 10),
                _ruleBook(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
