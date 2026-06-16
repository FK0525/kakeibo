import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'screens/income_input_screen.dart';

const bool kUseDummyData = false;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider()..load(),
      child: const KakeiboApp(),
    ),
  );
}

class KakeiboApp extends StatelessWidget {
  const KakeiboApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WymV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1A1A2E)),
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansJpTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const _RootScreen(),
    );
  }
}

class _RootScreen extends StatefulWidget {
  const _RootScreen();

  @override
  State<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<_RootScreen> {
  bool _incomeShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = context.watch<AppProvider>();

    if (p.loaded && p.shouldShowIncomeInput && !_incomeShown) {
      _incomeShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const IncomeInputScreen(),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}