import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/controller.dart';
import '../core/models.dart';
import '../ui/theme.dart';

class SupportContent extends StatelessWidget {
  const SupportContent({required this.content, super.key});
  final Json content;

  @override
  Widget build(BuildContext context) {
    final h5 = H5Scope.of(context);
    final labels = object(content['labels']),
        controller = object(content['controller']);
    String label(String key) => text(labels[key]);
    final email = text(controller['contact_email']);
    return Column(
      key: ValueKey('support-content-${h5.language}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _paragraph(text(content['intro'])),
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: gold.withValues(alpha: 0.07),
            border: Border.all(color: gold.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label('contactTitle'),
                style: const TextStyle(
                  fontSize: 16,
                  color: gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                email.isEmpty ? label('noContact') : email,
                semanticsLabel: email.isEmpty ? label('noContact') : email,
                key: const ValueKey('support-email'),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const ValueKey('support-compose-email'),
                onPressed: email.isEmpty
                    ? null
                    : () => h5.browser.openPage(
                        Uri(
                          scheme: 'mailto',
                          path: email,
                          query:
                              'subject=${Uri.encodeComponent(label('emailSubject'))}',
                        ).toString(),
                      ),
                icon: const Icon(Icons.mail_outline, size: 19),
                label: Text(label('emailAction')),
              ),
            ],
          ),
        ),
        Text(
          label('operator'),
          style: const TextStyle(fontSize: 12, color: lavender),
        ),
        _paragraph(text(controller['controller_name'])),
        Text(
          label('address'),
          style: const TextStyle(fontSize: 12, color: lavender),
        ),
        _paragraph(text(controller['controller_address']), color: lavender),
        if (text(controller['translation_notice']).isNotEmpty)
          _paragraph(text(controller['translation_notice']), color: lavender),
        const Divider(height: 28),
        _heading(label('requestTitle')),
        for (final item in content['requestDetails'] as List? ?? [])
          _paragraph('• $item'),
        const SizedBox(height: 8),
        _heading(label('faqTitle')),
        for (final section in objects(content['sections']))
          ExpansionTile(
            key: ValueKey('support-faq-${text(section['id'])}'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            shape: const Border(bottom: BorderSide(color: line)),
            collapsedShape: const Border(bottom: BorderSide(color: line)),
            iconColor: gold,
            collapsedIconColor: gold,
            title: Text(
              text(section['title']),
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
            children: [
              for (final paragraph in section['paragraphs'] as List? ?? [])
                _paragraph('$paragraph', color: lavender),
            ],
          ),
        const SizedBox(height: 24),
        _paragraph(label('privacyHint'), color: lavender),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('support-privacy-link'),
            onPressed: () => context.go('/privacy.html?lang=${h5.language}'),
            icon: const Icon(Icons.privacy_tip_outlined, size: 18),
            label: Text(label('privacyLink')),
          ),
        ),
      ],
    );
  }

  Widget _heading(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      header: true,
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 17,
          color: gold,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
      ),
    ),
  );

  Widget _paragraph(String value, {Color color = cream}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: SelectableText(
      value,
      semanticsLabel: value,
      style: TextStyle(fontSize: 14, height: 1.8, color: color),
    ),
  );
}
