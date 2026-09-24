import 'package:flutter/material.dart';
import 'dart:async';
import '../services/workout_service.dart';
import '../services/progress_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

const Color primaryColor = Color(0xFF007AFF);
const Color backgroundDark = Color(0xFF1A1A1A);
const Color cardDark = Color(0xFF212121);
const Color textDark = Color(0xFFFFFFFF);
const Color subtextDark = Color(0xFFB0B0B0);
const Color errorColor = Color(0xFFE53935);

class WorkoutInProgressScreen extends StatefulWidget {
  final String workoutId;
  const WorkoutInProgressScreen({super.key, required this.workoutId});

  @override
  State<WorkoutInProgressScreen> createState() =>
      _WorkoutInProgressScreenState();
}

class _WorkoutInProgressScreenState extends State<WorkoutInProgressScreen> {
  bool _isPaused = true;
  int _elapsedSeconds = 0;
  int _lastExerciseSeconds = 0; // Marcação de tempo para cálculo por exercício
  Timer? _timer;

  List<Map<String, dynamic>> _exercises = [];
  String _workoutName = '';
  bool _isLoading = true;

  String? _progressId;
  final ProgressService _progressService = ProgressService();
  final WorkoutService _workoutService = WorkoutService();

  double get _overallProgress {
    if (_exercises.isEmpty) return 0.0;
    final completed = _exercises.where((e) => e['isCompleted'] == true).length;
    return completed / _exercises.length;
  }

  int get _minutes => _elapsedSeconds ~/ 60;
  int get _seconds => _elapsedSeconds % 60;

  @override
  void initState() {
    super.initState();
    _loadWorkoutData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();

    setState(() {
      _isPaused = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    _timer = null;

    setState(() {
      _isPaused = true;
    });
  }

  void _togglePause() {
    if (_isPaused) {
      _startTimer();
    } else {
      _pauseTimer();
    }
  }

  Future<void> _loadWorkoutData() async {
    final userId = AuthService.currentUser?['user_id'];
    if (userId == null) {
      _showSnackbar('Usuário não autenticado.', isError: true);
      Navigator.of(context).pop();
      return;
    }

    try {
      final sessionId = await _progressService.startWorkoutProgress(
        userId: userId as String,
        workoutId: widget.workoutId,
      );
      _progressId = sessionId;

      final workoutData = await _workoutService.fetchWorkoutById(widget.workoutId);

      if (mounted) {
        if (workoutData != null) {
          final exercisesJson =
              workoutData['workout_exercises'] as List<dynamic>? ?? [];

          setState(() {
            _workoutName = workoutData['name'] ?? 'Treino Sem Nome';
            _exercises = exercisesJson.map((item) {
              final Map<String, dynamic>? exerciseDetails =
                  item['exercises'] as Map<String, dynamic>?;

              return {
                'name': exerciseDetails?['name'] ?? 'Exercício',
                'details':
                    '${item['sets'] ?? 3} séries x ${item['repetitions'] ?? 10} repetições',
                'isCompleted': false,
                'duration_seconds': 0,
              };
            }).toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _workoutName = 'Treino Offline';
            _isLoading = false;
          });
          _showSnackbar(
            'Treino aberto offline. Complete os exercícios e cronometre normalmente.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackbar('Aviso: modo offline ativado.', isError: false);
      }
    }
  }

  void _finishWorkout() async {
    _timer?.cancel();

    if (_progressId != null) {
      // 1. Prepara a lista detalhada com a duração de cada exercício
      final breakdown = _exercises.map((e) {
        int duration = (e['duration_seconds'] as int?) ?? 0;
        // Se o usuário concluiu o treino direto sem marcar individualmente, divide por igual
        if (duration == 0 && _exercises.isNotEmpty && _elapsedSeconds > 0) {
          duration = _elapsedSeconds ~/ _exercises.length;
        }
        return {
          'name': e['name'] ?? 'Exercício',
          'duration_seconds': duration,
        };
      }).toList();

      try {
        await _progressService.completeWorkoutProgress(
          progressId: _progressId!,
          durationSeconds: _elapsedSeconds,
          notes:
              'Treino concluído com ${(_overallProgress * 100).toInt()}% dos exercícios completados',
          exerciseTimestamps: breakdown,
        );
      } catch (_) {}
    }

    if (mounted) {
      _showSnackbar('Treino concluído! Bom descanso.', isError: false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? errorColor : primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        backgroundColor: backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _workoutName,
          style: const TextStyle(color: textDark, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    child: Column(
                      children: [
                        _buildTimerSection(),
                        const SizedBox(height: 24),
                        _buildProgressIndicator(),
                        const SizedBox(height: 32),
                        _buildPauseButton(),
                        const SizedBox(height: 32),
                        _exercises.isEmpty
                            ? _buildEmptyExercisesCard()
                            : _buildExerciseChecklist(),
                      ],
                    ),
                  ),
                ),
                _buildFinishWorkoutButton(),
              ],
            ),
    );
  }

  Widget _buildEmptyExercisesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          'Treino iniciado em modo rápido. Utilize o cronômetro para marcar sua rotina.',
          textAlign: TextAlign.center,
          style: TextStyle(color: subtextDark, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildTimerSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTimerBox(_minutes.toString().padLeft(2, '0')),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              ':',
              style: TextStyle(
                color: textDark,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildTimerBox(_seconds.toString().padLeft(2, '0')),
        ],
      ),
    );
  }

