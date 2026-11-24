import 'dart:async';
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
import 'screens/safe_friend_screen.dart';
import 'screens/auth_entry_screen.dart';
import 'screens/auth_login_screen.dart';
import 'screens/auth_register_screen.dart';
import 'screens/email_verification_screen.dart';
import 'services/shake_detector_service.dart';
import 'widgets/emergency_sos_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Custom ErrorWidget builder so release build shows error details instead of grey/black screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Text(
              'Startup Error:\n${details.exceptionAsString()}\n\n${details.stack}',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  String? firebaseError;
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e, stack) {
    firebaseError = '$e\n$stack';
    debugPrint('Firebase init error: $e');
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(SafeZoneApp(firebaseError: firebaseError));
}

class SafeZoneApp extends StatelessWidget {
  final String? firebaseError;
  const SafeZoneApp({super.key, this.firebaseError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeZone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: GoogleFonts.plusJakartaSans().fontFamily ?? 'sans-serif',
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.red),
        useMaterial3: true,
      ),
      home: firebaseError != null
          ? Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.red, size: 54),
                      const SizedBox(height: 16),
                      const Text(
                        'Gagal Memulai Firebase',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        firebaseError!,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const _AuthEntryGate(),
      routes: {
        '/login': (_) => const AuthLoginScreen(),
        '/register': (_) => const AuthRegisterScreen(),
        '/verify-email': (_) => const EmailVerificationScreen(),
        '/home': (_) => const MainShell(),
      },
    );
  }
}

class _AuthEntryGate extends StatefulWidget {
  const _AuthEntryGate();

  @override
  State<_AuthEntryGate> createState() => _AuthEntryGateState();
}

class _AuthEntryGateState extends State<_AuthEntryGate> {
  StreamSubscription? _authSubscription;
  Object? _authError;
  bool _loading = true;
  bool _hasUser = false;
  bool _needsVerification = false;
  int _authGeneration = 0;

  @override
  void initState() {
    super.initState();
    _initializeAuthState();
  }

