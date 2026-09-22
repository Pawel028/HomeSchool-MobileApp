import 'package:flutter/material.dart';

class ChipOption {
  const ChipOption(this.value, this.label);

  final String value;
  final String label;
}

/// A wrap of [FilterChip]s for picking zero or more of [options] (interests, goals, filters).
class ChipPicker extends StatelessWidget {
  const ChipPicker({super.key, required this.options, required this.selected, required this.onChanged});

  final List<ChipOption> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        for (final ChipOption option in options)
          FilterChip(
            label: Text(option.label),
            selected: selected.contains(option.value),
            onSelected: (bool value) {
              final Set<String> next = Set<String>.of(selected);
              if (value) {
                next.add(option.value);
              } else {
                next.remove(option.value);
              }
              onChanged(next);
            },
          ),
      ],
    );
  }
}

/// A single-select row of [ChoiceChip]s (subject/level filters, etc). `null` selection means "any".
class SingleChoiceChips extends StatelessWidget {
  const SingleChoiceChips({super.key, required this.options, required this.selected, required this.onChanged});

  final List<ChipOption> options;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        for (final ChipOption option in options)
          ChoiceChip(
            label: Text(option.label),
            selected: selected == option.value,
            onSelected: (bool value) => onChanged(value ? option.value : null),
          ),
      ],
    );
  }
}
