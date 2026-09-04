import 'package:flutter/material.dart';

import '../../../core/support/support_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../shared/widgets/custom_app_bar.dart';

/// Gösterilecek hukuki belge.
enum LegalDocumentKind { terms, privacy, faq }

/// Kullanım Koşulları, Gizlilik Politikası ve SSS ekranı.
///
/// ## Neden gerekli
/// Bu belgeler uygulamanın **hiçbir yerinde görünmüyordu**. Play Store
/// gizlilik politikasını zorunlu tutuyor; KVKK ise kullanıcının verisinin
/// ne olduğunu okuyabilmesini gerektiriyor.
///
/// ## Gizlilik metni neden yeniden yazıldı
/// Veli profilindeki eski metin *"öğrenci bilgilerini öğretmenin cihazında
/// saklar; bu veriler buluta aktarılmaz"* diyordu. **Bu doğru değildi:**
/// `studentName` en az üç koleksiyonda buluta gidiyor (veli bağlantıları,
/// mesajlar, durum bildirimleri). Yanlış beyan hukuki risk taşır.
///
/// Aşağıdaki metin koddan doğrulanarak yazıldı: hangi alanın nereye
/// gittiği tek tek kontrol edildi.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.kind});

  final LegalDocumentKind kind;

  String get _title {
    switch (kind) {
      case LegalDocumentKind.terms:
        return 'Kullanım Koşulları';
      case LegalDocumentKind.privacy:
        return 'Gizlilik Politikası';
      case LegalDocumentKind.faq:
        return 'Sıkça Sorulan Sorular';
    }
  }

  List<_Section> get _sections {
    switch (kind) {
      case LegalDocumentKind.terms:
        return _terms;
      case LegalDocumentKind.privacy:
        return _privacy;
      case LegalDocumentKind.faq:
        return _faq;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: CustomAppBar(title: _title),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _sections.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == _sections.length) {
            return _FooterNote(isDark: isDark);
          }
          return _SectionCard(section: _sections[index], isDark: isDark);
        },
      ),
    );
  }

  // ------------------------------------------------------------------
  // KULLANIM KOŞULLARI
  // ------------------------------------------------------------------
  static const List<_Section> _terms = [
    _Section(
      'Uygulamanın Amacı',
      'SınıfCepte, öğretmenlerin sınıf yönetimi işlerini kolaylaştırmak ve '
          'öğretmen–veli iletişimini tek bir yerde toplamak için '
          'geliştirilmiştir. Millî Eğitim Bakanlığı\'nın resmî bir ürünü '
          'değildir ve MEB ile herhangi bir kurumsal bağı yoktur.',
    ),
    _Section(
      'Hesap ve Sorumluluk',
      'Öğretmen hesabı, öğretmenin kendi Google hesabıyla açılır. '
          'Hesabınızla yapılan işlemlerden siz sorumlusunuz.\n\n'
          'Öğrenci ve veli bilgilerini uygulamaya girerken, bu bilgileri '
          'işleme yetkiniz olduğundan emin olmalısınız. Uygulama, '
          'girdiğiniz verinin doğruluğunu denetlemez.',
    ),
    _Section(
      'Veli Referans Kodları',
      'Veliler sınıfa, öğretmenin ürettiği referans koduyla bağlanır. '
          'Kodu yalnızca ilgili veliyle paylaşın. Kodu paylaşan kişi, o '
          'kodun kimin eline geçtiğinden sorumludur.\n\n'
          'Bir kodu istediğiniz zaman iptal edebilirsiniz; iptal edilen '
          'kodla yeni bağlantı kurulamaz.',
    ),
    _Section(
      'Kabul Edilmeyen Kullanım',
      '• Başkasının hesabına izinsiz erişmeye çalışmak\n'
          '• Öğrenci ve veli bilgilerini uygulama dışına izinsiz aktarmak\n'
          '• Mesajlaşmayı taciz, hakaret veya reklam için kullanmak\n'
          '• Uygulamayı tersine mühendislikle değiştirmeye çalışmak',
    ),
    _Section(
      'Hizmetin Sürekliliği',
      'Uygulama "olduğu gibi" sunulur. Kesintisiz çalışacağı garanti '
          'edilmez. Verilerinizin yedeğini almak sizin sorumluluğunuzdadır: '
          'telefonunuzu kaybederseniz cihazda tutulan veriler (notlar, '
          'katılım kayıtları, devamsızlık) geri getirilemez.',
    ),
  ];

  // ------------------------------------------------------------------
  // GİZLİLİK POLİTİKASI
  // ------------------------------------------------------------------
  static const List<_Section> _privacy = [
    _Section(
      'Kısaca',
      'Öğrenci verilerinin büyük bölümü **yalnızca öğretmenin '
          'telefonunda** kalır ve hiçbir zaman sunucuya gönderilmez. '
          'Buluta yalnızca iletişim için gereken en az bilgi çıkar.\n\n'
          'Aşağıda hangi verinin nerede durduğu tek tek yazılmıştır.',
    ),
    _Section(
      'Yalnızca cihazda kalan veriler',
      'Bunlar telefondan çıkmaz, sunucuya hiç gönderilmez:\n\n'
          '• Sınav notları ve sınav analizleri\n'
          '• Ders içi katılım ve davranış değerlendirmeleri\n'
          '• Devamsızlık kayıtları\n'
          '• Quiz, sözlü ve proje puanları\n'
          '• Veli telefon numaraları\n'
          '• Ders programı\n'
          '• Oturma planı ve sınıf evrakları',
    ),
    _Section(
      'Buluta gönderilen veriler',
      'İletişim çalışabilsin diye şunlar sunucuda tutulur:\n\n'
          '• Öğrencinin **adı, soyadı ve okul numarası** (velinin doğru '
          'çocuğa bağlanabilmesi için)\n'
          '• Sınıf adı ve okul adı\n'
          '• Öğretmenin adı, soyadı ve branşı\n'
          '• Velinin adı ve yakınlık bilgisi (anne/baba/vasi)\n'
          '• Mesaj ve duyuru içerikleri\n'
          '• Randevu talepleri ve durum bildirimleri\n'
          '• Destek talepleriniz',
    ),
    _Section(
      'Saklama süreleri',
      '• Durum bildirimleri: 30 gün sonra otomatik silinir\n'
          '• Randevu kayıtları: 90 gün sonra otomatik silinir\n'
          '• Mesaj ve duyurular: 1 öğretim yılı (365 gün) sonra silinir\n'
          '• Destek talepleri: çözülene kadar saklanır\n\n'
          'Veli bağlantısını kaldırdığınızda o velinin sınıf duyurularına '
          'erişimi anında sona erer.',
    ),
    _Section(
      'Verileriniz kimlerle paylaşılır',
      'Verileriniz üçüncü taraflara satılmaz ve reklam amacıyla '
          'kullanılmaz.\n\n'
          'Altyapı olarak Google Firebase kullanılmaktadır; veriler '
          'Google\'ın sunucularında saklanır. Çökme kayıtları (hata '
          'ayıklama amacıyla) Firebase Crashlytics\'e gönderilir; bu '
          'kayıtlar öğrenci bilgisi içermez.',
    ),
    _Section(
      'Haklarınız (KVKK md. 11)',
      'Kişisel verilerinizle ilgili olarak bilgi talep etme, düzeltilmesini '
          'veya silinmesini isteme hakkına sahipsiniz.\n\n'
          'Hesabınızın ve verilerinizin silinmesini istiyorsanız '
          '${SupportRepository.supportEmail} adresine yazabilirsiniz. '
          'Talebiniz en geç 30 gün içinde sonuçlandırılır.',
    ),
  ];

  // ------------------------------------------------------------------
  // SIKÇA SORULAN SORULAR
  // ------------------------------------------------------------------
  static const List<_Section> _faq = [
    _Section(
      'Referans kodu çalışmıyor, ne yapmalıyım?',
      'Sık karşılaşılan sebepler:\n\n'
          '• Kod büyük/küçük harf duyarlı değildir ama boşluk içermemelidir\n'
          '• Öğretmen kodu iptal etmiş olabilir; yeni kod isteyin\n'
          '• Aynı kod daha önce başka bir hesapta kullanılmış olabilir\n'
          '• İnternet bağlantınızı kontrol edin\n\n'
          'Sorun sürerse öğretmeninizden yeni bir kod üretmesini isteyin.',
    ),
    _Section(
      'Öğretmenimi listede göremiyorum',
      'Veli, yalnızca çocuğunun sınıf kadrosuna eklenmiş öğretmenleri '
          'görür. Sınıf rehber öğretmeni kadroya otomatik eklenir; branş '
          'öğretmenlerini rehber öğretmenin ayrıca eklemesi gerekir.\n\n'
          'Göremiyorsanız rehber öğretmenden ilgili öğretmeni sınıf '
          'kadrosuna eklemesini isteyin.',
    ),
    _Section(
      'Mesajım gitmiyor',
      '• İnternet bağlantınızı kontrol edin\n'
          '• Günlük mesaj sınırına ulaşmış olabilirsiniz; ertesi gün '
          'tekrar deneyin\n'
          '• Öğretmen görüşme saati kısıtlaması koymuş olabilir\n\n'
          'Mesajlarınız gönderilene kadar kaybolmaz.',
    ),
    _Section(
      'Çocuğumu nasıl eklerim?',
      'Çocuğunuzun sınıf rehber öğretmeninden bir **veli referans kodu** '
          'isteyin. Uygulamada "Çocuk Ekle" ekranından bu kodu girdiğinizde '
          'bağlantı kurulur.\n\n'
          'Birden fazla çocuğunuz varsa her biri için ayrı kod alırsınız. '
          'Aynı okulda farklı sınıflarda çocuğunuz olabilir.',
    ),
    _Section(
      'Anne ve baba ayrı ayrı bağlanabilir mi?',
      'Evet. Öğretmen aynı öğrenci için ikinci bir kod üretebilir ve bu '
          'kodu etiketleyebilir (Anne / Baba / Vasi). İki bağlantı '
          'birbirinden bağımsızdır; birinin kodu iptal edilirse diğeri '
          'etkilenmez.',
    ),
    _Section(
      'Çocuğum sınıf değiştirdi, ne olur?',
      'Aynı okul içinde sınıf değişikliğinde bağlantınız korunur; '
          'yalnızca eriştiğiniz sınıf değişir. Yeni sınıfın duyurularını '
          'görmeye başlarsınız.\n\n'
          'Öğrenci okuldan ayrılırsa veya mezun olursa bağlantı kapanır.',
    ),
    _Section(
      'Notları ve devamsızlığı neden göremiyorum?',
      'Notlar, katılım değerlendirmeleri ve devamsızlık kayıtları '
          'öğretmenin telefonunda kalır ve buluta hiç gönderilmez. Bu, '
          'öğrenci verisini korumak için alınmış bilinçli bir karardır.\n\n'
          'Bu bilgiler için öğretmeninizle doğrudan iletişime geçin.',
    ),
    _Section(
      'Hesabımı nasıl silerim?',
      '${SupportRepository.supportEmail} adresine hesabınızın silinmesini '
          'istediğinizi yazın. Talebiniz en geç 30 gün içinde '
          'sonuçlandırılır.',
    ),
  ];
}

class _Section {
  const _Section(this.title, this.body);

  final String title;
  final String body;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.isDark});

  final _Section section;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: AppFonts.outfit(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            section.body,
            style: AppFonts.outfit(
              fontSize: 13,
              height: 1.55,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(
            'Sorularınız için',
            style: AppFonts.outfit(
              fontSize: 11.5,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            SupportRepository.supportEmail,
            style: AppFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
