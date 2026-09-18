import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_fonts.dart';

/// Kurulum QR'ının altındaki TOTP secret satırı — **gizli başlar**.
///
/// ## Neden gösteriliyor
///
/// İki gerçek ihtiyaç var:
/// 1. Öğretmenin telefonu kamerasızsa ya da kamera izni yoksa kodu
///    **elle** girmek gerekiyor.
/// 2. İdarecinin yedek alması: secret kaybolursa öğretmen tahtayı hiç
///    açamaz ve yeni kayıt oluşturmak gerekir.
///
/// ## Neden gizli başlıyor
///
/// Aynı diyalogda "ekran görüntüsü alıp paylaşmayın" uyarısı var. Sır
/// sürekli açık dursa o uyarıyla çelişirdi ve omuz üstü okuma
/// kolaylaşırdı. Bir dokunuş, gösterme kararını idarecinin eline
/// veriyor.
///
/// ## Neden ayrı dosyada
///
/// Ekran dosyası Firestore ve güvenli depo platform kanallarını
/// istiyor; widget testi için ağır sahtelik gerekirdi. Bu widget ise
/// yalnızca metin alıyor, yani kendi başına test edilebiliyor —
/// gizlilik kuralı da öyle kilitleniyor.
class SecretSatiri extends StatefulWidget {
  const SecretSatiri({super.key, required this.secret});

  final String secret;

  @override
  State<SecretSatiri> createState() => _SecretSatiriState();
}

class _SecretSatiriState extends State<SecretSatiri> {
  bool _acik = false;

  @override
  Widget build(BuildContext context) {
    if (widget.secret.isEmpty) {
      // Sessiz boş satır bırakmak, idareciye "kod yok mu, hata mı var"
      // diye sorduruyordu.
      return Text(
        'Bu öğretmen için açma kodu tanımlı değil.',
        textAlign: TextAlign.center,
        style: AppFonts.outfit(fontSize: 11, color: Colors.grey),
      );
    }

    if (!_acik) {
      return TextButton.icon(
        onPressed: () => setState(() => _acik = true),
        icon: const Icon(Icons.visibility_outlined, size: 16),
        label: Text(
          'Kodu yazıyla göster',
          style: AppFonts.outfit(fontSize: 12),
        ),
      );
    }

    return Column(
      children: [
        SelectableText(
          widget.secret,
          textAlign: TextAlign.center,
          style: AppFonts.outfit(
            fontSize: 11.5,
            height: 1.5,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: widget.secret));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Kod kopyalandı. Yapıştırdıktan sonra panoyu '
                      'temizleyin.',
                      style: AppFonts.outfit(fontSize: 12.5),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 15),
              label: Text('Kopyala', style: AppFonts.outfit(fontSize: 11.5)),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _acik = false),
              icon: const Icon(Icons.visibility_off_outlined, size: 15),
              label: Text('Gizle', style: AppFonts.outfit(fontSize: 11.5)),
            ),
          ],
        ),
      ],
    );
  }
}
