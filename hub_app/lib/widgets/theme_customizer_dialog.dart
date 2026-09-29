import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/schrobbedock_theme.dart';

class ThemeCustomizerDialog extends ConsumerStatefulWidget {
  const ThemeCustomizerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const ThemeCustomizerDialog(),
    );
  }

  @override
  ConsumerState<ThemeCustomizerDialog> createState() =>
      _ThemeCustomizerDialogState();
}

class _ThemeCustomizerDialogState extends ConsumerState<ThemeCustomizerDialog> {
  late TextEditingController _primaryHexController;
  late TextEditingController _secondaryHexController;
  bool _isCustomMode = false;
  int _activeColorTab = 0; // 0 = Primair, 1 = Secundair

  static const List<Color> _swatches = [
    Color(0xFFEA580C), // Warm Amber / Orange (Default)
    Color(0xFFB45309), // Warm Rust
    Color(0xFFF97316), // Bright Orange
    Color(0xFFEF4444), // Crimson Red
    Color(0xFFF59E0B), // Golden Amber
    Color(0xFF10B981), // Emerald
    Color(0xFF059669), // Dark Emerald
    Color(0xFF06B6D4), // Cyan
    Color(0xFF2563EB), // Ocean Blue
    Color(0xFF1D4ED8), // Deep Blue
    Color(0xFF4F46E5), // Indigo
    Color(0xFF7C3AED), // Violet
    Color(0xFF9333EA), // Purple
    Color(0xFFDB2777), // Pink
    Color(0xFF475569), // Slate
    Color(0xFF1E293B), // Dark Slate
  ];

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(themePreferencesProvider);
    _primaryHexController =
        TextEditingController(text: colorToHex(prefs.primaryColor));
    _secondaryHexController =
        TextEditingController(text: colorToHex(prefs.secondaryColor));
    _isCustomMode = prefs.preset == 'custom';
  }

  @override
  void dispose() {
    _primaryHexController.dispose();
    _secondaryHexController.dispose();
    super.dispose();
  }

  void _syncHexInputs(Color primary, Color secondary) {
    _primaryHexController.text = colorToHex(primary);
    _secondaryHexController.text = colorToHex(secondary);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = ref.watch(themePreferencesProvider);
    final notifier = ref.read(themePreferencesProvider.notifier);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                    child: Icon(Icons.palette_outlined,
                        color: prefs.primaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Uiterlijk & Thema',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Personaliseer de weergave en accentkleuren voor al je apps.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
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
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              // Content met Scroll
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Modus Kiezer (Systeem, Licht, Donker)
                      Text(
                        'WEERGAVEMODUS',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto, size: 18),
                            label: Text('Systeem'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode, size: 18),
                            label: Text('Licht'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode, size: 18),
                            label: Text('Donker (Slate)'),
                          ),
                        ],
                        selected: {prefs.themeMode},
                        onSelectionChanged: (selected) {
                          notifier.setThemeMode(selected.first);
                        },
                      ),
                      const SizedBox(height: 24),

                      // 2. Presets / Templates
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'VOORGEMAAKTE THEMA\'S',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          if (_isCustomMode)
                            TextButton.icon(
                              onPressed: () {
                                setState(() => _isCustomMode = false);
                                final defaultPreset = ThemePresets.amberRust;
                                notifier.applyPreset(defaultPreset);
                                _syncHexInputs(defaultPreset.primaryColor,
                                    defaultPreset.secondaryColor);
                              },
                              icon: const Icon(Icons.restart_alt, size: 16),
                              label: const Text('Herstel Standaard'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ...ThemePresets.allPresets.map((preset) {
                            final isSelected = !_isCustomMode &&
                                prefs.preset == preset.id;
                            return InkWell(
                              onTap: () {
                                setState(() => _isCustomMode = false);
                                notifier.applyPreset(preset);
                                _syncHexInputs(preset.primaryColor,
                                    preset.secondaryColor);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? preset.primaryColor
                                          .withValues(alpha: 0.12)
                                      : theme.colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? preset.primaryColor
                                        : theme.colorScheme.outline
                                            .withValues(alpha: 0.5),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Kleurenbadges (Primair + Secundair)
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
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 8),
                                      Icon(Icons.check,
                                          size: 16, color: preset.primaryColor),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }),
                          // Custom button
                          InkWell(
                            onTap: () {
                              setState(() => _isCustomMode = true);
                              notifier.setCustomColors(
                                primary: prefs.primaryColor,
                                secondary: prefs.secondaryColor,
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isCustomMode
                                    ? prefs.primaryColor
                                        .withValues(alpha: 0.12)
                                    : theme.colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _isCustomMode
                                      ? prefs.primaryColor
                                      : theme.colorScheme.outline
                                          .withValues(alpha: 0.5),
                                  width: _isCustomMode ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.colorize,
                                      size: 18,
                                      color: _isCustomMode
                                          ? prefs.primaryColor
                                          : theme.colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Zelf Kiezen (Custom)',
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: _isCustomMode
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  if (_isCustomMode) ...[
                                    const SizedBox(width: 8),
                                    Icon(Icons.check,
                                        size: 16, color: prefs.primaryColor),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 3. Custom Kleur Kiezer (Indien Custom actief)
                      if (_isCustomMode) ...[
                        Text(
                          'AANGEPASTE KLEUREN INSTELLEN',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<int>(
                          segments: [
                            ButtonSegment(
                              value: 0,
                              icon: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: prefs.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              label: const Text('Primaire Accentkleur'),
                            ),
                            ButtonSegment(
                              value: 1,
                              icon: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: prefs.secondaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              label: const Text('Secundaire Kleur'),
                            ),
                          ],
                          selected: {_activeColorTab},
                          onSelectionChanged: (selected) {
                            setState(() => _activeColorTab = selected.first);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Hex Invoerveld
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: _activeColorTab == 0
                                    ? prefs.primaryColor
                                    : prefs.secondaryColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _activeColorTab == 0
                                    ? _primaryHexController
                                    : _secondaryHexController,
                                decoration: InputDecoration(
                                  labelText: _activeColorTab == 0
                                      ? 'Primaire Hex Code'
                                      : 'Secundaire Hex Code',
                                  hintText: '#EA580C',
                                  prefixIcon: const Icon(Icons.tag, size: 20),
                                  isDense: true,
                                ),
                                onChanged: (val) {
                                  if (val.trim().length >= 6) {
                                    final parsed = colorFromHex(
                                      val,
                                      _activeColorTab == 0
                                          ? prefs.primaryColor
                                          : prefs.secondaryColor,
                                    );
                                    if (_activeColorTab == 0) {
                                      notifier.setCustomColors(
                                        primary: parsed,
                                        secondary: prefs.secondaryColor,
                                      );
                                    } else {
                                      notifier.setCustomColors(
                                        primary: prefs.primaryColor,
                                        secondary: parsed,
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Swatches Palette
                        Text(
                          'Snelkiezer:',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _swatches.map((color) {
                            final isColorSelected = _activeColorTab == 0
                                ? prefs.primaryColor.toARGB32() ==
                                    color.toARGB32()
                                : prefs.secondaryColor.toARGB32() ==
                                    color.toARGB32();

                            return InkWell(
                              onTap: () {
                                if (_activeColorTab == 0) {
                                  _primaryHexController.text =
                                      colorToHex(color);
                                  notifier.setCustomColors(
                                    primary: color,
                                    secondary: prefs.secondaryColor,
                                  );
                                } else {
                                  _secondaryHexController.text =
                                      colorToHex(color);
                                  notifier.setCustomColors(
                                    primary: prefs.primaryColor,
                                    secondary: color,
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isColorSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                  boxShadow: isColorSelected
                                      ? [
                                          BoxShadow(
                                            color: color.withValues(alpha: 0.5),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          )
                                        ]
                                      : null,
                                ),
                                child: isColorSelected
                                    ? const Icon(Icons.check,
                                        size: 16, color: Colors.white)
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Footer acties
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Sluiten'),
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
