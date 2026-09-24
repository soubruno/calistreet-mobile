import 'package:flutter/material.dart';
import '../../services/workout_service.dart';
import '../../models/workout_exercise_item.dart';
import 'exercise_library_screen.dart';

// Cores baseadas no padrão:
const Color primaryColor = Color(0xFF007AFF);
const Color secondaryColor = Color(0xFF007AFF);
const Color backgroundDark = Color(0xFF000000);
const Color cardDark = Color(0xFF1A1A1A);
const Color textDark = Color(0xFFFFFFFF);
const Color subtextDark = Color(0xFF888888);
const Color borderDark = Color(0xFF2C2C2C);
const Color errorColor = Color(0xFFE53935);

class CreateWorkoutScreen extends StatefulWidget {
  final String? workoutId;

  const CreateWorkoutScreen({super.key, this.workoutId});

  @override
  State<CreateWorkoutScreen> createState() => _CreateWorkoutScreenState();
}

class _CreateWorkoutScreenState extends State<CreateWorkoutScreen> {
  final TextEditingController _nameController = TextEditingController();
  final WorkoutService _workoutService = WorkoutService();

  List<WorkoutExerciseItem> _exercises = [];
  bool _isSaving = false;
  bool _isLoading = false;

  final List<String> _weekDays = [
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sáb',
    'Dom',
  ];
  List<String> _selectedDays = [];

  // Mapeamento de níveis (backend -> frontend)
  final Map<String, String> _levelMap = {
    'beginner': 'Iniciante',
    'intermediate': 'Intermediário',
    'advanced': 'Avançado',
  };
  
  String? _selectedLevel;

