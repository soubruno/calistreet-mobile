import 'package:flutter/material.dart';
import 'create_workout_screen.dart';
import '../../services/workout_service.dart';
import '../../services/auth_service.dart';

const Color primaryColor = Color(0xFF007AFF);
const Color backgroundDark = Color(0xFF000000); 
const Color cardDark = Color(0xFF1A1A1A); 
const Color textDark = Color(0xFFFFFFFF);
const Color subtextDark = Color(0xFF888888); 
const Color borderDark = Color(0xFF2C2C2C); 
const Color errorColor = Color(0xFFE53935);

class MyWorkoutsScreen extends StatefulWidget {
  const MyWorkoutsScreen({super.key});

  @override
  State<MyWorkoutsScreen> createState() => _MyWorkoutsScreenState();
}

class _MyWorkoutsScreenState extends State<MyWorkoutsScreen> {
  List<Map<String, dynamic>> _userWorkouts = [];
  bool _isLoading = true;
  final WorkoutService _workoutService = WorkoutService();

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    final userId = AuthService.currentUser?['user_id'];
    
    if (userId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final List<Map<String, dynamic>> workouts =
          await _workoutService.fetchUserWorkouts(userId as String);

      if (mounted) {
        setState(() {
          _userWorkouts = workouts;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _editWorkout(String workoutId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateWorkoutScreen(workoutId: workoutId),
      ),
    ).then((_) => _loadWorkouts());
  }

  Future<void> _deleteWorkout(String workoutId) async {
    // Confirmação antes de excluir
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardDark,
        title: const Text('Excluir Treino', style: TextStyle(color: textDark)),
        content: const Text(
          'Deseja realmente excluir este treino? Esta ação não pode ser desfeita.',
          style: TextStyle(color: subtextDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: subtextDark)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir', style: TextStyle(color: errorColor)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _workoutService.deleteWorkout(workoutId);

      if (mounted) {
        setState(() {
          _userWorkouts.removeWhere((w) => w['id'] == workoutId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Treino excluído com sucesso!'),
            backgroundColor: primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao excluir treino. Verifique sua conexão.'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
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
        title: const Text('Meus Treinos', style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: textDark),
            onPressed: _loadWorkouts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : _userWorkouts.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: primaryColor,
                  backgroundColor: cardDark,
                  onRefresh: _loadWorkouts,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: _userWorkouts.map((workout) => _buildWorkoutCard(workout)).toList(),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.list_alt, color: subtextDark, size: 60),
          const SizedBox(height: 16),
          const Text('Nenhum treino encontrado.', style: TextStyle(color: textDark, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Crie seu primeiro treino personalizado!', style: TextStyle(color: subtextDark)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const CreateWorkoutScreen()),
              ).then((_) => _loadWorkouts());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Montar Novo Treino', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(Map<String, dynamic> workout) {
    final String levelDisplay = workout['level'] ?? 'Não definido'; 
    
    return Card(
      color: cardDark,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        leading: const Icon(Icons.fitness_center, color: primaryColor),
        title: Text(
          workout['name'] as String? ?? 'Treino Sem Nome',
          style: const TextStyle(color: textDark, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Nível: $levelDisplay',
          style: const TextStyle(color: subtextDark),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: primaryColor, size: 20),
              onPressed: () => _editWorkout(workout['id'] as String),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: errorColor, size: 20),
              onPressed: () => _deleteWorkout(workout['id'] as String),
            ),
          ],
        ),
        onTap: () => _editWorkout(workout['id'] as String), 
      ),
    );
  }
}