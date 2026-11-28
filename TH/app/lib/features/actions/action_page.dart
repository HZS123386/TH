import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/dependencies.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';
import '../chart/chart_view_model.dart' show newRequestKey;
import 'action_ledger.dart';
import 'action_offering.dart';

const actionColor = Color(0xFFADBF9A);

enum _Filter { all, pending, ready, reviewed }

class ActionPage extends StatefulWidget {
  const ActionPage({super.key});

  @override
  State<ActionPage> createState() => _ActionPageState();
}

class _ActionPageState extends State<ActionPage> {
  _Filter _filter = _Filter.all;
  final _scroll = ScrollController();
  final _completing = <String>{};

  void _revealOffering() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || _scroll.offset <= 0) return;
      if (FateMotion.reduced(context)) {
        _scroll.jumpTo(0);
      } else {
        unawaited(
          _scroll.animateTo(
            0,
            duration: FateMotion.page,
            curve: Curves.easeOutCubic,
          ),
        );
      }
    });
  }

  Future<void> _complete(
    AppDependencies d,
    String owner,
    ActionPlan plan,
  ) async {
    if (d.session.owner != owner || _completing.contains(plan.id)) return;
    setState(() => _completing.add(plan.id));
    try {
      await d.actions.complete(owner, plan.id);
      if (mounted &&
          d.session.owner == owner &&
          d.actions
              .plans(owner)
              .any((item) => item.id == plan.id && item.done)) {
        FateMotion.selectionFeedback();
        final s = AppLocalizations.of(context);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(s.actionCompleted)));
      }
    } catch (_) {
      if (mounted) {
        final s = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.error)));
      }
    } finally {
      if (mounted) setState(() => _completing.remove(plan.id));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([d.actions, d.session]),
      builder: (context, _) {
        final owner = d.session.owner;
        final plans = d.actions.plans(owner);
        final day = d.actions.weekday(owner);
        final today = DateUtils.dateOnly(DateTime.now());
        final completed = plans.where((plan) => plan.done).length;
        final ready = plans.where((plan) => plan.readyOn(today)).length;
        final filtered = plans
            .where(
              (plan) => switch (_filter) {
                _Filter.all => true,
                _Filter.pending => !plan.done,
                _Filter.ready => plan.readyOn(today),
                _Filter.reviewed => plan.reviewed,
              },
            )
            .toList();
        final dayNumber =
            DateTime.utc(
              today.year,
              today.month,
              today.day,
            ).millisecondsSinceEpoch ~/
            Duration.millisecondsPerDay;
        final suggestionId = 'daily-$dayNumber';
        final suggestions = [
          s.careAction,
          s.familyAction,
          s.actionSuggestionThanks,
          s.actionSuggestionCheckIn,
          s.actionSuggestionShare,
        ];
        final suggested = Random(dayNumber).nextInt(suggestions.length);
        final dailyPlan = plans
            .where((plan) => plan.id == suggestionId)
            .firstOrNull;
        return CustomScrollView(
          key: const PageStorageKey('action-scroll'),
          controller: _scroll,
          slivers: [
            // Keep the offering mounted when an action is completed farther down the list.
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              sliver: SliverToBoxAdapter(
                child: FateEntrance(
                  child: ActionOfferingCard(
                    key: ValueKey(owner),
                    energy: d.actions.energyFor(owner),
                    onEnergyGained: _revealOffering,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList.list(
                children: [
                  FateCard(
                    accent: actionColor,
                    radius: 16,
                    padding: const EdgeInsets.all(13),
                    onTap: () => showActionEditor(
                      context,
                      plan: dailyPlan,
                      initialId: suggestionId,
                      initialTitle: suggestions[suggested],
                      family: suggested == 1,
                    ),
                    child: Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: actionColor.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(
                              Icons.eco_outlined,
                              color: actionColor,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.actionDailySuggestion,
                                style: const TextStyle(
                                  color: actionColor,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                dailyPlan?.title ?? suggestions[suggested],
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (dailyPlan == null)
                                Text(
                                  s.actionUseSuggestion,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          dailyPlan?.done == true
                              ? Icons.check_circle_outline
                              : dailyPlan == null
                              ? Icons.add
                              : Icons.chevron_right,
                          color: actionColor,
                          size: 21,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  OutlinedButton.icon(
                    onPressed: () => showActionEditor(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(s.actionCustomPlan),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    s.actionLedger,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 3,
                    children: [
                      for (final (count, label) in [
                        (plans.length - completed, s.actionPending),
                        (completed, s.actionDone),
                        (ready, s.actionReady),
                      ])
                        Text(
                          '$count $label',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final (filter, label) in [
                        (_Filter.all, s.allItems),
                        (_Filter.pending, s.actionTodo),
                        (_Filter.ready, s.actionReviewAvailable),
                        (_Filter.reviewed, s.actionReviewed),
                      ])
                        FilterChip(
                          selected: _filter == filter,
                          showCheckmark: false,
                          label: Text(
                            label,
                            style: const TextStyle(fontSize: 11),
                          ),
                          onSelected: (_) {
                            if (_filter == filter) return;
                            FateMotion.selectionFeedback();
                            setState(() => _filter = filter);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (filtered.isEmpty)
                    FateCard(
                      radius: 16,
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        s.noActionPlan,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  for (final plan in filtered)
                    Padding(
                      key: ValueKey(plan.id),
                      padding: const EdgeInsets.only(bottom: 9),
                      child: FateCard(
                        radius: 16,
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          leading: Icon(
                            plan.done
                                ? Icons.check_circle_outline
                                : Icons.eco_outlined,
                            color: actionColor,
                          ),
                          title: Text(plan.title),
                          subtitle: Text(
                            '${MaterialLocalizations.of(context).formatCompactDate(plan.date)} · ${plan.reviewed
                                ? s.actionReviewed
                                : plan.readyOn(today)
                                ? s.actionReviewAvailable
                                : plan.done
                                ? s.actionCompleted
                                : s.actionTodo}',
                          ),
                          trailing: plan.done
                              ? const Icon(Icons.chevron_right)
                              : FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 42),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed: _completing.contains(plan.id)
                                      ? null
                                      : () => _complete(d, owner, plan),
                                  child: Text(s.actionCompleteNow),
                                ),
                          onTap: () => showActionEditor(context, plan: plan),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  FateCard(
                    radius: 16,
                    padding: const EdgeInsets.fromLTRB(15, 13, 15, 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.weeklyMoment,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          s.weeklyMomentNote,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Divider(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                day == null
                                    ? s.myWeeklyDay
                                    : '${s.myWeeklyDay} · ${_weekday(context, day)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _chooseDay(context, d, owner, day),
                              child: Text(
                                s.arrangeDay,
                                style: const TextStyle(color: actionColor),
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () => showActionEditor(
                            context,
                            initialTitle: s.familyAction,
                            family: true,
                          ),
                          icon: const Icon(Icons.favorite_outline, size: 17),
                          label: Text(s.chooseFamilyAction),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _chooseDay(
    BuildContext context,
    AppDependencies d,
    String owner,
    int? current,
  ) async {
    final s = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 430),
      sheetAnimationStyle: FateMotion.dialog(context),
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var day = 1; day <= 7; day++)
              ListTile(
                title: Text(_weekday(sheet, day)),
                trailing: current == day
                    ? const Icon(Icons.check, color: actionColor)
                    : null,
                onTap: () => Navigator.pop(sheet, day),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted || selected == null || d.session.owner != owner) {
      return;
    }
    try {
      await d.actions.setWeekday(owner, selected);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.error)));
      }
    }
  }
}

String _weekday(BuildContext context, int day) => DateFormat.EEEE(
  Localizations.localeOf(context).languageCode,
).format(DateTime(2024, 1, day));

Future<void> showActionEditor(
  BuildContext context, {
  ActionPlan? plan,
  String? initialTitle,
  String? initialId,
  bool family = false,
}) {
  final d = DependencyScope.of(context);
  final owner = d.session.owner;
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 430),
    sheetAnimationStyle: FateMotion.dialog(context),
    builder: (_) => _ActionEditor(
      dependencies: d,
      owner: owner,
      plan: plan,
      initialTitle: initialTitle,
      initialId: initialId,
      family: family,
    ),
  );
}

class _ActionEditor extends StatefulWidget {
  const _ActionEditor({
    required this.dependencies,
    required this.owner,
    required this.family,
    this.plan,
    this.initialTitle,
    this.initialId,
  });
  final AppDependencies dependencies;
  final String owner;
  final bool family;
  final ActionPlan? plan;
  final String? initialTitle, initialId;

  @override
  State<_ActionEditor> createState() => _ActionEditorState();
}

class _ActionEditorState extends State<_ActionEditor> {
  final _form = GlobalKey<FormState>();
  late final _id = widget.plan?.id ?? widget.initialId ?? newRequestKey();
  late final _title = TextEditingController(
    text: widget.plan?.title ?? widget.initialTitle,
  );
  late final _notes = TextEditingController(text: widget.plan?.notes);
  late final _reflection = TextEditingController(text: widget.plan?.reflection);
  late var _category = widget.plan?.category ?? 0;
  late var _beneficiary = widget.plan?.beneficiary ?? (widget.family ? 2 : 1);
  late var _date = widget.plan?.date ?? DateUtils.dateOnly(DateTime.now());
  late var _review = widget.plan?.reviewDate ?? _date;
  late var _done = widget.plan?.done ?? false;
  late var _reviewed = widget.plan?.reviewed ?? false;
  bool _saving = false, _error = false;

  Future<void> _pickDate({required bool review}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: review ? _review : _date,
      firstDate: review ? _date : DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (review) {
        if (_review != selected) _reviewed = false;
        _review = selected;
      } else {
        _date = selected;
        if (_review.isBefore(_date)) {
          _review = _date;
          _reviewed = false;
        }
      }
    });
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (widget.owner != widget.dependencies.session.owner) {
      setState(() => _error = true);
      return;
    }
    setState(() {
      _saving = true;
      _error = false;
    });
    try {
      await widget.dependencies.actions.save(
        widget.owner,
        ActionPlan(
          id: _id,
          title: _title.text.trim(),
          category: _category,
          beneficiary: _beneficiary,
          date: _date,
          reviewDate: _review,
          notes: _notes.text.trim(),
          reflection: _reflection.text.trim(),
          done: _done,
          reviewed: _done && _reviewed,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context),
        material = MaterialLocalizations.of(context);
    final reflectionAvailable =
        _done && !_review.isAfter(DateUtils.dateOnly(DateTime.now()));
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _form,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.actionRecord,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: s.close,
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (_reviewed)
                Text(
                  s.actionReviewed,
                  style: const TextStyle(color: actionColor),
                ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _title,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: s.actionTitle,
                  counterText: '',
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? s.actionTitle : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _category,
                isExpanded: true,
                decoration: InputDecoration(labelText: s.actionCategory),
                items: [
                  DropdownMenuItem(value: 0, child: Text(s.actionTypeService)),
                  DropdownMenuItem(value: 1, child: Text(s.actionTypePractice)),
                ],
                onChanged: (value) => setState(() => _category = value ?? 0),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _beneficiary,
                decoration: InputDecoration(labelText: s.beneficiary),
                items: [
                  DropdownMenuItem(value: 0, child: Text(s.forSelf)),
                  DropdownMenuItem(value: 1, child: Text(s.forOthers)),
                  DropdownMenuItem(value: 2, child: Text(s.forFamily)),
                ],
                onChanged: (value) => setState(() => _beneficiary = value ?? 1),
              ),
              const SizedBox(height: 10),
              Text(
                '${s.recordMethod} · ${s.recordOnDevice}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (review, label, date) in [
                    (false, s.actionDate, _date),
                    (true, s.reviewDate, _review),
                  ]) ...[
                    if (review) const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            label,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 5),
                          OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => _pickDate(review: review),
                            child: Text(
                              material.formatCompactDate(date),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notes,
                maxLines: 3,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: s.actionNotes,
                  counterText: '',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.actionCompleted),
                value: _done,
                onChanged: (value) => setState(() {
                  _done = value ?? false;
                  if (!_done) _reviewed = false;
                }),
              ),
              Text(
                s.actionReview,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 7),
              TextField(
                controller: _reflection,
                maxLines: 3,
                maxLength: 1000,
                enabled: reflectionAvailable,
                decoration: InputDecoration(
                  labelText: s.questionProgress,
                  counterText: '',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.actionReviewed),
                value: _reviewed,
                onChanged: reflectionAvailable
                    ? (value) => setState(() => _reviewed = value ?? false)
                    : null,
              ),
              if (_error)
                Text(
                  s.error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(MaterialLocalizations.of(context).saveButtonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _reflection.dispose();
    super.dispose();
  }
}
