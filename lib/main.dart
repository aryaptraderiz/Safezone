import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'app_colors.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/lapor_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Init notifikasi
  await NotificationService.init();
  await NotificationService.requestPermission();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const SafeZoneApp());
}

class SafeZoneApp extends StatelessWidget {
  const SafeZoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeZone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.red),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: AuthService.userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _SplashScreen();
          }
          return const MainShell();
        },
      ),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => const MainShell(),
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.shield_rounded,
                  color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            Text('SafeZone',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.red)),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
                color: AppColors.red, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  OverlayEntry? _toastOverlay;

  void showToast() {
    _toastOverlay?.remove();
    _toastOverlay = OverlayEntry(builder: (_) => const _ToastWidget());
    Overlay.of(context).insert(_toastOverlay!);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      _toastOverlay?.remove();
      _toastOverlay = null;
      setState(() => _currentIndex = 0);
    });
  }

  void _requireLogin(int targetIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
        fullscreenDialog: true,
      ),
    ).then((success) {
      if (success == true && mounted) {
        setState(() => _currentIndex = targetIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreen(),
      const MapScreen(),
      LaporScreen(
        onKirim: showToast,
        onBack: () => setState(() => _currentIndex = 0),
      ),
      const AlertsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) {
          if ((i == 2 || i == 4) && !AuthService.isLoggedIn) {
            _requireLogin(i);
            return;
          }
          setState(() => _currentIndex = i);
        },
      ),
    );
  }
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget();

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _anim = Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 18,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _anim,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.text,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF4ADE80), size: 18),
                const SizedBox(width: 8),
                Text('Laporan terkirim!',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(icon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: Icons.location_on_rounded, label: 'Map'),
      _NavItem(icon: Icons.add_circle_rounded, label: 'Lapor'),
      _NavItem(icon: Icons.notifications_rounded, label: 'Alerts'),
      _NavItem(icon: Icons.settings_rounded, label: 'Settings'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border:
            const Border(top: BorderSide(color: AppColors.cream, width: 1.5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 24,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: List.generate(items.length, (i) {
              final active = currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: active ? AppColors.red : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(items[i].icon,
                            size: 24,
                            color:
                                active ? Colors.white : AppColors.text3),
                      ),
                      const SizedBox(height: 2),
                      Text(items[i].label,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color:
                                  active ? AppColors.text : AppColors.text3)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem({required this.icon, required this.label});
}
