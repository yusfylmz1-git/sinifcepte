/// Öğretmen dosyasının resmî metinleri.
///
/// ## Kaynak (11 Ekim 2026)
/// İstiklâl Marşı ve Gençliğe Hitabe, **MEB ders kitaplarının ön
/// sayfalarındaki** metinle birebir aynıdır. Öğrencinin her kitabın
/// başında gördüğü metin budur; okul evrakı için ölçüt de o.
///
/// İki MEB kitabından makineyle çıkarılıp karşılaştırıldı:
///   * eba.gov.tr — `dogm.eba.gov.tr/panel/upload/kitap/kur08/kur08.pdf`
///     (s. 3-4),
///   * MESEM 9. Sınıf Türk Dili ve Edebiyatı (s. 5-6).
/// İkisi iki yer dışında aynı: 20. dizenin sonundaki nokta ve 40.
/// dizede "hürriyet/hürriyyet". İkisinde de MESEM esas alındı (TBMM'nin
/// 100. yıl kitabı da "hürriyet" yazar).
///
/// Neden "tek doğru noktalama" yok: TBMM'nin "Kabulünün 100. Yılında
/// İstiklâl Marşı" kitabı marşı dört ayrı yerde dört farklı noktalamayla
/// basar. Eski sürümümüz bunlardan birine yakındı ve MEB metninden 15
/// dizede ayrılıyordu ("helâl...", "'Medeniyet!'", "Arkadaş! Yurduma"…).
///
/// Testteki altın dosyalar (`test/veri/istiklal_marsi_meb.txt`,
/// `test/veri/genclige_hitabe_meb.txt`) aynı PDF'lerden makineyle
/// çıkarıldı; bu dosya da onlardan üretildi. Metin değişirse önce
/// kaynağa bakılır, ikisi birlikte güncellenir.
///
/// ## Neden ayrı dosya
/// Bu metinler **değişmez**. Tek harfi bile yanlış basılırsa belge
/// teftişte kusurlu sayılır. PDF üreticisinin içine gömülü olsalardı
/// düzen değişikliği yaparken yanlışlıkla bozulabilirlerdi.
///
/// ## Telif
/// Kamu malıdır: İstiklâl Marşı 12 Mart 1921'de TBMM'nin kabul ettiği
/// millî marş (Anayasa m. 3 yalnız "Millî marşı İstiklâl Marşı'dır"
/// der, metni içermez), Gençliğe Hitabe Nutuk'un (1927) kapanışıdır.
class TeacherFileTexts {
  TeacherFileTexts._();

  /// İstiklâl Marşı — 10 kıtanın tamamı (MEB ders kitabı metni).
  ///
  /// Her eleman bir kıta, kıta içindeki dizeler `\n` ile ayrılmıştır.
  /// Onuncu kıta beş dizedir.
  static const List<String> istiklalMarsi = [
    'Korkma, sönmez bu şafaklarda yüzen al sancak;\n'
        'Sönmeden yurdumun üstünde tüten en son ocak.\n'
        'O benim milletimin yıldızıdır, parlayacak;\n'
        'O benimdir, o benim milletimindir ancak.',
    'Çatma, kurban olayım, çehreni ey nazlı hilâl!\n'
        'Kahraman ırkıma bir gül! Ne bu şiddet, bu celâl?\n'
        'Sana olmaz dökülen kanlarımız sonra helâl.\n'
        'Hakkıdır Hakk\'a tapan milletimin istiklâl.',
    'Ben ezelden beridir hür yaşadım, hür yaşarım.\n'
        'Hangi çılgın bana zincir vuracakmış? Şaşarım!\n'
        'Kükremiş sel gibiyim, bendimi çiğner, aşarım.\n'
        'Yırtarım dağları, enginlere sığmam, taşarım.',
    'Garbın âfâkını sarmışsa çelik zırhlı duvar,\n'
        'Benim iman dolu göğsüm gibi serhaddim var.\n'
        'Ulusun, korkma! Nasıl böyle bir imanı boğar,\n'
        'Medeniyyet dediğin tek dişi kalmış canavar?',
    'Arkadaş, yurduma alçakları uğratma sakın;\n'
        'Siper et gövdeni, dursun bu hayâsızca akın.\n'
        'Doğacaktır sana va\'dettiği günler Hakk\'ın;\n'
        'Kim bilir, belki yarın, belki yarından da yakın.',
    'Bastığın yerleri toprak diyerek geçme, tanı:\n'
        'Düşün altındaki binlerce kefensiz yatanı.\n'
        'Sen şehit oğlusun, incitme, yazıktır, atanı:\n'
        'Verme, dünyaları alsan da bu cennet vatanı.',
    'Kim bu cennet vatanın uğruna olmaz ki feda?\n'
        'Şüheda fışkıracak toprağı sıksan, şüheda!\n'
        'Cânı, cânânı, bütün varımı alsın da Huda,\n'
        'Etmesin tek vatanımdan beni dünyada cüda.',
    'Ruhumun senden İlâhî, şudur ancak emeli:\n'
        'Değmesin mabedimin göğsüne nâmahrem eli.\n'
        'Bu ezanlar -ki şehadetleri dinin temeli-\n'
        'Ebedî yurdumun üstünde benim inlemeli.',
    'O zaman vecd ile bin secde eder -varsa- taşım,\n'
        'Her cerîhamdan İlâhî, boşanıp kanlı yaşım,\n'
        'Fışkırır ruh-ı mücerret gibi yerden na\'şım;\n'
        'O zaman yükselerek arşa değer belki başım.',
    'Dalgalan sen de şafaklar gibi ey şanlı hilâl!\n'
        'Olsun artık dökülen kanlarımın hepsi helâl.\n'
        'Ebediyyen sana yok, ırkıma yok izmihlâl;\n'
        'Hakkıdır hür yaşamış bayrağımın hürriyet;\n'
        'Hakkıdır Hakk\'a tapan milletimin istiklâl!',
  ];

