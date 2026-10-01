import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' hide colorToHex;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../schrobbedock_theme_riverpod.dart';

class ThemeCustomizerDialog extends ConsumerStatefulWidget {
  final SchrobbeDockThemeController? controller;

  const ThemeCustomizerDialog({
    super.key,
    this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    SchrobbeDockThemeController? controller,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ThemeCustomizerDialog(controller: controller),
    );
  }

  @override
  ConsumerState<ThemeCustomizerDialog> createState() =>
      _ThemeCustomizerDialogState();
}

class _ThemeCustomizerDialogState extends ConsumerState<ThemeCustomizerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeColorTarget = 0; // 0 = Primair, 1 = Secundair
  late Color _currentPrimary;
  late Color _currentSecondary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final initialPrefs = _resolveInitialPreferences();
    _currentPrimary = initialPrefs.primaryColor;
    _currentSecondary = initialPrefs.secondaryColor;
  }

  ThemePreferences _resolveInitialPreferences() {
    if (widget.controller != null) {
      return widget.controller!.preferences;
    }
    final scope = SchrobbeDockThemeScope.maybeOf(context);
    if (scope != null) {
      return scope.preferences;
    }
    try {
      return ref.read(themePreferencesProvider);
    } catch (_) {
      return ThemePreferences.defaultPreferences;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSaveThemeDialog(
    BuildContext context,
    ThemePreferences prefs,
    Future<void> Function(String name) onSave,
  ) {
    final nameController = TextEditingController(text: 'Mijn Thema');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.bookmark_add_outlined),
              SizedBox(width: 8),
              Text('Thema Opslaan'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Geef een herkenbare naam aan jouw aangepaste kleurensamenstelling om deze later snel opnieuw te kiezen.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Themanaam',
                  hintText: 'bijv. Bedrijfsstijl, Avondrust...',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  await onSave(name);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.green,
                        content: Text('Thema "$name" succesvol opgeslagen!'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Opslaan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveController =
        widget.controller ?? SchrobbeDockThemeScope.maybeOf(context);

    final ThemePreferences prefs;
    final bool canAccessRobHub;

    if (effectiveController != null) {
      prefs = effectiveController.preferences;
      canAccessRobHub = effectiveController.canAccessRobHub;
    } else {
      prefs = ref.watch(themePreferencesProvider);
      canAccessRobHub = ref.watch(canAccessRobHubProvider).value ?? false;
    }

    final availablePresets = canAccessRobHub
        ? ThemePresets.allPresets
        : ThemePresets.standardPresets;

    final isRobHub = prefs.preset == 'rob_hub';

    // Action callbacks
    Future<void> onSetThemeMode(ThemeMode mode) async {
      if (effectiveController != null) {
        await effectiveController.setThemeMode(mode);
      } else {
        await ref.read(themePreferencesProvider.notifier).setThemeMode(mode);
      }
    }

    Future<void> onApplyPreset(ThemePresetItem preset) async {
      if (effectiveController != null) {
        await effectiveController.applyPreset(preset);
      } else {
        await ref.read(themePreferencesProvider.notifier).applyPreset(preset);
      }
    }

    Future<void> onSetCustomColors(Color primary, Color secondary) async {
      if (effectiveController != null) {
        await effectiveController.setCustomColors(
          primary: primary,
          secondary: secondary,
        );
      } else {
        await ref.read(themePreferencesProvider.notifier).setCustomColors(
              primary: primary,
              secondary: secondary,
            );
      }
    }

    Future<void> onSaveCustomTheme(String name) async {
      if (effectiveController != null) {
        await effectiveController.saveCurrentAsCustomTheme(name);
      } else {
        await ref
            .read(themePreferencesProvider.notifier)
            .saveCurrentAsCustomTheme(name);
      }
    }

    Future<void> onApplySavedTheme(SavedTheme saved) async {
      if (effectiveController != null) {
        await effectiveController.applySavedTheme(saved);
      } else {
        await ref
            .read(themePreferencesProvider.notifier)
            .applySavedTheme(saved);
      }
    }

    Future<void> onDeleteSavedTheme(String id) async {
      if (effectiveController != null) {
        await effectiveController.deleteSavedTheme(id);
      } else {
        await ref
            .read(themePreferencesProvider.notifier)
            .deleteSavedTheme(id);
      }
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: prefs.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.palette_outlined,
                      color: prefs.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Uiterlijk & Thema Personalisatie',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Stel weergavemodus in en creëer eigen thema\'s met de colorpicker.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Weergavemodus SegmentedButton
              if (isRobHub)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141416),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFFA31A).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.dark_mode,
                        size: 18,
                        color: Color(0xFFFFA31A),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'RobHub is exclusief vergrendeld op Pitch-Black Donker thema.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFFFA31A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFFFA31A).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'DONKER',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFA31A),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto, size: 16),
                        label: Text('Systeem'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode, size: 16),
                        label: Text('Licht'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode, size: 16),
                        label: Text('Donker (Slate)'),
                      ),
                    ],
                    selected: {prefs.themeMode},
                    onSelectionChanged: (selected) {
                      onSetThemeMode(selected.first);
                    },
                  ),
                ),
              const SizedBox(height: 14),

              // Tabs
              TabBar(
                controller: _tabController,
                labelColor: prefs.primaryColor,
                indicatorColor: prefs.primaryColor,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.dashboard_customize_outlined,
                        size: 18),
                    text:
                        'Thema\'s (${prefs.savedThemes.length + availablePresets.length})',
                  ),
                  const Tab(
                    icon: Icon(Icons.colorize, size: 18),
                    text: 'Interactieve Colorpicker',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildThemesTab(
                      theme: theme,
                      prefs: prefs,
                      availablePresets: availablePresets,
                      onApplyPreset: onApplyPreset,
                      onApplySavedTheme: onApplySavedTheme,
                      onDeleteSavedTheme: onDeleteSavedTheme,
                      onSaveTheme: onSaveCustomTheme,
                    ),
                    _buildColorPickerTab(
                      theme: theme,
                      prefs: prefs,
                      onSaveTheme: onSaveCustomTheme,
                      onSetColors: onSetCustomColors,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      const defaultPreset = ThemePresets.amberRust;
                      onApplyPreset(defaultPreset);
                      setState(() {
                        _currentPrimary = defaultPreset.primaryColor;
                        _currentSecondary = defaultPreset.secondaryColor;
                      });
                    },
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('Herstel Warm Amber'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Klaar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemesTab({
    required ThemeData theme,
    required ThemePreferences prefs,
    required List<ThemePresetItem> availablePresets,
    required Future<void> Function(ThemePresetItem preset) onApplyPreset,
    required Future<void> Function(SavedTheme saved) onApplySavedTheme,
    required Future<void> Function(String id) onDeleteSavedTheme,
    required Future<void> Function(String name) onSaveTheme,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MIJN OPGESLAGEN THEMA\'S',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: theme.colorScheme.primary,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _showSaveThemeDialog(context, prefs, onSaveTheme),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Thema Opslaan'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (prefs.savedThemes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Je hebt nog geen eigen thema\'s opgeslagen. Ga naar de tab "Interactieve Colorpicker" om kleuren te kiezen en sla ze hier op!',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: prefs.savedThemes.length,
              separatorBuilder: (_, i) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final saved = prefs.savedThemes[idx];
                final isSelected = prefs.preset == 'saved_${saved.id}';

                return Card(
                  elevation: 0,
                  color: isSelected
                      ? saved.primaryColor.withValues(alpha: 0.12)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected
                          ? saved.primaryColor
                          : theme.colorScheme.outline.withValues(alpha: 0.4),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    onTap: () {
                      onApplySavedTheme(saved);
                      setState(() {
                        _currentPrimary = saved.primaryColor;
                        _currentSecondary = saved.secondaryColor;
                      });
                    },
                    leading: Stack(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: saved.secondaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Positioned(
                          left: 8,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: saved.primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      saved.name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Primair: ${colorToHex(saved.primaryColor)} • Secundair: ${colorToHex(saved.secondaryColor)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          Icon(Icons.check_circle,
                              color: saved.primaryColor, size: 20),
                        IconButton(
                          tooltip: 'Thema Verwijderen',
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.redAccent),
                          onPressed: () {
                            onDeleteSavedTheme(saved.id);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 20),

          // Standaard Sjablonen
          Text(
            'STANDAARD SJABLONEN',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: availablePresets.map((preset) {
              final isSelected = prefs.preset == preset.id;
              final isRobHub = preset.id == 'rob_hub';
              return InkWell(
                onTap: () {
                  onApplyPreset(preset);
                  setState(() {
                    _currentPrimary = preset.primaryColor;
                    _currentSecondary = preset.secondaryColor;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isRobHub
                            ? const Color(0xFF141416)
                            : preset.primaryColor.withValues(alpha: 0.12))
                        : (isRobHub
                            ? const Color(0xFF141416)
                            : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? (isRobHub
                              ? const Color(0xFFFFA31A)
                              : preset.primaryColor)
                          : (isRobHub
                              ? const Color(0xFFFFA31A).withValues(alpha: 0.5)
                              : theme.colorScheme.outline
                                  .withValues(alpha: 0.5)),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: preset.secondaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Positioned(
                            left: 6,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: preset.primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Text(
                        preset.name,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isRobHub
                              ? Colors.white
                              : (isSelected
                                  ? preset.primaryColor
                                  : theme.colorScheme.onSurface),
                        ),
                      ),
                      if (isRobHub) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFA31A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'EXCLUSIEF',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.check,
                          size: 16,
                          color: isRobHub
                              ? const Color(0xFFFFA31A)
                              : preset.primaryColor,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPickerTab({
    required ThemeData theme,
    required ThemePreferences prefs,
    required Future<void> Function(String name) onSaveTheme,
    required Future<void> Function(Color primary, Color secondary) onSetColors,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'KIES ONDERDEEL OM AAN TE PASSEN:',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: theme.colorScheme.primary,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showSaveThemeDialog(context, prefs, onSaveTheme),
                icon: const Icon(Icons.bookmark_add, size: 16),
                label: const Text('Opslaan als Thema'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _currentPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('Primaire Accentkleur (${colorToHex(_currentPrimary)})'),
                    ],
                  ),
                  selected: _activeColorTarget == 0,
                  onSelected: (val) {
                    if (val) setState(() => _activeColorTarget = 0);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _currentSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('Secundaire Kleur (${colorToHex(_currentSecondary)})'),
                    ],
                  ),
                  selected: _activeColorTarget == 1,
                  onSelected: (val) {
                    if (val) setState(() => _activeColorTarget = 1);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: ColorPicker(
              pickerColor:
                  _activeColorTarget == 0 ? _currentPrimary : _currentSecondary,
              onColorChanged: (newColor) {
                setState(() {
                  if (_activeColorTarget == 0) {
                    _currentPrimary = newColor;
                  } else {
                    _currentSecondary = newColor;
                  }
                });
                onSetColors(_currentPrimary, _currentSecondary);
              },
              colorPickerWidth: 320,
              pickerAreaHeightPercent: 0.5,
              enableAlpha: false,
              displayThumbColor: true,
              paletteType: PaletteType.hsvWithHue,
              labelTypes: const [
                ColorLabelType.hex,
                ColorLabelType.rgb,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