  @override
  void initState() {
    super.initState();
    if (widget.workoutId != null) {
      _loadWorkoutForEditing(); // Se tiver ID, carrega dados
    }
    // Se não tiver ID, _exercises e _nameController permanecem vazios
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Carrega dados do treino para edição
  void _loadWorkoutForEditing() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final rawWorkoutData = await _workoutService.fetchWorkoutById(widget.workoutId!);

      if (rawWorkoutData != null && mounted) {
        // Garante a conversão estrita para Map<String, dynamic>
        final Map<String, dynamic> workoutData = Map<String, dynamic>.from(rawWorkoutData);

        _nameController.text = workoutData['name']?.toString() ?? '';

        final List<dynamic> exercisesJson =
            workoutData['workout_exercises'] as List<dynamic>? ?? [];
        List<WorkoutExerciseItem> loadedItems = [];

        for (var rawItem in exercisesJson) {
          final item = Map<String, dynamic>.from(rawItem as Map);
          
          final Map<String, dynamic>? exerciseDetails = item['exercises'] != null
              ? Map<String, dynamic>.from(item['exercises'] as Map)
              : null;

          loadedItems.add(
            WorkoutExerciseItem(
              exerciseId: item['exercise_id']?.toString() ?? '',
              exerciseName: exerciseDetails?['name']?.toString() ?? 'Nome Desconhecido',
              imageUrl: exerciseDetails?['video_url']?.toString() ?? 'https://placehold.co/60',
              sets: item['sets'] is int ? item['sets'] : (int.tryParse(item['sets']?.toString() ?? '3') ?? 3),
              repetitions: item['repetitions'] is int
                  ? item['repetitions']
                  : (int.tryParse(item['repetitions']?.toString() ?? '10') ?? 10),
            ),
          );
        }

        setState(() {
          _exercises = loadedItems;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          _showSnackbar(
            'Treino não encontrado ou erro de carregamento.',
            isError: true,
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Erro ao carregar dados do treino: $e', isError: true);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // FUNÇÃO UNIFICADA: Salva (Cria) ou Atualiza (Edita)
  void _saveWorkout() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackbar('Por favor, dê um nome ao seu treino.');
      return;
    }
    if (_exercises.isEmpty) {
      _showSnackbar('Adicione pelo menos um exercício.');
      return;
    }
    if (_selectedDays.isEmpty) {
      _showSnackbar('Selecione pelo menos um dia para agendar este treino.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.workoutId != null) {
        // LÓGICA DE EDIÇÃO (UPDATE)
        await _workoutService.updateWorkout(
          workoutId: widget.workoutId!,
          workoutName: _nameController.text.trim(),
          items: _exercises,
          scheduleDays: _selectedDays,
        );
        _showSnackbar('Treino atualizado com sucesso!', isError: false);
      } else {
        // LÓGICA DE CRIAÇÃO (CREATE)
        await _workoutService.saveNewWorkout(
          workoutName: _nameController.text.trim(),
          items: _exercises,
          scheduleDays: _selectedDays,
        );
        _showSnackbar('Treino salvo com sucesso!', isError: false);
      }

      Navigator.of(context).pop();
    } catch (e) {
      _showSnackbar('Falha na persistência: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _addExercise() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ExerciseLibraryScreen()),
    );

    if (result != null && result is Map<String, dynamic>) {
      final String? exerciseId = result['id'] as String?;
      final String? exerciseName = result['name'] as String?;
      final String? imageUrl = result['image'] as String?;

      if (exerciseId == null || exerciseId.isEmpty) {
        _showSnackbar('Erro: ID do exercício não encontrado.', isError: true);
        return;
      }

      final newItem = WorkoutExerciseItem(
        exerciseId: exerciseId,
        exerciseName: exerciseName ?? 'Exercício Novo',
        imageUrl: imageUrl ?? 'https://placehold.co/60',
        sets: 3,
        repetitions: 10,
      );

      setState(() {
        _exercises.add(newItem);
      });
    }
  }

  void _deleteExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
    });
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? errorColor : secondaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      // Se estiver carregando, mostra apenas o spinner
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNameInput(),
                        const SizedBox(height: 24),
                        _buildLevelInput(),
                        const SizedBox(height: 24),
                        _buildDaySelector(),
                        const SizedBox(height: 24),
                        _exercises.isEmpty
                            ? _buildEmptyState()
                            : Column(
                                children: List.generate(_exercises.length, (
                                  index,
                                ) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 12.0,
                                    ),
                                    child: _buildExerciseCard(
                                      _exercises[index],
                                      index,
                                    ),
                                  );
                                }),
                              ),
                      ],
                    ),
                  ),
                ),
                _buildAddExerciseButton(),
              ],
            ),
    );
  }

  Widget _buildDaySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12.0),
          child: Text(
            'Dias de Treino',
            style: TextStyle(
              color: textDark,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Wrap(
          spacing: 8.0,
          children: _weekDays.map((day) {
            final isSelected = _selectedDays.contains(day);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedDays.remove(day);
                  } else {
                    _selectedDays.add(day);
                  }
                });
              },
              child: Chip(
                label: Text(day),
                backgroundColor: isSelected
                    ? primaryColor
                    : cardDark.withOpacity(0.4),
                labelStyle: TextStyle(
                  color: isSelected ? backgroundDark : textDark,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? primaryColor : borderDark,
                    width: 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Separar a AppBar para melhor legibilidade
  Widget _buildAppBar() {
    return AppBar(
      backgroundColor: backgroundDark,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: textDark),
        onPressed: () => Navigator.of(context).pop(),
      ),
      centerTitle: true,
      title: Text(
        widget.workoutId != null ? 'Editar Treino' : 'Criar Novo Treino',
        style: const TextStyle(color: textDark, fontWeight: FontWeight.bold),
      ),
      actions: [
        TextButton(
          onPressed: _exercises.isNotEmpty && !_isSaving ? _saveWorkout : null,
          child: Text(
            _isSaving
                ? 'Salvando...'
                : (widget.workoutId != null ? 'Atualizar' : 'Salvar'),
            style: TextStyle(
              color: _exercises.isNotEmpty && !_isSaving
                  ? secondaryColor
                  : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Nome do Treino',
            style: TextStyle(color: textDark, fontWeight: FontWeight.w500),
          ),
        ),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: cardDark.withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderDark),
          ),
          child: TextField(
            controller: _nameController,
            style: const TextStyle(color: textDark, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Ex: Treino de Peito',
              hintStyle: TextStyle(color: subtextDark),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Nível de Dificuldade',
            style: TextStyle(color: textDark, fontWeight: FontWeight.w500),
          ),
        ),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: cardDark.withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderDark),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedLevel,
              hint: Text(
                'Selecione o nível',
                style: TextStyle(color: subtextDark, fontSize: 16),
              ),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: textDark),
              dropdownColor: cardDark,
              style: const TextStyle(color: textDark, fontSize: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              items: _levelMap.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key, // Valor do backend (beginner, intermediate, etc)
                  child: Text(
                    entry.value, // Texto em português (Iniciante, Intermediário, etc)
                    style: const TextStyle(color: textDark),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedLevel = newValue;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseCard(WorkoutExerciseItem item, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: backgroundDark.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: NetworkImage(item.imageUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Detalhes e Controles de Série/Repetição
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.exerciseName,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // Séries
                _buildRepSetControl('Séries:', item.sets, (newValue) {
                  setState(() {
                    item.sets = newValue;
                  });
                }),
                const SizedBox(height: 4),

                // Repetições
                _buildRepSetControl('Reps:', item.repetitions, (newValue) {
                  setState(() {
                    item.repetitions = newValue;
                  });
                }),
              ],
            ),
          ),

          // Botões de Ação (Deletar e Reordenar)
          Column(
            children: [
              IconButton(
                icon: Icon(Icons.delete_outline, color: subtextDark),
                onPressed: () => _deleteExercise(index),
              ),
              const SizedBox(height: 8),
              Icon(
                Icons.drag_indicator,
                color: subtextDark,
                size: 24,
              ), // Ícone de drag para reordenar
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRepSetControl(
    String label,
    int currentValue,
    Function(int) onChange,
  ) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8.0,
      runSpacing: 4.0,
      children: [
        Text(label, style: TextStyle(color: subtextDark, fontSize: 14)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: backgroundDark.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.remove, color: textDark),
                  onPressed: () =>
                      onChange(currentValue > 1 ? currentValue - 1 : 1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  currentValue.toString(),
                  style: const TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.add, color: textDark),
                  onPressed: () => onChange(currentValue + 1),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 50),
          Icon(Icons.fitness_center_outlined, color: subtextDark, size: 60),
          const SizedBox(height: 16),
          Text(
            'Comece a montar seu treino',
            style: const TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Adicione exercícios para criar uma rotina personalizada.',
            style: TextStyle(color: subtextDark, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAddExerciseButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      color: backgroundDark,
      child: SizedBox(
        height: 56,
        child: ElevatedButton(
          onPressed: _addExercise,
          style: ElevatedButton.styleFrom(
            backgroundColor: secondaryColor, // Azul para o botão Adicionar
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Adicionar Exercício',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
