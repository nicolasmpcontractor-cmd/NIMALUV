import 'dart:ui';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:nimahub_app/core/theme/app_theme.dart';
import 'package:nimahub_app/features/albums/screens/albums_screen.dart';
import 'package:nimahub_app/features/budget/screens/budget_screen.dart';
import 'package:nimahub_app/features/date_planner/screens/date_planner_screen.dart';
import 'package:nimahub_app/features/dates/screens/important_dates_screen.dart';
import 'package:nimahub_app/features/goals/screens/goals_screen.dart';
import 'package:nimahub_app/features/notes/screens/notes_screen.dart';
import 'package:nimahub_app/features/kpi/screens/kpi_screen.dart';
import 'package:nimahub_app/features/trips/screens/trips_screen.dart';
import 'package:nimahub_app/features/workout/screens/workout_screen.dart';
import 'package:nimahub_app/features/nutri_hub/screens/nutri_hub_screen.dart';
import 'package:nimahub_app/features/settings/screens/settings_screen.dart';

enum _QuickDestination {
  notes,
  goals,
  photo,
  finance,
  datePlanner,
  importantDates,
  kpi,
  trips,
  workout,
  nutriHub,
  settings,
  home,
}

enum _QuickCreateAction { photo, expense, date, note, goal, kpi, trip }

class _PetMember {
  const _PetMember({required this.name, required this.kind});

  final String name;
  final String kind;
}

enum _DashboardWidgetType {
  daysTogether,
  anniversaries,
  memories,
  streak,
  goals,
  trips,
  bannerCarousel,
  budgetSummary,
  nextDate,
  moodSummary,
  waterTracker,
  workoutProgress,
  albumHighlight,
  specialDateCountdown,
  goalsProgress,
}

class _DashboardItem {
  const _DashboardItem({
    required this.id,
    required this.type,
    required this.column,
    required this.row,
    required this.columnSpan,
    required this.rowSpan,
  });

  final String id;
  final _DashboardWidgetType type;

  final int column;
  final int row;

  final int columnSpan;
  final int rowSpan;

  _DashboardItem copyWith({
    int? column,
    int? row,
    int? columnSpan,
    int? rowSpan,
  }) {
    return _DashboardItem(
      id: id,
      type: type,
      column: column ?? this.column,
      row: row ?? this.row,
      columnSpan: columnSpan ?? this.columnSpan,
      rowSpan: rowSpan ?? this.rowSpan,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _isQuickMenuOpen = false;
  _QuickDestination _selectedQuickDestination =
      _QuickDestination.home; // null significa que se está mostrando el Home.
  _QuickDestination? _currentDestination;
  bool _isFavoritePickerOpen = false;
  final GlobalKey<_QuickActionOverlayState> _quickActionOverlayKey =
      GlobalKey<_QuickActionOverlayState>();
  bool _partnerOneGoogleConnected = false;
  bool _partnerTwoGoogleConnected = false;
  bool _isDashboardEditing = false;
  bool _isDashboardWidgetLibraryOpen = false;

  final List<_PetMember> _petMembers = [];
  List<String> _quickFavoriteLabels = [
    'Nota',
    'Logros',
    'Foto',
    'Finanzas',
    'Date',
    'Fechas',
    'KPI',
    'Viajes',
    'Workout',
    'Nutri Hub',
    'Configuración',
    'Inicio',
  ];

  String _selectedQuickActionLabel = 'Inicio';
  String _partnerOneName = 'Pareja #1';
  String _partnerTwoName = 'Pareja #2';

  String? _partnerOnePhotoUrl;
  String? _partnerTwoPhotoUrl;
  String? _heroBackgroundPath;
  Matrix4 _heroBackgroundTransform = Matrix4.identity();

  bool _isHeroBackgroundEditing = false;

  String? _previousHeroBackgroundPath;
  Matrix4 _previousHeroBackgroundTransform = Matrix4.identity();

  late final TransformationController _heroBackgroundController;

  late final AnimationController _quickMenuController;
  late final Animation<double> _quickMenuFade;
  late final Animation<double> _quickMenuScale;
  late final Animation<Offset> _quickMenuSlide;
  late final AnimationController _previewTransitionController;
  late final Animation<double> _previewTransitionFade;
  late final List<_DashboardItem> _dashboardItems;

  _QuickDestination _previousPreviewDestination = _QuickDestination.home;

  Future<void> _openHeroBackgroundEditor() async {
    if (_isDashboardEditing || _isHeroBackgroundEditing) {
      return;
    }

    HapticFeedback.mediumImpact();

    final pickedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (!mounted || pickedImage == null) {
      return;
    }

    _previousHeroBackgroundPath = _heroBackgroundPath;

    _previousHeroBackgroundTransform = Matrix4.copy(_heroBackgroundTransform);

    _heroBackgroundController.value = Matrix4.identity();

    setState(() {
      _heroBackgroundPath = pickedImage.path;
      _heroBackgroundTransform = Matrix4.identity();
      _isHeroBackgroundEditing = true;
    });
  }

  void _saveHeroBackgroundEditor() {
    if (!_isHeroBackgroundEditing) {
      return;
    }

    final Matrix4 savedTransform = Matrix4.copy(
      _heroBackgroundController.value,
    );

    setState(() {
      _heroBackgroundTransform = savedTransform;

      _isHeroBackgroundEditing = false;
      _previousHeroBackgroundPath = null;
    });

    HapticFeedback.mediumImpact();
  }

  void _cancelHeroBackgroundEditor() {
    if (!_isHeroBackgroundEditing) {
      return;
    }

    final Matrix4 restoredTransform = Matrix4.copy(
      _previousHeroBackgroundTransform,
    );

    _heroBackgroundController.value = restoredTransform;

    setState(() {
      _heroBackgroundPath = _previousHeroBackgroundPath;

      _heroBackgroundTransform = restoredTransform;

      _isHeroBackgroundEditing = false;
      _previousHeroBackgroundPath = null;
    });

    HapticFeedback.selectionClick();
  }

  @override
  void initState() {
    super.initState();

    _heroBackgroundController = TransformationController(
      Matrix4.copy(_heroBackgroundTransform),
    );

    _dashboardItems = [
      const _DashboardItem(
        id: 'kpi_days_together',
        type: _DashboardWidgetType.daysTogether,
        column: 0,
        row: 0,
        columnSpan: 1,
        rowSpan: 1,
      ),
      const _DashboardItem(
        id: 'kpi_anniversaries',
        type: _DashboardWidgetType.anniversaries,
        column: 1,
        row: 0,
        columnSpan: 1,
        rowSpan: 1,
      ),
      const _DashboardItem(
        id: 'kpi_memories',
        type: _DashboardWidgetType.memories,
        column: 2,
        row: 0,
        columnSpan: 1,
        rowSpan: 1,
      ),
      const _DashboardItem(
        id: 'kpi_streak',
        type: _DashboardWidgetType.streak,
        column: 3,
        row: 0,
        columnSpan: 1,
        rowSpan: 1,
      ),
      const _DashboardItem(
        id: 'kpi_goals',
        type: _DashboardWidgetType.goals,
        column: 4,
        row: 0,
        columnSpan: 1,
        rowSpan: 1,
      ),
      const _DashboardItem(
        id: 'kpi_trips',
        type: _DashboardWidgetType.trips,
        column: 5,
        row: 0,
        columnSpan: 1,
        rowSpan: 1,
      ),
      const _DashboardItem(
        id: 'banner_carousel',
        type: _DashboardWidgetType.bannerCarousel,
        column: 0,
        row: 1,
        columnSpan: 6,
        rowSpan: 1,
      ),
      const _DashboardItem(
        id: 'budget_summary',
        type: _DashboardWidgetType.budgetSummary,
        column: 0,
        row: 2,
        columnSpan: 3,
        rowSpan: 2,
      ),
      const _DashboardItem(
        id: 'next_date',
        type: _DashboardWidgetType.nextDate,
        column: 3,
        row: 2,
        columnSpan: 3,
        rowSpan: 2,
      ),
      const _DashboardItem(
        id: 'mood_summary',
        type: _DashboardWidgetType.moodSummary,
        column: 0,
        row: 4,
        columnSpan: 2,
        rowSpan: 2,
      ),
      const _DashboardItem(
        id: 'water_tracker',
        type: _DashboardWidgetType.waterTracker,
        column: 2,
        row: 4,
        columnSpan: 2,
        rowSpan: 2,
      ),
      const _DashboardItem(
        id: 'workout_progress',
        type: _DashboardWidgetType.workoutProgress,
        column: 4,
        row: 4,
        columnSpan: 2,
        rowSpan: 2,
      ),
      const _DashboardItem(
        id: 'album_highlight',
        type: _DashboardWidgetType.albumHighlight,
        column: 0,
        row: 6,
        columnSpan: 3,
        rowSpan: 2,
      ),
      const _DashboardItem(
        id: 'special_date_countdown',
        type: _DashboardWidgetType.specialDateCountdown,
        column: 3,
        row: 6,
        columnSpan: 3,
        rowSpan: 2,
      ),
      const _DashboardItem(
        id: 'goals_progress',
        type: _DashboardWidgetType.goalsProgress,
        column: 0,
        row: 8,
        columnSpan: 6,
        rowSpan: 1,
      ),
    ];

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemStatusBarContrastEnforced: false,

        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
    );

    _quickMenuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 330),
    );

