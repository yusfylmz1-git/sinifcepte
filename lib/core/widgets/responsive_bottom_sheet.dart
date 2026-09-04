import 'package:flutter/material.dart';

/// SınıfCepte - Klavyeye Duyarlı ve Akıcı Responsive Bottom Sheet (60-120 FPS Performans)
class ResponsiveBottomSheet {
  ResponsiveBottomSheet._();

  static Future<T?> show<T>({
    required BuildContext context,
    Widget? child,
    Widget Function(BuildContext context, StateSetter setState)? builder,
    String? title,
    bool isDismissible = true,
    double maxFactor = 0.88,
    Widget? bottomAction,
    Widget Function(BuildContext context, StateSetter setState)? bottomActionBuilder,
  }) {
    assert(
      child != null || builder != null,
      'child veya builder parametrelerinden en az biri sağlanmalıdır.',
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: isDismissible,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;

        Widget buildContent(StateSetter? setStateModal) {
          final content = builder != null ? builder(ctx, setStateModal!) : child!;
          final footer = bottomActionBuilder != null
              ? bottomActionBuilder(ctx, setStateModal!)
              : bottomAction;

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * maxFactor,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sürükleme Tutacağı (Drag Handle)
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (title != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const Divider(height: 16, thickness: 0.6),
                ],
                // Esnek İçerik (Scrollable Body)
                Flexible(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 10, 20, footer != null ? 10 : 24),
                    child: content,
                  ),
                ),
                // Sabit Alt Aksiyon Butonu (Pinned Bottom Action)
                if (footer != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: isDark ? Colors.white12 : Colors.grey.shade200,
                          width: 0.8,
                        ),
                      ),
                    ),
                    child: footer,
                  ),
                ],
              ],
            ),
          );
        }

        return AnimatedPadding(
          padding: EdgeInsets.only(bottom: bottomInset),
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutQuad,
          child: (builder != null || bottomActionBuilder != null)
              ? StatefulBuilder(
                  builder: (ctx, setStateModal) => buildContent(setStateModal),
                )
              : buildContent(null),
        );
      },
    );
  }
}