  Widget _buildTimerBox(String value) {
    return Expanded(
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            value,
            style: const TextStyle(
              color: textDark,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progresso Geral',
                style: TextStyle(color: textDark, fontSize: 16),
              ),
              Text(
                '${(_overallProgress * 100).toInt()}%',
                style: const TextStyle(color: subtextDark),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _overallProgress,
              minHeight: 10,
              backgroundColor: cardDark,
              valueColor: const AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPauseButton() {
    return GestureDetector(
      onTap: _togglePause,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: primaryColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Icon(
          _isPaused ? Icons.play_arrow : Icons.pause,
          color: textDark,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildExerciseChecklist() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _exercises.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> exercise = entry.value;

          return Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Checkbox(
                  value: exercise['isCompleted'],
                  onChanged: (bool? newValue) {
                    setState(() {
                      final bool isChecked = newValue ?? false;
                      _exercises[index]['isCompleted'] = isChecked;

                      // Calcula a duração do exercício atual com base no cronômetro
                      if (isChecked) {
                        final durationCurrent = _elapsedSeconds - _lastExerciseSeconds;
                        _exercises[index]['duration_seconds'] =
                            durationCurrent > 0 ? durationCurrent : 1;
                        _lastExerciseSeconds = _elapsedSeconds;
                      } else {
                        _exercises[index]['duration_seconds'] = 0;
                      }
                    });
                  },
                  activeColor: primaryColor,
                  checkColor: textDark,
                  side: const BorderSide(color: Color(0xFF404040), width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                title: Text(
                  exercise['name'],
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  exercise['details'],
                  style: const TextStyle(color: subtextDark, fontSize: 13),
                ),
                onTap: () {
                  setState(() {
                    final bool nextState = !exercise['isCompleted'];
                    _exercises[index]['isCompleted'] = nextState;

                    if (nextState) {
                      final durationCurrent = _elapsedSeconds - _lastExerciseSeconds;
                      _exercises[index]['duration_seconds'] =
                          durationCurrent > 0 ? durationCurrent : 1;
                      _lastExerciseSeconds = _elapsedSeconds;
                    } else {
                      _exercises[index]['duration_seconds'] = 0;
                    }
                  });
                },
              ),
              if (index < _exercises.length - 1)
                const Divider(color: Color(0xFF404040), height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFinishWorkoutButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      color: backgroundDark,
      child: SizedBox(
        height: 56,
        child: ElevatedButton(
          onPressed: _finishWorkout,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Concluir Treino',
            style: TextStyle(
              color: textDark,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}