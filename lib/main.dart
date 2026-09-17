import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/card_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CardStore.instance.load();
  runApp(const NexTapApp());
}

class NexTapApp extends StatelessWidget {
  const NexTapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NexTap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _StartupScreen(),
    );
  }
}

/// Keeps the existing app entry point intact while presenting a brief,
/// distraction-free startup experience.
class _StartupScreen extends StatefulWidget {
  const _StartupScreen();

  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen> {
  bool _showHome = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _showHome = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: _showHome
          ? const HomeScreen(key: ValueKey('home'))
          : const _SplashScreen(key: ValueKey('splash')),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen({super.key});

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOut,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'NexTap',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.8,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Your identity, one tap away.',
                style: TextStyle(
                  color: Color(0xFFD1D1D1),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
