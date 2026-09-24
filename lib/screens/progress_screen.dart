import 'dart:collection';

import 'package:calistreet/models/achievement.dart';
import 'package:calistreet/models/progress.dart';
import 'package:calistreet/screens/home_screen.dart';
import 'package:calistreet/services/auth_service.dart';
import 'package:calistreet/services/progress_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'profile_screen.dart';
import 'workout_history_screen.dart';

const Color primaryColor = Color(0xFF007AFF);
const Color secondaryColor = Color(0xFFFF6F00);
const Color backgroundDark = Color(0xFF000000);
const Color cardDark = Color(0xFF1A1A1A);
const Color textDark = Color(0xFFFFFFFF);
const Color subtextDark = Color(0xFF888888);
const Color borderDark = Color(0xFF2C2C2C);

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final int _selectedIndex = 1;
  final ProgressService _progressService = ProgressService();

  bool _isLoading = true;
  bool _isOfflineNotice = false;
  List<Progress> _progressData = [];
  Map<String, double> _weeklyData = {};
  int _totalWorkouts = 0;
  String _totalTime = "0h 0m";
  List<Achievement> _latestAchievements = [];

  @override
  void initState() {
    super.initState();
    _initScreen();
    _loadLatestAchievements();
  }

  Future<void> _initScreen() async {
    try {
      final userId = AuthService.currentUser?['user_id'] as String?;
      if (userId == null) {
        throw Exception("User not logged in.");
      }

      final progress = await _progressService.getLast7DaysProgress(userId);
      if (mounted) {
        setState(() {
          _progressData = progress;
          _processProgressData();
          _isLoading = false;
          _isOfflineNotice = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOfflineNotice = true;
        });
      }
    }
  }

  void _processProgressData() {
    _totalWorkouts = _progressData
        .where((p) => p.status == ProgressStatus.completed)
        .length;

    int totalSeconds = _progressData
        .where(
          (p) =>
              p.status == ProgressStatus.completed && p.durationSeconds != null,
        )
        .fold(0, (sum, p) => sum + p.durationSeconds!);

    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    _totalTime = "${hours}h ${minutes}m";

    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    
    _weeklyData = LinkedHashMap.fromIterable(
      List.generate(7, (i) => startOfWeek.add(Duration(days: i))),
      key: (date) => DateFormat('E', 'pt_BR').format(date).toUpperCase(),
      value: (date) => 0.0,
    );

    final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    List<Progress> weekProgress = _progressData
        .where((p) => 
            p.startDate.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
            p.startDate.isBefore(endOfWeek.add(const Duration(seconds: 1))))
        .toList();
      
    for (var p in weekProgress) {
      String day = DateFormat('E', 'pt_BR').format(p.startDate).toUpperCase();
      if (_weeklyData.containsKey(day)) {
        _weeklyData[day] =
            (_weeklyData[day] ?? 0) +
            (p.durationSeconds ?? 0) / 60.0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: backgroundDark,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Seu Progresso',
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_isOfflineNotice) _buildOfflineBanner(),
                  _buildWeeklySummaryCard(),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                  const SizedBox(height: 16),
                  _buildLatestAchievements(),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderDark),
      ),
      child: Row(
        children: const [
          Icon(Icons.wifi_off, color: primaryColor, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Modo offline ativo. Exibindo dados locais gravados.',
              style: TextStyle(color: textDark, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklySummaryCard() {
    final double maxBarHeight = _weeklyData.values.isEmpty
        ? 1
        : _weeklyData.values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderDark, width: 1),
      ),
      child: Column(
        children: [
          const Text(
            'Resumo da Semana',
            style: TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetric(_totalWorkouts.toString(), 'Treinos', primaryColor),
              _buildMetric(_totalTime, 'Tempo Total', primaryColor),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _weeklyData.entries.map((entry) {
                final double normalizedHeight = maxBarHeight > 0
                    ? entry.value / maxBarHeight
                    : 0.0;
                final currentDay = DateFormat('E', 'pt_BR').format(DateTime.now()).toUpperCase();

                return _buildBar(
                  heightRatio: normalizedHeight,
                  label: entry.key,
                  minutes: entry.value,
                  isActive: entry.key == currentDay,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: subtextDark,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBar({
    required double heightRatio,
    required String label,
    required double minutes,
    bool isActive = false,
  }) {
    final barColor = isActive ? primaryColor : primaryColor.withValues(alpha: 0.4);
    final double barHeight = heightRatio > 0 ? (100 * heightRatio) : 8.0;

    return GestureDetector(
      onTap: () {
        final hours = minutes ~/ 60;
        final mins = (minutes % 60).round();
        final timeText = hours > 0 ? "${hours}h ${mins}m" : "${mins}m";
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              minutes > 0 
                ? '$label: $timeText de treino'
                : '$label: Nenhum treino realizado',
            ),
            backgroundColor: isActive ? primaryColor : cardDark,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 14,
            height: barHeight,
            decoration: BoxDecoration(
              color: heightRatio > 0 ? barColor : borderDark,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                topRight: Radius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? textDark : subtextDark,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildActionButton(
          title: 'Histórico de Treinos',
          subtitle: 'Veja todos os seus treinos',
          icon: Icons.history,
          iconColor: primaryColor,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const WorkoutHistoryScreen()),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          title: 'Compartilhar Conquistas',
          subtitle: 'Mostre seu progresso',
          icon: Icons.share,
          iconColor: secondaryColor,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderDark, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: subtextDark, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const Icon(Icons.chevron_right, color: subtextDark),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestAchievements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16.0, left: 4),
          child: Text(
            'Últimas Conquistas',
            style: TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _latestAchievements.isEmpty
            ? const Text(
                "Nenhuma conquista desbloqueada ainda.",
                style: TextStyle(color: subtextDark),
              )
            : GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.8,
                children: _latestAchievements.map((a) {
                  return _buildAchievementCard(
                    a.name,
                    _mapIcon(a.iconName),
                    secondaryColor,
                  );
                }).toList(),
              ),
      ],
    );
  }

  Widget _buildAchievementCard(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderDark, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textDark,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: const BoxDecoration(
        color: backgroundDark,
        border: Border(top: BorderSide(color: borderDark, width: 1)),
      ),
      child: BottomNavigationBar(
        backgroundColor: backgroundDark,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index != _selectedIndex) {
            _navigateToScreen(index);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Progresso',
          ),
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.trophy),
            label: 'Desafios',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }

  void _navigateToScreen(int index) {
    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        break;
      case 1:
        break;
      case 2:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tela de Desafios em desenvolvimento.'),
            backgroundColor: primaryColor,
          ),
        );
        break;
      case 3:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
        break;
    }
  }

  Future<void> _loadLatestAchievements() async {
    try {
      final userId = AuthService.currentUser?['user_id'] as String?;
      if (userId == null) return;

      final achievements = await _progressService.getUserAchievements(userId);

      final unlocked = achievements
          .where((a) => a.isUnlocked)
          .toList()
        ..sort((a, b) => (b.currentValue ?? 0).compareTo(a.currentValue ?? 0));

      if (mounted) {
        setState(() {
          _latestAchievements = unlocked.take(3).toList();
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar últimas conquistas: $e");
    }
  }

  IconData _mapIcon(String? iconName) {
    switch (iconName) {
      case "pushup":
        return Icons.fitness_center;
      case "run":
        return Icons.directions_run;
      case "abs":
        return Icons.accessibility_new;
      case "trophy":
        return Icons.emoji_events;
      default:
        return Icons.emoji_events;
    }
  }
}