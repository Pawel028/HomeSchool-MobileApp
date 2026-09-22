import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homeschooling/features/common/chip_picker.dart';
import 'package:homeschooling/features/common/state_views.dart';
import 'package:homeschooling/features/parent/parent_scaffold.dart';
import 'package:homeschooling/models/activity.dart';
import 'package:homeschooling/models/curriculum.dart';
import 'package:homeschooling/state/catalogue_providers.dart';
import 'package:homeschooling/state/curriculum_providers.dart';
import 'package:homeschooling/strings.dart';

class CatalogueScreen extends ConsumerStatefulWidget {
  const CatalogueScreen({super.key});

  @override
  ConsumerState<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends ConsumerState<CatalogueScreen> {
  final TextEditingController _query = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => ref.read(catalogueProvider.notifier).search());
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) {
        ref.read(catalogueProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CatalogueState state = ref.watch(catalogueProvider);
    final AsyncValue<List<Subject>> subjects = ref.watch(subjectsProvider);
    final AsyncValue<List<Level>> levels = ref.watch(levelsProvider);

    return ParentScaffold(
      currentPath: '/parent/catalogue',
      title: Str.catalogueTitle,
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _query,
              decoration: const InputDecoration(labelText: Str.catalogueSearchHint, prefixIcon: Icon(Icons.search)),
              onSubmitted: (String q) => ref.read(catalogueProvider.notifier).search(query: q),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                subjects.when(
                  data: (List<Subject> options) => SingleChoiceChips(
                    options: <ChipOption>[
                      const ChipOption('', Str.catalogueAllSubjects),
                      for (final Subject s in options) ChipOption(s.code, s.name),
                    ],
                    selected: state.subject,
                    onChanged: (String? v) => ref.read(catalogueProvider.notifier).search(subject: v),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (Object e, StackTrace st) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),
                levels.when(
                  data: (List<Level> options) => SingleChoiceChips(
                    options: <ChipOption>[
                      const ChipOption('', Str.catalogueAllLevels),
                      for (final Level l in options) ChipOption(l.code, l.name),
                    ],
                    selected: state.level,
                    onChanged: (String? v) => ref.read(catalogueProvider.notifier).search(level: v),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (Object e, StackTrace st) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          Expanded(
            child: state.loading
                ? const LoadingView()
                : state.error != null && state.results.isEmpty
                    ? ErrorView.fromException(state.error!, onRetry: () => ref.read(catalogueProvider.notifier).search())
                    : state.results.isEmpty
                        ? const EmptyView(message: Str.catalogueNoResults)
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.all(16),
                            itemCount: state.results.length + (state.hasMore ? 1 : 0),
                            itemBuilder: (BuildContext context, int index) {
                              if (index >= state.results.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final ActivitySummary a = state.results[index];
                              return Card(
                                child: ListTile(
                                  title: Text(a.title),
                                  subtitle: Text('${a.levelRange} · ${a.durationMin} min · ${a.subjectCode}'),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
