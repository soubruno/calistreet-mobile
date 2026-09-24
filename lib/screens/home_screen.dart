import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/workout_service.dart';
import '../utils/logger.dart';
import 'create_workout_screen.dart';
import 'exercise_library_screen.dart';
import 'my_workouts_screen.dart';
import 'profile_screen.dart';
import 'progress_screen.dart';
import 'workout_in_progress_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _welcomeMessage = 'Olá, Usuário!';
  Map<String, dynamic>? _todaysWorkout;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTodaysWorkout();
  }

  void _loadUserData() async {
    // 1. Lê os dados imediatos do cache local (Hive) através do AuthService
    final userData = AuthService.currentUser;

    if (userData != null) {
      final String? name = userData['name'] as String?;
      if (name != null && name.isNotEmpty && name != 'Usuário') {
        setState(() {
          _welcomeMessage = 'Olá, ${name.split(' ')[0]}!';
          _isLoading = false;
        });
      }

      // 2. Se houver conectividade, tenta sincronizar/atualizar o perfil em segundo plano
      try {
        final userId = userData['user_id'] as String;
        final profile = await AuthService.fetchUserProfile(userId);

        if (mounted && profile != null && profile.containsKey('name')) {
          setState(() {
            _welcomeMessage = 'Olá, ${profile['name'].toString().split(' ')[0]}!';
            _isLoading = false;
          });
        }
      } catch (e) {
        Logger.debug('HomeScreen', 'Perfil carregado via cache offline.');
      }
    }

    if (mounted && _isLoading) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Determina o treino do dia (com suporte offline via Hive)
  void _loadTodaysWorkout() async {
    final userId = AuthService.currentUser?['user_id'];
    if (userId == null) return;

    // 1. Obtém o dia atual em formato abreviado em pt_BR (ex: 'seg', 'ter', 'sáb')
    final currentDayName = DateFormat('EEE', 'pt_BR').format(DateTime.now());
    final String dayAbbr = currentDayName.substring(0, 3);

    // 2. Formata para o padrão esperado (Ex: 'Seg', 'Ter')
    final String finalDayFilter =
        dayAbbr.substring(0, 1).toUpperCase() + dayAbbr.substring(1);

    Logger.debug(
      'HomeScreen',
      'Buscando treinos do dia',
      extra: {'user_id': userId, 'day': finalDayFilter},
    );

    final WorkoutService service = WorkoutService();

    // 3. Procura o treino agendado (se offline, o WorkoutService faz fallback para o Hive)
    final List<Map<String, dynamic>> workouts = await service
        .fetchUserWorkoutsByDay(userId as String, finalDayFilter);

    if (mounted) {
      setState(() {
        _todaysWorkout = workouts.isNotEmpty ? workouts.first : null;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.isCurrent == true) {
      setState(() {
        _selectedIndex = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          _welcomeMessage,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF007AFF)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTodayWorkoutCard(),
                  const SizedBox(height: 16),
                  _buildCustomWorkoutCard(),
                  const SizedBox(height: 16),
                  _buildMyWorkoutsCard(),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomNavigation(),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueAccent),
              child: Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.fitness_center),
              title: const Text('Biblioteca de Exercícios'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ExerciseLibraryScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayWorkoutCard() {
    if (_todaysWorkout == null) {
      return const SizedBox.shrink();
    }

    final String workoutName = _todaysWorkout!['name'] ?? 'Treino Agendado';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1E1E1E),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Image.network(
              'https://images.unsplash.com/vector-1738325063770-a9785d40c39f?q=80&w=880&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              // Fallback elegante quando não há ligação à internet
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 160,
                  width: double.infinity,
                  color: const Color(0xFF252525),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.fitness_center,
                        color: Colors.white38,
                        size: 44,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Calistreet Routine',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workoutName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Agendado para hoje. Mantenha o foco!',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Duração: Estimada',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => WorkoutInProgressScreen(
                              workoutId: _todaysWorkout!['id'],
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Começar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyWorkoutsCard() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const MyWorkoutsScreen()),
        ).then((_) => _loadTodaysWorkout()); // Atualiza a Home ao voltar
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Meus Treinos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Visualize, edite e organize suas rotinas.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFF007AFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.list_alt, color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomWorkoutCard() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const CreateWorkoutScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Monte seu Treino',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Crie um plano personalizado.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFF007AFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(top: BorderSide(color: Color(0xFF2C2C2C), width: 1)),
      ),
      child: BottomNavigationBar(
        backgroundColor: const Color(0xFF000000),
        selectedItemColor: const Color(0xFF007AFF),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          _navigateToScreen(index);
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
        break;
      case 1:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const ProgressScreen()),
        );
        break;
      case 2:
        break;
      case 3:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
        break;
    }
  }

  void _handleLogout() async {
    try {
      await AuthService.signOut();

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao fazer logout: $e'),
            backgroundColor: const Color(0xFF2C2C2C),
          ),
        );
      }
    }
  }
}