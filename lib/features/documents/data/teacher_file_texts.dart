/// Öğretmen dosyasının resmî metinleri.
///
/// ## Neden ayrı dosya
/// Bu metinler **değişmez**. İstiklal Marşı ve Gençliğe Hitabe'nin
/// tek harfi bile yanlış basılırsa belge teftişte kusurlu sayılır.
/// PDF üreticisinin içine gömülü olsalardı düzen değişikliği
/// yaparken yanlışlıkla bozulabilirlerdi; burada durunca metin
/// üzerinde test yazmak da mümkün oluyor.
///
/// ## Telif
/// Her ikisi de kamu malıdır: İstiklal Marşı 12 Mart 1921'de TBMM
/// tarafından millî marş olarak kabul edilmiş resmî metin, Gençliğe
/// Hitabe ise Nutuk'un (1927) kapanış bölümüdür.
///
/// Metinler Anayasa'nın 3. maddesinde ve MEB'in resmî yayınlarında
/// geçen imlâyla yazılmıştır; okullarda asılan levhalardaki hâli
/// budur.
class TeacherFileTexts {
  TeacherFileTexts._();

  /// İstiklâl Marşı — 10 kıtanın tamamı.
  ///
  /// Törenlerde ilk iki kıta okunur ama **dosyada tam metin bulunur**;
  /// teftişte bakılan da budur. Her eleman bir kıta, kıta içindeki
  /// satırlar `\n` ile ayrılmıştır.
  static const List<String> istiklalMarsi = [
    'Korkma, sönmez bu şafaklarda yüzen al sancak;\n'
        'Sönmeden yurdumun üstünde tüten en son ocak.\n'
        'O benim milletimin yıldızıdır, parlayacak;\n'
        'O benimdir, o benim milletimindir ancak.',
    'Çatma, kurban olayım, çehreni ey nazlı hilâl!\n'
        'Kahraman ırkıma bir gül! Ne bu şiddet, bu celâl?\n'
        'Sana olmaz dökülen kanlarımız sonra helâl...\n'
        'Hakkıdır, Hakk\'a tapan, milletimin istiklâl!',
    'Ben ezelden beridir hür yaşadım, hür yaşarım.\n'
        'Hangi çılgın bana zincir vuracakmış? Şaşarım!\n'
        'Kükremiş sel gibiyim, bendimi çiğner, aşarım.\n'
        'Yırtarım dağları, enginlere sığmam, taşarım.',
    'Garbın âfâkını sarmışsa çelik zırhlı duvar,\n'
        'Benim iman dolu göğsüm gibi serhaddim var.\n'
        'Ulusun, korkma! Nasıl böyle bir imanı boğar,\n'
        '\'Medeniyet!\' dediğin tek dişi kalmış canavar?',
    'Arkadaş! Yurduma alçakları uğratma, sakın.\n'
        'Siper et gövdeni, dursun bu hayâsızca akın.\n'
        'Doğacaktır sana va\'dettiği günler Hakk\'ın...\n'
        'Kim bilir, belki yarın, belki yarından da yakın.',
    'Bastığın yerleri \'toprak!\' diyerek geçme, tanı:\n'
        'Düşün altındaki binlerce kefensiz yatanı.\n'
        'Sen şehit oğlusun, incitme, yazıktır, atanı:\n'
        'Verme, dünyaları alsan da bu cennet vatanı.',
    'Kim bu cennet vatanın uğruna olmaz ki fedâ?\n'
        'Şühedâ fışkıracak toprağı sıksan, şühedâ!\n'
        'Cânı, cânânı, bütün varımı alsın da Huda,\n'
        'Etmesin tek vatanımdan beni dünyada cüdâ.',
    'Ruhumun senden İlâhî, şudur ancak emeli:\n'
        'Değmesin mâbedimin göğsüne nâmahrem eli.\n'
        'Bu ezanlar -ki şehadetleri dinin temeli-\n'
        'Ebedî yurdumun üstünde benim inlemeli.',
    'O zaman vecd ile bin secde eder -varsa- taşım,\n'
        'Her cerîhamdan İlâhî, boşanıp kanlı yaşım,\n'
        'Fışkırır rûh-ı mücerret gibi yerden na\'şım;\n'
        'O zaman yükselerek arşa değer belki başım.',
    'Dalgalan sen de şafaklar gibi ey şanlı hilâl!\n'
        'Olsun artık dökülen kanlarımın hepsi helâl.\n'
        'Ebediyyen sana yok, ırkıma yok izmihlâl:\n'
        'Hakkıdır, hür yaşamış, bayrağımın hürriyet;\n'
        'Hakkıdır, Hakk\'a tapan, milletimin istiklâl!',
  ];

