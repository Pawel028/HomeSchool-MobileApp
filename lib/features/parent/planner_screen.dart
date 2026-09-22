import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homeschooling/core/dates.dart';
import 'package:homeschooling/features/common/state_views.dart';
import 'package:homeschooling/features/parent/parent_scaffold.dart';
import 'package:homeschooling/models/activity.dart';
import 'package:homeschooling/models/child.dart';
import 'package:homeschooling/models/plan.dart';
import 'package:homeschooling/state/catalogue_providers.dart';
import 'package:homeschooling/state/parent_view_providers.dart';
import 'package:homeschooling/state/plan_providers.dart';
import 'package:homeschooling/strings.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  DateTime _selectedDay = dateOnly(DateTime.now());
  String? _loadedForChildId;
  DateTime? _loadedWeek;

  @override
  Widget build(BuildContext context) {
    final Child? child = ref.watch(parentViewedChildProvider);
    final WeekPlanState week = ref.watch(weekPlanProvider);
    final DateTime weekStart = weekStartOf(_selectedDay);

    if (child != null && (_loadedForChildId != child.id || _loadedWeek != weekStart)) {
      _loadedForChildId = child.id;
      _loadedWeek = weekStart;
      Future<void>.microtask(() => ref.read(weekPlanProvider.notifier).loadWeek(child.id, _selectedDay));
    }

    return ParentScaffold(
      currentPath: '/parent/planner',
      title: Str.plannerTitle,
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: Str.plannerAddActivity,
          onPressed: child == null ? null : () => _openAddSheet(context, child, _selectedDay),
        ),
      ],
      body: child == null
          ? const EmptyView(message: Str.emptyGeneric, icon: Icons.face_outlined)
          : Column(
              children: <Widget>[
                _WeekStrip(
                  weekStart: weekStart,
                  selected: _selectedDay,
                  onSelect: (DateTime d) => setState(() => _selectedDay = d),
                ),
                const Divider(height: 1),
                Expanded(
                  child: week.loading
                      ? const LoadingView()
                      : week.error != null && week.items.isEmpty
                          ? ErrorView.fromException(
                              week.error!,
                              onRetry: () => ref.read(weekPlanProvider.notifier).loadWeek(child.id, _selectedDay),
                            )
                          : _DayList(day: _selectedDay, items: week.itemsOn(_selectedDay)),
                ),
              ],
            ),
    );
  }

  void _openAddSheet(BuildContext context, Child child, DateTime day) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _AddActivitySheet(childId: child.id, date: day),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.weekStart, required this.selected, required this.onSelect});

  final DateTime weekStart;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final List<DateTime> days = weekDays(weekStart);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          for (final DateTime d in days)
            InkWell(
              onTap: () => onSelect(d),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSameDay(d, selected) ? Theme.of(context).colorScheme.primaryContainer : null,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: <Widget>[Text(weekdayShort(d)), Text('${d.day}')],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayList extends ConsumerWidget {
  const _DayList({required this.day, required this.items});

  final DateTime day;
  final List<PlanItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const EmptyView(message: Str.plannerEmptyDay, icon: Icons.event_available_outlined);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final PlanItem item = items[index];
        return Card(
          child: ListTile(
            title: Text(item.activity.title),
            subtitle: Text('${item.activity.durationMin} min · ${item.status}'),
            trailing: item.canEdit
                ? PopupMenuButton<String>(
                    onSelected: (String value) async {
                      if (value == 'reschedule') await _reschedule(context, ref, item);
                      if (value == 'skip') await ref.read(weekPlanProvider.notifier).skip(item);
                      if (value == 'delete' && item.canDelete) await ref.read(weekPlanProvider.notifier).deleteItem(item.id);
                    },
                    itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(value: 'reschedule', child: Text(Str.plannerReschedule)),
                      const PopupMenuItem<String>(value: 'skip', child: Text(Str.plannerSkip)),
                      if (item.canDelete) const PopupMenuItem<String>(value: 'delete', child: Text(Str.plannerRemove)),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }

  Future<void> _reschedule(BuildContext context, WidgetRef ref, PlanItem item) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: item.scheduledDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) await ref.read(weekPlanProvider.notifier).reschedule(item, picked);
  }
}

class _AddActivitySheet extends ConsumerStatefulWidget {
  const _AddActivitySheet({required this.childId, required this.date});

  final String childId;
  final DateTime date;

  @override
  ConsumerState<_AddActivitySheet> createState() => _AddActivitySheetState();
}

class _AddActivitySheetState extends ConsumerState<_AddActivitySheet> {
  final TextEditingController _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => ref.read(catalogueProvider.notifier).search());
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CatalogueState catalogue = ref.watch(catalogueProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _query,
                decoration: const InputDecoration(labelText: Str.catalogueSearchHint, prefixIcon: Icon(Icons.search)),
                onSubmitted: (String q) => ref.read(catalogueProvider.notifier).search(query: q),
              ),
            ),
            Expanded(
              child: catalogue.loading
                  ? const LoadingView()
                  : ListView.builder(
                      itemCount: catalogue.results.length,
                      itemBuilder: (BuildContext context, int index) {
                        final ActivitySummary a = catalogue.results[index];
                        return ListTile(
                          title: Text(a.title),
                          subtitle: Text('${a.durationMin} min · ${a.levelRange}'),
                          trailing: TextButton(
                            onPressed: () async {
                              final bool ok = await ref
                                  .read(weekPlanProvider.notifier)
                                  .addItem(childId: widget.childId, activityId: a.id, date: widget.date);
                              if (ok && context.mounted) Navigator.of(context).pop();
                            },
                            child: const Text(Str.add),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