  Future<void> _initializeAuthState() async {
    final generation = ++_authGeneration;
    final previousSubscription = _authSubscription;
    _authSubscription = null;
    await previousSubscription?.cancel();
    if (!mounted || generation != _authGeneration) return;

    if (mounted) {
      setState(() {
        _loading = true;
        _authError = null;
      });
    }

    try {
      final restoredUser = await AuthService.waitForInitialAuthState();
      if (!mounted || generation != _authGeneration) return;

      if (restoredUser == null) {
        setState(() {
          _hasUser = false;
          _loading = false;
          _authError = null;
        });
      } else {
        unawaited(_validateSession(restoredUser, generation));
      }
    } catch (error) {
      if (!mounted || generation != _authGeneration) return;
      debugPrint('Could not restore Firebase session: $error');
      setState(() {
        _loading = false;
        _authError = error;
      });
      return;
    }

    _authSubscription = AuthService.userStream.listen(
      (user) {
        if (!mounted) return;
        final generation = ++_authGeneration;
        if (user != null) {
          setState(() {
            _loading = true;
            _authError = null;
          });
          unawaited(_validateSession(user, generation));
          return;
        }
        setState(() {
          _hasUser = false;
          _loading = false;
          _authError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        debugPrint('Startup auth state error: $error');
        setState(() {
          _loading = false;
          _authError = error;
        });
      },
    );
  }

  Future<void> _validateSession(User user, int generation) async {
    final activeUser = await AuthService.validateAndRefreshSession(user);
    if (!mounted || generation != _authGeneration) return;
    setState(() {
      _hasUser = activeUser != null;
      _needsVerification = AuthService.needsEmailVerification(activeUser);
      _loading = false;
      _authError = null;
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.red),
        ),
      );
    }

    if (_authError != null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    color: AppColors.red, size: 42),
                const SizedBox(height: 12),
                Text(
                  'Status login belum bisa diperiksa.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _initializeAuthState,
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_hasUser) return const AuthEntryScreen();
    if (_needsVerification) return const EmailVerificationScreen();
    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final Set<int> _visitedTabs = {0};
  OverlayEntry? _toastOverlay;
  bool _openingProtectedTab = false;
  bool _showingSosDialog = false;
  late final ShakeDetectorService _shakeDetector;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeNotifications());
    _shakeDetector = ShakeDetectorService(
      onShake: _triggerSosFromShake,
    );
    _shakeDetector.startListening();
  }

  Future<void> _initializeNotifications() async {
    try {
      await NotificationService.init();
      await NotificationService.requestPermission();
    } catch (error) {
      debugPrint('Notification initialization failed: $error');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shakeDetector.stopListening();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final user = AuthService.currentUser;
      if (user != null) unawaited(_validateResumedSession(user));
    }
  }

  Future<void> _validateResumedSession(User user) async {
    final activeUser = await AuthService.validateAndRefreshSession(user);
    if (!mounted || activeUser != null) return;
    await Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  void _triggerSosFromShake() {
    if (!mounted || _showingSosDialog) return;
    _openSosDialog(autoCountdown: true);
  }

  void _openSosDialog({bool autoCountdown = false}) async {
    if (_showingSosDialog) return;
    _showingSosDialog = true;
    try {
      await EmergencySosDialog.show(context, autoCountdown: autoCountdown);
    } finally {
      if (mounted) _showingSosDialog = false;
    }
  }

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

  Future<void> _openProtectedTab(int targetIndex) async {
    if (!mounted || _openingProtectedTab) return;
    _openingProtectedTab = true;

    try {
      final user = await AuthService.restoreSession();
      if (!mounted) return;

      if (user == null) {
        final success = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => const AuthLoginScreen(),
            fullscreenDialog: true,
          ),
        );
        if (success == true && mounted) {
          setState(() {
            _visitedTabs.add(targetIndex);
            _currentIndex = targetIndex;
          });
        }
      } else {
        setState(() {
          _visitedTabs.add(targetIndex);
          _currentIndex = targetIndex;
        });
      }
    } finally {
      _openingProtectedTab = false;
    }
  }

  void _selectTab(int index) {
    setState(() {
      _visitedTabs.add(index);
      _currentIndex = index;
    });
  }

  void _showMainMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFCF8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE4E0DA),
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 18),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('Menu SafeZone',
                    style: GoogleFonts.plusJakartaSans(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800))),
            const SizedBox(height: 12),
            _MainMenuTile(
                icon: Icons.map_outlined,
                title: 'Peta keamanan',
                subtitle: 'Lihat kondisi dan laporan di sekitar',
                color: const Color(0xFF3978D5),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _selectTab(1);
                }),
            _MainMenuTile(
                icon: Icons.add_location_alt_outlined,
                title: 'Buat laporan',
                subtitle: 'Bagikan kejadian dengan warga sekitar',
                color: AppColors.red,
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_openProtectedTab(2));
                }),
            _MainMenuTile(
                icon: Icons.campaign_outlined,
                title: 'Laporan warga',
                subtitle: 'Lihat laporan dan buka detailnya',
                color: const Color(0xFF8058B8),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _selectTab(3);
                }),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = List<Widget>.generate(5, (index) {
      if (!_visitedTabs.contains(index)) return const SizedBox.shrink();
      switch (index) {
        case 0:
          return HomeScreen(
            onOpenSettings: () => _openProtectedTab(4),
            onOpenMap: () => _selectTab(1),
            onOpenLapor: () => _openProtectedTab(2),
            onOpenAlerts: () => _selectTab(3),
            onOpenSafeFriend: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SafeFriendScreen()),
            ),
          );
        case 1:
          return const MapScreen();
        case 2:
          return LaporScreen(
            onKirim: showToast,
            onBack: () => _selectTab(0),
          );
        case 3:
          return const AlertsScreen();
        default:
          return const SettingsScreen();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: _selectTab,
        onMenuTap: _showMainMenu,
        onSosTap: () => _openSosDialog(),
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

class _MainMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MainMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(17),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.plusJakartaSans(
                              color: AppColors.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: GoogleFonts.plusJakartaSans(
                              color: AppColors.text3, fontSize: 10)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.text3),
              ]),
            ),
          ),
        ),
      );
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onSosTap;
  final VoidCallback onMenuTap;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.onSosTap,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              _navItem(
                index: 0,
                icon: Icons.home_rounded,
                label: 'Home',
                active: currentIndex == 0,
              ),
              _sosButton(),
              _navItem(
                index: -1,
                icon: Icons.grid_view_rounded,
                label: 'Menu',
                active:
                    currentIndex == 1 || currentIndex == 2 || currentIndex == 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sosButton() {
    return SizedBox(
      width: 96,
      child: Semantics(
        button: true,
        label: 'SOS, bantuan darurat',
        child: GestureDetector(
          onTap: onSosTap,
          behavior: HitTestBehavior.opaque,
          child: Transform.translate(
            offset: const Offset(0, -13),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: AppColors.red, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.red.withOpacity(0.16),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CustomPaint(
                      size: Size(48, 39), painter: _SosBeaconPainter()),
                  Text(
                    'SOS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.red,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required String label,
    required bool active,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => index < 0 ? onMenuTap() : onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 23,
              color: active ? AppColors.red : const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.text : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SosBeaconPainter extends CustomPainter {
  const _SosBeaconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final red = Paint()..color = AppColors.red;
    final glow = Paint()..color = const Color(0xFFFF7770);
    final base = Paint()..color = const Color(0xFFD9DEE5);
    final rays = Paint()
      ..color = const Color(0xFFE76A62)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(8, 8), const Offset(12, 13), rays);
    canvas.drawLine(
        Offset(size.width / 2, 3), Offset(size.width / 2, 10), rays);
    canvas.drawLine(
        Offset(size.width - 8, 8), Offset(size.width - 12, 13), rays);

    final dome = Path()
      ..moveTo(10, 31)
      ..lineTo(10, 22)
      ..quadraticBezierTo(10, 8, size.width / 2, 8)
      ..quadraticBezierTo(size.width - 10, 8, size.width - 10, 22)
      ..lineTo(size.width - 10, 31)
      ..close();
    canvas.drawPath(dome, red);
    canvas.drawCircle(Offset(size.width / 2, 13), 4, glow);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(5, 32, size.width - 10, 6), const Radius.circular(3)),
      base,
    );
  }

  @override
  bool shouldRepaint(covariant _SosBeaconPainter oldDelegate) => false;
}
