import 'dart:ui';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:nimaluv_app/core/theme/app_theme.dart';
import 'package:nimaluv_app/features/albums/screens/albums_screen.dart';
import 'package:nimaluv_app/features/budget/screens/budget_screen.dart';
import 'package:nimaluv_app/features/date_planner/screens/date_planner_screen.dart';
import 'package:nimaluv_app/features/dates/screens/important_dates_screen.dart';
import 'package:nimaluv_app/features/goals/screens/goals_screen.dart';
import 'package:nimaluv_app/features/notes/screens/notes_screen.dart';
import 'package:nimaluv_app/features/kpi/screens/kpi_screen.dart';
import 'package:nimaluv_app/features/trips/screens/trips_screen.dart';
import 'package:nimaluv_app/features/workout/screens/workout_screen.dart';
import 'package:nimaluv_app/features/nutri_hub/screens/nutri_hub_screen.dart';
import 'package:nimaluv_app/features/settings/screens/settings_screen.dart';

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
  bool _partnerOneGoogleConnected = false;
  bool _partnerTwoGoogleConnected = false;
  bool _isDashboardEditing = false;

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

  late final AnimationController _quickMenuController;
  late final Animation<double> _quickMenuFade;
  late final Animation<double> _quickMenuScale;
  late final Animation<Offset> _quickMenuSlide;
  late final AnimationController _previewTransitionController;
  late final Animation<double> _previewTransitionFade;
  late final List<_DashboardItem> _dashboardItems;

  _QuickDestination _previousPreviewDestination = _QuickDestination.home;
  Future<void> _openHeroBackgroundEditor() async {
    String? currentPath = _heroBackgroundPath;

    if (currentPath == null) {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );

      if (!mounted || image == null) return;

      currentPath = image.path;

      setState(() {
        _heroBackgroundPath = currentPath;
        _heroBackgroundTransform = Matrix4.identity();
      });
    }

    final result = await showModalBottomSheet<_HeroBackgroundEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _HeroBackgroundEditorSheet(
          initialImagePath: currentPath!,
          initialTransform: _heroBackgroundTransform,
          heroHeight: 235,
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      _heroBackgroundPath = result.imagePath;
      _heroBackgroundTransform = Matrix4.copy(result.transform);
    });
  }

  @override
  void initState() {
    super.initState();

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

  Widget _buildQuickDestinationScreen(
    BuildContext context,
    _QuickDestination destination,
  ) {
    switch (destination) {
      case _QuickDestination.notes:
        return const NotesScreen();
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
        candidate.row + candidate.rowSpan > 10) {
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

  void _moveDashboardItem(_DashboardItem item, int newColumn, int newRow) {
    final movedItem = item.copyWith(column: newColumn, row: newRow);
    if (!_canPlaceDashboardItem(movedItem, ignoringItemId: item.id)) {
      HapticFeedback.heavyImpact();
      return;
    }
    final int itemIndex = _dashboardItems.indexWhere(
      (currentItem) => currentItem.id == item.id,
    );
    if (itemIndex == -1) return;
    HapticFeedback.selectionClick();
    setState(() {
      _dashboardItems[itemIndex] = movedItem;
    });
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
    }
  }

  _DashboardItem? _findAvailableDashboardPosition(_DashboardWidgetType type) {
    final template = _createDashboardItem(type, 0, 0);
    for (int row = 0; row < 10; row++) {
      for (int column = 0; column < 6; column++) {
        final candidate = template.copyWith(column: column, row: row);
        if (_canPlaceDashboardItem(candidate)) {
          return candidate;
        }
      }
    }
    return null;
  }

  void _addDashboardWidget(
    _DashboardWidgetType type, {
    required int preferredColumn,
    required int preferredRow,
  }) {
    final bool alreadyExists = _dashboardItems.any((item) => item.type == type);

    if (alreadyExists) return;

    final template = _createDashboardItem(type, 0, 0);

    final int maxColumn = 6 - template.columnSpan;

    final int maxRow = 10 - template.rowSpan;

    final int adjustedColumn = preferredColumn.clamp(0, maxColumn);

    final int adjustedRow = preferredRow.clamp(0, maxRow);

    final preferredItem = template.copyWith(
      column: adjustedColumn,
      row: adjustedRow,
    );

    _DashboardItem? itemToAdd;

    if (_canPlaceDashboardItem(preferredItem)) {
      itemToAdd = preferredItem;
    } else {
      itemToAdd = _findAvailableDashboardPosition(type);
    }

    if (itemToAdd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay suficiente espacio disponible.')),
      );
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _dashboardItems.add(itemToAdd!);
    });
  }

  Future<void> _openDashboardWidgetCatalog(
    int preferredColumn,
    int preferredRow,
  ) async {
    final availableTypes = _DashboardWidgetType.values.where((type) {
      return !_dashboardItems.any((item) => item.type == type);
    }).toList();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF18191E),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Agregar widget',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Selecciona un widget para agregarlo al Home.',
                  style: TextStyle(color: Color(0xFF989AA3), fontSize: 13),
                ),
                const SizedBox(height: 18),

                if (availableTypes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: Text(
                        'Todos los widgets ya están agregados.',
                        style: TextStyle(color: Color(0xFF989AA3)),
                      ),
                    ),
                  )
                else
                  for (final type in availableTypes)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _dashboardWidgetIcon(type),
                        color: _dashboardWidgetColor(type),
                      ),
                      title: Text(
                        _dashboardWidgetName(type),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: Colors.white,
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();

                        _addDashboardWidget(
                          type,
                          preferredColumn: preferredColumn,
                          preferredRow: preferredRow,
                        );
                      },
                    ),
              ],
            ),
          ),
        );
      },
    );
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
    }
  }

  Widget _buildHomeContent(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        const ColoredBox(color: AppColors.background),

        const _BackgroundGlow(),

        Column(
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              opacity: _isDashboardEditing ? 0.35 : 1.0,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: _isDashboardEditing ? 10 : 0,
                  sigmaY: _isDashboardEditing ? 10 : 0,
                ),
                child: IgnorePointer(
                  ignoring: _isDashboardEditing,
                  child: _HeroHeaderSection(
                    backgroundPath: _heroBackgroundPath,
                    backgroundTransform: _heroBackgroundTransform,
                    onChangeBackground: _openHeroBackgroundEditor,
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

                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      8,
                      24,
                      72 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    child: _DashboardGrid(
                      items: _dashboardItems,
                      itemBuilder: _buildDashboardWidget,
                      isEditing: _isDashboardEditing,
                      onRemoveItem: _removeDashboardItem,
                      onMoveItem: _moveDashboardItem,
                      onEmptyCellTap: (column, row) {
                        _openDashboardWidgetCatalog(column, row);
                      },
                      onLongPress: _toggleDashboardEditing,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
        const ColoredBox(color: AppColors.background),

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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
                      progress: _quickMenuController,
                      initialDestination:
                          _currentDestination ?? _selectedQuickDestination,
                      favoriteLabels: _quickFavoriteLabels,
                      onFavoriteChanged: _replaceQuickFavorite,
                      onFavoritePickerOpenChanged: _setFavoritePickerOpen,
                      onSelectedActionChanged: _setSelectedQuickActionLabel,
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
                        _showDestination(_QuickDestination.importantDates);
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
                      child: _NimaluvBottomNav(
                        isQuickMenuOpen: _quickMenuController.value > 0.0,
                        isFavoritePickerOpen: _isFavoritePickerOpen,
                        selectedQuickActionLabel: _selectedQuickActionLabel,
                        quickMenuProgress: _quickMenuController,
                        onQuickActionsTap: _openQuickActionPanel,
                        onCenterTap: toggleQuickMenu,
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
                    onTap: toggleQuickMenu,
                    onLongPress: _goHomeFromCenterLongPress,
                    child: const SizedBox(width: 86, height: 52),
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

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({
    required this.items,
    required this.itemBuilder,
    required this.isEditing,
    required this.onRemoveItem,
    required this.onMoveItem,
    required this.onEmptyCellTap,
    required this.onLongPress,
  });

  final List<_DashboardItem> items;
  final Widget Function(_DashboardItem item) itemBuilder;

  final bool isEditing;
  final ValueChanged<String> onRemoveItem;

  final void Function(_DashboardItem item, int column, int row) onMoveItem;

  final void Function(int column, int row) onEmptyCellTap;
  final VoidCallback onLongPress;

  static const int columnCount = 6;
  static const int rowCount = 10;

  static const double horizontalGap = 5;
  static const double verticalGap = 5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double availableHeight = constraints.maxHeight;

        final double cellFromWidth =
            (availableWidth - ((columnCount - 1) * horizontalGap)) /
            columnCount;

        final double cellFromHeight =
            (availableHeight - ((rowCount - 1) * verticalGap)) / rowCount;

        final double cellSize = math.min(cellFromWidth, cellFromHeight);

        final double gridWidth =
            (columnCount * cellSize) + ((columnCount - 1) * horizontalGap);

        final double gridHeight =
            (rowCount * cellSize) + ((rowCount - 1) * verticalGap);

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: gridWidth,
            height: gridHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPress: onLongPress,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (isEditing)
                    for (int row = 0; row < rowCount; row++)
                      for (int column = 0; column < columnCount; column++)
                        Positioned(
                          left: column * (cellSize + horizontalGap),
                          top: row * (cellSize + verticalGap),
                          width: cellSize,
                          height: cellSize,
                          child: DragTarget<_DashboardItem>(
                            onWillAcceptWithDetails: (details) {
                              return true;
                            },
                            onAcceptWithDetails: (details) {
                              final _DashboardItem draggedItem = details.data;

                              final int maxColumn =
                                  columnCount - draggedItem.columnSpan;

                              final int maxRow = rowCount - draggedItem.rowSpan;

                              final int centeredColumn =
                                  (column - (draggedItem.columnSpan ~/ 2))
                                      .clamp(0, maxColumn)
                                      .toInt();

                              final int centeredRow =
                                  (row - (draggedItem.rowSpan ~/ 2))
                                      .clamp(0, maxRow)
                                      .toInt();

                              onMoveItem(
                                draggedItem,
                                centeredColumn,
                                centeredRow,
                              );
                            },
                            builder: (context, candidateData, rejectedData) {
                              final bool isReceiving = candidateData.isNotEmpty;

                              final bool isCellOccupied = items.any((item) {
                                final bool insideColumns =
                                    column >= item.column &&
                                    column < item.column + item.columnSpan;

                                final bool insideRows =
                                    row >= item.row &&
                                    row < item.row + item.rowSpan;

                                return insideColumns && insideRows;
                              });

                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: isEditing && !isCellOccupied
                                    ? () {
                                        onEmptyCellTap(column, row);
                                      }
                                    : null,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  decoration: BoxDecoration(
                                    color: isReceiving
                                        ? Colors.white.withValues(alpha: 0.10)
                                        : Colors.white.withValues(alpha: 0.015),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isReceiving
                                          ? Colors.white.withValues(alpha: 0.55)
                                          : Colors.white.withValues(
                                              alpha: 0.10,
                                            ),
                                      width: isReceiving ? 1.2 : 0.6,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                  for (final item in items)
                    Positioned(
                      key: ValueKey(item.id),
                      left: item.column * (cellSize + horizontalGap),
                      top: item.row * (cellSize + verticalGap),
                      width:
                          (item.columnSpan * cellSize) +
                          ((item.columnSpan - 1) * horizontalGap),
                      height:
                          (item.rowSpan * cellSize) +
                          ((item.rowSpan - 1) * verticalGap),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: isEditing
                                ? Draggable<_DashboardItem>(
                                    data: item,
                                    dragAnchorStrategy:
                                        (draggable, dragContext, position) {
                                          final RenderBox renderBox =
                                              dragContext.findRenderObject()!
                                                  as RenderBox;

                                          return Offset(
                                            renderBox.size.width / 2,
                                            renderBox.size.height / 2,
                                          );
                                        },
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: SizedBox(
                                        width:
                                            (item.columnSpan * cellSize) +
                                            ((item.columnSpan - 1) *
                                                horizontalGap),
                                        height:
                                            (item.rowSpan * cellSize) +
                                            ((item.rowSpan - 1) * verticalGap),
                                        child: Opacity(
                                          opacity: 0.88,
                                          child: itemBuilder(item),
                                        ),
                                      ),
                                    ),
                                    childWhenDragging: IgnorePointer(
                                      child: Opacity(
                                        opacity: 0.22,
                                        child: itemBuilder(item),
                                      ),
                                    ),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        onRemoveItem(item.id);
                                      },
                                      child: IgnorePointer(
                                        child: itemBuilder(item),
                                      ),
                                    ),
                                  )
                                : itemBuilder(item),
                          ),
                        ],
                      ),
                    ),
                ], // children del Stack principal
              ), // Stack principal
            ), // GestureDetector
          ), // SizedBox
        ); // Align
      },
    ); // LayoutBuilder
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
    required this.backgroundTransform,
    required this.onChangeBackground,
    required this.partnerOneName,
    required this.partnerTwoName,
    required this.partnerOnePhotoUrl,
    required this.partnerTwoPhotoUrl,
    required this.onPartnerOneTap,
    required this.onPartnerTwoTap,
  });

  final String? backgroundPath;
  final Matrix4 backgroundTransform;
  final VoidCallback onChangeBackground;

  final String partnerOneName;
  final String partnerTwoName;
  final String? partnerOnePhotoUrl;
  final String? partnerTwoPhotoUrl;
  final VoidCallback onPartnerOneTap;
  final VoidCallback onPartnerTwoTap;

  @override
  Widget build(BuildContext context) {
    const double heroHeight = 170;
    return GestureDetector(
      onLongPress: onChangeBackground,
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
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Transform(
                            transform: backgroundTransform,
                            alignment: Alignment.center,
                            child: Image.file(
                              File(backgroundPath!),
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                            ),
                          );
                        },
                      ),
                    ),
            ),

            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.45, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.10),
                        Colors.black.withValues(alpha: 0.16),
                        Colors.black.withValues(alpha: 0.22),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.18)),
            ),

            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.44),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.18),
                    ],
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
                      child: _NimaluvWordmark(),
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