  /// İstiklâl Marşı'nın şairi ve kabul bilgisi — sayfa altına basılır.
  static const String istiklalMarsiKunye =
      'Mehmet Âkif ERSOY\n12 Mart 1921\'de Türkiye Büyük Millet Meclisi '
      'tarafından millî marş olarak kabul edilmiştir.';

  /// Atatürk'ün Gençliğe Hitabesi — tam metin.
  ///
  /// Nutuk'un (1927) kapanış bölümü. Paragraflar ayrı elemanlarda.
  static const List<String> gencligeHitabe = [
    'Ey Türk gençliği! Birinci vazifen, Türk istiklâlini, Türk '
        'Cumhuriyetini, ilelebet muhafaza ve müdafaa etmektir.',
    'Mevcudiyetinin ve istikbalinin yegâne temeli budur. Bu temel, '
        'senin en kıymetli hazinendir. İstikbalde dahi seni bu '
        'hazineden mahrum etmek isteyecek dâhilî ve haricî '
        'bedhahların olacaktır. Bir gün, istiklâl ve cumhuriyeti '
        'müdafaa mecburiyetine düşersen, vazifeye atılmak için, '
        'içinde bulunacağın vaziyetin imkân ve şeraitini düşünmeyeceksin! '
        'Bu imkân ve şerait, çok namüsait bir mahiyette tezahür '
        'edebilir. İstiklâl ve cumhuriyetine kastedecek düşmanlar, '
        'bütün dünyada emsali görülmemiş bir galibiyetin mümessili '
        'olabilirler. Cebren ve hile ile aziz vatanın bütün kaleleri '
        'zapt edilmiş, bütün tersanelerine girilmiş, bütün orduları '
        'dağıtılmış ve memleketin her köşesi bilfiil işgal edilmiş '
        'olabilir. Bütün bu şeraitten daha elîm ve daha vahim olmak '
        'üzere, memleketin dâhilinde iktidara sahip olanlar gaflet ve '
        'dalâlet ve hattâ hıyanet içinde bulunabilirler. Hattâ bu '
        'iktidar sahipleri şahsî menfaatlerini, müstevlîlerin siyasî '
        'emelleriyle tevhit edebilirler. Millet, fakr u zaruret '
        'içinde harap ve bîtap düşmüş olabilir.',
    'Ey Türk istikbalinin evlâdı! İşte, bu ahval ve şerait içinde '
        'dahi vazifen, Türk istiklâl ve cumhuriyetini kurtarmaktır! '
        'Muhtaç olduğun kudret, damarlarındaki asil kanda mevcuttur!',
  ];

  /// Hitabenin künyesi.
  static const String gencligeHitabeKunye =
      'Gazi Mustafa Kemal ATATÜRK\n20 Ekim 1927';

  /// Atatürk'ün Öğretmenlere Hitabı — kapak sayfasının altında.
  ///
  /// Öğretmen dosyasının kapağına yakışan, sık kullanılan söz.
  static const String ogretmenlereHitap =
      'Öğretmenler! Yeni nesil sizin eseriniz olacaktır.';

  static const String ogretmenlereHitapKunye = 'Mustafa Kemal ATATÜRK';
}
