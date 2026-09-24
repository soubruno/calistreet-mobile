import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '../../models/user_onboarding_data.dart';
import '../../services/auth_service.dart';

// REUTILIZAÇÃO DAS CORES
const Color primaryColor = Color(0xFF007AFF); // Azul padrão do projeto
const Color backgroundDark = Color(0xFF000000); // Fundo Preto (texto no botão)
const Color surfaceDark = Color(0xFF1C1C1E); // Input Background
const Color textDark = Color(0xFFFFFFFF); // Texto Principal
const Color subtleTextDark = Color(0xFFA3B99D); // Texto Subtil
const Color borderDark = Color(0xFF2E2E30); // Borda

class EquipmentSelectionScreen extends StatefulWidget {
  final UserOnboardingData onboardingData;

  const EquipmentSelectionScreen({super.key, required this.onboardingData});

  @override
  State<EquipmentSelectionScreen> createState() =>
      _EquipmentSelectionScreenState();
}

class _EquipmentSelectionScreenState extends State<EquipmentSelectionScreen> {
  // --- ESTADO ---
  late String _selectedLocation;
  late List<String> _selectedEquipment;
  bool _isLoading = false;

  // Lista de opções de equipamentos
  final List<Map<String, dynamic>> _equipmentOptions = [
    {'label': 'Barra de porta', 'icon': Symbols.horizontal_rule},
    {'label': 'Elásticos', 'icon': Symbols.laps},
    {'label': 'Paralelas', 'icon': Symbols.cadence},
    {'label': 'Argolas', 'icon': Icons.radio_button_unchecked},
    {'label': 'Corda', 'icon': Symbols.cable},
    {'label': 'Halteres', 'icon': Symbols.fitness_center},
  ];

  @override
  void initState() {
    super.initState();
    // Inicializa o estado com dados existentes ou padrão
    _selectedLocation = widget.onboardingData.trainingLocation ?? 'Em casa';
    _selectedEquipment = List.from(widget.onboardingData.equipment);
  }

  void _toggleEquipment(String item) {
    setState(() {
      if (_selectedEquipment.contains(item)) {
        _selectedEquipment.remove(item);
      } else {
        _selectedEquipment.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitle(),
                    const SizedBox(height: 16),
                    _buildProgressBar(),
                    const SizedBox(height: 24),
                    _buildLocationSelector(),
                    const SizedBox(height: 32),
                    _buildEquipmentSelector(),
                  ],
                ),
              ),
            ),

            _buildNextButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 24, top: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: textDark,
              size: 20,
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Onde você vai treinar?',
          style: TextStyle(
            color: textDark,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Selecione os equipamentos que você tem acesso para uma experiência personalizada.',
          style: TextStyle(
            color: subtleTextDark,
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Row(
      children: [
        // Passo 1 (Completo)
        Expanded(child: _buildProgressSegment(isComplete: true)),
        const SizedBox(width: 8),
        // Passo 2 (Completo)
        Expanded(child: _buildProgressSegment(isComplete: true)),
        const SizedBox(width: 8),
        // Passo 3 (Ativo/Completo)
        Expanded(child: _buildProgressSegment(isComplete: true)),
      ],
    );
  }

  Widget _buildProgressSegment({required bool isComplete}) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: isComplete ? primaryColor : borderDark,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildLocationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12.0),
          child: Text(
            'Local de treino',
            style: TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(child: _buildLocationButton('Em casa', Symbols.home)),
            const SizedBox(width: 16),
            Expanded(
              child: _buildLocationButton('Academia', Symbols.fitness_center),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationButton(String label, IconData icon) {
    bool isSelected = _selectedLocation == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLocation = label; // Seleção única
        });
      },
      child: Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.2) : surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : borderDark,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? primaryColor : textDark, size: 40),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? primaryColor : textDark,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12.0),
          child: Text(
            'Equipamentos',
            style: TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
          ),
          itemCount: _equipmentOptions.length,
          itemBuilder: (context, index) {
            final item = _equipmentOptions[index];
            return _buildEquipmentCard(item['label'], item['icon']);
          },
        ),
      ],
    );
  }

  Widget _buildEquipmentCard(String label, IconData icon) {
    bool isSelected = _selectedEquipment.contains(label);

    return GestureDetector(
      onTap: () => _toggleEquipment(label), // Permite seleção múltipla
      child: Container(
        height: 120,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.2) : surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : borderDark,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Usando Symbols para ícones
            Icon(icon, color: isSelected ? primaryColor : textDark, size: 40),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? primaryColor : textDark,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _handleFinalize,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'Finalizar',
                style: TextStyle(
                  color: backgroundDark,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, color: backgroundDark, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleFinalize() async {
    if (_isLoading) return;

    if (_selectedEquipment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione pelo menos um equipamento.'),
          backgroundColor: Color(0xFFE53935),
        ),
      );
      return;
    }

    if (widget.onboardingData.name == null ||
        widget.onboardingData.weight == null ||
        widget.onboardingData.height == null ||
        widget.onboardingData.dateOfBirth == null ||
        widget.onboardingData.gender == null ||
        widget.onboardingData.goal == null ||
        widget.onboardingData.level == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dados incompletos. Por favor, volte e preencha todos os campos.',
          ),
          backgroundColor: Color(0xFFE53935),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Atualizar o DTO com os dados da tela 3
      widget.onboardingData.trainingLocation = _selectedLocation;
      widget.onboardingData.equipment = _selectedEquipment;

      // 2. Obter o ID do usuário logado (armazenado no AuthService durante o Cadastro/Login)
      final userId = AuthService.currentUser?['user_id'];
      if (userId == null) {
        throw Exception(
          'Usuário não autenticado ou ID de usuário não encontrado.',
        );
      }

      // 3. Preparar os dados para o Supabase
      final dataToSave = widget.onboardingData.toJson(userId as String);

      // 4. Inserir na tabela 'user_profiles' utilizando o cliente autenticado (respeitando RLS)
      await AuthService.client.from('user_profiles').insert(dataToSave);

      // 5. Navegar para a Home e limpar a pilha de navegação
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cadastro concluído! Bem-vindo ao Calistreet!'),
            backgroundColor: primaryColor,
          ),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao finalizar cadastro: ${e.toString()}'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}