import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/class_provider.dart';
import 'class_list_screen.dart';
import 'student_list_screen.dart';

/// Alt çubuktaki "Sınıfım" sekmesi: rehberlik sınıfı doğrudan açılır
/// (öğrenci listesi ve Katılım · Devamsızlık · Oturma · Veliler · Evrak
/// şeridi). Kullanıcı kararı (26 Ekim 2026).
///
/// Diğer sınıflar Özet'teki "Sınıflar" düğmesinden açılır. Rehberlik
/// sınıfı olmayan (branş) öğretmene sınıf listesi gösterilir; liste
/// rehberlik sınıfının nasıl seçileceğini söyler.
class SinifimSekmesi extends ConsumerWidget {
  const SinifimSekmesi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liste = ref.watch(classListProvider);
    final rehberlik = ref.watch(homeroomClassProvider);

    if (rehberlik != null) {
      // Başka sınıf rehberlik yapılırsa sayfa o sınıfla baştan kurulur.
      return StudentListScreen(
        key: ValueKey('sinifim_${rehberlik.id}'),
        classModel: rehberlik,
      );
    }
    // Hata durumunu sınıf listesi kendisi gösterir.
    if (liste.isLoading && !liste.hasValue) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    return const ClassListScreen();
  }
}
