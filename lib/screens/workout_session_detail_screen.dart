import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color primaryColor = Color(0xFF007AFF);
const Color backgroundDark = Color(0xFF000000);
const Color cardDark = Color(0xFF1A1A1A);
const Color textDark = Color(0xFFFFFFFF);
const Color subtextDark = Color(0xFF888888);
const Color borderDark = Color(0xFF2C2C2C);

class WorkoutSessionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> session;

  const WorkoutSessionDetailScreen({super.key, required this.session});

  String _formatDuration(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final DateTime startDate = session['date'] is DateTime
        ? session['date']
        : (DateTime.tryParse(session['start_date']?.toString() ?? '') ?? DateTime.now());

    final String startTimeFormatted = DateFormat('HH:mm').format(startDate);
    final String dateFormatted = DateFormat("dd 'de' MMMM, yyyy", 'pt_BR').format(startDate);
    final int totalDurationSeconds = session['duration'] ?? session['duration_seconds'] ?? 0;

    final List<dynamic> exercises = session['exercises_breakdown'] as List? ?? [];
    final int exerciseCount = exercises.isNotEmpty ? exercises.length : 1;
    final int avgSecondsPerExercise = totalDurationSeconds ~/ exerciseCount;

    final String workoutName = session['workout_name'] ??
        (session['workouts'] as Map?)?['name'] ??
        'Treino Concluído';

    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        backgroundColor: backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Detalhes do Treino',
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workoutName,
                    style: const TextStyle(
                      color: textDark,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormatted,
                    style: const TextStyle(color: subtextDark, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Hora de Início',
                    value: startTimeFormatted,
                    icon: Icons.schedule,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Duração Total',
                    value: _formatDuration(totalDurationSeconds),
                    icon: Icons.timer_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildMetricCard(
              title: 'Duração Média por Exercício',
              value: _formatDuration(avgSecondsPerExercise),
              icon: Icons.speed,
              fullWidth: true,
            ),
            const SizedBox(height: 24),
            const Text(
              'Exercícios Realizados',
              style: TextStyle(
                color: textDark,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (exercises.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Tempo registrado no modo geral do treino.',
                  style: TextStyle(color: subtextDark),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: exercises.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final ex = exercises[index] as Map;
                  final String exName = ex['name'] ?? 'Exercício ${index + 1}';
                  final int exDuration = ex['duration_seconds'] is int
                      ? ex['duration_seconds']
                      : (int.tryParse(ex['duration_seconds']?.toString() ?? '0') ?? 0);

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderDark),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: primaryColor.withValues(alpha: 0.2),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              exName,
                              style: const TextStyle(
                                color: textDark,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _formatDuration(exDuration),
                          style: const TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderDark),
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: subtextDark, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}