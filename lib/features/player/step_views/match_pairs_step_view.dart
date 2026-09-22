import 'package:flutter/material.dart';
import 'package:homeschooling/models/steps.dart';
import 'package:homeschooling/strings.dart';

/// `match_pairs`: tap one on the left, then its match on the right. Answer is a list of `[left_id, right_id]`.
class MatchPairsStepView extends StatefulWidget {
  const MatchPairsStepView({super.key, required this.step, required this.answer, required this.onChanged});

  final MatchPairsStep step;

  /// Pairs made so far, each `[leftId, rightId]`.
  final List<List<String>> answer;
  final ValueChanged<List<List<String>>> onChanged;

  @override
  State<MatchPairsStepView> createState() => _MatchPairsStepViewState();
}

class _MatchPairsStepViewState extends State<MatchPairsStepView> {
  String? _selectedLeft;

  Set<String> get _matchedLeft => widget.answer.map((List<String> p) => p[0]).toSet();
  Set<String> get _matchedRight => widget.answer.map((List<String> p) => p[1]).toSet();

  void _tapLeft(String id) {
    if (_matchedLeft.contains(id)) return;
    setState(() => _selectedLeft = _selectedLeft == id ? null : id);
  }

  void _tapRight(String id) {
    final String? left = _selectedLeft;
    if (left == null || _matchedRight.contains(id)) return;
    final List<List<String>> next = <List<String>>[...widget.answer, <String>[left, id]];
    setState(() => _selectedLeft = null);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(widget.step.prompt, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(Str.matchLeftHint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                children: <Widget>[
                  for (final Choice c in widget.step.left)
                    _Tile(
                      label: c.label,
                      selected: _selectedLeft == c.id,
                      matched: _matchedLeft.contains(c.id),
                      onTap: () => _tapLeft(c.id),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: <Widget>[
                  for (final Choice c in widget.step.right)
                    _Tile(
                      label: c.label,
                      selected: false,
                      matched: _matchedRight.contains(c.id),
                      onTap: () => _tapRight(c.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.selected, required this.matched, required this.onTap});

  final String label;
  final bool selected;
  final bool matched;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: matched ? scheme.secondaryContainer : (selected ? scheme.primaryContainer : scheme.surfaceContainerHighest),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: matched ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            child: Text(label, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
