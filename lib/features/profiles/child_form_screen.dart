import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homeschooling/core/api_exception.dart';
import 'package:homeschooling/core/validators.dart';
import 'package:homeschooling/features/common/chip_picker.dart';
import 'package:homeschooling/features/common/state_views.dart';
import 'package:homeschooling/models/child.dart';
import 'package:homeschooling/models/curriculum.dart';
import 'package:homeschooling/state/curriculum_providers.dart';
import 'package:homeschooling/state/family_providers.dart';
import 'package:homeschooling/strings.dart';

const List<String> _kAvatars = <String>['star', 'sun', 'rocket', 'flower', 'cat', 'owl'];

/// Add (no [existing]) or edit a child profile.
class ChildFormScreen extends ConsumerStatefulWidget {
  const ChildFormScreen({super.key, this.existing});

  final Child? existing;

  @override
  ConsumerState<ChildFormScreen> createState() => _ChildFormScreenState();
}

class _ChildFormScreenState extends ConsumerState<ChildFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _birthYear;
  late final TextEditingController _goals;
  late String _avatar;
  String? _levelCode;
  late Set<String> _interests;
  late int _version;
  bool _busy = false;
  String? _apiError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final Child? c = widget.existing;
    _name = TextEditingController(text: c?.displayName ?? '');
    _birthYear = TextEditingController(text: c?.birthYear?.toString() ?? '');
    _goals = TextEditingController(text: c?.goals.join(', ') ?? '');
    _avatar = c?.avatar ?? _kAvatars.first;
    _levelCode = c?.levelCode;
    _interests = Set<String>.of(c?.interests ?? const <String>[]);
    _version = c?.version ?? 1;
  }

  @override
  void dispose() {
    _name.dispose();
    _birthYear.dispose();
    _goals.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _apiError = null;
    });
    final ChildDraft draft = ChildDraft(
      displayName: _name.text.trim(),
      avatar: _avatar,
      birthYear: _birthYear.text.trim().isEmpty ? null : int.tryParse(_birthYear.text.trim()),
      levelCode: _levelCode,
      interests: _interests.toList(),
      goals: _goals.text.split(',').map((String s) => s.trim()).where((String s) => s.isNotEmpty).toList(),
    );

    final Child? result = _isEdit
        ? await ref.read(familyProvider.notifier).updateChild(widget.existing!.id, draft, _version)
        : await ref.read(familyProvider.notifier).createChild(draft);

    if (!mounted) return;
    setState(() => _busy = false);

    if (result != null) {
      if (context.canPop()) context.pop();
      return;
    }

    final ApiException? apiError = ref.read(familyProvider).error;
    if (apiError != null && apiError.isConflict) {
      Child? fresh;
      for (final Child c in ref.read(familyProvider).children) {
        if (c.id == widget.existing?.id) {
          fresh = c;
          break;
        }
      }
      if (fresh != null) {
        final Child freshChild = fresh;
        setState(() {
          _name.text = freshChild.displayName;
          _avatar = freshChild.avatar;
          _levelCode = freshChild.levelCode;
          _interests = Set<String>.of(freshChild.interests);
          _goals.text = freshChild.goals.join(', ');
          _version = freshChild.version;
          _apiError = Str.staleProfile;
        });
      }
    } else if (apiError != null) {
      setState(() => _apiError = errorText(apiError));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Level>> levels = ref.watch(levelsProvider);
    final AsyncValue<List<Interest>> interests = ref.watch(interestsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? Str.editChild : Str.addChild)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: Str.childNameLabel),
                  validator: (String? v) => (v == null || v.trim().isEmpty) ? Str.invalidFullName : null,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  children: <Widget>[
                    for (final String avatar in _kAvatars)
                      ChoiceChip(
                        label: Text(avatar),
                        selected: _avatar == avatar,
                        onSelected: (bool _) => setState(() => _avatar = avatar),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _birthYear,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: Str.birthYearLabel),
                  validator: (String? v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return Validators.isBirthYear(v, DateTime.now().year) ? null : Str.invalidFullName;
                  },
                ),
                const SizedBox(height: 16),
                Text(Str.levelLabel, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                levels.when(
                  data: (List<Level> options) => SingleChoiceChips(
                    options: <ChipOption>[for (final Level l in options) ChipOption(l.code, l.name)],
                    selected: _levelCode,
                    onChanged: (String? v) => setState(() => _levelCode = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (Object e, StackTrace st) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                Text(Str.interestsLabel, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                interests.when(
                  data: (List<Interest> options) => ChipPicker(
                    options: <ChipOption>[for (final Interest i in options) ChipOption(i.code, i.name)],
                    selected: _interests,
                    onChanged: (Set<String> v) => setState(() => _interests = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (Object e, StackTrace st) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _goals,
                  decoration: const InputDecoration(labelText: Str.goalsLabel, helperText: 'Comma separated'),
                ),
                if (_apiError != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(_apiError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_isEdit ? Str.saveChanges : Str.createProfile),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
