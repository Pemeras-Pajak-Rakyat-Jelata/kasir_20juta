import 'package:flutter/material.dart';
import 'package:kasir_barokah/pages/absensi_page.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';

import 'dashboard_page.dart';
import 'kasir_page.dart';
import 'stok_page.dart';
import 'laporan_page.dart';
import 'akun_page.dart';

final GlobalKey<KasirPageState> kasirKey = GlobalKey<KasirPageState>();
final GlobalKey<LaporanPageState> laporanKey = GlobalKey<LaporanPageState>();
final GlobalKey<DashboardPageState> dashboardKey =
    GlobalKey<DashboardPageState>();

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  bool _loading = true;
  bool _isAdmin = false;

  List<Widget> _pages = [];
  List<_NavItem> _navItems = [];

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final admin = await SupabaseService.isAdmin();

      setState(() {
        _isAdmin = admin;

        if (_isAdmin) {
          _pages = [
            DashboardPage(key: dashboardKey),
            KasirPage(key: kasirKey),
            StokPage(),
            LaporanPage(key: laporanKey),
            AbsensiPage(),
            AkunPage(),
          ];

          _navItems = const [
            _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
            _NavItem(icon: Icons.point_of_sale_rounded, label: 'Kasir'),
            _NavItem(icon: Icons.inventory_2_rounded, label: 'Stok'),
            _NavItem(icon: Icons.bar_chart_rounded, label: 'Laporan'),
            _NavItem(icon: Icons.fact_check_rounded, label: 'Absen'),
            _NavItem(icon: Icons.person_rounded, label: 'Akun'),
          ];
        } else {
          _pages = [
            DashboardPage(),
            KasirPage(),
            StokPage(),
            AkunPage(),
          ];

          _navItems = const [
            _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
            _NavItem(icon: Icons.point_of_sale_rounded, label: 'Kasir'),
            _NavItem(icon: Icons.inventory_2_rounded, label: 'Stok'),
            _NavItem(icon: Icons.person_rounded, label: 'Akun'),
          ];
        }

        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.hijauEmerald,
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF3B3A28).withOpacity(0.92),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: List.generate(_navItems.length, (i) {
                final item = _navItems[i];
                final selected = _currentIndex == i;

                return Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: () async {
                        setState(() => _currentIndex = i);

                        if (i == 1) {
                          kasirKey.currentState?.reload();
                        }

                        await Future.delayed(
                          const Duration(milliseconds: 150),
                        );

                        if (mounted) {
                          setState(() {});
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        padding: selected
                            ? const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              )
                            : const EdgeInsets.all(10),
                        decoration: selected
                            ? BoxDecoration(
                                color: const Color(0xFFF5A823),
                                borderRadius: BorderRadius.circular(30),
                              )
                            : null,
                        child: selected
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    item.icon,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      item.label,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Icon(
                                item.icon,
                                color: AppTheme.hijauEmerald,
                                size: 22,
                              ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.label,
  });
}