class _NimaluvWordmark extends StatelessWidget {
  const _NimaluvWordmark();

  @override
  Widget build(BuildContext context) {
    const double logoFontSize = 15;

    return Align(
      alignment: Alignment.centerLeft,
      child: Transform.translate(
        offset: const Offset(-2, 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'NIMA',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: logoFontSize,
                fontWeight: FontWeight.w500,
                letterSpacing: 3.0,
                height: 1,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.95),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                  Shadow(
                    color: Colors.white.withValues(alpha: 0.38),
                    blurRadius: 14,
                  ),
                  Shadow(
                    color: AppColors.neonPurple.withValues(alpha: 0.42),
                    blurRadius: 24,
                  ),
                  Shadow(
                    color: AppColors.neonPink.withValues(alpha: 0.22),
                    blurRadius: 34,
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -0.98),
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Aura detrás de LUV.
                    Text(
                      'LUV',
                      style: GoogleFonts.playfairDisplay(
                        color: AppColors.neonPink.withValues(alpha: 0.55),
                        fontSize: logoFontSize,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 0.9,
                        height: 1,
                        shadows: [
                          Shadow(
                            color: AppColors.neonPink.withValues(alpha: 0.95),
                            blurRadius: 16,
                          ),
                          Shadow(
                            color: AppColors.neonPurple.withValues(alpha: 0.82),
                            blurRadius: 26,
                          ),
                          Shadow(
                            color: AppColors.neonBlue.withValues(alpha: 0.35),
                            blurRadius: 38,
                          ),
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.95),
                            blurRadius: 9,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),

                    // Texto principal con degradado.
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFB978FF),
                            Color(0xFFFF5DDA),
                            Color(0xFF8B4DFF),
                          ],
                        ).createShader(
                          Rect.fromLTRB(
                            bounds.left,
                            bounds.top,
                            bounds.right + 30,
                            bounds.bottom,
                          ),
                        );
                      },
                      child: Text(
                        'LUV',
                        style: GoogleFonts.playfairDisplay(
                          color: const Color(0xFF7B2CFF),
                          fontSize: logoFontSize,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.9,
                          height: 1,
                        ),
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
                  color: const Color(0xFFFF3B3B).withValues(alpha: 0.38),
                  blurRadius: 12,
                  spreadRadius: 0.3,
                ),
                BoxShadow(
                  color: const Color(0xFFFF1744).withValues(alpha: 0.18),
                  blurRadius: 22,
                  spreadRadius: 0.8,
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
                          color: const Color(
                            0xFFFF3B3B,
                          ).withValues(alpha: 0.95),
                          width: 1.2,
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
                              color: AppColors.neonPink.withValues(alpha: 0.20),
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
        color: AppColors.surface.withValues(alpha: 0.88),
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

  void _confirmFavoritePickerSelection() {
    final favoriteSlot = _favoriteSlotBeingEdited;

    if (favoriteSlot == null || _favoritePickerActions.isEmpty) {
      return;
    }

    final selectedAction = _favoritePickerActions[_favoritePickerSelectedIndex];

    widget.onFavoriteChanged(favoriteSlot, selectedAction.label);

    widget.onFavoritePickerOpenChanged(false);

    _favoritePickerController?.dispose();
    _favoritePickerController = null;

    setState(() {
      _favoriteSlotBeingEdited = null;
      _favoritePickerAnchor = null;
      _favoritePickerActions = [];
      _favoritePickerSelectedIndex = 0;

      // No modificar _centerIndex.
      // No modificar _dragProgress.
      // Así la rueda conserva exactamente su posición actual.

      _pendingStep = 0;
    });
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
          const double radius = 120;

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

                        final Color selectedColor = selectedAction.color;

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
                                        0xFF05030B,
                                      ).withValues(alpha: 0.48),
                                    ),
                                  ),

                                  // Base oscura violeta.
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        center: const Alignment(0, 0.08),
                                        radius: 0.94,
                                        colors: [
                                          selectedColor.withValues(alpha: 0.20),
                                          const Color(
                                            0xFF2B1248,
                                          ).withValues(alpha: 0.24),
                                          const Color(
                                            0xFF120A20,
                                          ).withValues(alpha: 0.66),
                                          const Color(
                                            0xFF05030A,
                                          ).withValues(alpha: 0.82),
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

                                              final int actionIndex =
                                                  _wrapIndex(
                                                    _centerIndex + slot,
                                                    actions.length,
                                                  );

                                              final Color glowColor =
                                                  actions[actionIndex].color;

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

                                  // Luz suave central para integrar todos los colores.
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        center: const Alignment(0, 0.26),
                                        radius: 0.68,
                                        colors: [
                                          selectedColor.withValues(alpha: 0.14),
                                          const Color(
                                            0xFF8B5CFF,
                                          ).withValues(alpha: 0.08),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.00, 0.52, 1.00],
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
    final double buttonSize = 64;
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
    const double itemExtent = 82;
    const double railWidth = 110;

    // Cinco posiciones visibles:
    // dos arriba, selector central y dos abajo.
    // Área visible:
    // 2 opciones arriba + el icono seleccionado.
    // No se muestra ninguna opción debajo.
    const double visibleRailHeight = itemExtent * 3.0;
    // El ListWheel sigue teniendo cinco posiciones internamente.
    // Esto coloca su centro magnético en el tercer icono.
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
              final double ovalRadius = (bounds.height / bounds.width) * 1.03;

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
        width: size + 12,
        height: size + 12,
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  action.color.withValues(alpha: 0.26),
                  AppColors.surface.withValues(alpha: 0.96),
                ],
              ),
              border: Border.all(
                color: action.color.withValues(alpha: 0.90),
                width: 1.6,
              ),

              // Glow pequeño que cabe dentro del rail.
              boxShadow: [
                BoxShadow(
                  color: action.color.withValues(alpha: 0.20),
                  blurRadius: 10,
                  spreadRadius: 0,
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
                        color.withValues(alpha: 0.30),
                        AppColors.surface.withValues(alpha: 0.96),
                      ],
                    ),
                    border: Border.all(
                      color: color.withValues(alpha: 0.95),
                      width: 1.8,
                    ),
                    boxShadow: [
                      // Glow concentrado alrededor del botón.
                      BoxShadow(
                        color: color.withValues(alpha: 0.55),
                        blurRadius: 22,
                        spreadRadius: 3,
                      ),

                      // Aura exterior amplia.
                      BoxShadow(
                        color: color.withValues(alpha: 0.30),
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

class _NimaluvBottomNav extends StatelessWidget {
  const _NimaluvBottomNav({
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
          final double barWidth = (constraints.maxWidth * 0.56)
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

                          const SizedBox(width: 76),

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
                bottom: 83 + bottomExtension,
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
      offset: const Offset(0, -20),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 88,
          height: 88,
          child: AnimatedBuilder(
            animation: progress,
            builder: (context, child) {
              final double rawValue = progress.value.clamp(0.0, 1.0);

              final double ledProgress = Curves.easeInOutCubic.transform(
                rawValue,
              );

              final double glowValue = Curves.easeOutCubic.transform(rawValue);

              return CustomPaint(
                painter: _CenterLedPainter(
                  progress: ledProgress,
                  glowOpacity: glowValue,
                  isActive: isActive,
                ),
                child: child,
              );
            },
            child: Center(
              child: AnimatedScale(
                scale: isActive ? 0.94 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFF4FD8),
                        Color(0xFF8B5CFF),
                        Color(0xFF35E8FF),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4FD8).withValues(alpha: 0.42),
                        blurRadius: 22,
                        spreadRadius: 1.4,
                      ),
                      BoxShadow(
                        color: const Color(0xFF35E8FF).withValues(alpha: 0.22),
                        blurRadius: 26,
                        spreadRadius: 1.2,
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
                          'assets/images/nimaluv_logo.png',
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
      ),
    );
  }
}

class _CenterLedPainter extends CustomPainter {
  const _CenterLedPainter({
    required this.progress,
    required this.glowOpacity,
    required this.isActive,
  });

  final double progress;
  final double glowOpacity;
  final bool isActive;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    final ringRect = Rect.fromCircle(center: center, radius: 33);

    final basePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.10);

    canvas.drawArc(ringRect, -math.pi / 2, math.pi * 2, false, basePaint);

    if (progress <= 0) return;

    final glowPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [
          Color(0x00FFFFFF),
          Color(0xFFFF4FD8),
          Color(0xFF8B5CFF),
          Color(0xFF35E8FF),
          Color(0xFFFFFFFF),
        ],
      ).createShader(ringRect)
      ..color = Colors.white.withValues(alpha: 0.42 * glowOpacity);

    canvas.drawArc(
      ringRect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      glowPaint,
    );

    final ledPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [
          Color(0xFFFF4FD8),
          Color(0xFF8B5CFF),
          Color(0xFF35E8FF),
          Color(0xFFFFFFFF),
        ],
      ).createShader(ringRect);

    canvas.drawArc(
      ringRect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      ledPaint,
    );

    final tipAngle = -math.pi / 2 + (math.pi * 2 * progress);

    final tipOffset = Offset(
      center.dx + math.cos(tipAngle) * 33,
      center.dy + math.sin(tipAngle) * 33,
    );

    final tipPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.92);

    canvas.drawCircle(tipOffset, 2.5, tipPaint);
  }

  @override
  bool shouldRepaint(covariant _CenterLedPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.glowOpacity != glowOpacity ||
        oldDelegate.isActive != isActive;
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.showLabel = true,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
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