  /// Şairin adı — MEB ders kitabındaki gibi metnin sağ altına basılır.
  static const String istiklalMarsiKunye = 'Mehmet Âkif Ersoy';

  /// Atatürk'ün Gençliğe Hitabesi — tam metin (MEB ders kitabı metni).
  ///
  /// Nutuk'un (1927) kapanış bölümü. Üç paragraf, MEB'deki bölünüşle.
  static const List<String> gencligeHitabe = [
    'Ey Türk gençliği! Birinci vazifen, Türk istiklâlini, Türk '
        'Cumhuriyetini, ilelebet muhafaza ve müdafaa etmektir.',
    'Mevcudiyetinin ve istikbalinin yegâne temeli budur. Bu temel, '
        'senin en kıymetli hazinendir. İstikbalde dahi, seni bu '
        'hazineden mahrum etmek isteyecek dâhilî ve hâricî bedhahların '
        'olacaktır. Bir gün, istiklâl ve cumhuriyeti müdafaa '
        'mecburiyetine düşersen, vazifeye atılmak için, içinde '
        'bulunacağın vaziyetin imkân ve şeraitini düşünmeyeceksin! Bu '
        'imkân ve şerait, çok namüsait bir mahiyette tezahür edebilir. '
        'İstiklâl ve cumhuriyetine kastedecek düşmanlar, bütün dünyada '
        'emsali görülmemiş bir galibiyetin mümessili olabilirler. '
        'Cebren ve hile ile aziz vatanın bütün kaleleri zapt edilmiş, '
        'bütün tersanelerine girilmiş, bütün orduları dağıtılmış ve '
        'memleketin her köşesi bilfiil işgal edilmiş olabilir. Bütün bu '
        'şeraitten daha elîm ve daha vahim olmak üzere, memleketin '
        'dâhilinde iktidara sahip olanlar gaflet ve dalâlet ve hattâ '
        'hıyanet içinde bulunabilirler. Hattâ bu iktidar sahipleri '
        'şahsî menfaatlerini, müstevlîlerin siyasî emelleriyle tevhit '
        'edebilirler. Millet, fakr u zaruret içinde harap ve bîtap '
        'düşmüş olabilir.',
    'Ey Türk istikbalinin evlâdı! İşte, bu ahval ve şerait içinde '
        'dahi vazifen, Türk istiklâl ve cumhuriyetini kurtarmaktır. '
        'Muhtaç olduğun kudret, damarlarındaki asil kanda mevcuttur.',
  ];

  /// Hitabenin imzası — MEB ders kitabındaki gibi sağ alta basılır.
  static const String gencligeHitabeKunye = 'Mustafa Kemal Atatürk';

  /// Atatürk sayfasının portre altı yazısı — MEB ders kitabındaki gibi.
  static const String ataturkPortreAltYazisi = 'MUSTAFA KEMAL ATATÜRK';

  /// Atatürk'ün Öğretmenlere Hitabı — kapak sayfasının altında.
  ///
  /// Öğretmen dosyasının kapağına yakışan, sık kullanılan söz.
  static const String ogretmenlereHitap =
      'Öğretmenler! Yeni nesil sizin eseriniz olacaktır.';

  static const String ogretmenlereHitapKunye = 'Mustafa Kemal ATATÜRK';
}
