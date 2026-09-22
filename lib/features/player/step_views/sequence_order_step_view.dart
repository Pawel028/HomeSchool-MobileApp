import 'dart:math';

import 'package:flutter/material.dart';
import 'package:homeschooling/models/steps.dart';
import 'package:homeschooling/strings.dart';

/// `sequence_order`: a [ReorderableListView] of `items[{id,label}]`. The server sends items in the correct
/// order, so this view shuffles them once for display (docs/client-guide.md) and reports ids in the child's
/// current order as the answer.
class SequenceOrderStepView extends StatefulWidget {
  const SequenceOrderStepView({super.key, required this.step, required this.answer, required this.onChanged});

  final SequenceOrderStep step;

  /// Item ids in the child's current order, or null before the first shuffle.
  final List<String>? answer;
  final ValueChanged<List<String>> onChanged;

  @override
  State<SequenceOrderStepView> createState() => _SequenceOrderStepViewState();
}

class _SequenceOrderStepViewState extends State<SequenceOrderStepView> {
  late List<Choice> _order;

  @override
  void initState() {
    super.initState();
    final Map<String, Choice> byId = <String, Choice>{for (final Choice c in widget.step.items) c.id: c};
    final List<String>? existing = widget.answer;
    if (existing != null && existing.length == widget.step.items.length) {
      _order = <Choice>[for (final String id in existing) if (byId.containsKey(id)) byId[id]!];
    } else {
      _order = List<Choice>.of(widget.step.items)..shuffle(Random());
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onChanged(_order.map((Choice c) => c.id).toList()));
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final Choice item = _order.removeAt(oldIndex);
      _order.insert(newIndex, item);
    });
    widget.onChanged(_order.map((Choice c) => c.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(widget.step.prompt, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(Str.sequenceHint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorder: _onReorder,
          children: <Widget>[
            for (final Choice item in _order)
              Card(
                key: ValueKey<String>(item.id),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(title: Text(item.label), trailing: const Icon(Icons.drag_handle)),
              ),
          ],
        ),
      ],
    );
  }
}
