import 'package:flutter/material.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final List<_WorkoutPlan> _plans = [];

  Future<void> _openCreateWorkoutModal() async {
    final result = await showModalBottomSheet<_WorkoutPlan>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CreateWorkoutSheet(),
    );

    if (result == null) return;

    setState(() {
      _plans.add(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF07070B);
    const surfaceColor = Color(0xFF15151D);
    const purpleColor = Color(0xFFB35CFF);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        title: const Text(
          'Workout',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: _plans.isEmpty
            ? _WorkoutEmptyState(onCreatePlan: _openCreateWorkoutModal)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                itemCount: _plans.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final plan = _plans[index];

                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: purpleColor.withValues(alpha: 0.34),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: purpleColor.withValues(alpha: 0.14),
                              ),
                              child: const Icon(
                                Icons.fitness_center_rounded,
                                color: purpleColor,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${plan.goal} · ${plan.location}',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.62,
                                      ),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white54,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _WorkoutChip(label: plan.term),
                            _WorkoutChip(label: '${plan.daysPerWeek} días'),
                            _WorkoutChip(label: plan.level),
                            _WorkoutChip(label: plan.mode),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),

      // No se usa FloatingActionButton.
      // El botón para crear planes está dentro del contenido.
      bottomNavigationBar: _plans.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: FilledButton.icon(
                onPressed: _openCreateWorkoutModal,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crear rutina'),
                style: FilledButton.styleFrom(
                  backgroundColor: purpleColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
    );
  }
}

class _WorkoutEmptyState extends StatelessWidget {
  const _WorkoutEmptyState({required this.onCreatePlan});

  final VoidCallback onCreatePlan;

  @override
  Widget build(BuildContext context) {
    const purpleColor = Color(0xFFB35CFF);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: purpleColor.withValues(alpha: 0.12),
                border: Border.all(color: purpleColor.withValues(alpha: 0.42)),
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                size: 42,
                color: purpleColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Entrenen con un objetivo compartido',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Creen rutinas para casa o gimnasio, definan metas y registren su progreso en pareja.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onCreatePlan,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crear primera rutina'),
              style: FilledButton.styleFrom(
                backgroundColor: purpleColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateWorkoutSheet extends StatefulWidget {
  const _CreateWorkoutSheet();

  @override
  State<_CreateWorkoutSheet> createState() => _CreateWorkoutSheetState();
}

class _CreateWorkoutSheetState extends State<_CreateWorkoutSheet> {
  final TextEditingController _nameController = TextEditingController();

  String _goal = 'Fuerza';
  String _location = 'Gimnasio';
  String _term = 'Corto plazo';
  String _level = 'Principiante';
  String _mode = 'Rutina conjunta';
  int _daysPerWeek = 3;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un nombre para la rutina.')),
      );
      return;
    }

    Navigator.pop(
      context,
      _WorkoutPlan(
        name: name,
        goal: _goal,
        location: _location,
        term: _term,
        level: _level,
        mode: _mode,
        daysPerWeek: _daysPerWeek,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const surfaceColor = Color(0xFF15151D);
    const purpleColor = Color(0xFFB35CFF);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            22,
            14,
            22,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Nueva rutina',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej. Fuerza en pareja',
                  labelStyle: const TextStyle(color: Colors.white60),
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.22),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _WorkoutSelector(
                title: 'Objetivo',
                value: _goal,
                values: const [
                  'Fuerza',
                  'Hipertrofia',
                  'Pérdida de grasa',
                  'Resistencia',
                  'Movilidad',
                  'Bienestar',
                ],
                onChanged: (value) {
                  setState(() => _goal = value);
                },
              ),
              _WorkoutSelector(
                title: 'Lugar',
                value: _location,
                values: const ['Casa', 'Gimnasio', 'Mixto'],
                onChanged: (value) {
                  setState(() => _location = value);
                },
              ),
              _WorkoutSelector(
                title: 'Plazo',
                value: _term,
                values: const ['Corto plazo', 'Largo plazo'],
                onChanged: (value) {
                  setState(() => _term = value);
                },
              ),
              _WorkoutSelector(
                title: 'Nivel',
                value: _level,
                values: const ['Principiante', 'Intermedio', 'Avanzado'],
                onChanged: (value) {
                  setState(() => _level = value);
                },
              ),
              _WorkoutSelector(
                title: 'Modalidad',
                value: _mode,
                values: const [
                  'Rutina conjunta',
                  'Rutinas individuales',
                  'Reto en pareja',
                  'Entrenamiento alternado',
                ],
                onChanged: (value) {
                  setState(() => _mode = value);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Días por semana',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _daysPerWeek > 1
                        ? () {
                            setState(() {
                              _daysPerWeek--;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.remove_rounded),
                    color: Colors.white,
                  ),
                  Text(
                    '$_daysPerWeek',
                    style: const TextStyle(
                      color: purpleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    onPressed: _daysPerWeek < 7
                        ? () {
                            setState(() {
                              _daysPerWeek++;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.add_rounded),
                    color: Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: purpleColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('Crear rutina'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutSelector extends StatelessWidget {
  const _WorkoutSelector({
    required this.title,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String title;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        dropdownColor: const Color(0xFF20202A),
        iconEnabledColor: Colors.white70,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: title,
          labelStyle: const TextStyle(color: Colors.white60),
          filled: true,
          fillColor: Colors.black.withValues(alpha: 0.22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
        items: values
            .map(
              (item) =>
                  DropdownMenuItem<String>(value: item, child: Text(item)),
            )
            .toList(),
        onChanged: (newValue) {
          if (newValue != null) {
            onChanged(newValue);
          }
        },
      ),
    );
  }
}

class _WorkoutChip extends StatelessWidget {
  const _WorkoutChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}

class _WorkoutPlan {
  const _WorkoutPlan({
    required this.name,
    required this.goal,
    required this.location,
    required this.term,
    required this.level,
    required this.mode,
    required this.daysPerWeek,
  });

  final String name;
  final String goal;
  final String location;
  final String term;
  final String level;
  final String mode;
  final int daysPerWeek;
}
