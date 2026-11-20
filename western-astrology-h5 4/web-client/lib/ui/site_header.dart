import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/controller.dart';
import 'jy_components.dart';
import 'theme.dart';

class SiteHeader extends StatelessWidget {
  const SiteHeader({this.showLanguages = true, super.key});
  final bool showLanguages;

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
    Widget language(String value, String label) => TextButton(
      onPressed: h5.languageLoading
          ? null
          : () => _language(context, h5, value),
      style: TextButton.styleFrom(
        minimumSize: const Size(40, 44),
        padding: const EdgeInsets.symmetric(horizontal: 3),
        foregroundColor: h5.language == value ? gold : lavender,
        backgroundColor: Colors.transparent,
        textStyle: TextStyle(
          fontFamily: h5FontFamily,
          fontFamilyFallback: h5FontFallback,
          fontSize: 12.3,
          fontWeight: h5.language == value ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      child: Text(label),
    );
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 21),
      color: const Color(0xFF110B1F),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => _goHome(context, h5),
            child: const FateBrand(),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showLanguages) ...[
                language('th', 'TH'),
                const ExcludeSemantics(
                  child: Text(
                    '/',
                    style: TextStyle(fontSize: 12.3, color: lavender),
                  ),
                ),
                language('zh', '中文'),
              ],
              HomeArrow(h5: h5),
            ],
          ),
        ],
      ),
    );
  }
}

void _goHome(BuildContext context, H5Controller h5, [VoidCallback? onLeaving]) {
  final router = GoRouter.of(context);
  onLeaving?.call();
  h5.returnToWelcome();
  router.go('/?lang=${h5.language}');
}

class HomeArrow extends StatelessWidget {
  const HomeArrow({required this.h5, this.onLeaving, super.key});

  final H5Controller h5;
  final VoidCallback? onLeaving;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: h5.copy.t('jy', 'checkout.back'),
    onPressed: () => _goHome(context, h5, onLeaving),
    icon: const Icon(Icons.arrow_back, color: gold, size: 20),
  );
}
