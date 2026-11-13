import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/parking_pass_screen.dart';
import 'screens/search_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const ParkingHustApp());
}

class ParkingHustApp extends StatefulWidget {
  const ParkingHustApp({super.key});

  @override
  State<ParkingHustApp> createState() => _ParkingHustAppState();
}

class _ParkingHustAppState extends State<ParkingHustApp> {
  // Trạng thái: Mặc định là false (Chưa đăng nhập)
  bool _isLoggedIn = false;

  void _handleLoginSuccess() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParkingHUST',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB71C1C), // Đỏ Bách Khoa
          primary: const Color(0xFFB71C1C),
        ),
        useMaterial3: true,
      ),
      // ĐIỀU KIỆN: Chưa đăng nhập -> Hiện LoginScreen; Đăng nhập rồi -> Vào MainNavigationScreen
      home: _isLoggedIn
          ? MainNavigationScreen(onLogout: _handleLogout)
          : LoginScreen(onLoginSuccess: _handleLoginSuccess),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const MainNavigationScreen({super.key, required this.onLogout});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

void switchMainTab(int index) {
  _MainNavigationScreenState.instance?.switchToTab(index);
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  // Khai báo instance tĩnh để gọi chuyển tab từ bất cứ đâu:
  static _MainNavigationScreenState? instance;
  int _currentIndex = 0;

  late final List<Widget> _screens;

  void switchToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    instance = this;
    _screens = [
      const HomeScreen(),
      const ParkingPassScreen(),
      const SearchScreen(),
      ProfileScreen(onLogout: widget.onLogout), // Truyền sự kiện đăng xuất vào Tab 4
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // DÒNG MỚI (DÙNG INDEXEDSTACK ĐỂ GIỮ NGUYÊN BỘ NHỚ):
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_parking),
            selectedIcon: Icon(Icons.local_parking, color: Color(0xFFB71C1C)),
            label: 'Nhà xe',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code),
            selectedIcon: Icon(Icons.qr_code, color: Color(0xFFB71C1C)),
            label: 'Vé xe',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search, color: Color(0xFFB71C1C)),
            label: 'Tìm kiếm',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            selectedIcon: Icon(Icons.person, color: Color(0xFFB71C1C)),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }
}