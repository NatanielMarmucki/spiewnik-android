import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';

/// Settings screen elements from docs/DESIGN-SYSTEM.md: a section with a header, a 48 dp row,
/// a switch, and a slider with its value written as a number next to the name (section 5).
///
/// Nothing here has a fixed height: everything grows with the system font.
class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsSection({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22.0, 20.0, 22.0, 8.0),
          child: Text(
            title.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: appColors.textTertiary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...children,
        Divider(color: appColors.line, height: 1.0),
      ],
    );
  }
}

/// Settings row: an optional icon, the name, and a value or an arrow.
class SettingsRow extends StatelessWidget {
  final IconData? icon;
  final String label;

  /// Value on the right, e.g. the version number.
  final String? value;

  final bool selected;
  final VoidCallback? onTap;

  const SettingsRow({
    super.key,
    this.icon,
    required this.label,
    this.value,
    this.selected = false,
    this.onTap,
  });

  static const double minHeight = 48.0;
  static const double iconSize = 17.0;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: onTap != null,
      selected: onTap != null && selected ? true : null,
      label: value == null ? label : '$label: $value',
      onTap: onTap,
      container: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 12.0),
            child: Row(
              children: [
                // The icon slot is always there so the labels line up in one column.
                SizedBox(
                  width: iconSize + 14.0,
                  child: icon == null
                      ? null
                      : Icon(icon, size: iconSize, color: selected ? appColors.accent : appColors.textSecondary),
                ),
                Expanded(
                  child: Text(
                    label,
                    style: textTheme.bodyMedium?.copyWith(
                      color: selected ? colors.onSurface : null,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                if (value != null)
                  Text(value!, style: textTheme.bodyMedium?.copyWith(color: appColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row with a switch and a sentence explaining what it does.
class SettingsSwitch extends StatelessWidget {
  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsSwitch({
    super.key,
    required this.label,
    this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      toggled: value,
      label: label,
      onTap: () => onChanged(!value),
      container: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SettingsRow.minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 10.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: textTheme.bodyMedium),
                      if (description != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            description!,
                            style: textTheme.bodySmall?.copyWith(color: appColors.textTertiary),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16.0),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A slider with a name and its value written as a number next to it.
class SettingsSlider extends StatelessWidget {
  final String label;
  final double value;
  final String valueLabel;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const SettingsSlider({
    super.key,
    required this.label,
    required this.value,
    required this.valueLabel,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22.0, 4.0, 22.0, 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: textTheme.bodyMedium)),
              Text(valueLabel, style: textTheme.bodyMedium?.copyWith(color: appColors.textSecondary)),
            ],
          ),
          Semantics(
            label: label,
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: valueLabel,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
