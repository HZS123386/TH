import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/controller.dart';
import '../app/languages.dart';
import 'jy_components.dart';
import 'theme.dart';

class SiteHeader extends StatelessWidget {
  const SiteHeader({
    this.showLanguages = true,
    this.showHomeArrow = true,
    super.key,
  });
  final bool showLanguages, showHomeArrow;

  Future<void> _language(
    BuildContext context,
    H5Controller h5,
    String language,
  ) async {
    final changed = await h5.changeLanguage(language);
    if (!context.mounted) return;
    if (!changed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(h5.copy.t('ui', 'network'))));
      return;
    }
    final uri = GoRouter.of(context).routeInformationProvider.value.uri;
    context.replace(
      Uri(
        path: uri.path,
        queryParameters: {...uri.queryParameters, 'lang': language},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h5 = H5Scope.of(context);
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 21),
      color: const Color(0xFF110B1F),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(onTap: () => _goHome(context, h5), child: const FateBrand()),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showLanguages)
                PopupMenuButton<String>(
                  key: const ValueKey('language-menu'),
                  tooltip: h5.copy.t('jy', 'language'),
                  enabled: !h5.languageLoading,
                  initialValue: h5.language,
                  popUpAnimationStyle: const AnimationStyle(
                    duration: Duration(milliseconds: 120),
                    reverseDuration: Duration(milliseconds: 80),
                  ),
                  position: PopupMenuPosition.under,
                  color: panel,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: line),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 180,
                    maxWidth: 240,
                  ),
                  onSelected: (value) => _language(context, h5, value),
                  itemBuilder: (_) => [
                    for (final option in h5Languages)
                      PopupMenuItem(
                        key: ValueKey('language-option-${option.$1}'),
                        value: option.$1,
                        child: Row(
                          children: [
                            Expanded(child: Text(option.$2)),
                            if (option.$1 == h5.language)
                              const Icon(Icons.check, color: gold, size: 18),
                          ],
                        ),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (h5.languageLoading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              color: gold,
                            ),
                          )
                        else
                          const Icon(
                            Icons.language_outlined,
                            size: 20,
                            color: gold,
                          ),
                        const SizedBox(width: 7),
                        Text(
                          h5Languages
                              .firstWhere((item) => item.$1 == h5.language)
                              .$2,
                          style: const TextStyle(fontSize: 12.3, color: gold),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: gold,
                        ),
                      ],
                    ),
                  ),
                ),
              if (showHomeArrow) HomeArrow(h5: h5),
            ],
          ),
        ],
      ),
    );
  }
}

void _goHome(BuildContext context, H5Controller h5) {
  final router = GoRouter.of(context);
  h5.browser.writeSetting('active-preview', '', session: true);
  router.go('/?lang=${h5.language}');
}

class HomeArrow extends StatelessWidget {
  const HomeArrow({required this.h5, super.key});

  final H5Controller h5;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: h5.copy.t('jy', 'checkout.back'),
    onPressed: () => _goHome(context, h5),
    icon: const Icon(Icons.arrow_back, color: gold, size: 20),
  );
}
