import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../models/submission_model.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    final bool isManagerOrStaff = user.role.toLowerCase() == 'manager' || user.role.toLowerCase() == 'superadmin' || user.role.toLowerCase() == 'staff';

    final List<Widget> _screens = [
      _buildDashboard(context),
      HistoryScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Welcome, ${user.name}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(child: _screens[_currentIndex]),
      ),
      floatingActionButton: _currentIndex == 0 ? FloatingActionButton.extended(
        onPressed: () {
          context.go('/new-submission');
        },
        backgroundColor: AppColors.secondary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Submission', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ).animate().scale(delay: 200.ms, duration: 300.ms, curve: Curves.easeOutBack) : null,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: NavigationBar(
              height: 65,
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              backgroundColor: Colors.white.withOpacity(0.8),
              indicatorColor: AppColors.primaryLight.withOpacity(0.5),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
              destinations: [
                const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: AppColors.primaryDark), label: 'Home'),
                const NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history, color: AppColors.primaryDark), label: 'History'),
                const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: AppColors.primaryDark), label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return const SizedBox.shrink();
    
    return FutureBuilder<List<SubmissionModel>>(
      future: ApiService().getHistory(user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final history = snapshot.data ?? [];
        
        final now = DateTime.now();
        double todayKg = 0;
        double weekKg = 0;
        double monthKg = 0;
        
        List<FlSpot> weeklySpots = List.generate(7, (index) => FlSpot(index.toDouble(), 0));

        for (var item in history) {
          try {
            final date = DateTime.parse(item.date);
            final diffDays = now.difference(date).inDays;
            
            if (date.year == now.year && date.month == now.month && date.day == now.day) {
              todayKg += item.kilogram;
            }
            if (date.year == now.year && date.month == now.month) {
              monthKg += item.kilogram;
            }
            if (diffDays >= 0 && diffDays < 7) {
              weekKg += item.kilogram;
              final spotIndex = 6 - diffDays;
              weeklySpots[spotIndex] = FlSpot(spotIndex.toDouble(), weeklySpots[spotIndex].y + item.kilogram);
            }
          } catch (e) {}
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Performance Overview',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ).animate().fadeIn().slideX(begin: -0.1),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildGlassCard('Today (KG)', '${todayKg.toStringAsFixed(1)}', Icons.today, Colors.blue)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildGlassCard('This Week (KG)', '${weekKg.toStringAsFixed(1)}', Icons.calendar_view_week, Colors.orange)),
                ],
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
              const SizedBox(height: 16),
              _buildGlassCard('This Month (KG)', '${monthKg.toStringAsFixed(1)}', Icons.calendar_month, Colors.green, fullWidth: true)
                  .animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
              
              const SizedBox(height: 32),
              const Text(
                'Last 7 Days (KG)',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 16),
              
              // Advanced Chart
              Container(
                height: 250,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                  boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 10)],
                ),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 && value.toInt() < 7) {
                              final d = DateTime.now().subtract(Duration(days: 6 - value.toInt()));
                              final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                              return Text(days[d.weekday - 1], style: const TextStyle(color: AppColors.textHint, fontWeight: FontWeight.bold));
                            }
                            return const Text('');
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: weeklySpots,
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms).scale(curve: Curves.easeOutBack),
            ],
          ),
        );
      }
    );
  }

  Widget _buildGlassCard(String title, String value, IconData icon, Color color, {bool fullWidth = false}) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