    final curvedAnimation = CurvedAnimation(
      parent: _quickMenuController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _quickMenuFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _quickMenuController,
        curve: const Interval(0.0, 0.22, curve: Curves.easeOut),
        reverseCurve: const Interval(0.0, 0.18, curve: Curves.easeIn),
      ),
    );

    _quickMenuScale = Tween<double>(
      begin: 0.86,
      end: 1,
    ).animate(curvedAnimation);

    _quickMenuSlide =
        Tween<Offset>(begin: const Offset(0, 0.28), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _quickMenuController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
    // Controlador de la transición entre previews.
    _previewTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    // Animación de opacidad de la nueva preview.
    _previewTransitionFade = CurvedAnimation(
      parent: _previewTransitionController,
      curve: Curves.easeOutCubic,
    );

    // Al terminar, la nueva preview se convierte
    // en la preview base.
    _previewTransitionController.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) {
        return;
      }

      setState(() {
        _previousPreviewDestination = _selectedQuickDestination;
      });

      _previewTransitionController.reset();
    });
  }

  @override
  void dispose() {
    _heroBackgroundController.dispose();
    _previewTransitionController.dispose();
    _quickMenuController.dispose();
    super.dispose();
  }

  Future<void> vibrateQuickMenu() async {
    final hasVibrator = await Vibration.hasVibrator();

    if (hasVibrator != true) {
      await HapticFeedback.mediumImpact();
      return;
    }

    final hasAmplitudeControl = await Vibration.hasAmplitudeControl();

    if (hasAmplitudeControl == true) {
      await Vibration.vibrate(duration: 70, amplitude: 180);
    } else {
      await Vibration.vibrate(duration: 70);
    }
  }

  void _showDestination(_QuickDestination destination) {
    if (destination == _QuickDestination.home) {
      if (_currentDestination == null) return;

      setState(() {
        _currentDestination = null;
      });

      return;
    }

    if (_currentDestination == destination) return;

    setState(() {
      _currentDestination = destination;
    });
  }

  void _handleQuickCreateAction(_QuickCreateAction action) {
    switch (action) {
      case _QuickCreateAction.photo:
        _showDestination(_QuickDestination.photo);
        return;

      case _QuickCreateAction.expense:
        _showDestination(_QuickDestination.finance);
        return;

      case _QuickCreateAction.date:
        _showDestination(_QuickDestination.datePlanner);
        return;

      case _QuickCreateAction.note:
        _showDestination(_QuickDestination.notes);
        return;

      case _QuickCreateAction.goal:
        _showDestination(_QuickDestination.goals);
        return;

      case _QuickCreateAction.kpi:
        _showDestination(_QuickDestination.kpi);
        return;

      case _QuickCreateAction.trip:
        _showDestination(_QuickDestination.trips);
        return;
    }
  }

  void _startDashboardEditingFromItem(_DashboardItem item) {
    if (_isDashboardEditing) {
      return;
    }

    setState(() {
      _isDashboardEditing = true;
      _isDashboardWidgetLibraryOpen = false;
    });
  }

  Future<void> _openQuickActionPanel() async {
    HapticFeedback.selectionClick();

    if (_quickMenuController.value > 0) {
      closeQuickMenu();
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      barrierLabel: 'Cerrar acciones rápidas',
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return _QuickActionSideDialog(
          animation: curvedAnimation,
          onSelected: (action) {
            _handleQuickCreateAction(action);
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  void _connectGooglePartnerPreview(int partnerNumber) {
    HapticFeedback.selectionClick();

    setState(() {
      if (partnerNumber == 1) {
        _partnerOneGoogleConnected = true;
      } else {
        _partnerTwoGoogleConnected = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pareja $partnerNumber marcada como conectada.')),
    );
  }

  void _goHomeFromCenterLongPress() {
    HapticFeedback.mediumImpact();

    _previewTransitionController.stop();
    _previewTransitionController.reset();

    setState(() {
      // null representa el Home principal real.
      _currentDestination = null;

      // Deja Inicio como preview seleccionada para la próxima apertura.
      _selectedQuickDestination = _QuickDestination.home;
      _previousPreviewDestination = _QuickDestination.home;
      _selectedQuickActionLabel = 'Inicio';

      _isFavoritePickerOpen = false;
    });

    // Cierra el menú circular si estaba abierto.
    if (_quickMenuController.value > 0.0) {
      closeQuickMenu();
    }
  }

  Future<void> _confirmSelectedDestination() async {
    _showDestination(_selectedQuickDestination);

    if (_isQuickMenuOpen) {
      await closeQuickMenu();
    }
  }

  Future<void> toggleQuickMenu() async {
    await vibrateQuickMenu();

    if (_isQuickMenuOpen) {
      await _confirmSelectedDestination();
      return;
    }

    setState(() {
      _isQuickMenuOpen = true;
    });

    await _quickMenuController.forward(from: 0);
  }

  Future<void> closeQuickMenu() async {
    await _quickMenuController.reverse();

    if (!mounted) return;

    setState(() {
      _isQuickMenuOpen = false;
    });
  }

  void _setSelectedQuickActionLabel(String label) {
    if (_selectedQuickActionLabel == label) return;

    setState(() {
      _selectedQuickActionLabel = label;
    });
  }

  Future<void> _editPartnerProfile({required bool isFirstPartner}) async {
    final currentName = isFirstPartner ? _partnerOneName : _partnerTwoName;
    final currentPhotoUrl = isFirstPartner
        ? _partnerOnePhotoUrl
        : _partnerTwoPhotoUrl;

    final result = await showModalBottomSheet<Map<String, String?>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _PartnerEditSheet(
          title: isFirstPartner ? 'Editar Pareja #1' : 'Editar Pareja #2',
          initialName: currentName,
          initialPhotoUrl: currentPhotoUrl,
        );
      },
    );

    if (!mounted || result == null) return;

    final newName = result['name']?.trim() ?? '';
    final newPhotoUrl = result['photoUrl']?.trim() ?? '';

    setState(() {
      if (isFirstPartner) {
        _partnerOneName = newName.isEmpty ? 'Pareja #1' : newName;
        _partnerOnePhotoUrl = newPhotoUrl.isEmpty ? null : newPhotoUrl;
      } else {
        _partnerTwoName = newName.isEmpty ? 'Pareja #2' : newName;
        _partnerTwoPhotoUrl = newPhotoUrl.isEmpty ? null : newPhotoUrl;
      }
    });
  }

  Future<void> _openAddPetDialog() async {
    final nameController = TextEditingController();
    String selectedKind = 'Gato';

    final result = await showDialog<_PetMember>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1B20),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              title: const Text(
                'Agregar mascota',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nombre',
                      labelStyle: const TextStyle(color: Color(0xFFA4A6AE)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedKind,
                    dropdownColor: const Color(0xFF24252B),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Tipo',
                      labelStyle: const TextStyle(color: Color(0xFFA4A6AE)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Gato', child: Text('Gato')),
                      DropdownMenuItem(value: 'Perro', child: Text('Perro')),
                      DropdownMenuItem(value: 'Ave', child: Text('Ave')),
                      DropdownMenuItem(value: 'Conejo', child: Text('Conejo')),
                      DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      setDialogState(() {
                        selectedKind = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();

                    if (name.isEmpty) return;

                    Navigator.of(
                      dialogContext,
                    ).pop(_PetMember(name: name, kind: selectedKind));
                  },
                  child: const Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();

    if (result == null || !mounted) return;

    setState(() {
      _petMembers.add(result);
    });
  }

  Future<void> _openMembersPanel() async {
    HapticFeedback.selectionClick();

    if (_quickMenuController.value > 0) {
      closeQuickMenu();
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      barrierLabel: 'Cerrar miembros',
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return _MembersSideDialog(
          animation: curvedAnimation,
          partnerOneName: _partnerOneName,
          partnerTwoName: _partnerTwoName,
          partnerOneConnected: _partnerOneGoogleConnected,
          partnerTwoConnected: _partnerTwoGoogleConnected,
          pets: List<_PetMember>.unmodifiable(_petMembers),
          onConnectPartnerOne: () {
            Navigator.of(dialogContext).pop();

            _connectGooglePartnerPreview(1);
          },
          onConnectPartnerTwo: () {
            Navigator.of(dialogContext).pop();

            _connectGooglePartnerPreview(2);
          },
          onAddPet: () {
            Navigator.of(dialogContext).pop();

            Future<void>.delayed(
              const Duration(milliseconds: 150),
              _openAddPetDialog,
            );
          },
          onRemovePet: (index) {
            Navigator.of(dialogContext).pop();

            setState(() {
              _petMembers.removeAt(index);
            });
          },
        );
      },
    );
  }

  void _replaceQuickFavorite(int targetSlot, String selectedLabel) {
    if (targetSlot < 0 || targetSlot >= _quickFavoriteLabels.length) {
      return;
    }

    final int selectedSlot = _quickFavoriteLabels.indexOf(selectedLabel);

    if (selectedSlot == -1 || selectedSlot == targetSlot) {
      return;
    }

    setState(() {
      final updatedOrder = List<String>.from(_quickFavoriteLabels);

      final String currentLabel = updatedOrder[targetSlot];

      // Intercambia las dos herramientas.
      updatedOrder[targetSlot] = selectedLabel;
      updatedOrder[selectedSlot] = currentLabel;

      _quickFavoriteLabels = updatedOrder;
    });
  }

  void _setFavoritePickerOpen(bool isOpen) {
    if (_isFavoritePickerOpen == isOpen) return;

    setState(() {
      _isFavoritePickerOpen = isOpen;
    });
  }

  Future<void> _handleCenterButtonTap() async {
    if (_isFavoritePickerOpen) {
      final overlayState = _quickActionOverlayKey.currentState;

      if (overlayState != null) {
        overlayState.closeFavoritePicker();
      } else if (mounted) {
        setState(() {
          _isFavoritePickerOpen = false;
        });
      }

      return;
    }

    await toggleQuickMenu();
  }

  Widget _buildQuickDestinationScreen(
    BuildContext context,
    _QuickDestination destination,
  ) {
    switch (destination) {
      case _QuickDestination.notes:
        return NotesScreen(showCreateButton: !_isQuickMenuOpen);
      case _QuickDestination.goals:
        return const GoalsScreen();
      case _QuickDestination.photo:
        return const AlbumsScreen();
      case _QuickDestination.finance:
        return const BudgetScreen();
      case _QuickDestination.datePlanner:
        return const DatePlannerScreen();
      case _QuickDestination.importantDates:
        return const ImportantDatesScreen();
      case _QuickDestination.kpi:
        return const KpiScreen();
      case _QuickDestination.trips:
        return const TripsScreen();
      case _QuickDestination.workout:
        return const WorkoutScreen();
      case _QuickDestination.nutriHub:
        return const NutriHubScreen();
      case _QuickDestination.settings:
        return const SettingsScreen();
      case _QuickDestination.home:
        return _buildHomeContent(context);
    }
  }

  Widget _buildDashboardWidget(_DashboardItem item) {
    switch (item.type) {
      case _DashboardWidgetType.daysTogether:
        return const _StatCard(
          icon: Icons.favorite_border_rounded,
          value: '528',
          label: 'juntos',
          accentColor: AppColors.neonPink,
        );
      case _DashboardWidgetType.anniversaries:
        return const _StatCard(
          icon: Icons.calendar_month_outlined,
          value: '24',
          label: 'aniv.',
          accentColor: AppColors.neonPurple,
        );
      case _DashboardWidgetType.memories:
        return const _StatCard(
          icon: Icons.image_outlined,
          value: '12',
          label: 'rec.',
          accentColor: AppColors.neonBlue,
        );
      case _DashboardWidgetType.streak:
        return const _StatCard(
          icon: Icons.local_fire_department_rounded,
          value: '7',
          label: 'racha',
          accentColor: AppColors.neonOrange,
        );
      case _DashboardWidgetType.goals:
        return const _StatCard(
          icon: Icons.flag_outlined,
          value: '3',
          label: 'metas',
          accentColor: AppColors.neonCyan,
        );
      case _DashboardWidgetType.trips:
        return const _StatCard(
          icon: Icons.flight_takeoff_rounded,
          value: '2',
          label: 'viajes',
          accentColor: Color(0xFF7CFFB2),
        );
      case _DashboardWidgetType.budgetSummary:
        return const _BudgetSummaryWidget();

      case _DashboardWidgetType.nextDate:
        return const _NextDateWidget();

      case _DashboardWidgetType.moodSummary:
        return const _MoodSummaryWidget();

      case _DashboardWidgetType.waterTracker:
        return const _WaterTrackerWidget();

      case _DashboardWidgetType.workoutProgress:
        return const _WorkoutProgressWidget();

      case _DashboardWidgetType.albumHighlight:
        return const _AlbumHighlightWidget();

      case _DashboardWidgetType.specialDateCountdown:
        return const _SpecialDateCountdownWidget();

      case _DashboardWidgetType.goalsProgress:
        return const _GoalsProgressWidget();
      case _DashboardWidgetType.bannerCarousel:
        return const _AchievementBanner();
    }
  }

  void _toggleDashboardEditing() {
    HapticFeedback.selectionClick();

    final bool willStartEditing = !_isDashboardEditing;

    if (willStartEditing && _quickMenuController.value > 0) {
      closeQuickMenu();
    }

    setState(() {
      _isDashboardEditing = willStartEditing;
      _isFavoritePickerOpen = false;
      _isDashboardWidgetLibraryOpen = false;
    });
  }

  void _closeDashboardEditorFromBack() {
    if (!_isDashboardEditing) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _isDashboardEditing = false;
      _isDashboardWidgetLibraryOpen = false;
      _isFavoritePickerOpen = false;
    });
  }

  void _removeDashboardItem(String itemId) {
    HapticFeedback.lightImpact();

    setState(() {
      _dashboardItems.removeWhere((item) => item.id == itemId);
    });
  }

  bool _dashboardItemsOverlap(_DashboardItem first, _DashboardItem second) {
    final bool separatedHorizontally =
        first.column + first.columnSpan <= second.column ||
        second.column + second.columnSpan <= first.column;

    final bool separatedVertically =
        first.row + first.rowSpan <= second.row ||
        second.row + second.rowSpan <= first.row;

    return !separatedHorizontally && !separatedVertically;
  }

  bool _canPlaceDashboardItem(
    _DashboardItem candidate, {
    String? ignoringItemId,
  }) {
    if (candidate.column < 0 ||
        candidate.row < 0 ||
        candidate.column + candidate.columnSpan > 6 ||
        candidate.row + candidate.rowSpan > 9) {
      return false;
    }

    for (final existingItem in _dashboardItems) {
      if (existingItem.id == ignoringItemId) {
        continue;
      }

      if (_dashboardItemsOverlap(candidate, existingItem)) {
        return false;
      }
    }

    return true;
  }

  bool _moveDashboardItem(_DashboardItem item, int column, int row) {
    const int columnCount = 6;
    const int rowCount = 9;

    bool fitsInsideGrid(_DashboardItem candidate) {
      return candidate.column >= 0 &&
          candidate.row >= 0 &&
          candidate.column + candidate.columnSpan <= columnCount &&
          candidate.row + candidate.rowSpan <= rowCount;
    }

    bool overlaps(_DashboardItem first, _DashboardItem second) {
      final bool separatedHorizontally =
          first.column + first.columnSpan <= second.column ||
          second.column + second.columnSpan <= first.column;

      final bool separatedVertically =
          first.row + first.rowSpan <= second.row ||
          second.row + second.rowSpan <= first.row;

      return !separatedHorizontally && !separatedVertically;
    }

    final int draggedIndex = _dashboardItems.indexWhere(
      (currentItem) => currentItem.id == item.id,
    );

    if (draggedIndex == -1) {
      return false;
    }

    final _DashboardItem draggedItem = _dashboardItems[draggedIndex];

    final _DashboardItem candidate = draggedItem.copyWith(
      column: column,
      row: row,
    );

    if (!fitsInsideGrid(candidate)) {
      return false;
    }

    final List<_DashboardItem> overlappingItems = _dashboardItems.where((
      existingItem,
    ) {
      if (existingItem.id == draggedItem.id) {
        return false;
      }

      return overlaps(candidate, existingItem);
    }).toList();

    // No hay otro widget debajo: movimiento normal.
    if (overlappingItems.isEmpty) {
      setState(() {
        _dashboardItems[draggedIndex] = candidate;
      });

      HapticFeedback.selectionClick();
      return true;
    }

    // No se permite cubrir varios widgets simultáneamente.
    if (overlappingItems.length != 1) {
      return false;
    }

    final _DashboardItem targetItem = overlappingItems.single;

    final int draggedCellCount = draggedItem.columnSpan * draggedItem.rowSpan;

    final int targetCellCount = targetItem.columnSpan * targetItem.rowSpan;

    // Solo pueden intercambiarse si usan la misma cantidad de celdas.
    if (draggedCellCount != targetCellCount) {
      return false;
    }

    // El widget arrastrado debe quedar alineado con el origen
    // exacto del widget objetivo.
    if (candidate.column != targetItem.column ||
        candidate.row != targetItem.row) {
      return false;
    }

    final _DashboardItem relocatedTarget = targetItem.copyWith(
      column: draggedItem.column,
      row: draggedItem.row,
    );

    if (!fitsInsideGrid(relocatedTarget)) {
      return false;
    }

    // Comprueba que las dos nuevas posiciones no choquen
    // con ningún tercer widget.
    for (final existingItem in _dashboardItems) {
      if (existingItem.id == draggedItem.id ||
          existingItem.id == targetItem.id) {
        continue;
      }

      if (overlaps(candidate, existingItem) ||
          overlaps(relocatedTarget, existingItem)) {
        return false;
      }
    }

    // También valida que las formas intercambiadas no se crucen.
    if (overlaps(candidate, relocatedTarget)) {
      return false;
    }

    final int targetIndex = _dashboardItems.indexWhere(
      (existingItem) => existingItem.id == targetItem.id,
    );

    if (targetIndex == -1) {
      return false;
    }

    setState(() {
      _dashboardItems[draggedIndex] = candidate;
      _dashboardItems[targetIndex] = relocatedTarget;
    });

    HapticFeedback.mediumImpact();
    return true;
  }

  _DashboardItem _createDashboardItem(
    _DashboardWidgetType type,
    int column,
    int row,
  ) {
    switch (type) {
      case _DashboardWidgetType.daysTogether:
        return _DashboardItem(
          id: 'kpi_days_together',
          type: type,
          column: column,
          row: row,
          columnSpan: 1,
          rowSpan: 1,
        );

      case _DashboardWidgetType.anniversaries:
        return _DashboardItem(
          id: 'kpi_anniversaries',
          type: type,
          column: column,
          row: row,
          columnSpan: 1,
          rowSpan: 1,
        );

      case _DashboardWidgetType.memories:
        return _DashboardItem(
          id: 'kpi_memories',
          type: type,
          column: column,
          row: row,
          columnSpan: 1,
          rowSpan: 1,
        );

      case _DashboardWidgetType.streak:
        return _DashboardItem(
          id: 'kpi_streak',
          type: type,
          column: column,
          row: row,
          columnSpan: 1,
          rowSpan: 1,
        );

      case _DashboardWidgetType.goals:
        return _DashboardItem(
          id: 'kpi_goals',
          type: type,
          column: column,
          row: row,
          columnSpan: 1,
          rowSpan: 1,
        );

      case _DashboardWidgetType.trips:
        return _DashboardItem(
          id: 'kpi_trips',
          type: type,
          column: column,
          row: row,
          columnSpan: 1,
          rowSpan: 1,
        );

      case _DashboardWidgetType.bannerCarousel:
        return _DashboardItem(
          id: 'banner_carousel',
          type: type,
          column: column,
          row: row,
          columnSpan: 6,
          rowSpan: 1,
        );

      case _DashboardWidgetType.budgetSummary:
        return _DashboardItem(
          id: 'budget_summary',
          type: type,
          column: column,
          row: row,
          columnSpan: 3,
          rowSpan: 2,
        );

      case _DashboardWidgetType.nextDate:
        return _DashboardItem(
          id: 'next_date',
          type: type,
          column: column,
          row: row,
          columnSpan: 3,
          rowSpan: 2,
        );

      case _DashboardWidgetType.moodSummary:
        return _DashboardItem(
          id: 'mood_summary',
          type: type,
          column: column,
          row: row,
          columnSpan: 2,
          rowSpan: 2,
        );

      case _DashboardWidgetType.waterTracker:
        return _DashboardItem(
          id: 'water_tracker',
          type: type,
          column: column,
          row: row,
          columnSpan: 2,
          rowSpan: 2,
        );

      case _DashboardWidgetType.workoutProgress:
        return _DashboardItem(
          id: 'workout_progress',
          type: type,
          column: column,
          row: row,
          columnSpan: 2,
          rowSpan: 2,
        );

      case _DashboardWidgetType.albumHighlight:
        return _DashboardItem(
          id: 'album_highlight',
          type: type,
          column: column,
          row: row,
          columnSpan: 3,
          rowSpan: 2,
        );

      case _DashboardWidgetType.specialDateCountdown:
        return _DashboardItem(
          id: 'special_date_countdown',
          type: type,
          column: column,
          row: row,
          columnSpan: 3,
          rowSpan: 2,
        );

      case _DashboardWidgetType.goalsProgress:
        return _DashboardItem(
          id: 'goals_progress',
          type: type,
          column: column,
          row: row,
          columnSpan: 6,
          rowSpan: 1,
        );
    }
  }

  _DashboardItem? _findAvailableDashboardPosition(_DashboardWidgetType type) {
    final template = _createDashboardItem(type, 0, 0);
    for (int row = 0; row < 9; row++) {
      for (int column = 0; column < 6; column++) {
        final candidate = template.copyWith(column: column, row: row);
        if (_canPlaceDashboardItem(candidate)) {
          return candidate;
        }
      }
    }
    return null;
  }

  String _dashboardWidgetName(_DashboardWidgetType type) {
    switch (type) {
      case _DashboardWidgetType.daysTogether:
        return 'Días juntos';
      case _DashboardWidgetType.anniversaries:
        return 'Aniversarios';
      case _DashboardWidgetType.memories:
        return 'Recuerdos';
      case _DashboardWidgetType.streak:
        return 'Racha';
      case _DashboardWidgetType.goals:
        return 'Metas';
      case _DashboardWidgetType.trips:
        return 'Viajes';
      case _DashboardWidgetType.bannerCarousel:
        return 'Galería de banners';
      case _DashboardWidgetType.budgetSummary:
        return 'Resumen de presupuesto';
      case _DashboardWidgetType.nextDate:
        return 'Próxima cita';
      case _DashboardWidgetType.moodSummary:
        return 'Estado de ánimo';
      case _DashboardWidgetType.waterTracker:
        return 'Control de agua';
      case _DashboardWidgetType.workoutProgress:
        return 'Progreso workout';
      case _DashboardWidgetType.albumHighlight:
        return 'Recuerdo destacado';
      case _DashboardWidgetType.specialDateCountdown:
        return 'Fecha especial';
      case _DashboardWidgetType.goalsProgress:
        return 'Metas compartidas';
    }
  }

  IconData _dashboardWidgetIcon(_DashboardWidgetType type) {
    switch (type) {
      case _DashboardWidgetType.daysTogether:
        return Icons.favorite_border_rounded;
      case _DashboardWidgetType.anniversaries:
        return Icons.calendar_month_outlined;
      case _DashboardWidgetType.memories:
        return Icons.image_outlined;
      case _DashboardWidgetType.streak:
        return Icons.local_fire_department_rounded;
      case _DashboardWidgetType.goals:
        return Icons.flag_outlined;
      case _DashboardWidgetType.trips:
        return Icons.flight_takeoff_rounded;
      case _DashboardWidgetType.bannerCarousel:
        return Icons.view_carousel_rounded;
      case _DashboardWidgetType.budgetSummary:
        return Icons.account_balance_wallet_rounded;
      case _DashboardWidgetType.nextDate:
        return Icons.favorite_rounded;
      case _DashboardWidgetType.moodSummary:
        return Icons.sentiment_satisfied_alt_rounded;
      case _DashboardWidgetType.waterTracker:
        return Icons.water_drop_rounded;
      case _DashboardWidgetType.workoutProgress:
        return Icons.fitness_center_rounded;
      case _DashboardWidgetType.albumHighlight:
        return Icons.photo_library_rounded;
      case _DashboardWidgetType.specialDateCountdown:
        return Icons.event_rounded;
      case _DashboardWidgetType.goalsProgress:
        return Icons.flag_rounded;
    }
  }

  Color _dashboardWidgetColor(_DashboardWidgetType type) {
    switch (type) {
      case _DashboardWidgetType.daysTogether:
        return AppColors.neonPink;
      case _DashboardWidgetType.anniversaries:
        return AppColors.neonPurple;
      case _DashboardWidgetType.memories:
        return AppColors.neonBlue;
      case _DashboardWidgetType.streak:
        return AppColors.neonOrange;
      case _DashboardWidgetType.goals:
        return AppColors.neonCyan;
      case _DashboardWidgetType.trips:
        return const Color(0xFF7CFFB2);
      case _DashboardWidgetType.bannerCarousel:
        return const Color(0xFFFF3B3B);
      case _DashboardWidgetType.budgetSummary:
        return AppColors.neonCyan;
      case _DashboardWidgetType.nextDate:
        return AppColors.neonPink;
      case _DashboardWidgetType.moodSummary:
        return AppColors.neonPurple;
      case _DashboardWidgetType.waterTracker:
        return AppColors.neonBlue;
      case _DashboardWidgetType.workoutProgress:
        return const Color(0xFF7CFFB2);
      case _DashboardWidgetType.albumHighlight:
        return AppColors.neonPurple;
      case _DashboardWidgetType.specialDateCountdown:
        return AppColors.neonOrange;
      case _DashboardWidgetType.goalsProgress:
        return AppColors.neonPink;
    }
  }

  void _toggleDashboardWidgetLibrary() {
    if (!_isDashboardEditing) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _isDashboardWidgetLibraryOpen = !_isDashboardWidgetLibraryOpen;
    });
  }

  void _addDashboardWidgetFromLibrary(_DashboardWidgetType type) {
    final bool alreadyExists = _dashboardItems.any((item) => item.type == type);

    if (alreadyExists) {
      return;
    }

    final _DashboardItem? itemToAdd = _findAvailableDashboardPosition(type);

    if (itemToAdd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay suficiente espacio disponible.')),
      );

      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _dashboardItems.add(itemToAdd);
      _isDashboardWidgetLibraryOpen = false;
    });
  }

  Widget _buildDashboardEditorOverlay(BuildContext context) {
    final double topInset = MediaQuery.paddingOf(context).top;

    final List<_DashboardWidgetType> availableTypes = _DashboardWidgetType
        .values
        .where((type) => !_dashboardItems.any((item) => item.type == type))
        .toList();

    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Franja superior: abrir catálogo.
          Positioned(
            left: -18,
            right: -18,
            top: topInset - 4,
            height: 34,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleDashboardWidgetLibrary,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: const Color(0xFF24262C).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: _isDashboardWidgetLibraryOpen
                        ? Colors.white.withValues(alpha: 0.88)
                        : Colors.white.withValues(alpha: 0.50),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(
                        alpha: _isDashboardWidgetLibraryOpen ? 0.20 : 0.10,
                      ),
                      blurRadius: _isDashboardWidgetLibraryOpen ? 16 : 9,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_circle_outline_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                    const SizedBox(width: 9),
                    const Text(
                      'Agregar widget',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _isDashboardWidgetLibraryOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFFB8BBC4),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Catálogo desplegable debajo de la franja superior.
          Positioned(
            left: 16,
            right: 16,
            top: topInset + 36,
            child: IgnorePointer(
              ignoring: !_isDashboardWidgetLibraryOpen,
              child: AnimatedSlide(
                offset: _isDashboardWidgetLibraryOpen
                    ? Offset.zero
                    : const Offset(0, -0.12),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _isDashboardWidgetLibraryOpen ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    height: 190,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFF202228).withValues(alpha: 0.98),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.62),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          blurRadius: 26,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.10),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: availableTypes.isEmpty
                        ? const Center(
                            child: Text(
                              'Todos los widgets ya están agregados.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFA6A8B0),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 3, bottom: 9),
                                child: Text(
                                  'Widgets disponibles',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: availableTypes.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (context, index) {
                                    final type = availableTypes[index];

                                    return _buildDashboardLibraryPreview(type);
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardLibraryPreview(_DashboardWidgetType type) {
    final _DashboardItem template = _createDashboardItem(type, 0, 0);

    const double previewCellSize = 42;
    const double previewGap = 4;

    final double previewWidth =
        (template.columnSpan * previewCellSize) +
        ((template.columnSpan - 1) * previewGap);

    final double previewHeight =
        (template.rowSpan * previewCellSize) +
        ((template.rowSpan - 1) * previewGap);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _addDashboardWidgetFromLibrary(type);
      },
      child: Container(
        width: 164,
        padding: const EdgeInsets.fromLTRB(9, 9, 9, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2C32),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: previewWidth,
                      height: previewHeight,
                      child: IgnorePointer(
                        child: _buildDashboardWidget(template),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Icon(
                  _dashboardWidgetIcon(type),
                  color: _dashboardWidgetColor(type),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _dashboardWidgetName(type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${template.columnSpan}×${template.rowSpan}',
                  style: const TextStyle(
                    color: Color(0xFF9598A2),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        const ColoredBox(color: Colors.black),
        const _BackgroundGlow(),

        Column(
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              opacity: _isDashboardEditing ? 0.35 : 1.0,
              child: Stack(
                children: [
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: _isDashboardEditing ? 10 : 0,
                      sigmaY: _isDashboardEditing ? 10 : 0,
                    ),
                    child: IgnorePointer(
                      ignoring: _isDashboardEditing,
                      child: _HeroHeaderSection(
                        backgroundPath: _heroBackgroundPath,
                        onChangeBackground: _openHeroBackgroundEditor,

                        isDashboardEditing: _isDashboardEditing,

                        isBackgroundEditing: _isHeroBackgroundEditing,

                        backgroundController: _heroBackgroundController,

                        onSaveBackground: _saveHeroBackgroundEditor,

                        onCancelBackground: _cancelHeroBackgroundEditor,

                        partnerOneName: _partnerOneName,
                        partnerTwoName: _partnerTwoName,
                        partnerOnePhotoUrl: _partnerOnePhotoUrl,
                        partnerTwoPhotoUrl: _partnerTwoPhotoUrl,
                        onPartnerOneTap: () {
                          _editPartnerProfile(isFirstPartner: true);
                        },
                        onPartnerTwoTap: () {
                          _editPartnerProfile(isFirstPartner: false);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isDashboardEditing)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 220),
                          opacity: 1.0,
                          child: ClipRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: ColoredBox(
                                color: Colors.black.withValues(alpha: 0.42),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      8,
                      18,
                      72 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    child: _DashboardGrid(
                      items: _dashboardItems,
                      itemBuilder: _buildDashboardWidget,
                      isEditing: _isDashboardEditing,
                      onRemoveItem: _removeDashboardItem,
                      onMoveItem: _moveDashboardItem,
                      onStartEditingWithItem: _startDashboardEditingFromItem,
                      onLongPress: _toggleDashboardEditing,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_isDashboardEditing) _buildDashboardEditorOverlay(context),
      ],
    );
  }

  Widget _buildCurrentContent(BuildContext context) {
    final destination = _currentDestination;

    // null representa la pantalla principal.
    if (destination == null) {
      return _buildHomeContent(context);
    }

    // Cualquier otro valor representa una herramienta.
    return KeyedSubtree(
      key: ValueKey(destination),
      child: _buildQuickDestinationScreen(context, destination),
    );
  }

  void _changeQuickPreview(_QuickDestination destination) {
    if (_selectedQuickDestination == destination) {
      return;
    }

    _previewTransitionController.stop();

    setState(() {
      // Conserva la pantalla anterior completamente visible.
      _previousPreviewDestination = _selectedQuickDestination;

      // Esta será la nueva pantalla que aparecerá encima.
      _selectedQuickDestination = destination;
    });

    _previewTransitionController.forward(from: 0);
  }

  Widget _buildQuickPreviewTransition() {
    final previousDestination = _previousPreviewDestination;
    final currentDestination = _selectedQuickDestination;

    // Cuando no hay cambio activo, solo construye una pantalla.
    if (previousDestination == currentDestination) {
      return RepaintBoundary(
        key: ValueKey('preview-$currentDestination'),
        child: _buildQuickDestinationScreen(context, currentDestination),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Fondo opaco de seguridad.
        // Evita que el Home pueda aparecer aunque una pantalla
        // tenga alguna zona parcialmente transparente.
        const ColoredBox(color: Colors.black),
        // La preview anterior permanece completamente opaca.
        RepaintBoundary(
          key: ValueKey('preview-previous-$previousDestination'),
          child: _buildQuickDestinationScreen(context, previousDestination),
        ),

        // Solo la preview nueva cambia de opacidad.
        FadeTransition(
          opacity: _previewTransitionFade,
          child: RepaintBoundary(
            key: ValueKey('preview-current-$currentDestination'),
            child: _buildQuickDestinationScreen(context, currentDestination),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_isDashboardEditing && !_isHeroBackgroundEditing,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        if (_isHeroBackgroundEditing) {
          _cancelHeroBackgroundEditor();
          return;
        }

        if (_isDashboardEditing) {
          _closeDashboardEditorFromBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: _buildCurrentContent(context)),

                  if (_isQuickMenuOpen) ...[
                    Positioned.fill(
                      child: FadeTransition(
                        // Esta animación se usa solamente para abrir
                        // y cerrar el menú circular completo.
                        opacity: _quickMenuFade,
                        child: IgnorePointer(
                          ignoring: true,
                          child: _buildQuickPreviewTransition(),
                        ),
                      ),
                    ),

                    Positioned.fill(
                      child: SlideTransition(
                        position: _quickMenuSlide,
                        child: ScaleTransition(
                          scale: _quickMenuScale,
                          alignment: Alignment.bottomCenter,
                          child: _QuickActionOverlay(
                            key: _quickActionOverlayKey,
                            progress: _quickMenuController,
                            initialDestination:
                                _currentDestination ??
                                _selectedQuickDestination,
                            favoriteLabels: _quickFavoriteLabels,
                            onFavoriteChanged: _replaceQuickFavorite,
                            onFavoritePickerOpenChanged: _setFavoritePickerOpen,
                            onSelectedActionChanged:
                                _setSelectedQuickActionLabel,
                            onCenteredDestinationChanged: (destination) {
                              _changeQuickPreview(destination);
                            },

                            onClose: closeQuickMenu,

                            onQuickHome: () {
                              _showDestination(_QuickDestination.home);
                            },

                            onQuickNote: () {
                              _showDestination(_QuickDestination.notes);
                            },

                            onQuickGoals: () {
                              _showDestination(_QuickDestination.goals);
                            },

                            onQuickFinance: () {
                              _showDestination(_QuickDestination.finance);
                            },

                            onQuickDatePlanner: () {
                              _showDestination(_QuickDestination.datePlanner);
                            },

                            onQuickDate: () {
                              _showDestination(
                                _QuickDestination.importantDates,
                              );
                            },

                            onQuickKpi: () {
                              _showDestination(_QuickDestination.kpi);
                            },

                            onQuickTrips: () {
                              _showDestination(_QuickDestination.trips);
                            },

                            onQuickWorkout: () {
                              _showDestination(_QuickDestination.workout);
                            },

                            onQuickNutriHub: () {
                              _showDestination(_QuickDestination.nutriHub);
                            },

                            onQuickSettings: () {
                              _showDestination(_QuickDestination.settings);
                            },

                            onQuickAlbumPhoto: () {
                              _showDestination(_QuickDestination.photo);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],

                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      ignoring: _isFavoritePickerOpen,
                      child: IgnorePointer(
                        ignoring: _isFavoritePickerOpen || _isDashboardEditing,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          opacity: _isDashboardEditing ? 0.22 : 1.0,
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: _isDashboardEditing ? 10 : 0,
                              sigmaY: _isDashboardEditing ? 10 : 0,
                            ),
                            child: _NimahubBottomNav(
                              isQuickMenuOpen: _quickMenuController.value > 0.0,
                              isFavoritePickerOpen: _isFavoritePickerOpen,
                              selectedQuickActionLabel:
                                  _selectedQuickActionLabel,
                              quickMenuProgress: _quickMenuController,
                              onQuickActionsTap: _openQuickActionPanel,
                              onCenterTap: _handleCenterButtonTap,
                              onCenterLongPress: _goHomeFromCenterLongPress,
                              onMembersTap: _openMembersPanel,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 40 + MediaQuery.viewPaddingOf(context).bottom,
                    child: Center(
                      child: IgnorePointer(
                        ignoring: _isDashboardEditing,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _handleCenterButtonTap,
                          onLongPress: _goHomeFromCenterLongPress,
                          child: const SizedBox(width: 86, height: 52),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Línea neón en todo el borde izquierdo.
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: _FullScreenNeonEdge(alignment: Alignment.centerLeft),
            ),

            // Línea neón en todo el borde derecho.
            const Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: _FullScreenNeonEdge(alignment: Alignment.centerRight),
            ),
          ],
        ),
      ),
    );
  }
}

enum _DashboardDropKind { move, swap, invalid }

class _DashboardGrid extends StatefulWidget {
  const _DashboardGrid({
    required this.items,
    required this.itemBuilder,
    required this.isEditing,
    required this.onRemoveItem,
    required this.onMoveItem,
    required this.onStartEditingWithItem,
    required this.onLongPress,
  });

  final List<_DashboardItem> items;
  final Widget Function(_DashboardItem item) itemBuilder;

  final bool isEditing;
  final ValueChanged<String> onRemoveItem;

  final bool Function(_DashboardItem item, int column, int row) onMoveItem;
  final ValueChanged<_DashboardItem> onStartEditingWithItem;
  final VoidCallback onLongPress;

  // Compatible con la versión anterior.

  // Compatible con la versión nueva que abre el catálogo
  // desde un cuadrito específico.

  @override
  State<_DashboardGrid> createState() => _DashboardGridState();
}

class _DashboardGridState extends State<_DashboardGrid>
    with SingleTickerProviderStateMixin {
  static const int columnCount = 6;
  static const int rowCount = 9;

  static const double horizontalGap = 5;
  static const double verticalGap = 5;

  final GlobalKey _gridKey = GlobalKey();

  _DashboardItem? _draggedItem;
  String? _pressedItemId;
  bool _dragStartedFromHome = false;

  late final AnimationController _widgetPressController;

  int? _previewColumn;
  int? _previewRow;

  _DashboardDropKind _previewKind = _DashboardDropKind.invalid;

  String? _rejectedItemId;
  int _rejectionGeneration = 0;

  bool get _previewIsValid => _previewKind != _DashboardDropKind.invalid;

  bool get _previewIsSwap => _previewKind == _DashboardDropKind.swap;

  @override
  void initState() {
    super.initState();

    _widgetPressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 190),
      reverseDuration: const Duration(milliseconds: 320),
    );
  }

  @override
  void didUpdateWidget(covariant _DashboardGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.isEditing && oldWidget.isEditing) {
      _widgetPressController.stop();
      _widgetPressController.value = 0;

      // Flutter hará un build inmediatamente después,
      // por eso aquí no hace falta setState.
      _draggedItem = null;
      _pressedItemId = null;
      _dragStartedFromHome = false;

      _previewColumn = null;
      _previewRow = null;
      _previewKind = _DashboardDropKind.invalid;

      // Evita repetir un salto antiguo al volver al Home.
      _rejectedItemId = null;
    }
  }

  @override
  void dispose() {
    _widgetPressController.dispose();
    super.dispose();
  }

  double _itemWidth(_DashboardItem item, double cellSize) {
    return (item.columnSpan * cellSize) +
        ((item.columnSpan - 1) * horizontalGap);
  }

  double _itemHeight(_DashboardItem item, double cellSize) {
    return (item.rowSpan * cellSize) + ((item.rowSpan - 1) * verticalGap);
  }

  bool _itemsOverlap(_DashboardItem first, _DashboardItem second) {
    final bool separatedHorizontally =
        first.column + first.columnSpan <= second.column ||
        second.column + second.columnSpan <= first.column;

    final bool separatedVertically =
        first.row + first.rowSpan <= second.row ||
        second.row + second.rowSpan <= first.row;

    return !separatedHorizontally && !separatedVertically;
  }

  bool _fitsInsideGrid(_DashboardItem item) {
    return item.column >= 0 &&
        item.row >= 0 &&
        item.column + item.columnSpan <= columnCount &&
        item.row + item.rowSpan <= rowCount;
  }

  _DashboardDropKind _resolveDropKind({
    required _DashboardItem candidate,
    required _DashboardItem draggedItem,
  }) {
    if (!_fitsInsideGrid(candidate)) {
      return _DashboardDropKind.invalid;
    }

    final List<_DashboardItem> overlappingItems = widget.items.where((
      existingItem,
    ) {
      if (existingItem.id == draggedItem.id) {
        return false;
      }

      return _itemsOverlap(candidate, existingItem);
    }).toList();

    if (overlappingItems.isEmpty) {
      return _DashboardDropKind.move;
    }

    if (overlappingItems.length != 1) {
      return _DashboardDropKind.invalid;
    }

    final _DashboardItem targetItem = overlappingItems.single;

    final int draggedCellCount = draggedItem.columnSpan * draggedItem.rowSpan;

    final int targetCellCount = targetItem.columnSpan * targetItem.rowSpan;

    if (draggedCellCount != targetCellCount) {
      return _DashboardDropKind.invalid;
    }

    if (candidate.column != targetItem.column ||
        candidate.row != targetItem.row) {
      return _DashboardDropKind.invalid;
    }

    final _DashboardItem relocatedTarget = targetItem.copyWith(
      column: draggedItem.column,
      row: draggedItem.row,
    );

    if (!_fitsInsideGrid(relocatedTarget)) {
      return _DashboardDropKind.invalid;
    }

    for (final existingItem in widget.items) {
      if (existingItem.id == draggedItem.id ||
          existingItem.id == targetItem.id) {
        continue;
      }

      if (_itemsOverlap(candidate, existingItem) ||
          _itemsOverlap(relocatedTarget, existingItem)) {
        return _DashboardDropKind.invalid;
      }
    }

    if (_itemsOverlap(candidate, relocatedTarget)) {
      return _DashboardDropKind.invalid;
    }

    return _DashboardDropKind.swap;
  }

  void _updateDragPreview({
    required Offset globalPosition,
    required _DashboardItem item,
    required double cellSize,
    required double gridWidth,
    required double gridHeight,
  }) {
    final gridContext = _gridKey.currentContext;

    if (gridContext == null) {
      return;
    }

    final renderObject = gridContext.findRenderObject();

    if (renderObject is! RenderBox) {
      return;
    }

    final Offset localPosition = renderObject.globalToLocal(globalPosition);

    // Si el centro del dedo sale completamente de la cuadrícula,
    // se oculta la previsualización.
    if (localPosition.dx < 0 ||
        localPosition.dy < 0 ||
        localPosition.dx > gridWidth ||
        localPosition.dy > gridHeight) {
      // El dedo salió de la cuadrícula, por ejemplo hacia
      // la zona superior de eliminación. Solo ocultamos
      // la previsualización de celdas.
      _clearPlacementPreview();
      return;
    }

    final double itemWidth = _itemWidth(item, cellSize);
    final double itemHeight = _itemHeight(item, cellSize);

    final double horizontalStride = cellSize + horizontalGap;
    final double verticalStride = cellSize + verticalGap;

    // El dedo representa el centro del widget.
    final double desiredLeft = localPosition.dx - (itemWidth / 2);

    final double desiredTop = localPosition.dy - (itemHeight / 2);

    int candidateColumn = (desiredLeft / horizontalStride).round();

    int candidateRow = (desiredTop / verticalStride).round();

    final int maxColumn = columnCount - item.columnSpan;
    final int maxRow = rowCount - item.rowSpan;

    candidateColumn = candidateColumn.clamp(0, maxColumn).toInt();

    candidateRow = candidateRow.clamp(0, maxRow).toInt();

    final candidate = item.copyWith(column: candidateColumn, row: candidateRow);

    final _DashboardDropKind previewKind = _resolveDropKind(
      candidate: candidate,
      draggedItem: item,
    );

    final bool changed =
        _draggedItem?.id != item.id ||
        _previewColumn != candidateColumn ||
        _previewRow != candidateRow ||
        _previewKind != previewKind;
    if (!changed) {
      return;
    }

    setState(() {
      _draggedItem = item;
      _previewColumn = candidateColumn;
      _previewRow = candidateRow;
      _previewKind = previewKind;
    });
  }

  void _clearPlacementPreview() {
    if (_previewColumn == null &&
        _previewRow == null &&
        _previewKind == _DashboardDropKind.invalid) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      // Solo desaparecen los cuadritos de colocación.
      // El widget continúa marcado como arrastrado.
      _previewColumn = null;
      _previewRow = null;
      _previewKind = _DashboardDropKind.invalid;
    });
  }

  void _clearDragPreview() {
    if (_draggedItem == null && _previewColumn == null && _previewRow == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _draggedItem = null;
      _pressedItemId = null;
      _previewColumn = null;
      _previewRow = null;
      _previewKind = _DashboardDropKind.invalid;
    });
  }

  void _triggerRejectedDrop(String itemId) {
    final int currentGeneration = _rejectionGeneration + 1;

    HapticFeedback.heavyImpact();

    setState(() {
      _rejectedItemId = itemId;
      _rejectionGeneration = currentGeneration;
    });

    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }

      // Evita borrar una animación más reciente.
      if (_rejectionGeneration != currentGeneration ||
          _rejectedItemId != itemId) {
        return;
      }

      setState(() {
        _rejectedItemId = null;
      });
    });
  }

  Widget _buildAnimatedDashboardItem(_DashboardItem item) {
    final Widget child = widget.itemBuilder(item);

    if (_rejectedItemId != item.id) {
      return child;
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey('${item.id}-rejection-$_rejectionGeneration'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      builder: (context, animationValue, child) {
        final double jump = math.sin(math.pi * animationValue);

        return Transform.translate(
          offset: Offset(0, -9 * jump),
          child: Transform.scale(scale: 1 - (0.035 * jump), child: child),
        );
      },
      child: child,
    );
  }

  void _setPressedItem(String itemId) {
    if (_pressedItemId != itemId) {
      setState(() {
        _pressedItemId = itemId;
      });
    }

    _widgetPressController.forward(from: 0);
  }

  void _clearPressedItem([String? itemId]) {
    if (_pressedItemId == null) {
      return;
    }

    if (itemId != null && _pressedItemId != itemId) {
      return;
    }

    _widgetPressController.reverse().whenComplete(() {
      if (!mounted || _draggedItem != null) {
        return;
      }

      setState(() {
        _pressedItemId = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;

        final double cellSize =
            (availableWidth - ((columnCount - 1) * horizontalGap)) /
            columnCount;

        final double gridWidth =
            (columnCount * cellSize) + ((columnCount - 1) * horizontalGap);

        final double gridHeight =
            (rowCount * cellSize) + ((rowCount - 1) * verticalGap);

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            key: _gridKey,
            width: gridWidth,
            height: gridHeight,
            child: DragTarget<_DashboardItem>(
              onWillAcceptWithDetails: (details) {
                return true;
              },

              onAcceptWithDetails: (details) {
                final int? column = _previewColumn;
                final int? row = _previewRow;

                if (column == null || row == null || !_previewIsValid) {
                  _triggerRejectedDrop(details.data.id);

                  _clearDragPreview();
                  return;
                }

                final bool movementSucceeded = widget.onMoveItem(
                  details.data,
                  column,
                  row,
                );

                if (!movementSucceeded) {
                  _triggerRejectedDrop(details.data.id);
                }

                _clearDragPreview();
              },

              onLeave: (_) {
                _clearPlacementPreview();
              },

              builder: (context, candidateData, rejectedData) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: widget.isEditing ? widget.onLongPress : null,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Cuadrícula base.
                      if (widget.isEditing)
                        for (int row = 0; row < rowCount; row++)
                          for (int column = 0; column < columnCount; column++)
                            Positioned(
                              left: column * (cellSize + horizontalGap),
                              top: row * (cellSize + verticalGap),
                              width: cellSize,
                              height: cellSize,
                              child: IgnorePointer(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 100),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(
                                      alpha: 0.015,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.10,
                                      ),
                                      width: 0.6,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                      // Widgets reales.
                      for (final item in widget.items)
                        Positioned(
                          key: ValueKey(item.id),
                          left: item.column * (cellSize + horizontalGap),
                          top: item.row * (cellSize + verticalGap),
                          width: _itemWidth(item, cellSize),
                          height: _itemHeight(item, cellSize),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 90),
                            curve: Curves.easeOut,
                            opacity: _draggedItem?.id == item.id ? 0.13 : 1.0,

                            child: widget.isEditing && !_dragStartedFromHome
                                ? Draggable<_DashboardItem>(
                                    data: item,
                                    maxSimultaneousDrags: 1,

                                    dragAnchorStrategy:
                                        (draggable, dragContext, position) {
                                          final renderObject = dragContext
                                              .findRenderObject();

                                          if (renderObject is! RenderBox) {
                                            return Offset.zero;
                                          }

                                          return Offset(
                                            renderObject.size.width / 2,
                                            renderObject.size.height / 2,
                                          );
                                        },

                                    // Dentro del editor, el movimiento comienza
                                    // inmediatamente al arrastrar.
                                    onDragStarted: () {
                                      setState(() {
                                        _rejectedItemId = null;
                                        _pressedItemId = null;
                                        _draggedItem = item;
                                      });

                                      _widgetPressController.stop();
                                      _widgetPressController.value = 0;

                                      HapticFeedback.selectionClick();
                                    },

                                    onDragUpdate: (details) {
                                      _updateDragPreview(
                                        globalPosition: details.globalPosition,
                                        item: item,
                                        cellSize: cellSize,
                                        gridWidth: gridWidth,
                                        gridHeight: gridHeight,
                                      );
                                    },

                                    onDragEnd: (details) {
                                      if (!details.wasAccepted) {
                                        _triggerRejectedDrop(item.id);
                                      }

                                      _clearDragPreview();
                                    },

                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: SizedBox(
                                        width: _itemWidth(item, cellSize),
                                        height: _itemHeight(item, cellSize),
                                        child: Opacity(
                                          opacity: 0.92,
                                          child: widget.itemBuilder(item),
                                        ),
                                      ),
                                    ),

                                    childWhenDragging: IgnorePointer(
                                      child: widget.itemBuilder(item),
                                    ),

                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        widget.onRemoveItem(item.id);
                                      },
                                      child: _buildAnimatedDashboardItem(item),
                                    ),
                                  )
                                : LongPressDraggable<_DashboardItem>(
                                    data: item,

                                    // Ahora siempre será necesario mantener
                                    // presionado el widget para moverlo.
                                    delay: const Duration(milliseconds: 430),

                                    hapticFeedbackOnStart: false,
                                    maxSimultaneousDrags: 1,

                                    dragAnchorStrategy:
                                        (draggable, dragContext, position) {
                                          final renderObject = dragContext
                                              .findRenderObject();

                                          if (renderObject is! RenderBox) {
                                            return Offset.zero;
                                          }

                                          return Offset(
                                            renderObject.size.width / 2,
                                            renderObject.size.height / 2,
                                          );
                                        },

                                    onDragStarted: () {
                                      final bool startedFromHome =
                                          !widget.isEditing;

                                      setState(() {
                                        _rejectedItemId = null;
                                        _dragStartedFromHome = startedFromHome;
                                        _draggedItem = item;
                                      });

                                      _widgetPressController.reverse();

                                      HapticFeedback.mediumImpact();

                                      if (startedFromHome) {
                                        widget.onStartEditingWithItem(item);
                                      }
                                    },

                                    onDragUpdate: (details) {
                                      _updateDragPreview(
                                        globalPosition: details.globalPosition,
                                        item: item,
                                        cellSize: cellSize,
                                        gridWidth: gridWidth,
                                        gridHeight: gridHeight,
                                      );
                                    },

                                    onDragEnd: (details) {
                                      if (!details.wasAccepted) {
                                        _triggerRejectedDrop(item.id);
                                      }

                                      _clearDragPreview();

                                      _widgetPressController.value = 0;

                                      if (mounted) {
                                        setState(() {
                                          _pressedItemId = null;
                                          _dragStartedFromHome = false;
                                        });
                                      }
                                    },

                                    feedback: AnimatedBuilder(
                                      animation: _widgetPressController,
                                      builder: (context, child) {
                                        final double curvedValue = Curves
                                            .easeInOutCubic
                                            .transform(
                                              _widgetPressController.value,
                                            );

                                        final double scaleValue =
                                            1.0 - (0.06 * curvedValue);

                                        return Transform.scale(
                                          scale: scaleValue,
                                          alignment: Alignment.center,
                                          child: child,
                                        );
                                      },
                                      child: Material(
                                        color: Colors.transparent,
                                        child: SizedBox(
                                          width: _itemWidth(item, cellSize),
                                          height: _itemHeight(item, cellSize),
                                          child: Opacity(
                                            opacity: 0.92,
                                            child: widget.itemBuilder(item),
                                          ),
                                        ),
                                      ),
                                    ),

                                    childWhenDragging: IgnorePointer(
                                      child: widget.itemBuilder(item),
                                    ),

                                    child: Listener(
                                      behavior: HitTestBehavior.opaque,

                                      onPointerDown: (_) {
                                        _setPressedItem(item.id);
                                      },

                                      onPointerUp: (_) {
                                        _clearPressedItem(item.id);
                                      },

                                      onPointerCancel: (_) {
                                        _clearPressedItem(item.id);
                                      },

                                      child: AnimatedBuilder(
                                        animation: _widgetPressController,
                                        builder: (context, child) {
                                          if (_pressedItemId != item.id) {
                                            return child!;
                                          }

                                          final double curvedValue = Curves
                                              .easeInOutCubic
                                              .transform(
                                                _widgetPressController.value,
                                              );

                                          final double scaleValue =
                                              1.0 - (0.06 * curvedValue);

                                          return Transform.scale(
                                            scale: scaleValue,
                                            alignment: Alignment.center,
                                            child: child,
                                          );
                                        },

                                        // Dentro del editor, un toque corto
                                        // todavía puede quitar el widget.
                                        child: widget.isEditing
                                            ? GestureDetector(
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                onTap: () {
                                                  widget.onRemoveItem(item.id);
                                                },
                                                child:
                                                    _buildAnimatedDashboardItem(
                                                      item,
                                                    ),
                                              )
                                            : _buildAnimatedDashboardItem(item),
                                      ),
                                    ),
                                  ),
                          ), // Cierra AnimatedOpacity
                        ), // Cierra Positioned
                      // Previsualización de la totalidad de
                      // cuadritos requeridos.
                      if (widget.isEditing &&
                          _draggedItem != null &&
                          _previewColumn != null &&
                          _previewRow != null)
                        for (
                          int previewRow = 0;
                          previewRow < _draggedItem!.rowSpan;
                          previewRow++
                        )
                          for (
                            int previewColumn = 0;
                            previewColumn < _draggedItem!.columnSpan;
                            previewColumn++
                          )
                            Positioned(
                              left:
                                  (_previewColumn! + previewColumn) *
                                  (cellSize + horizontalGap),
                              top:
                                  (_previewRow! + previewRow) *
                                  (cellSize + verticalGap),
                              width: cellSize,
                              height: cellSize,
                              child: IgnorePointer(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 80),
                                  curve: Curves.easeOutCubic,
                                  decoration: BoxDecoration(
                                    color: _previewIsSwap
                                        ? const Color(
                                            0xFFB388FF,
                                          ).withValues(alpha: 0.20)
                                        : _previewIsValid
                                        ? Colors.white.withValues(alpha: 0.16)
                                        : const Color(
                                            0xFFFF3B3B,
                                          ).withValues(alpha: 0.18),

                                    borderRadius: BorderRadius.circular(10),

                                    border: Border.all(
                                      color: _previewIsSwap
                                          ? const Color(
                                              0xFFD7C2FF,
                                            ).withValues(alpha: 0.95)
                                          : _previewIsValid
                                          ? Colors.white.withValues(alpha: 0.82)
                                          : const Color(
                                              0xFFFF5252,
                                            ).withValues(alpha: 0.90),
                                      width: 1.3,
                                    ),

                                    boxShadow: [
                                      BoxShadow(
                                        color: _previewIsSwap
                                            ? const Color(
                                                0xFFB388FF,
                                              ).withValues(alpha: 0.26)
                                            : _previewIsValid
                                            ? Colors.white.withValues(
                                                alpha: 0.18,
                                              )
                                            : const Color(
                                                0xFFFF3B3B,
                                              ).withValues(alpha: 0.22),
                                        blurRadius: 9,
                                        spreadRadius: 0.2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}

class _HeroBackgroundEditResult {
  const _HeroBackgroundEditResult({
    required this.imagePath,
    required this.transform,
  });

  final String imagePath;
  final Matrix4 transform;
}

class _HeroBackgroundEditorSheet extends StatefulWidget {
  const _HeroBackgroundEditorSheet({
    required this.initialImagePath,
    required this.initialTransform,
    required this.heroHeight,
  });

  final String initialImagePath;
  final Matrix4 initialTransform;
  final double heroHeight;

  @override
  State<_HeroBackgroundEditorSheet> createState() =>
      _HeroBackgroundEditorSheetState();
}

class _HeroBackgroundEditorSheetState
    extends State<_HeroBackgroundEditorSheet> {
  late String _imagePath;
  late final TransformationController _controller;

  @override
  void initState() {
    super.initState();

    _imagePath = widget.initialImagePath;
    _controller = TransformationController(
      Matrix4.copy(widget.initialTransform),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );

    if (!mounted || image == null) return;

    setState(() {
      _imagePath = image.path;
      _controller.value = Matrix4.identity();
    });
  }

  void _resetPosition() {
    setState(() {
      _controller.value = Matrix4.identity();
    });
  }

  void _save() {
    Navigator.of(context).pop(
      _HeroBackgroundEditResult(
        imagePath: _imagePath,
        transform: Matrix4.copy(_controller.value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),

              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Editar fondo',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _resetPosition,
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: widget.heroHeight,
                width: double.infinity,
                child: ClipRect(
                  child: Stack(
                    children: [
                      InteractiveViewer(
                        transformationController: _controller,
                        minScale: 1.0,
                        maxScale: 3.2,
                        boundaryMargin: const EdgeInsets.all(120),
                        clipBehavior: Clip.hardEdge,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SizedBox(
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              child: Image.file(
                                File(_imagePath),
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                              ),
                            );
                          },
                        ),
                      ),

                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.symmetric(
                                horizontal: BorderSide(
                                  color: AppColors.neonPink.withValues(
                                    alpha: 0.45,
                                  ),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 12,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.46),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Arrastra la foto y usa zoom para centrarla',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.primary.withValues(
                                  alpha: 0.86,
                                ),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _changePhoto,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppColors.neonPurple.withValues(alpha: 0.5),
                          ),
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Cambiar foto'),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.neonPink,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text(
                          'Guardar',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroHeaderSection extends StatelessWidget {
  const _HeroHeaderSection({
    required this.backgroundPath,
    required this.onChangeBackground,
    required this.isDashboardEditing,
    required this.isBackgroundEditing,
    required this.backgroundController,
    required this.onSaveBackground,
    required this.onCancelBackground,
    required this.partnerOneName,
    required this.partnerTwoName,
    required this.partnerOnePhotoUrl,
    required this.partnerTwoPhotoUrl,
    required this.onPartnerOneTap,
    required this.onPartnerTwoTap,
  });

  final String? backgroundPath;
  final VoidCallback onChangeBackground;

  final bool isDashboardEditing;
  final bool isBackgroundEditing;

  final TransformationController backgroundController;

  final VoidCallback onSaveBackground;
  final VoidCallback onCancelBackground;

  final String partnerOneName;
  final String partnerTwoName;
  final String? partnerOnePhotoUrl;
  final String? partnerTwoPhotoUrl;

  final VoidCallback onPartnerOneTap;
  final VoidCallback onPartnerTwoTap;

  void _setBackgroundZoom(double newZoom) {
    final matrix = Matrix4.copy(backgroundController.value);

    final currentZoom = matrix.getMaxScaleOnAxis();

    if (!currentZoom.isFinite || currentZoom <= 0) {
      return;
    }

    final ratio = newZoom / currentZoom;
    final storage = matrix.storage;

    const scaleIndexes = <int>[0, 1, 2, 4, 5, 6, 8, 9, 10];

    for (final index in scaleIndexes) {
      storage[index] *= ratio;
    }

    backgroundController.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    const double heroHeight = 170;
    return GestureDetector(
      onLongPress: isDashboardEditing || isBackgroundEditing
          ? null
          : onChangeBackground,
      child: SizedBox(
        height: heroHeight,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: backgroundPath == null
                  ? Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF1A1033), Color(0xFF140B2B)],
                        ),
                      ),
                    )
                  : ClipRect(
                      child: InteractiveViewer(
                        transformationController: backgroundController,

                        minScale: 1.0,
                        maxScale: 6.0,

                        // Permite desplazar libremente toda la fotografía,
                        // incluso después de aplicar bastante zoom.
                        boundaryMargin: const EdgeInsets.all(1000),

                        constrained: true,
                        alignment: Alignment.center,
                        panAxis: PanAxis.free,

                        panEnabled: false,
                        scaleEnabled: false,
                        // Reduce el movimiento automático al soltar.
                        interactionEndFrictionCoefficient: 0.001,

                        clipBehavior: Clip.hardEdge,

                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SizedBox(
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              child: ColoredBox(
                                color: Colors.black,
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  alignment: Alignment.center,
                                  child: Image.file(
                                    File(backgroundPath!),
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 92,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.00, 0.28, 0.52, 0.76, 1.00],
                      colors: [
                        AppColors.background.withValues(alpha: 0.00),
                        AppColors.background.withValues(alpha: 0.015),
                        AppColors.background.withValues(alpha: 0.08),
                        AppColors.background.withValues(alpha: 0.34),
                        AppColors.background.withValues(alpha: 0.86),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: -1,
              height: 22,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.55, 1.0],
                      colors: [
                        AppColors.background.withValues(alpha: 0.00),
                        AppColors.background.withValues(alpha: 0.22),
                        AppColors.background.withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: _HomeHeader(
                partnerOneName: partnerOneName,
                partnerTwoName: partnerTwoName,
                partnerOnePhotoUrl: partnerOnePhotoUrl,
                partnerTwoPhotoUrl: partnerTwoPhotoUrl,
                onPartnerOneTap: onPartnerOneTap,
                onPartnerTwoTap: onPartnerTwoTap,
              ),
            ),

            if (isBackgroundEditing && backgroundPath != null)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRect(
                          child: InteractiveViewer(
                            transformationController: backgroundController,

                            minScale: 1.0,
                            maxScale: 6.0,

                            // Permite recorrer la foto completa después del zoom.
                            boundaryMargin: const EdgeInsets.all(1000),

                            constrained: true,
                            alignment: Alignment.center,
                            panAxis: PanAxis.free,

                            panEnabled: true,
                            scaleEnabled: true,

                            interactionEndFrictionCoefficient: 0.0008,

                            clipBehavior: Clip.hardEdge,

                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return SizedBox(
                                  width: constraints.maxWidth,
                                  height: constraints.maxHeight,
                                  child: ColoredBox(
                                    color: Colors.black,
                                    child: FittedBox(
                                      fit: BoxFit.contain,
                                      alignment: Alignment.center,
                                      child: Image.file(
                                        File(backgroundPath!),
                                        filterQuality: FilterQuality.high,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      // Borde que representa el marco final.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.72),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Barra vertical de zoom.
                      Positioned(
                        right: 4,
                        top: 16,
                        bottom: 16,
                        width: 50,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return ValueListenableBuilder<Matrix4>(
                              valueListenable: backgroundController,
                              builder: (context, matrix, child) {
                                final zoom = matrix
                                    .getMaxScaleOnAxis()
                                    .clamp(1.0, 6.0)
                                    .toDouble();

                                return Center(
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: SizedBox(
                                      width: constraints.maxHeight,
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          activeTrackColor: Colors.white,
                                          inactiveTrackColor: Colors.white
                                              .withValues(alpha: 0.28),
                                          thumbColor: Colors.white,
                                          overlayColor: Colors.white.withValues(
                                            alpha: 0.12,
                                          ),
                                          trackHeight: 3,
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                                enabledThumbRadius: 7,
                                              ),
                                          overlayShape:
                                              const RoundSliderOverlayShape(
                                                overlayRadius: 14,
                                              ),
                                        ),
                                        child: Slider(
                                          min: 1.0,
                                          max: 6.0,
                                          value: zoom,
                                          onChanged: _setBackgroundZoom,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),

                      Positioned(
                        left: 12,
                        bottom: 10,
                        child: _HeroEditActionButton(
                          icon: Icons.close_rounded,
                          onTap: onCancelBackground,
                          isPrimary: false,
                        ),
                      ),

                      Positioned(
                        left: 12,
                        top: 10,
                        child: _HeroEditActionButton(
                          icon: Icons.check_rounded,
                          onTap: onSaveBackground,
                          isPrimary: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.partnerOneName,
    required this.partnerTwoName,
    required this.partnerOnePhotoUrl,
    required this.partnerTwoPhotoUrl,
    required this.onPartnerOneTap,
    required this.onPartnerTwoTap,
  });

  final String partnerOneName;
  final String partnerTwoName;
  final String? partnerOnePhotoUrl;
  final String? partnerTwoPhotoUrl;
  final VoidCallback onPartnerOneTap;
  final VoidCallback onPartnerTwoTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Transform.translate(
            offset: const Offset(
              -8,
              -16.5,
            ), // mueve SOLO el contenido completo del header
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: Transform.translate(
                  offset: const Offset(0, -15),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 8, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _NimahubWordmark(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NimahubWordmark extends StatelessWidget {
  const _NimahubWordmark();

  @override
  Widget build(BuildContext context) {
    const double logoFontSize = 15;

    return Align(
      alignment: Alignment.centerLeft,
      child: Transform.translate(
        offset: const Offset(-30, 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'NIMAHUB',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: logoFontSize,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 3.0,
                      height: 1,
                      shadows: [
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.48),
                          blurRadius: 4,
                        ),
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.22),
                          blurRadius: 9,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerEditSheet extends StatefulWidget {
  const _PartnerEditSheet({
    required this.title,
    required this.initialName,
    required this.initialPhotoUrl,
  });

  final String title;
  final String initialName;
  final String? initialPhotoUrl;

  @override
  State<_PartnerEditSheet> createState() => _PartnerEditSheetState();
}

class _PartnerEditSheetState extends State<_PartnerEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _photoController;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.initialName);
    _photoController = TextEditingController(
      text: widget.initialPhotoUrl ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(left: 18, right: 18, bottom: keyboardInset + 18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.neonPurple.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonPurple.withValues(alpha: 0.24),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _nameController,
                style: const TextStyle(color: AppColors.primary),
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  labelStyle: const TextStyle(color: AppColors.secondary),
                  filled: true,
                  fillColor: AppColors.background.withValues(alpha: 0.45),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.9),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.neonPurple),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _photoController,
                style: const TextStyle(color: AppColors.primary),
                decoration: InputDecoration(
                  labelText: 'URL de foto',
                  hintText: 'Opcional',
                  hintStyle: TextStyle(
                    color: AppColors.secondary.withValues(alpha: 0.55),
                  ),
                  labelStyle: const TextStyle(color: AppColors.secondary),
                  filled: true,
                  fillColor: AppColors.background.withValues(alpha: 0.45),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.9),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.neonPurple),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(color: AppColors.secondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop({
                          'name': _nameController.text.trim(),
                          'photoUrl': _photoController.text.trim(),
                        });
                      },
                      child: const Text(
                        'Guardar',
                        style: TextStyle(
                          color: AppColors.neonPurple,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementBanner extends StatefulWidget {
  const _AchievementBanner();

  @override
  State<_AchievementBanner> createState() => _AchievementBannerState();
}

class _AchievementBannerState extends State<_AchievementBanner> {
  late final PageController _bannerController;

  final List<String> _bannerAssets = const [
    'assets/images/home/achievement_hands_banner.png',
    'assets/images/home/achievement_dates_banner.png',
    'assets/images/home/achievement_goals_banner.png',
    'assets/images/home/achievement_trips_banner.png',
    'assets/images/home/achievement_loving_banner.png',
  ];

  @override
  void initState() {
    super.initState();

    _bannerController = PageController(viewportFraction: 1.0);
  }

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.24),
                  blurRadius: 8,
                  spreadRadius: 0.2,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.10),
                  blurRadius: 16,
                  spreadRadius: 0.6,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: PageView.builder(
                controller: _bannerController,
                padEnds: false,
                clipBehavior: Clip.hardEdge,
                itemCount: _bannerAssets.length,
                physics: const PageScrollPhysics(),

                itemBuilder: (context, index) {
                  return AnimatedBuilder(
                    animation: _bannerController,
                    builder: (context, child) {
                      return child!;
                    },
                    child: Container(
                      width: double.infinity,
                      margin: EdgeInsets.zero,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.78),
                          width: 1.0,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.asset(
                          _bannerAssets[index],
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppColors.widgetBackground,
                              alignment: Alignment.center,
                              child: Text(
                                'Banner ${index + 1}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.accentColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.widgetBackground, AppColors.widgetBackgroundDeep],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.88),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.26),
            blurRadius: 9,
            spreadRadius: 0.3,
          ),
          BoxShadow(
            color: const Color(0xFFEAF2FF).withValues(alpha: 0.14),
            blurRadius: 18,
            spreadRadius: 0.7,
          ),
        ],
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accentColor, size: 17),
              const SizedBox(height: 5),
              Text(
                value,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionOverlay extends StatefulWidget {
  const _QuickActionOverlay({
    required this.progress,
    required this.initialDestination,
    required this.favoriteLabels,
    required this.onFavoriteChanged,
    required this.onFavoritePickerOpenChanged,
    required this.onSelectedActionChanged,
    required this.onCenteredDestinationChanged,
    required this.onClose,
    required this.onQuickNote,
    required this.onQuickGoals,
    required this.onQuickFinance,
    required this.onQuickDatePlanner,
    required this.onQuickDate,
    required this.onQuickKpi,
    required this.onQuickTrips,
    required this.onQuickWorkout,
    required this.onQuickNutriHub,
    required this.onQuickSettings,
    required this.onQuickAlbumPhoto,
    required this.onQuickHome,
    super.key,
  });

  final Animation<double> progress;
  final _QuickDestination initialDestination;

  final List<String> favoriteLabels;

  final void Function(int favoriteSlot, String newLabel) onFavoriteChanged;

  final ValueChanged<bool> onFavoritePickerOpenChanged;

  // Recibe textos como Foto, KPI, Date, etc.
  final ValueChanged<String> onSelectedActionChanged;

  // Recibe el destino correspondiente a la pantalla.
  final ValueChanged<_QuickDestination> onCenteredDestinationChanged;

  final VoidCallback onClose;
  final VoidCallback onQuickNote;
  final VoidCallback onQuickGoals;
  final VoidCallback onQuickFinance;
  final VoidCallback onQuickDatePlanner;
  final VoidCallback onQuickDate;
  final VoidCallback onQuickKpi;
  final VoidCallback onQuickTrips;
  final VoidCallback onQuickWorkout;
  final VoidCallback onQuickNutriHub;
  final VoidCallback onQuickAlbumPhoto;
  final VoidCallback onQuickSettings;
  final VoidCallback onQuickHome;

  @override
  State<_QuickActionOverlay> createState() => _QuickActionOverlayState();
}

class _QuickActionOverlayState extends State<_QuickActionOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _favoriteOrbitController;
  int _centerIndex = 0;
  double _dragProgress = 0;

  _QuickDestination? _lastReportedDestination;

  Offset? _favoritePickerAnchor;
  int? _favoriteSlotBeingEdited;
  bool _didInitializeFavoriteCenter = false;

  FixedExtentScrollController? _favoritePickerController;

  int _favoritePickerSelectedIndex = 0;
  int _favoritePickerPendingIndex = 0;

  bool _favoritePickerIsScrolling = false;

  List<_GearMenuAction> _favoritePickerActions = [];

  late final AnimationController _snapController;

  double _snapStart = 0;
  double _snapTarget = 0;
  int _pendingStep = 0;
  int _snapTotalItems = 0;

  @override
  void initState() {
    super.initState();

    _favoriteOrbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _snapController.addListener(() {
      final curvedValue = Curves.easeOutCubic.transform(_snapController.value);

      setState(() {
        _dragProgress =
            lerpDouble(_snapStart, _snapTarget, curvedValue) ?? _snapTarget;
      });
    });

    _snapController.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;

      setState(() {
        if (_pendingStep != 0) {
          _centerIndex = _wrapIndex(
            _centerIndex - _pendingStep,
            _snapTotalItems,
          );
        }

        _dragProgress = 0;
        _pendingStep = 0;
      });
    });
  }

  @override
  void dispose() {
    _favoritePickerController?.dispose();
    _favoriteOrbitController.dispose();
    _snapController.dispose();
    super.dispose();
  }

  int _wrapIndex(int index, int length) {
    return (index % length + length) % length;
  }

  void _handleDragUpdate(DragUpdateDetails details, int totalItems) {
    if (_snapController.isAnimating) {
      _snapController.stop();
    }
    setState(() {
      // Menor número = gira más fácil.
      // 68 se siente más tipo ruleta que 90.
      _dragProgress += details.delta.dx / 50;
      while (_dragProgress >= 1) {
        _centerIndex = _wrapIndex(_centerIndex - 1, totalItems);
        _dragProgress -= 1;
      }

      while (_dragProgress <= -1) {
        _centerIndex = _wrapIndex(_centerIndex + 1, totalItems);
        _dragProgress += 1;
      }
    });
  }

  void _handleDragEnd(DragEndDetails details, int totalItems) {
    final double velocityBoost = ((details.primaryVelocity ?? 0) / 700)
        .clamp(-0.42, 0.42)
        .toDouble();

    final double projectedProgress = (_dragProgress + velocityBoost)
        .clamp(-1.0, 1.0)
        .toDouble();

    double targetProgress = 0;

    // Selector magnético suave:
    // si ya está cerca del siguiente ícono, termina el giro.
    if (projectedProgress > 0.24) {
      targetProgress = 1;
    } else if (projectedProgress < -0.24) {
      targetProgress = -1;
    }

    _startSnapAnimation(targetProgress: targetProgress, totalItems: totalItems);
  }

  void _startSnapAnimation({
    required double targetProgress,
    required int totalItems,
  }) {
    _snapController.stop();

    _snapStart = _dragProgress;
    _snapTarget = targetProgress;
    _pendingStep = targetProgress.round();
    _snapTotalItems = totalItems;

    final int distance = targetProgress.abs().round();

    _snapController.duration = targetProgress == 0
        ? const Duration(milliseconds: 180)
        : Duration(milliseconds: 260 + (distance * 90));

    _snapController.forward(from: 0);
  }

  void _runAction(VoidCallback action) {
    action();
    widget.onClose();
  }

  void _handleGearButtonTap({
    required int slot,
    required VoidCallback action,
    required int totalItems,
  }) {
    // Si el botón ya está en el centro, ejecuta la acción.
    if (slot == 0) {
      _runAction(action);
      return;
    }

    // Si el botón está a un lado, la rueda gira hasta centrarlo.
    _startSnapAnimation(
      targetProgress: -slot.toDouble(),
      totalItems: totalItems,
    );
  }

  void _openFavoritePicker({
    required int favoriteSlot,
    required Offset anchor,
    required List<_GearMenuAction> actions,
  }) {
    HapticFeedback.mediumImpact();

    final String currentLabel = widget.favoriteLabels[favoriteSlot];

    final List<_GearMenuAction> replacementActions = actions
        .where((action) => action.label != currentLabel)
        .toList();

    if (replacementActions.isEmpty) return;

    widget.onFavoritePickerOpenChanged(true);

    _favoritePickerController?.dispose();

    // Comienza en un índice alto para poder desplazarse
    // indefinidamente hacia arriba y hacia abajo.
    final int initialItem = replacementActions.length * 1000;

    _favoritePickerController = FixedExtentScrollController(
      initialItem: initialItem,
    );

    setState(() {
      _favoriteSlotBeingEdited = favoriteSlot;
      _favoritePickerAnchor = anchor;
      _favoritePickerActions = replacementActions;

      _favoritePickerSelectedIndex = 0;
      _favoritePickerPendingIndex = 0;
      _favoritePickerIsScrolling = false;
    });
  }

  void closeFavoritePicker() {
    if (_favoritePickerAnchor == null) {
      return;
    }

    widget.onFavoritePickerOpenChanged(false);

    _favoritePickerController?.dispose();
    _favoritePickerController = null;

    if (!mounted) {
      return;
    }

    setState(() {
      _favoriteSlotBeingEdited = null;
      _favoritePickerAnchor = null;
      _favoritePickerActions = [];

      _favoritePickerSelectedIndex = 0;
      _favoritePickerPendingIndex = 0;
      _favoritePickerIsScrolling = false;

      // La rueda circular conserva su posición.
      _pendingStep = 0;
    });
  }

  void _confirmFavoritePickerSelection() {
    final favoriteSlot = _favoriteSlotBeingEdited;

    if (favoriteSlot == null || _favoritePickerActions.isEmpty) {
      return;
    }

    final selectedAction = _favoritePickerActions[_favoritePickerSelectedIndex];

    widget.onFavoriteChanged(favoriteSlot, selectedAction.label);

    closeFavoritePicker();
  }

  @override
  Widget build(BuildContext context) {
    final allActions = [
      _GearMenuAction(
        destination: _QuickDestination.notes,
        label: 'Nota',
        icon: Icons.notes_rounded,
        color: AppColors.neonPurple,
        onTap: widget.onQuickNote,
      ),
      _GearMenuAction(
        destination: _QuickDestination.goals,
        label: 'Logros',
        icon: Icons.emoji_events_rounded,
        color: AppColors.neonOrange,
        onTap: widget.onQuickGoals,
      ),
      _GearMenuAction(
        destination: _QuickDestination.photo,
        label: 'Foto',
        icon: Icons.camera_alt_rounded,
        color: AppColors.neonPink,
        onTap: widget.onQuickAlbumPhoto,
      ),
      _GearMenuAction(
        destination: _QuickDestination.finance,
        label: 'Finanzas',
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.neonGreen,
        onTap: widget.onQuickFinance,
      ),
      _GearMenuAction(
        destination: _QuickDestination.datePlanner,
        label: 'Date',
        icon: Icons.favorite_rounded,
        color: AppColors.neonPink,
        onTap: widget.onQuickDatePlanner,
      ),
      _GearMenuAction(
        destination: _QuickDestination.importantDates,
        label: 'Fechas',
        icon: Icons.calendar_month_rounded,
        color: AppColors.neonBlue,
        onTap: widget.onQuickDate,
      ),
      _GearMenuAction(
        destination: _QuickDestination.kpi,
        label: 'KPI',
        icon: Icons.bar_chart_rounded,
        color: AppColors.neonCyan,
        onTap: widget.onQuickKpi,
      ),
      _GearMenuAction(
        destination: _QuickDestination.trips,
        label: 'Viajes',
        icon: Icons.flight_takeoff_rounded,
        color: AppColors.neonPurple,
        onTap: widget.onQuickTrips,
      ),
      _GearMenuAction(
        destination: _QuickDestination.workout,
        label: 'Workout',
        icon: Icons.fitness_center_rounded,
        color: const Color(0xFFB35CFF),
        onTap: widget.onQuickWorkout,
      ),
      _GearMenuAction(
        destination: _QuickDestination.nutriHub,
        label: 'Nutri Hub',
        icon: Icons.restaurant_menu_rounded,
        color: const Color(0xFF7CFFB2),
        onTap: widget.onQuickNutriHub,
      ),
      _GearMenuAction(
        destination: _QuickDestination.settings,
        label: 'Configuración',
        icon: Icons.settings_rounded,
        color: const Color(0xFFC3A6FF),
        onTap: widget.onQuickSettings,
      ),
      _GearMenuAction(
        destination: _QuickDestination.home,
        label: 'Inicio',
        icon: Icons.home_rounded,
        color: AppColors.neonBlue,
        onTap: widget.onQuickHome,
      ),
    ];

    final List<String> orderedLabels = widget.favoriteLabels
        .where((label) => allActions.any((action) => action.label == label))
        .toList();

    // Agrega automáticamente cualquier herramienta nueva
    // que todavía no esté guardada en el orden.
    for (final action in allActions) {
      if (!orderedLabels.contains(action.label)) {
        orderedLabels.add(action.label);
      }
    }

    final List<_GearMenuAction> actions = orderedLabels
        .map(
          (label) => allActions.firstWhere((action) => action.label == label),
        )
        .toList();

    if (!_didInitializeFavoriteCenter) {
      final int initialIndex = actions.indexWhere((action) {
        return action.destination == widget.initialDestination;
      });

      _centerIndex = initialIndex >= 0 ? initialIndex : 0;
      _didInitializeFavoriteCenter = true;
    }

    final selectedAction = actions[_wrapIndex(_centerIndex, actions.length)];

    if (_lastReportedDestination != selectedAction.destination) {
      final destination = selectedAction.destination;

      _lastReportedDestination = destination;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        widget.onCenteredDestinationChanged(destination);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onSelectedActionChanged(selectedAction.label);
    });

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

          final double centerX = constraints.maxWidth / 2;

          // Centro real de la tuerca.
          // Más alto: sube este número.
          // Más bajo: baja este número.
          final double centerY =
              constraints.maxHeight - 37 - (bottomInset * 0.70);

          // Radio de la tuerca.
          // Más radio = botones más separados.
          const double radius = 110;

          // Tamaño del fondo circular difuminado.
          // El radio del menú es 150, por eso el diámetro base es 300.
          // Se agregan 100 px para cubrir también los brillos de los botones.
          // Tamaño adicional alrededor del arco.
          // Un valor menor encoge el blur uniformemente hacia el centro.
          // Tamaño base del blur.
          const double menuBlurExtraSize = 5;
          final double menuBlurBaseSize = (radius * 2) + menuBlurExtraSize;

          const double menuBlurHorizontalScale = 0.99;

          final double menuBlurWidth =
              menuBlurBaseSize * menuBlurHorizontalScale;

          // La altura permanece igual.
          final double menuBlurHeight = menuBlurBaseSize;

          // Estas fórmulas mantienen el blur centrado.
          final double menuBlurLeft = centerX - (menuBlurWidth / 2);

          final double menuBlurTop = centerY - (menuBlurHeight / 2);

          // Estos son los 5 que realmente se ven.
          const visibleSlots = [-2, -1, 0, 1, 2];

          // Estos son los 7 que se construyen.
          // -3 y 3 quedan ocultos/pre-cargados para entrar suave.
          const preloadSlots = [-4, -3, -2, -1, 0, 1, 2, 3, 4];
          const double visibleArc = math.pi * 0.95;

          final double slotAngleStep = visibleArc / (visibleSlots.length - 1);

          final double startAngle = -math.pi / 2 - (visibleArc / 2);

          double angleForSlot(double visualSlot) {
            return startAngle + ((visualSlot + 2) * slotAngleStep);
          }

          final bool isFavoritePickerOpen = _favoritePickerAnchor != null;

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: isFavoritePickerOpen
                ? null
                : (details) {
                    _handleDragUpdate(details, actions.length);
                  },
            onHorizontalDragEnd: isFavoritePickerOpen
                ? null
                : (details) {
                    _handleDragEnd(details, actions.length);
                  },
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: isFavoritePickerOpen
                        ? () {}
                        : () {
                            _runAction(selectedAction.onTap);
                          },
                    child: Container(color: Colors.transparent),
                  ),
                ),

                Positioned(
                  left: menuBlurLeft,
                  top: menuBlurTop,
                  width: menuBlurWidth,
                  height: menuBlurHeight,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: widget.progress,
                      builder: (context, child) {
                        final double rawValue = widget.progress.value.clamp(
                          0.0,
                          1.0,
                        );

                        final double value = Curves.easeOutCubic.transform(
                          (rawValue * 1.35).clamp(0.0, 1.0),
                        );

                        return Opacity(
                          opacity: value,
                          child: ShaderMask(
                            blendMode: BlendMode.dstIn,
                            shaderCallback: (bounds) {
                              return const RadialGradient(
                                center: Alignment.center,
                                radius: 1.0,
                                colors: [
                                  Colors.white,
                                  Colors.white,
                                  Colors.white,
                                  Color(0xF2FFFFFF),
                                  Color(0xCCFFFFFF),
                                  Color(0x88FFFFFF),
                                  Color(0x44FFFFFF),
                                  Color(0x14FFFFFF),
                                  Colors.transparent,
                                ],
                                stops: [
                                  0.00,
                                  0.38,
                                  0.58,
                                  0.70,
                                  0.80,
                                  0.89,
                                  0.95,
                                  0.985,
                                  1.00,
                                ],
                              ).createShader(bounds);
                            },
                            child: ClipOval(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Desenfoca la pantalla que está detrás del menú.
                                  BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 34 * value,
                                      sigmaY: 34 * value,
                                    ),
                                    child: ColoredBox(
                                      color: const Color(
                                        0xFF000000,
                                      ).withValues(alpha: 0.99),
                                    ),
                                  ),

                                  // Base oscura neutra del menú.
                                  // No adopta el color de la herramienta seleccionada.
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        center: const Alignment(0, 0.08),
                                        radius: 0.94,
                                        colors: [
                                          const Color(
                                            0xFF17171A,
                                          ).withValues(alpha: 0.52),
                                          const Color(
                                            0xFF101012,
                                          ).withValues(alpha: 0.66),
                                          const Color(
                                            0xFF09090B,
                                          ).withValues(alpha: 0.84),
                                          const Color(
                                            0xFF000000,
                                          ).withValues(alpha: 0.94),
                                          Colors.transparent,
                                        ],
                                        stops: const [
                                          0.00,
                                          0.30,
                                          0.58,
                                          0.82,
                                          1.00,
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Glows dinámicos correspondientes a los cinco
                                  // botones visibles del menú circular.
                                  ImageFiltered(
                                    imageFilter: ImageFilter.blur(
                                      sigmaX: 22 * value,
                                      sigmaY: 22 * value,
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      clipBehavior: Clip.none,
                                      children: [
                                        for (final slot in visibleSlots)
                                          Builder(
                                            builder: (context) {
                                              final double visualSlot =
                                                  slot + _dragProgress;

                                              final double angle = angleForSlot(
                                                visualSlot,
                                              );

                                              final double buttonX =
                                                  centerX +
                                                  math.cos(angle) * radius;

                                              final double buttonY =
                                                  centerY +
                                                  math.sin(angle) * radius;

                                              // Convierte la posición general del botón
                                              // a coordenadas locales del área del blur.
                                              final double localX =
                                                  buttonX - menuBlurLeft;

                                              final double localY =
                                                  buttonY - menuBlurTop;

                                              const Color glowColor =
                                                  Colors.white;

                                              final double distance = visualSlot
                                                  .abs();

                                              final double glowStrength =
                                                  (1.0 - distance * 0.07)
                                                      .clamp(0.72, 1.0)
                                                      .toDouble();

                                              const double glowSize = 142;

                                              return Positioned(
                                                left: localX - glowSize / 2,
                                                top: localY - glowSize / 2,
                                                width: glowSize,
                                                height: glowSize,
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    gradient: RadialGradient(
                                                      colors: [
                                                        glowColor.withValues(
                                                          alpha:
                                                              0.58 *
                                                              glowStrength,
                                                        ),
                                                        glowColor.withValues(
                                                          alpha:
                                                              0.28 *
                                                              glowStrength,
                                                        ),
                                                        glowColor.withValues(
                                                          alpha:
                                                              0.08 *
                                                              glowStrength,
                                                        ),
                                                        Colors.transparent,
                                                      ],
                                                      stops: const [
                                                        0.00,
                                                        0.30,
                                                        0.66,
                                                        1.00,
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Zona central neutra para impedir que los colores
                                  // de los iconos alcancen el botón principal.
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        center: const Alignment(0, 0.26),
                                        radius: 0.68,
                                        colors: [
                                          const Color(
                                            0xFF070709,
                                          ).withValues(alpha: 0.96),
                                          const Color(
                                            0xFF09090B,
                                          ).withValues(alpha: 0.70),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.00, 0.42, 1.00],
                                      ),
                                    ),
                                  ),

                                  // Acabado oscuro premium: más claro arriba,
                                  // más profundo en la parte inferior.
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white.withValues(alpha: 0.025),
                                          const Color(
                                            0xFF241138,
                                          ).withValues(alpha: 0.08),
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.38),
                                        ],
                                        stops: const [0.00, 0.30, 0.62, 1.00],
                                      ),
                                    ),
                                  ),

                                  // Viñeta exterior para que el color no termine
                                  // con un borde circular evidente.
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        center: Alignment.center,
                                        radius: 1.0,
                                        colors: [
                                          Colors.transparent,
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.16),
                                          Colors.black.withValues(alpha: 0.42),
                                        ],
                                        stops: const [0.00, 0.58, 0.82, 1.00],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                for (final slot in preloadSlots)
                  _buildGearItem(
                    actions: actions,
                    slot: slot,
                    visualSlot: slot + _dragProgress,
                    angle: angleForSlot(slot + _dragProgress),
                    centerX: centerX,
                    centerY: centerY,
                    radius: radius,
                  ),

                if (isFavoritePickerOpen) ...[
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.70),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Positioned.fill(
                    child: ModalBarrier(
                      dismissible: false,
                      color: Colors.transparent,
                    ),
                  ),

                  _buildFavoritePickerMenu(
                    actions: allActions,
                    constraints: constraints,
                  ),

                  _buildFavoritePickerSelectedIcon(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGearItem({
    required List<_GearMenuAction> actions,
    required int slot,
    required double visualSlot,
    required double angle,
    required double centerX,
    required double centerY,
    required double radius,
  }) {
    final index = _wrapIndex(_centerIndex + slot, actions.length);
    final action = actions[index];
    final double baseX = centerX + math.cos(angle) * radius;
    final double y = centerY + math.sin(angle) * radius;
    // Acerca únicamente los iconos laterales de las posiciones -2 y 2.
    // Los tres iconos superiores (-1, 0 y 1) mantienen su posición.
    final double outerFactor = (visualSlot.abs() - 1.5)
        .clamp(0.0, 1.0)
        .toDouble();
    const double sidePullTowardCenter = 13.0;
    final double directionToCenter = (centerX - baseX).sign;
    final double x =
        baseX + (directionToCenter * sidePullTowardCenter * outerFactor);
    final double buttonSize = 62;
    final double distanceFromCenter = visualSlot.abs();
    final int favoriteSlot = widget.favoriteLabels.indexOf(action.label);
    // Se conserva para permitir editar únicamente los favoritos.
    final bool isFavorite = favoriteSlot != -1;
    final bool isEditingThisFavorite =
        _favoriteSlotBeingEdited == favoriteSlot &&
        _favoritePickerActions.isNotEmpty;
    final _GearMenuAction currentVisualAction = isEditingThisFavorite
        ? _favoritePickerActions[_favoritePickerSelectedIndex]
        : action;
    final double preloadProgress = (3.0 - distanceFromCenter)
        .clamp(0.0, 1.0)
        .toDouble();
    final bool isInsideVisibleRange = distanceFromCenter <= 2.0;
    final double opacity = isInsideVisibleRange ? 1.0 : preloadProgress * 0.65;
    final double scale = isInsideVisibleRange
        ? 1.0
        : 0.82 + (preloadProgress * 0.18);
    // El contorno punteado permanece en todos los iconos.
    const bool showOrbitBorder = true;
    // La bolita giratoria aparece solo en el icono central.
    final double activeOrbitDotOpacity = (1.0 - visualSlot.abs())
        .clamp(0.0, 1.0)
        .toDouble();

    final double orbitOpacity = opacity;
    // Hace que el ícono nuevo aparezca desde abajo.
    final double preloadYOffset = isInsideVisibleRange
        ? 0.0
        : 22 * (1 - preloadProgress);
    return Positioned(
      left: x - (buttonSize / 2),
      top: y - (buttonSize / 2) + preloadYOffset,
      child: IgnorePointer(
        ignoring: visualSlot.abs() > 2.05,
        child: _GearActionButton(
          size: buttonSize,
          scale: scale,
          opacity: opacity,
          showOrbit: showOrbitBorder,
          activeOrbitDotOpacity: activeOrbitDotOpacity,
          orbitOpacity: orbitOpacity,
          orbitPhase: 0.0,
          orbitAnimation: _favoriteOrbitController,
          label: currentVisualAction.label,
          icon: currentVisualAction.icon,
          color: currentVisualAction.color,
          onLongPress: isFavorite && _favoritePickerAnchor == null
              ? () => _openFavoritePicker(
                  favoriteSlot: favoriteSlot,
                  anchor: Offset(x, y + preloadYOffset),
                  actions: actions,
                )
              : null,
          onTap: isEditingThisFavorite
              ? _confirmFavoritePickerSelection
              : () => _handleGearButtonTap(
                  slot: slot,
                  action: action.onTap,
                  totalItems: actions.length,
                ),
        ),
      ),
    );
  }

  Widget _buildFavoritePickerMenu({
    required List<_GearMenuAction> actions,
    required BoxConstraints constraints,
  }) {
    final anchor = _favoritePickerAnchor;

    if (anchor == null || _favoritePickerActions.isEmpty) {
      return const SizedBox.shrink();
    }

    final controller = _favoritePickerController;

    if (controller == null) {
      return const SizedBox.shrink();
    }

    const double itemSize = 64;

    // Mantiene una separación mínima entre los iconos.
    const double itemExtent = 70;

    // Solo 3 px a cada lado del círculo.
    const double capsulePadding = 3;
    const double railWidth = itemSize + (capsulePadding * 2);

    // Dos iconos superiores y el icono seleccionado,
    // con la cápsula rozando sus bordes.
    const double visibleRailHeight =
        (itemExtent * 2.5) + (itemSize / 2) + capsulePadding;

    const double wheelHeight = itemExtent * 5;

    final double left = (anchor.dx - (railWidth / 2)).clamp(
      8.0,
      constraints.maxWidth - railWidth - 8,
    );

    // El selector queda exactamente en el centro del menú.
    final double top = anchor.dy - (itemExtent * 2.5);
    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: railWidth,
          height: visibleRailHeight,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              // El radio se adapta a la proporción vertical del menú.
              // Esto crea un desvanecimiento ovalado en lugar
              // de dos líneas horizontales planas.
              final double ovalRadius = (bounds.height / bounds.width) * 0.96;

              return RadialGradient(
                center: Alignment.center,
                radius: ovalRadius,
                colors: const [Colors.white, Colors.white, Colors.transparent],
                stops: const [0.0, 0.84, 1.0],
              ).createShader(bounds);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(railWidth / 2),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: wheelHeight,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.depth != 0) {
                          return false;
                        }

                        if (notification is ScrollStartNotification) {
                          _favoritePickerIsScrolling = true;
                        }

                        if (notification is ScrollEndNotification) {
                          final int finalIndex = _favoritePickerPendingIndex;

                          if (_favoritePickerSelectedIndex != finalIndex) {
                            HapticFeedback.selectionClick();
                          }

                          setState(() {
                            _favoritePickerSelectedIndex = finalIndex;
                            _favoritePickerIsScrolling = false;
                          });
                        }

                        return false;
                      },
                      child: ListWheelScrollView.useDelegate(
                        controller: controller,
                        itemExtent: itemExtent,
                        physics: const FixedExtentScrollPhysics(
                          parent: ClampingScrollPhysics(),
                        ),
                        diameterRatio: 1000,
                        perspective: 0.0001,
                        squeeze: 1.0,
                        useMagnifier: false,
                        overAndUnderCenterOpacity: 1.0,

                        // El recorte rectangular interno deja de ser visible
                        // porque ahora queda cubierto por la máscara.
                        renderChildrenOutsideViewport: true,
                        clipBehavior: Clip.none,

                        onSelectedItemChanged: (absoluteIndex) {
                          final int normalizedIndex =
                              absoluteIndex % _favoritePickerActions.length;

                          _favoritePickerPendingIndex = normalizedIndex;
                        },

                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: _favoritePickerActions.length * 2000,
                          builder: (context, absoluteIndex) {
                            final int normalizedIndex =
                                absoluteIndex % _favoritePickerActions.length;

                            final action =
                                _favoritePickerActions[normalizedIndex];

                            return SizedBox(
                              width: railWidth,
                              height: itemExtent,
                              child: Center(
                                child: _VerticalPickerOption(
                                  size: itemSize,
                                  action: action,
                                  onTap: () {
                                    if (!controller.hasClients) {
                                      return;
                                    }

                                    final bool isCentered =
                                        controller.selectedItem ==
                                        absoluteIndex;

                                    if (isCentered &&
                                        !_favoritePickerIsScrolling) {
                                      _confirmFavoritePickerSelection();
                                      return;
                                    }

                                    controller.animateToItem(
                                      absoluteIndex,
                                      duration: const Duration(
                                        milliseconds: 240,
                                      ),
                                      curve: Curves.easeOutCubic,
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Blur inferior.
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritePickerSelectedIcon() {
    final anchor = _favoritePickerAnchor;

    if (anchor == null || _favoritePickerActions.isEmpty) {
      return const SizedBox.shrink();
    }

    const double itemSize = 64;

    return Positioned(
      left: anchor.dx - ((itemSize + 2) / 2),
      top: anchor.dy - ((itemSize + 2) / 2),
      child: IgnorePointer(
        child: Container(
          width: itemSize + 2,
          height: itemSize + 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            border: Border.all(color: Colors.white, width: 0.95),
          ),
        ),
      ),
    );
  }
}

class _GearMenuAction {
  const _GearMenuAction({
    required this.destination,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final _QuickDestination destination;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _VerticalPickerOption extends StatelessWidget {
  const _VerticalPickerOption({
    required this.size,
    required this.action,
    required this.onTap,
  });

  final double size;
  final _GearMenuAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFE2E2E5).withValues(alpha: 0.34),
                  AppColors.surface.withValues(alpha: 0.96),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.95),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.62),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.30),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.18),
                  blurRadius: 34,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.08),
                  blurRadius: 70,
                  spreadRadius: 9,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: size * 0.64,
                height: size * 0.64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.background.withValues(alpha: 0.78),
                ),
                child: Icon(
                  action.icon,
                  color: action.color,
                  size: size * 0.42,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedFavoriteOrbit extends StatelessWidget {
  const _AnimatedFavoriteOrbit({
    required this.size,
    required this.opacity,
    required this.phaseOffset,
    required this.activeDotOpacity,
    required this.animation,
  });

  final double size;
  final double opacity;
  final double phaseOffset;
  final double activeDotOpacity;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _FavoriteOrbitPainter(
            animation: animation,
            opacity: opacity,
            phaseOffset: phaseOffset,
            activeDotOpacity: activeDotOpacity,
          ),
        ),
      ),
    );
  }
}

class _FavoriteOrbitPainter extends CustomPainter {
  _FavoriteOrbitPainter({
    required this.animation,
    required this.opacity,
    required this.phaseOffset,
    required this.activeDotOpacity,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final double opacity;
  final double phaseOffset;
  final double activeDotOpacity;
  static const int dotCount = 30;

  @override
  void paint(Canvas canvas, Size size) {
    final double visibleOpacity = opacity.clamp(0.0, 1.0);

    if (visibleOpacity <= 0.0) {
      return;
    }

    final Offset center = Offset(size.width / 2, size.height / 2);

    final double radius = math.min(size.width, size.height) / 2 - 2.5;

    final Paint normalDotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.62 * visibleOpacity)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Dibuja todos los puntos que forman
    // la circunferencia blanca.
    for (int index = 0; index < dotCount; index++) {
      final double angle = -math.pi / 2 + (index / dotCount) * math.pi * 2;

      final Offset dotPosition = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );

      canvas.drawCircle(dotPosition, 0.95, normalDotPaint);
    }

    // Movimiento continuo del punto activo.
    final double movingDotOpacity =
        visibleOpacity * activeDotOpacity.clamp(0.0, 1.0);

    final double animatedProgress = (animation.value + phaseOffset) % 1.0;

    final double activeAngle = -math.pi / 2 + animatedProgress * math.pi * 2;

    final Offset activePosition = Offset(
      center.dx + math.cos(activeAngle) * radius,
      center.dy + math.sin(activeAngle) * radius,
    );

    // Resplandor pequeño del punto móvil.
    final Paint glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.38 * movingDotOpacity)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);

    canvas.drawCircle(activePosition, 3.3, glowPaint);

    // Punto blanco principal.
    final Paint activeDotPaint = Paint()
      ..color = Colors.white.withValues(alpha: movingDotOpacity)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(activePosition, 2.0, activeDotPaint);
  } // Cierra paint()

  @override
  bool shouldRepaint(covariant _FavoriteOrbitPainter oldDelegate) {
    return oldDelegate.opacity != opacity ||
        oldDelegate.phaseOffset != phaseOffset ||
        oldDelegate.activeDotOpacity != activeDotOpacity;
  }
} // Cierra _FavoriteOrbitPainter

class _GearActionButton extends StatelessWidget {
  const _GearActionButton({
    required this.size,
    required this.scale,
    required this.opacity,
    required this.showOrbit,
    required this.activeOrbitDotOpacity,
    required this.orbitOpacity,
    required this.label,
    required this.icon,
    required this.color,
    required this.onLongPress,
    required this.onTap,
    this.orbitPhase = 0.0,
    this.orbitAnimation,
  });

  final double size;
  final double scale;
  final double opacity;
  final bool showOrbit;
  final double activeOrbitDotOpacity;
  final double orbitOpacity;
  final double orbitPhase;
  final Animation<double>? orbitAnimation;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onLongPress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFE2E2E5).withValues(alpha: 0.34),
                        AppColors.surface.withValues(alpha: 0.96),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.95),
                      width: 1.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.62),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.30),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.18),
                        blurRadius: 34,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.08),
                        blurRadius: 70,
                        spreadRadius: 9,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: size * 0.64,
                      height: size * 0.64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.background.withValues(alpha: 0.78),
                      ),
                      child: Icon(icon, color: color, size: size * 0.42),
                    ),
                  ),
                ),

                if (showOrbit)
                  IgnorePointer(
                    child: _AnimatedFavoriteOrbit(
                      size: size + 2,
                      opacity: orbitOpacity,
                      phaseOffset: orbitPhase,
                      activeDotOpacity: activeOrbitDotOpacity,
                      animation:
                          orbitAnimation ??
                          const AlwaysStoppedAnimation<double>(0.0),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NimahubBottomNav extends StatelessWidget {
  const _NimahubBottomNav({
    required this.isQuickMenuOpen,
    required this.isFavoritePickerOpen,
    required this.quickMenuProgress,
    required this.selectedQuickActionLabel,
    required this.onQuickActionsTap,
    required this.onCenterTap,
    required this.onCenterLongPress,
    required this.onMembersTap,
  });

  final bool isQuickMenuOpen;
  final bool isFavoritePickerOpen;
  final Animation<double> quickMenuProgress;
  final String selectedQuickActionLabel;
  final VoidCallback onQuickActionsTap;
  final VoidCallback onCenterTap;
  final VoidCallback onCenterLongPress;
  final VoidCallback onMembersTap;
  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    final double bottomExtension = bottomInset;

    const double navHeight = 72;

    // No modifica la posición del botón central.
    // Misma altura para toda la franja inferior.
    const double dockHeight = 54;

    const double barBottom = 4;

    return SizedBox(
      height: navHeight + bottomExtension,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double barWidth = (constraints.maxWidth * 0.40)
              .clamp(210.0, 320.0)
              .toDouble();

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: barBottom + bottomExtension,
                child: AnimatedBuilder(
                  animation: quickMenuProgress,
                  builder: (context, child) {
                    final value = Curves.easeOutCubic.transform(
                      (quickMenuProgress.value * 1.45)
                          .clamp(0.0, 1.0)
                          .toDouble(),
                    );

                    return IgnorePointer(
                      ignoring: value > 0.01,
                      child: Opacity(opacity: 1 - value, child: child),
                    );
                  },
                  child: Center(
                    child: Container(
                      width: barWidth,
                      height: dockHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF55575D),
                            Color(0xFF3D3F45),
                            Color(0xFF292B30),
                            Color(0xFF414349),
                          ],
                          stops: [0.00, 0.34, 0.72, 1.00],
                        ),
                        borderRadius: BorderRadius.circular(dockHeight / 2),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.82),
                          width: 1.1,
                        ),
                        boxShadow: [
                          // Aura blanca cercana.
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.35),
                            blurRadius: 10,
                            spreadRadius: 0.4,
                          ),

                          // Aura exterior suave.
                          BoxShadow(
                            color: const Color(
                              0xFFEAF2FF,
                            ).withValues(alpha: 0.14),
                            blurRadius: 22,
                            spreadRadius: 1.2,
                          ),

                          // Sombra inferior para mantener profundidad.
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.38),
                            blurRadius: 16,
                            spreadRadius: -3,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _BottomNavItem(
                            icon: Icons.group_rounded,
                            label: 'Miembros',
                            isSelected: false,
                            onTap: onMembersTap,
                            showLabel: true,
                          ),

                          const SizedBox(width: 64),

                          _BottomNavItem(
                            icon: Icons.bolt_rounded,
                            label: 'Acciones',
                            isSelected: false,
                            onTap: onQuickActionsTap,
                            showLabel: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 77 + bottomExtension,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: isFavoritePickerOpen ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    child: AnimatedScale(
                      scale: isFavoritePickerOpen ? 0.94 : 1.0,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      child: Center(
                        child: _BottomSelectedGearCapsule(
                          label: selectedQuickActionLabel,
                          progress: quickMenuProgress,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: isFavoritePickerOpen
                    ? ImageFiltered(
                        key: const ValueKey('blurred-center-button'),
                        imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                        child: Opacity(
                          opacity: 0.38,
                          child: _CenterMemoryButton(
                            isActive: isQuickMenuOpen,
                            progress: quickMenuProgress,
                            onTap: onCenterTap,
                            onLongPress: onCenterLongPress,
                          ),
                        ),
                      )
                    : _CenterMemoryButton(
                        key: const ValueKey('normal-center-button'),
                        isActive: isQuickMenuOpen,
                        progress: quickMenuProgress,
                        onTap: onCenterTap,
                        onLongPress: onCenterLongPress,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CenterMemoryButton extends StatelessWidget {
  const _CenterMemoryButton({
    super.key,
    required this.isActive,
    required this.progress,
    required this.onTap,
    required this.onLongPress,
  });

  final bool isActive;
  final Animation<double> progress;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -19),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 88,
          height: 88,
          child: Center(
            child: AnimatedScale(
              scale: 1.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  // Aro sólido blanco neón.
                  color: const Color(0xFFF8FBFF),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.68),
                      blurRadius: 10,
                      spreadRadius: 0.6,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.30),
                      blurRadius: 22,
                      spreadRadius: 1.0,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 53,
                    height: 53,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF080812).withValues(alpha: 0.94),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                        width: 0.9,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 57,
                      height: 57,
                      child: Image.asset(
                        'assets/images/nimahub_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
    this.showLabel = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: Colors.black.withValues(alpha: 0.06),
        highlightColor: Colors.white.withValues(alpha: 0.18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 64,
          height: 42,
          decoration: const BoxDecoration(color: Colors.transparent),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: showLabel ? 19 : 24, color: Colors.white),
              if (showLabel) ...[
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0.1,
                    height: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomSelectedGearCapsule extends StatelessWidget {
  const _BottomSelectedGearCapsule({
    required this.label,
    required this.progress,
  });

  final String label;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        final rawValue = progress.value.clamp(0.0, 1.0).toDouble();
        final value = Curves.easeOutCubic.transform(rawValue);

        return Opacity(
          opacity: value,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.12),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              label,
              key: ValueKey(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.96),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.25,
                height: 1.0,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.75),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                  Shadow(
                    color: Colors.white.withValues(alpha: 0.28),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuickActionSideDialog extends StatelessWidget {
  const _QuickActionSideDialog({
    required this.animation,
    required this.onSelected,
  });

  final Animation<double> animation;
  final ValueChanged<_QuickCreateAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;

    final double panelWidth = (screenWidth * 0.78)
        .clamp(280.0, 330.0)
        .toDouble();

    final slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: Offset.zero,
    ).animate(animation);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: animation,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.28),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.centerRight,
            child: SlideTransition(
              position: slideAnimation,
              child: SafeArea(
                left: false,
                child: Container(
                  width: panelWidth,
                  margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18191E).withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                      width: 0.9,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 30,
                        spreadRadius: 2,
                        offset: const Offset(-8, 0),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.07),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 20, 14, 12),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Acciones rápidas',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Crea contenido desde cualquier sección',
                                    style: TextStyle(
                                      color: Color(0xFF9C9EA7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),

                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                          children: [
                            _QuickActionSideTile(
                              icon: Icons.camera_alt_rounded,
                              title: 'Tomar foto',
                              subtitle: 'Agregar un recuerdo al álbum',
                              color: AppColors.neonPink,
                              onTap: () {
                                onSelected(_QuickCreateAction.photo);
                              },
                            ),
                            _QuickActionSideTile(
                              icon: Icons.payments_rounded,
                              title: 'Agregar gasto',
                              subtitle: 'Registrar un movimiento',
                              color: AppColors.neonCyan,
                              onTap: () {
                                onSelected(_QuickCreateAction.expense);
                              },
                            ),
                            _QuickActionSideTile(
                              icon: Icons.favorite_rounded,
                              title: 'Agregar date',
                              subtitle: 'Planear una nueva cita',
                              color: AppColors.neonPink,
                              onTap: () {
                                onSelected(_QuickCreateAction.date);
                              },
                            ),
                            _QuickActionSideTile(
                              icon: Icons.note_add_rounded,
                              title: 'Agregar nota',
                              subtitle: 'Crear una nota rápida',
                              color: AppColors.neonPurple,
                              onTap: () {
                                onSelected(_QuickCreateAction.note);
                              },
                            ),
                            _QuickActionSideTile(
                              icon: Icons.flag_rounded,
                              title: 'Agregar goal',
                              subtitle: 'Crear una meta en pareja',
                              color: AppColors.neonBlue,
                              onTap: () {
                                onSelected(_QuickCreateAction.goal);
                              },
                            ),
                            _QuickActionSideTile(
                              icon: Icons.query_stats_rounded,
                              title: 'Crear KPI',
                              subtitle: 'Registrar una nueva métrica',
                              color: AppColors.neonCyan,
                              onTap: () {
                                onSelected(_QuickCreateAction.kpi);
                              },
                            ),
                            _QuickActionSideTile(
                              icon: Icons.flight_takeoff_rounded,
                              title: 'Agregar viaje',
                              subtitle: 'Planear una nueva aventura',
                              color: AppColors.neonPurple,
                              onTap: () {
                                onSelected(_QuickCreateAction.trip);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionSideTile extends StatelessWidget {
  const _QuickActionSideTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          splashColor: color.withValues(alpha: 0.10),
          highlightColor: color.withValues(alpha: 0.05),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.26)),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF9698A1),
                          fontSize: 11.5,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF8E9098),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MembersSideDialog extends StatelessWidget {
  const _MembersSideDialog({
    required this.animation,
    required this.partnerOneName,
    required this.partnerTwoName,
    required this.partnerOneConnected,
    required this.partnerTwoConnected,
    required this.pets,
    required this.onConnectPartnerOne,
    required this.onConnectPartnerTwo,
    required this.onAddPet,
    required this.onRemovePet,
  });

  final Animation<double> animation;

  final String partnerOneName;
  final String partnerTwoName;

  final bool partnerOneConnected;
  final bool partnerTwoConnected;

  final List<_PetMember> pets;

  final VoidCallback onConnectPartnerOne;
  final VoidCallback onConnectPartnerTwo;
  final VoidCallback onAddPet;
  final ValueChanged<int> onRemovePet;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    final panelWidth = (screenWidth * 0.82).clamp(290.0, 350.0).toDouble();

    final slideAnimation = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(animation);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: animation,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.28),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.centerLeft,
            child: SlideTransition(
              position: slideAnimation,
              child: SafeArea(
                right: false,
                child: Container(
                  width: panelWidth,
                  margin: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18191E).withValues(alpha: 0.97),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                      width: 0.9,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.58),
                        blurRadius: 34,
                        spreadRadius: 2,
                        offset: const Offset(8, 0),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.06),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Miembros',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Tu espacio familiar',
                                    style: TextStyle(
                                      color: Color(0xFF9B9DA6),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),

                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                          children: [
                            const _MembersSectionTitle(title: 'PAREJA'),

                            _PartnerMemberCard(
                              label: 'Pareja 1',
                              name: partnerOneName,
                              accentColor: AppColors.neonPurple,
                              connected: partnerOneConnected,
                              onConnect: onConnectPartnerOne,
                            ),

                            const SizedBox(height: 10),

                            _PartnerMemberCard(
                              label: 'Pareja 2',
                              name: partnerTwoName,
                              accentColor: AppColors.neonPink,
                              connected: partnerTwoConnected,
                              onConnect: onConnectPartnerTwo,
                            ),

                            const SizedBox(height: 24),

                            Row(
                              children: [
                                const Expanded(
                                  child: _MembersSectionTitle(
                                    title: 'MASCOTAS',
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Agregar mascota',
                                  onPressed: onAddPet,
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: AppColors.neonCyan,
                                  ),
                                ),
                              ],
                            ),

                            if (pets.isEmpty)
                              _EmptyPetsCard(onTap: onAddPet)
                            else
                              for (
                                int index = 0;
                                index < pets.length;
                                index++
                              ) ...[
                                _PetMemberCard(
                                  pet: pets[index],
                                  onDelete: () {
                                    onRemovePet(index);
                                  },
                                ),
                                if (index < pets.length - 1)
                                  const SizedBox(height: 10),
                              ],

                            const SizedBox(height: 14),

                            OutlinedButton.icon(
                              onPressed: onAddPet,
                              icon: const Icon(Icons.pets_rounded),
                              label: const Text('Agregar mascota'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MembersSectionTitle extends StatelessWidget {
  const _MembersSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF888A93),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _PartnerMemberCard extends StatelessWidget {
  const _PartnerMemberCard({
    required this.label,
    required this.name,
    required this.accentColor,
    required this.connected,
    required this.onConnect,
  });

  final String label;
  final String name;
  final Color accentColor;
  final bool connected;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: connected
              ? accentColor.withValues(alpha: 0.32)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: accentColor.withValues(alpha: 0.34)),
            ),
            child: Icon(Icons.person_rounded, color: accentColor, size: 26),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF9698A1),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  connected ? 'Cuenta de Google conectada' : 'Sin conectar',
                  style: TextStyle(
                    color: connected ? accentColor : const Color(0xFF858791),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onConnect,
            child: Text(
              connected ? 'Cambiar' : 'Conectar',
              style: TextStyle(
                color: accentColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PetMemberCard extends StatelessWidget {
  const _PetMemberCard({required this.pet, required this.onDelete});

  final _PetMember pet;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: AppColors.neonCyan.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pets_rounded,
              color: AppColors.neonCyan,
              size: 21,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  pet.kind,
                  style: const TextStyle(
                    color: Color(0xFF92949D),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: onDelete,
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFF989AA3),
              size: 19,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPetsCard extends StatelessWidget {
  const _EmptyPetsCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: const Column(
            children: [
              Icon(Icons.pets_outlined, color: Color(0xFF90929B), size: 30),
              SizedBox(height: 8),
              Text(
                'Todavía no hay mascotas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Toca aquí para agregar una',
                style: TextStyle(color: Color(0xFF8E9099), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardPreviewShell extends StatelessWidget {
  const _DashboardPreviewShell({
    required this.accentColor,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Color accentColor;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.widgetBackground, AppColors.widgetBackgroundDeep],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.72),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.22),
            blurRadius: 8,
            spreadRadius: 0.2,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.10),
            blurRadius: 16,
            spreadRadius: 0.6,
          ),
          BoxShadow(
            color: accentColor.withValues(alpha: 0.10),
            blurRadius: 20,
            spreadRadius: 0.2,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BudgetSummaryWidget extends StatelessWidget {
  const _BudgetSummaryWidget();

  @override
  Widget build(BuildContext context) {
    return _DashboardPreviewShell(
      accentColor: AppColors.neonCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.neonCyan,
                size: 18,
              ),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Presupuesto',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Text(
            '\$1.240.000',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: 0.62,
                  minHeight: 5,
                  color: AppColors.neonCyan,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                '62% utilizado este mes',
                style: TextStyle(color: Color(0xFF9698A2), fontSize: 9.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NextDateWidget extends StatelessWidget {
  const _NextDateWidget();

  @override
  Widget build(BuildContext context) {
    return _DashboardPreviewShell(
      accentColor: AppColors.neonPink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color: AppColors.neonPink.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.neonPink,
                  size: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.neonPink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'EN 3 DÍAS',
                  style: TextStyle(
                    color: AppColors.neonPink,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Text(
            'Cena italiana',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Row(
            children: [
              Icon(Icons.schedule_rounded, color: Color(0xFF999BA5), size: 13),
              SizedBox(width: 5),
              Text(
                'Sábado · 7:30 PM',
                style: TextStyle(color: Color(0xFF999BA5), fontSize: 9.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodSummaryWidget extends StatelessWidget {
  const _MoodSummaryWidget();

  @override
  Widget build(BuildContext context) {
    return _DashboardPreviewShell(
      accentColor: AppColors.neonPurple,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.sentiment_satisfied_alt_rounded,
                color: AppColors.neonPurple,
                size: 18,
              ),
              Spacer(),
              Text(
                'HOY',
                style: TextStyle(
                  color: Color(0xFF898B94),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Text(
            'Muy bien',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '4.6 / 5',
            style: TextStyle(
              color: AppColors.neonPurple,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaterTrackerWidget extends StatelessWidget {
  const _WaterTrackerWidget();

  @override
  Widget build(BuildContext context) {
    return _DashboardPreviewShell(
      accentColor: AppColors.neonBlue,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(
                Icons.water_drop_rounded,
                color: AppColors.neonBlue,
                size: 18,
              ),
              Spacer(),
              Text(
                'AGUA',
                style: TextStyle(
                  color: Color(0xFF898B94),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Text(
            '5 / 8',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: 0.625,
              minHeight: 5,
              color: AppColors.neonBlue,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutProgressWidget extends StatelessWidget {
  const _WorkoutProgressWidget();

  @override
  Widget build(BuildContext context) {
    return _DashboardPreviewShell(
      accentColor: const Color(0xFF7CFFB2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(
                Icons.fitness_center_rounded,
                color: Color(0xFF7CFFB2),
                size: 18,
              ),
              Spacer(),
              Text(
                'SEMANA',
                style: TextStyle(
                  color: Color(0xFF898B94),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Text(
            '3 / 5',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: 0.60,
              minHeight: 5,
              color: const Color(0xFF7CFFB2),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumHighlightWidget extends StatelessWidget {
  const _AlbumHighlightWidget();

  @override
  Widget build(BuildContext context) {
    return _DashboardPreviewShell(
      accentColor: AppColors.neonPurple,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.widgetBackground,
                    Color(0xFF202227),
                    AppColors.widgetBackgroundDeep,
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 10,
              child: Icon(
                Icons.photo_library_rounded,
                color: Colors.white.withValues(alpha: 0.28),
                size: 42,
              ),
            ),
            const Positioned(
              left: 12,
              right: 12,
              bottom: 11,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recuerdo destacado',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Cartagena · hace 2 días',
                    style: TextStyle(color: Color(0xFFC8C2D2), fontSize: 9.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecialDateCountdownWidget extends StatelessWidget {
  const _SpecialDateCountdownWidget();

  @override
  Widget build(BuildContext context) {
    return _DashboardPreviewShell(
      accentColor: AppColors.neonOrange,
      child: Row(
        children: [
          Container(
            width: 50,
            height: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.neonOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '12',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'JUL',
                  style: TextStyle(
                    color: AppColors.neonOrange,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Aniversario',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Faltan 24 días',
                  style: TextStyle(
                    color: AppColors.neonOrange,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalsProgressWidget extends StatelessWidget {
  const _GoalsProgressWidget();

  @override
  Widget build(BuildContext context) {
    return _DashboardPreviewShell(
      accentColor: AppColors.neonPink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.flag_rounded, color: AppColors.neonPink, size: 19),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Metas compartidas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '4 / 6',
                style: TextStyle(
                  color: AppColors.neonPink,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: 0.66,
              minHeight: 6,
              color: AppColors.neonPink,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: const [
              _GoalPreviewChip(text: 'Viaje', completed: true),
              _GoalPreviewChip(text: 'Ahorro', completed: true),
              _GoalPreviewChip(text: 'Gym', completed: false),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalPreviewChip extends StatelessWidget {
  const _GoalPreviewChip({required this.text, required this.completed});

  final String text;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: completed
            ? AppColors.neonPink.withValues(alpha: 0.13)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completed
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: completed ? AppColors.neonPink : const Color(0xFF8D8F98),
            size: 11,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: completed ? Colors.white : const Color(0xFF9A9CA5),
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FullScreenNeonEdge extends StatelessWidget {
  const _FullScreenNeonEdge({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 8,
        height: double.infinity,
        child: Align(
          alignment: alignment,
          child: Container(
            width: 1.4,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.98),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.90),
                  blurRadius: 6,
                  spreadRadius: 0.4,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.48),
                  blurRadius: 13,
                  spreadRadius: 0.8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroEditActionButton extends StatelessWidget {
  const _HeroEditActionButton({
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isPrimary
                ? Colors.white
                : Colors.black.withValues(alpha: 0.68),
            border: Border.all(
              color: Colors.white.withValues(alpha: isPrimary ? 0.92 : 0.50),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 10,
              ),
              if (isPrimary)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.22),
                  blurRadius: 12,
                ),
            ],
          ),
          child: Icon(
            icon,
            color: isPrimary ? Colors.black : Colors.white,
            size: 21,
          ),
        ),
      ),
    );
  }
}
