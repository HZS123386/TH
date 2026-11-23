import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';
import 'companion_view_model.dart';
import 'guardian.dart';

class BondPage extends StatefulWidget {
  const BondPage({super.key});
  @override
  State<BondPage> createState() => _BondPageState();
}

class _BondPageState extends State<BondPage> {
  bool _requested = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) DependencyScope.of(context).companion.load(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([d.companion, d.session]),
      builder: (context, _) {
        final model = d.companion;
        final recent = model.history
            .where((row) => row['role'] == 'user')
            .toList()
            .reversed
            .take(3);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            PageHeading(s.bondTitle, s.bondIntro, icon: Icons.favorite_border),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final guardian in Guardian.values)
                    SizedBox(
                      width: (constraints.maxWidth - 12) / 2,
                      child: FateCard(
                        padding: EdgeInsets.zero,
                        accent: guardian.color,
                        onTap: () => openGuardian(context, guardian: guardian),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  GuardianAvatar(
                                    guardian,
                                    size: 48,
                                    hero: true,
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.north_east,
                                    size: 16,
                                    color: guardian.color,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                guardian.title(s),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                model.conversations(guardian) == 0
                                    ? s.bondNew
                                    : model.conversations(guardian) < 5
                                    ? s.bondFamiliar
                                    : s.bondGrowing,
                                style: TextStyle(
                                  color: guardian.color,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 12),
                              AnimatedSwitcher(
                                duration: FateMotion.duration(
                                  context,
                                  FateMotion.change,
                                ),
                                child: Text(
                                  '${model.conversations(guardian)} ${s.bondCount}',
                                  key: ValueKey(model.conversations(guardian)),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: mutedColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ExcludeSemantics(
                                child: Row(
                                  children: [
                                    for (var step = 0; step < 3; step++)
                                      Expanded(
                                        child: AnimatedContainer(
                                          duration: FateMotion.duration(
                                            context,
                                            FateMotion.change,
                                          ),
                                          height: 3,
                                          margin: EdgeInsets.only(
                                            right: step == 2 ? 0 : 5,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                            color:
                                                step <=
                                                    (model.conversations(
                                                              guardian,
                                                            ) ==
                                                            0
                                                        ? 0
                                                        : model.conversations(
                                                                guardian,
                                                              ) <
                                                              5
                                                        ? 1
                                                        : 2)
                                                ? guardian.color.withValues(
                                                    alpha: .75,
                                                  )
                                                : lineColor,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              s.bondRecentNote,
              style: const TextStyle(
                fontSize: 10,
                color: mutedColor,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 24),
            FateCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline, color: goldColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.profileSelf,
                          style: const TextStyle(fontSize: 17),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/birth'),
                        child: Text(s.editBirth),
                      ),
                    ],
                  ),
                  Text(
                    d.session.displayName ?? s.guest,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    d.session.profile == null
                        ? s.chatProfileNeeded
                        : '${d.session.profile!.date} · ${d.session.profile!.place}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.bondMemory,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                IconButton(
                  tooltip: s.addMemory,
                  onPressed: model.sending ? null : () => _edit(model),
                  icon: const Icon(Icons.add, color: goldColor),
                ),
              ],
            ),
            Text(s.memoryHelp, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            if (model.loading) const LinearProgressIndicator(minHeight: 2),
            if (model.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextButton.icon(
                  onPressed: () => model.load(force: true),
                  icon: const Icon(Icons.refresh),
                  label: Text(s.connection),
                ),
              ),
            AnimatedSize(
              alignment: Alignment.topCenter,
              duration: FateMotion.duration(context, FateMotion.change),
              curve: Curves.easeOutCubic,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!model.loading && model.memories.isEmpty)
                    FateCard(
                      child: Column(
                        children: [
                          const FateEmblem(Icons.bookmark_border, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            s.memoryEmpty,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: model.sending
                                ? null
                                : () => _edit(model),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(s.addMemory),
                          ),
                        ],
                      ),
                    ),
                  for (final row in model.memories) ...[
                    FateEntrance(
                      key: ValueKey(row['id']),
                      child: FateCard(
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: FateMotion.duration(
                                  context,
                                  FateMotion.change,
                                ),
                                child: Text(
                                  row['content'] as String? ?? '',
                                  key: ValueKey(row['content']),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: s.editMemory,
                              onPressed: model.sending
                                  ? null
                                  : () => _edit(model, row: row),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                            ),
                            IconButton(
                              tooltip: s.remove,
                              onPressed: model.sending
                                  ? null
                                  : () => _remove(model, row),
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(s.recentConversations, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            FateCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (recent.isEmpty)
                    Text(
                      s.noConversations,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  for (final row in recent)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        row['content'] as String? ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    s.sharedHistory,
                    style: const TextStyle(fontSize: 10, color: mutedColor),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _edit(CompanionViewModel model, {Map<String, dynamic>? row}) =>
      showDialog<void>(
        context: context,
        animationStyle: FateMotion.dialog(context),
        builder: (_) => _MemoryEditor(model: model, row: row),
      );

  Future<void> _remove(
    CompanionViewModel model,
    Map<String, dynamic> row,
  ) async {
    final s = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: FateMotion.dialog(context),
      builder: (context) => AlertDialog(
        content: Text(s.memoryDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.remove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await model.deleteMemory(row['id'] as String);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.error)));
      }
    }
  }
}

class _MemoryEditor extends StatefulWidget {
  const _MemoryEditor({required this.model, this.row});
  final CompanionViewModel model;
  final Map<String, dynamic>? row;
  @override
  State<_MemoryEditor> createState() => _MemoryEditorState();
}

class _MemoryEditorState extends State<_MemoryEditor> {
  late final _input = TextEditingController(
    text: widget.row?['content'] as String? ?? '',
  );
  bool _saving = false, _error = false;
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(s.bondMemory),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _input,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            enabled: !_saving,
            decoration: InputDecoration(hintText: s.memoryHint),
          ),
          if (_error)
            Text(
              s.error,
              style: const TextStyle(color: Color(0xFFF1B5B5), fontSize: 12),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        TextButton(
          onPressed: _saving
              ? null
              : () async {
                  if (_input.text.trim().isEmpty) return;
                  setState(() {
                    _saving = true;
                    _error = false;
                  });
                  try {
                    await widget.model.saveMemory(
                      _input.text,
                      id: widget.row?['id'] as String?,
                    );
                    if (context.mounted) Navigator.pop(context);
                  } catch (_) {
                    if (mounted) {
                      setState(() {
                        _saving = false;
                        _error = true;
                      });
                    }
                  }
                },
          child: AnimatedSwitcher(
            duration: FateMotion.duration(context, FateMotion.settle),
            child: _saving
                ? const SizedBox(
                    key: ValueKey('saving'),
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(s.saveMemory, key: const ValueKey('save')),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }
}
