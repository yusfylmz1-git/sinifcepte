import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'backup_service.dart';
import 'geri_yukleme_akisi.dart';

/// "Yedekle ve geri yükle" penceresi. Ben sekmesinden ve Cepte aramasından
/// ("yedek") açılır.
///
/// Eskiden üç çizgili menüdeydi; menü kalkınca buraya taşındı (17 Ekim
/// 2026). Altındaki "%100 Gizlilik ve Güvenlik" yazısı da kalktı: yedek
/// dosyası şifresiz ve paylaşılıyor, doğrusu nerede saklanacağını söylemek.
void yedekPenceresiniAc(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: isDark ? AppColors.darkCardBackground : AppColors.lightCardBackground,
      title: Row(
        children: [
          Icon(Icons.sd_storage_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Yedekle ve geri yükle',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tüm sınıf ve öğrenci verileriniz, e-Okul fotoğrafları dahil, tek dosyaya yedeklenir. '
            'Yedek almak için internet gerekmez.',
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Dosyada öğrenci bilgileri var; güvendiğiniz bir yerde saklayın.',
            style: TextStyle(
              color: isDark ? AppColors.accent : const Color(0xFF047857),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Gezgin durumu pencere kapansa da yaşar; pencerenin bağlamı ölür.
            final nav = Navigator.of(ctx);
            nav.pop();
            nav.push(MaterialPageRoute(builder: (_) => const GeriYuklemeEkrani()));
          },
          child: const Text('Yedekten geri yükle'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(
            'Kapat',
            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
          ),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            Navigator.of(ctx).pop();

            messenger.showSnackBar(
              const SnackBar(
                content: Text('Yedek hazırlanıyor...'),
                duration: Duration(seconds: 2),
              ),
            );

            final yol = await BackupService.instance.exportDatabase();
            if (yol == null) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Yedek alınamadı. Lütfen tekrar deneyin.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
              return;
            }

            final paylasildi = await BackupService.instance.shareBackup(yol);
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  paylasildi
                      ? 'Yedek dosyası paylaşıldı. Güvenli bir yerde saklayın.'
                      : 'Yedek hazırlandı ancak paylaşılmadı.',
                ),
                backgroundColor: paylasildi ? AppColors.success : Colors.orange,
              ),
            );
          },
          icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white),
          label: const Text('Yedek Al', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}
