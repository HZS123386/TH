import 'package:flutter/material.dart';
import '../app/controller.dart';
import '../core/models.dart';
import '../ui/theme.dart';

class PrivacyPolicy extends StatefulWidget {
  const PrivacyPolicy({required this.policy, super.key});
  final Json policy;

  @override
  State<PrivacyPolicy> createState() => _PrivacyPolicyState();
}

class _PrivacyPolicyState extends State<PrivacyPolicy> {
  final _sectionKeys = <String, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    final h5 = H5Scope.of(context), policy = widget.policy;
    final labels = object(policy['labels']);
    final profile = object(policy['controller']);
    String label(String key) => text(labels[key]);
    final sections = objects(policy['sections']);
    final complete = [
      'controller_name',
      'controller_address',
      'contact_email',
      'effective_date',
    ].every((key) => text(profile[key]).trim().isNotEmpty);
    return Column(
      key: ValueKey('privacy-content-${h5.language}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            Text(
              '${label('version')} ${text(policy['version'])}',
              style: const TextStyle(color: gold),
            ),
            Text(
              '${label('updated')}: ${text(policy['updated'])}',
              style: const TextStyle(color: lavender),
            ),
          ],
        ),
        _paragraph(
          '${label('effective')}: ${text(profile['effective_date']).isEmpty ? label('pending') : text(profile['effective_date'])}',
          color: lavender,
        ),
        if (!complete) _notice(label('reviewNote')),
        const SizedBox(height: 12),
        for (final field in [
          ('controller', 'controller_name'),
          ('address', 'controller_address'),
          ('contact', 'contact_email'),
        ]) ...[
          Text(
            label(field.$1),
            style: const TextStyle(color: lavender, fontSize: 12),
          ),
          _paragraph(
            text(profile[field.$2]).isEmpty
                ? label('pending')
                : text(profile[field.$2]),
            color: gold,
          ),
        ],
        if (text(profile['translation_notice']).isNotEmpty)
          _paragraph(text(profile['translation_notice']), color: lavender),
        _paragraph(label('contactHint'), color: lavender),
        const Divider(height: 32),
        _heading(label('overview')),
        for (final item in policy['summary'] as List) _bullet('$item'),
        const SizedBox(height: 12),
        _heading(label('contents')),
        for (final section in sections)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                final target =
                    _sectionKeys[text(section['id'])]?.currentContext;
                if (target != null) {
                  Scrollable.ensureVisible(
                    target,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 280),
                    alignment: 0.05,
                  );
                }
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.centerLeft,
              ),
              child: Text(
                text(section['title']),
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          ),
        for (final section in sections)
          Column(
            key: _sectionKeys.putIfAbsent(text(section['id']), GlobalKey.new),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(height: 36),
              _heading(text(section['title'])),
              for (final paragraph in section['paragraphs'] as List? ?? [])
                _paragraph('$paragraph'),
              for (final item in section['bullets'] as List? ?? [])
                _bullet('$item'),
              for (final link in objects(section['links']))
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      final uri = Uri.tryParse(text(link['url']));
                      if (uri != null &&
                          uri.scheme == 'https' &&
                          uri.host.isNotEmpty) {
                        h5.browser.openPage(uri.toString());
                      }
                    },
                    icon: const Icon(Icons.open_in_new, size: 15),
                    label: Text(
                      text(link['label']),
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _heading(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Semantics(
      header: true,
      child: Text(
        value,
        style: const TextStyle(
          color: gold,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
      ),
    ),
  );

  Widget _paragraph(String value, {Color color = cream}) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 14),
    child: SelectableText(
      value,
      semanticsLabel: value,
      style: TextStyle(color: color, fontSize: 14, height: 1.8),
    ),
  );

  Widget _bullet(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 9, right: 10),
          child: Icon(Icons.circle, color: gold, size: 5),
        ),
        Expanded(
          child: SelectableText(
            value,
            semanticsLabel: value,
            style: const TextStyle(fontSize: 14, height: 1.8),
          ),
        ),
      ],
    ),
  );

  Widget _notice(String value) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: gold.withValues(alpha: 0.07),
      border: Border.all(color: gold.withValues(alpha: 0.35)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: SelectableText(
      value,
      semanticsLabel: value,
      style: const TextStyle(color: gold, fontSize: 13, height: 1.7),
    ),
  );
}
