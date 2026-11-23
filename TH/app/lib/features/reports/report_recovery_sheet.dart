import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';
import '../home/reading_guide.dart';

Future<void> showReportRecovery(BuildContext context) async {
  final selection = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 430),
    sheetAnimationStyle: FateMotion.dialog(context),
    builder: (_) => const _ReportRecoverySheet(),
  );
  if (selection != null && context.mounted) context.push(selection);
}

class _ReportRecoverySheet extends StatefulWidget {
  const _ReportRecoverySheet();

  @override
  State<_ReportRecoverySheet> createState() => _ReportRecoverySheetState();
}

class _ReportRecoverySheetState extends State<_ReportRecoverySheet> {
  final _code = TextEditingController();
  bool _missing = false;

  void _select(ReadingGuide guide) =>
      Navigator.pop(context, '/reading/${guide.name}?sample=1');

  void _find() {
    final code = _code.text.trim();
    final uri = Uri.tryParse(code);
    final input = uri?.hasScheme == true
        ? (Uri.tryParse(uri!.fragment)?.pathSegments.lastOrNull ??
              uri.pathSegments.lastOrNull ??
              code)
        : code;
    final match = ReadingGuide.values
        .where((guide) => guide.sampleCode == input.toUpperCase())
        .firstOrNull;
    if (match == null) {
      setState(() => _missing = true);
    } else {
      _select(match);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: .92,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.recoverReports,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: s.close,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FateCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(
                    Icons.menu_book_outlined,
                    color: goldColor,
                  ),
                  title: Text(s.recentReadings),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, '/reports'),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${s.guideWelcomeLabel} · ${s.demo}',
                style: const TextStyle(color: mutedColor, fontSize: 12),
              ),
              const SizedBox(height: 10),
              for (final guide in ReadingGuide.values.reversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FateCard(
                    padding: EdgeInsets.zero,
                    radius: 14,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: SizedBox(
                          width: 43,
                          height: 58,
                          child: GuidePortrait(guide),
                        ),
                      ),
                      title: Text(
                        '${guide.displayName(s)} · ${guide.method(s)}',
                      ),
                      subtitle: Text(
                        guide.sampleQuestion(s),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: mutedColor,
                        size: 18,
                      ),
                      onTap: () => _select(guide),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                s.reportLookupDemo,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Text(s.reportLookup, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _code,
                      maxLength: 240,
                      textInputAction: TextInputAction.search,
                      autocorrect: false,
                      onChanged: (_) =>
                          _missing ? setState(() => _missing = false) : null,
                      onSubmitted: (_) => _find(),
                      decoration: const InputDecoration(
                        hintText: 'FATE-THAI-001',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(55, 46),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: _find,
                    child: Text(s.findReport),
                  ),
                ],
              ),
              if (_missing)
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      s.reportCodeMissing,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }
}
