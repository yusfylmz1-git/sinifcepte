import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/features/auth_profile/data/models/teacher_profile_model.dart';
import 'package:sinifcepte/features/auth_profile/providers/teacher_profile_provider.dart';
import 'package:sinifcepte/features/classes/providers/class_provider.dart';
import 'package:sinifcepte/features/parent_portal/data/gelen_kutusu.dart';
import 'package:sinifcepte/features/parent_portal/data/models/parent_link_model.dart';
import 'package:sinifcepte/features/parent_portal/data/repositories/cloud_communication_repository.dart';
import 'package:sinifcepte/features/parent_portal/presentation/screens/gelen_kutusu_ekrani.dart';
import 'package:sinifcepte/features/parent_portal/presentation/widgets/gelen_kutusu_karti.dart';
import 'package:sinifcepte/features/parent_portal/presentation/widgets/parent_teacher_chat_modal.dart';
import 'package:sinifcepte/features/parent_portal/providers/cloud_communication_provider.dart';
import 'package:sinifcepte/features/parent_portal/providers/gelen_kutusu_provider.dart';
import 'package:sinifcepte/features/parent_portal/providers/parent_token_provider.dart';

/// Tek veli gelen kutusu (sadeleştirme 2. aşama, 18 Ekim 2026).
///
/// ## Neden bu testler var
/// Veliden gelenler üç yere dağılmıştı (Bugün akışı, Veli Paneli
/// sekmeleri, bildirim sayacı) ve öğretmen tarafında okunma takibi yoktu:
/// her veli mesajı her açılışta "yeni" sayılıyordu. Kadrodaki branş
/// öğretmenine yazılan mesaj ise hiçbir ekrana düşmüyordu. Artık hepsi tek
/// gelen kutusunda: sınıf başına delta okunur, okunmamış sayısı cihazda
/// tutulur, sohbet açılınca sıfırlanır.
///
/// Mesaj zamanı gönderen telefonun saatidir; saati kaymış bir telefonun
/// mesajı kaçmamalı ve iki kez sayılmamalı (imleç payı + kimlikle ayıklama).
const _uid = 'ogr1';
const _cls = 'cls_ogr1_1';
const _kadroCls = 'cls_baskaOgr_7';

const _profil = TeacherProfileModel(
  id: _uid,
  firstName: 'Deneme',
  lastName: 'Öğretmen',
  branch: 'Türkçe',
  schoolName: 'Deneme Ortaokulu',
  schoolId: 'okul1',
  schoolPrincipalName: 'Müdür',
  email: 'deneme@example.com',
);

const _rehberlik = ClassModel(
    id: 1, name: '5-A', subject: 'Türkçe', academicYear: '2026-2027', isHomeroom: true);

const _kadroSinifi = KadroSinifi(
  classCloudId: _kadroCls,
  className: '7-C',
  homeroomTeacherName: 'Ayşe Demir',
  branch: 'Türkçe',
);

DateTime _t(int saat, [int dakika = 0]) => DateTime(2026, 10, 18, saat, dakika);

final _anahtar = sohbetAnahtari(_cls, 'stu1', 'veli1');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GelenKutusuDeposu.bellegiBosalt();
  });

  group('mesajlariIsle (saf hesap)', () {
    Map<String, SohbetOzeti> isle(
      List<CloudMessage> mesajlar, {
      Map<String, SohbetOzeti> mevcut = const {},
      Map<String, DateTime> gorulen = const {},
    }) =>
        mesajlariIsle(mevcut: mevcut, classCloudId: _cls, yeniMesajlar: mesajlar, sonGorulen: gorulen);

    test('veli mesajları okunmamış sayılır; son mesaj, öğrenci ve veli adı işlenir', () {
      // Sunucu yeniden eskiye döndürür; son mesaj yine zamana göre seçilir.
      final s = isle([
        _mesaj('m2', zaman: _t(10, 5), govde: 'Yarın gelemeyecek'),
        _mesaj('m1', zaman: _t(10), ogrenciAdi: 'Ali YILMAZ'),
      ]);
      final o = s[_anahtar]!;
      expect(o.okunmamis, 2);
      expect(o.sonMesaj, 'Yarın gelemeyecek');
      expect(o.sonYazanVeli, isTrue);
      expect(o.studentName, 'Ali YILMAZ');
      expect(o.parentName, 'Fatma YILMAZ');
    });

    test('KRITIK: öğretmen yanıt yazdıysa öncesi okunmuş sayılır', () {
      final s = isle([
        _mesaj('v1', zaman: _t(10)),
        _mesaj('v2', zaman: _t(10, 1)),
        _mesaj('o1', zaman: _t(10, 2), ogretmen: true),
        _mesaj('v3', zaman: _t(10, 3)),
      ]);
      expect(s[_anahtar]!.okunmamis, 1, reason: 'yalnız yanıttan sonraki veli mesajı');

      // Yanıt sonraki okumada gelse de (başka cihazdan ya da "Bir veliye
      // yaz" listesinden yazılmış) sayaç sıfırlanır.
      final once = isle([_mesaj('v1', zaman: _t(10)), _mesaj('v2', zaman: _t(10, 1))]);
      expect(once[_anahtar]!.okunmamis, 2);
      final sonra = isle([_mesaj('o1', zaman: _t(10, 2), ogretmen: true, govde: 'Tamam')], mevcut: once);
      expect(sonra[_anahtar]!.okunmamis, 0);
      expect(sonra[_anahtar]!.sonYazanVeli, isFalse);
      expect(sonra[_anahtar]!.sonMesaj, 'Tamam');
      expect(sonra[_anahtar]!.parentName, 'Fatma YILMAZ', reason: 'öğretmenin adı veli adının yerine geçmez');
    });

    test('görüldükten önce yazılan veli mesajı okunmamış sayılmaz', () {
      final s = isle(
        [_mesaj('v1', zaman: _t(10)), _mesaj('v2', zaman: _t(10, 5))],
        gorulen: {_anahtar: _t(10, 2)},
      );
      expect(s[_anahtar]!.okunmamis, 1);
    });

    test('her veli ayrı sohbet; öğrencisi olmayan mesaj atlanır', () {
      final s = isle([
        _mesaj('a', zaman: _t(9)),
        _mesaj('b', zaman: _t(9, 1), veli: 'veli2', yazar: 'Hasan YILMAZ'),
        _mesaj('c', zaman: _t(9, 2), stu: ''),
      ]);
      expect(s.keys, unorderedEquals([_anahtar, sohbetAnahtari(_cls, 'stu1', 'veli2')]));
    });

    test('geç gelen eski mesaj son mesajın yerine geçmez ama sayılır', () {
      final once = isle([_mesaj('yeni', zaman: _t(12), govde: 'en son')]);
      final s = isle([_mesaj('eski', zaman: _t(11), govde: 'daha önce')], mevcut: once);
      expect(s[_anahtar]!.sonMesaj, 'en son');
      expect(s[_anahtar]!.okunmamis, 2);
    });
  });

  group('GelenKutusuDeposu (cihazdaki kayıt)', () {
    test('kaydedilen her şey diskten geri gelir; her hesabın kaydı ayrı', () async {
      final depo = GelenKutusuDeposu(_uid);
      await depo.yukle();
      depo.sohbetler = mesajlariIsle(
        mevcut: const {},
        classCloudId: _cls,
        yeniMesajlar: [_mesaj('m1', zaman: _t(10), ogrenciAdi: 'Ali YILMAZ')],
        sonGorulen: const {},
      );
      depo.senkron[_cls] = _t(9, 50);
      depo.gorulen['baska'] = _t(8);
      depo.islenen[_cls] = {'m1': _t(10)};
      depo.kadroSiniflari = const [_kadroSinifi];
      depo.kadroZamani = _t(7);
      await depo.kaydet();

      GelenKutusuDeposu.bellegiBosalt();
      final geri = GelenKutusuDeposu(_uid);
      expect(identical(geri, depo), isFalse, reason: 'diskten yeniden okunmalı');
      await geri.yukle();
      final o = geri.sohbetler.values.single;
      expect(o.anahtar, _anahtar);
      expect(o.studentName, 'Ali YILMAZ');
      expect(o.parentName, 'Fatma YILMAZ');
      expect(o.okunmamis, 1);
      expect(o.sonZaman, _t(10));
      expect(o.sonYazanVeli, isTrue);
      expect(geri.senkron, {_cls: _t(9, 50)});
      expect(geri.gorulen, {'baska': _t(8)});
      expect(geri.islenen, {
        _cls: {'m1': _t(10)},
      });
      expect(geri.kadroSiniflari.single.classCloudId, _kadroCls);
      expect(geri.kadroSiniflari.single.className, '7-C');
      expect(geri.kadroSiniflari.single.homeroomTeacherName, 'Ayşe Demir');
      expect(geri.kadroSiniflari.single.branch, 'Türkçe');
      expect(geri.kadroZamani, _t(7));

      final baska = GelenKutusuDeposu('ogr2');
      await baska.yukle();
      expect(baska.sohbetler, isEmpty, reason: 'aynı telefonda başka öğretmen hesabı');
    });

    test('bozuk kayıt uygulamayı düşürmez; kutu boş başlar', () async {
      SharedPreferences.setMockInitialValues({'gelen_kutusu_v1_$_uid': '{bozuk'});
      final depo = GelenKutusuDeposu(_uid);
      await depo.yukle();
      expect(depo.sohbetler, isEmpty);
      expect(depo.senkron, isEmpty);
    });

    test('görüldü işareti okunmamışı sıfırlar ve diske yazılır', () async {
      final depo = GelenKutusuDeposu(_uid);
      await depo.yukle();
      depo.sohbetler = mesajlariIsle(
        mevcut: const {},
        classCloudId: _cls,
        yeniMesajlar: [_mesaj('v1', zaman: _t(10)), _mesaj('v2', zaman: _t(10, 1))],
        sonGorulen: const {},
      );
      await depo.gorulduIsaretle(_anahtar, an: _t(11));

      GelenKutusuDeposu.bellegiBosalt();
      final geri = GelenKutusuDeposu(_uid);
      await geri.yukle();
      expect(geri.sohbetler[_anahtar]!.okunmamis, 0);
      expect(geri.gorulen[_anahtar], _t(11));
    });

    test('KRITIK: senkron ağı beklerken açılıp kapanan sohbetin görüldü işareti ezilmez', () async {
      final depo = GelenKutusuDeposu(_uid);
      await depo.yukle();
      depo.sohbetler = mesajlariIsle(
        mevcut: const {},
        classCloudId: _cls,
        yeniMesajlar: [_mesaj('v1', zaman: _t(10)), _mesaj('v2', zaman: _t(10, 1))],
        sonGorulen: const {},
      );
      await depo.kaydet();

      // Sağlayıcı gibi: kaydı yükler, senkronu başlatır; ağ yanıtı gecikir.
      final bulut = _SahteBulut()..kapi = Completer<void>();
      final senkronDeposu = GelenKutusuDeposu(_uid);
      await senkronDeposu.yukle();
      final senkron = gelenKutusunuEsitle(depo: senkronDeposu, bulut: bulut, siniflar: [_cls], simdi: _t(12));

      // Bu sırada öğretmen sohbeti açıp kapatır.
      await GelenKutusuDeposu(_uid).gorulduIsaretle(_anahtar, an: _t(11));
      bulut.kapi!.complete();
      await senkron;

      GelenKutusuDeposu.bellegiBosalt();
      final geri = GelenKutusuDeposu(_uid);
      await geri.yukle();
      expect(geri.sohbetler[_anahtar]!.okunmamis, 0,
          reason: 'senkron eski kopyayı kaydedip görüldü işaretini ezmemeli');
    });
  });

  group('gelenKutusunuEsitle (delta okuma)', () {
    Future<GelenKutusuDeposu> depoAc() async {
      final d = GelenKutusuDeposu(_uid);
      await d.yukle();
      return d;
    }

    test('ilk okuma imleçsiz; sonra yalnız imleçten yeniler istenir, aynı mesaj iki kez sayılmaz', () async {
      final depo = await depoAc();
      final bulut = _SahteBulut()..sunucu[_cls] = [_mesaj('v1', zaman: _t(9)), _mesaj('v2', zaman: _t(9, 30))];

      expect(await gelenKutusunuEsitle(depo: depo, bulut: bulut, siniflar: [_cls], simdi: _t(12)), isFalse);
      expect(depo.senkron[_cls], _t(9, 30));
      expect(depo.sohbetler[_anahtar]!.okunmamis, 2);

      await gelenKutusunuEsitle(depo: depo, bulut: bulut, siniflar: [_cls], simdi: _t(12, 30));
      expect(bulut.sorgular, ['$_cls>-', '$_cls>${_t(9, 30).toIso8601String()}']);
      expect(depo.sohbetler[_anahtar]!.okunmamis, 2);
    });

    test('KRITIK: saati geride velinin sonradan düşen mesajı kaçmaz, yanıt ikinci kez işlenmez', () async {
      final depo = await depoAc();
      final bulut = _SahteBulut()
        ..sunucu[_cls] = [
          _mesaj('v1', zaman: _t(11, 40)),
          _mesaj('o1', zaman: _t(11, 55), ogretmen: true),
        ];
      await gelenKutusunuEsitle(depo: depo, bulut: bulut, siniflar: [_cls], simdi: _t(12));
      expect(depo.sohbetler[_anahtar]!.okunmamis, 0, reason: 'öğretmen yanıt yazmış');
      expect(depo.senkron[_cls], _t(11, 50), reason: 'imleç okuma anından pay kadar geride, 11:55 değil');

      // Velinin saati 4 dakika geride: 11:57'de yazdığı mesaj 11:53 görünür.
      bulut.sunucu[_cls]!.add(_mesaj('v2', zaman: _t(11, 53), govde: 'Teşekkürler hocam'));
      await gelenKutusunuEsitle(depo: depo, bulut: bulut, siniflar: [_cls], simdi: _t(12, 20));
      expect(depo.sohbetler[_anahtar]!.okunmamis, 1,
          reason: 'imleç 11:55 olsaydı mesaj hiç gelmezdi; o1 yeniden işlenseydi sayaç sıfırlanırdı');
      expect(depo.senkron[_cls], _t(11, 55));
      expect(depo.islenen[_cls], isEmpty, reason: 'imleçten eskiler ayıklama listesinden düşer');
    });

    test('saati ileride telefonun mesajı imleci ileri atıp aradakileri gizlemez', () async {
      final depo = await depoAc();
      final bulut = _SahteBulut()..sunucu[_cls] = [_mesaj('ileri', zaman: _t(13))];
      await gelenKutusunuEsitle(depo: depo, bulut: bulut, siniflar: [_cls], simdi: _t(12));
      expect(depo.senkron[_cls], _t(11, 50));

      bulut.sunucu[_cls]!.add(_mesaj('normal', zaman: _t(12, 20)));
      await gelenKutusunuEsitle(depo: depo, bulut: bulut, siniflar: [_cls], simdi: _t(12, 30));
      expect(depo.sohbetler[_anahtar]!.okunmamis, 2, reason: '12:20 mesajı gelir; ileri tarihli olan tekrar sayılmaz');
    });

    test('bir sınıf okunamazsa diğerleri sürer; onun imleci yerinde kalır, eksik bildirilir', () async {
      final depo = await depoAc();
      final bulut = _SahteBulut()
        ..sunucu[_cls] = [_mesaj('v1', zaman: _t(9))]
        ..sunucu[_kadroCls] = [_mesaj('k1', zaman: _t(9))]
        ..bozukSiniflar.add(_kadroCls);
      final eksik = await gelenKutusunuEsitle(depo: depo, bulut: bulut, siniflar: [_kadroCls, _cls], simdi: _t(12));
      expect(eksik, isTrue);
      expect(depo.senkron.containsKey(_kadroCls), isFalse);
      expect(depo.senkron[_cls], _t(9));
      expect(depo.sohbetler.keys, [_anahtar]);
    });

    test('yeni mesaj yoksa imleç yerinde kalır; sonuç diske yazılır', () async {
      final depo = await depoAc();
      final bulut = _SahteBulut()..sunucu[_cls] = [_mesaj('v1', zaman: _t(9))];
      await gelenKutusunuEsitle(depo: depo, bulut: bulut, siniflar: [_cls], simdi: _t(12));
      await gelenKutusunuEsitle(depo: depo, bulut: bulut, siniflar: [_cls], simdi: _t(15));
      expect(depo.senkron[_cls], _t(9));

      final prefs = await SharedPreferences.getInstance();
      final kayit = jsonDecode(prefs.getString('gelen_kutusu_v1_$_uid')!) as Map<String, dynamic>;
      expect((kayit['sohbetler'] as List).length, 1);
    });
  });

  group('randevuBanaMi ve özet sayılar', () {
    test('yeni talepte öğretmen kimliğine, eskide ada bakılır; ikisi de boşsa sınıf öğretmeninindir', () {
      bool bana(CloudAppointment a, {bool kendi = false}) =>
          randevuBanaMi(a, uid: _uid, ad: 'Deneme ÖĞRETMEN', kendiSinifim: kendi);

      expect(bana(_randevu('a', teacherUid: _uid)), isTrue);
      expect(bana(_randevu('b', teacherUid: 'baskaOgr', ogretmenAdi: 'Deneme ÖĞRETMEN')), isFalse,
          reason: 'kimlik varsa ad eşleşmesi sayılmaz');
      expect(bana(_randevu('c', ogretmenAdi: 'Deneme ÖĞRETMEN')), isTrue);
      expect(bana(_randevu('d', ogretmenAdi: 'Başka Öğretmen')), isFalse);
      expect(bana(_randevu('e'), kendi: true), isTrue);
      expect(bana(_randevu('f')), isFalse);
    });

    test('rozet: okunmamış mesaj + bekleyen randevu + görülmemiş bildirim', () {
      final d = _ornekDurum();
      expect(d.okunmamisMesaj, 2);
      expect(d.rozet, 4);
      expect(d.sinifAdi(_kadroCls), '7-C');
      expect(d.sinifAdi('yok'), '');
      expect(GelenKutusuDurumu.bulutsuz.rozet, 0);
    });
  });

  group('gelenKutusuProvider', () {
    ProviderContainer kapsayici(
      _SahteBulut bulut, {
      String profilId = _uid,
      List<CloudAppointment> kendiRandevularim = const [],
      List<CloudStatusReport> bildirimler = const [],
    }) {
      final kap = ProviderContainer(overrides: [
        teacherProfileProvider.overrideWith((ref) => _SahteProfil(_profil.copyWith(id: profilId))),
        cloudCommunicationRepositoryProvider.overrideWithValue(bulut),
        homeroomClassProvider.overrideWithValue(_rehberlik),
        classLinkedParentsProvider(_rehberlik).overrideWith((ref) async => [_bag()]),
        classAppointmentsCloudProvider(_cls).overrideWith((ref) async => kendiRandevularim),
        classStatusReportsCloudProvider(_cls).overrideWith((ref) async => bildirimler),
      ]);
      addTearDown(kap.dispose);
      return kap;
    }

    test('KRITIK: rehberlik ve kadro sınıfı tek kutuda; randevu yalnız bana istenen, bildirim yalnız kendi sınıfımdan',
        () async {
      final bulut = _SahteBulut()
        ..kadro = const [_kadroSinifi]
        // Eski mesaj: öğrenci ve veli adı yok, veli bağından tamamlanır.
        ..sunucu[_cls] = [_mesaj('m1', zaman: _t(10), yazar: '')]
        ..sunucu[_kadroCls] = [
          _mesaj('k1', zaman: _t(10, 30), stu: 'stu7', veli: 'veli7', ogrenciAdi: 'Can ÖZ', yazar: 'Hasan ÖZ'),
        ]
        ..randevular[_kadroCls] = [
          _randevu('bana', teacherUid: _uid),
          _randevu('baskasina', teacherUid: 'baskaOgr'),
          _randevu('onayli', teacherUid: _uid, durum: 'confirmed'),
        ];
      final kap = kapsayici(
        bulut,
        kendiRandevularim: [_randevu('eski-talep', ogretmenAdi: _profil.fullName)],
        bildirimler: [_bildirim('b1'), _bildirim('b2', durum: 'acknowledged')],
      );

      final d = await kap.read(gelenKutusuProvider.future);
      expect(d.bulutVar, isTrue);
      expect(d.eksik, isFalse);
      expect([for (final s in d.siniflar) '${s.ad}|${s.kendi}|${s.aciklama}'], [
        '5-A|true|Rehberlik sınıfım',
        '7-C|false|Türkçe · sınıf öğretmeni Ayşe Demir',
      ]);
      expect(d.sohbetler.first.classCloudId, _kadroCls, reason: 'en yeni sohbet üstte');
      final kendi = d.sohbetler.firstWhere((o) => o.classCloudId == _cls);
      expect(kendi.studentName, 'Ali YILMAZ');
      expect(kendi.parentName, 'Anne: Fatma YILMAZ');
      expect(d.sohbetler.firstWhere((o) => o.classCloudId == _kadroCls).studentName, 'Can ÖZ');
      expect([for (final r in d.randevular) r.randevu.id], unorderedEquals(['eski-talep', 'bana']));
      expect(bulut.randevuSorgulari, ['$_kadroCls|$_uid'],
          reason: 'kadro sınıfında süzgeçsiz sorguyu kural reddeder, randevular sessizce kaybolurdu');
      expect([for (final b in d.bildirimler) b.bildirim.id], ['b1']);
      expect(d.okunmamisMesaj, 2);
      expect(d.rozet, 5);
    });

    test('kadro sınıfları her açılışta değil, 6 saatte bir sorulur', () async {
      final bulut = _SahteBulut()..kadro = const [_kadroSinifi];
      final kap = kapsayici(bulut);
      await kap.read(gelenKutusuProvider.future);
      kap.invalidate(gelenKutusuProvider);
      await kap.read(gelenKutusuProvider.future);
      expect(bulut.kadroSorgusu, 1);

      GelenKutusuDeposu(_uid).kadroZamani = DateTime.now().subtract(const Duration(hours: 7));
      kap.invalidate(gelenKutusuProvider);
      final d = await kap.read(gelenKutusuProvider.future);
      expect(bulut.kadroSorgusu, 2);
      expect(d.siniflar.length, 2);
    });

    test('kadro okunamazsa eksik denir; rehberlik sınıfı yine gelir', () async {
      final bulut = _SahteBulut()
        ..kadroBozuk = true
        ..sunucu[_cls] = [_mesaj('m1', zaman: _t(10))];
      final d = await kapsayici(bulut).read(gelenKutusuProvider.future);
      expect(d.eksik, isTrue);
      expect(d.siniflar.single.kendi, isTrue);
      expect(d.okunmamisMesaj, 1);
    });

    test('Google girişi yoksa kutu bulutsuz; buluta hiç sorulmaz', () async {
      final bulut = _SahteBulut();
      final d = await kapsayici(bulut, profilId: 'yerel_1').read(gelenKutusuProvider.future);
      expect(d.bulutVar, isFalse);
      expect(bulut.kadroSorgusu, 0);
      expect(bulut.sorgular, isEmpty);
    });
  });

  group('Ekranlar', () {
    Future<void> bekleKadar(WidgetTester tester, bool Function() kosul) async {
      for (var i = 0; i < 200 && !kosul(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    setUpAll(() async {
      // Gerçek yazı tipi: test yazı tipinde her harf kare çizilir.
      final yukleyici = FontLoader('Roboto')
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
      await yukleyici.load();
    });

    void buyukEkran(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
    }

    Future<void> hazirDurumla(WidgetTester tester, Widget ekran, GelenKutusuDurumu durum) async {
      buyukEkran(tester);
      await tester.pumpWidget(ProviderScope(
        // Her çağrıda yeni kapsam: sağlayıcı geçersiz kılmaları değiştirilemez.
        key: UniqueKey(),
        overrides: [
          gelenKutusuProvider.overrideWith((ref) async => durum),
          teacherProfileProvider.overrideWith((ref) => _SahteProfil(_profil)),
        ],
        child: MaterialApp(home: ekran),
      ));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('KRITIK: sohbet açılıp kapanınca okunmamış sıfırlanır, Bugün kartı da güncellenir', (tester) async {
      buyukEkran(tester);
      final bulut = _SahteBulut()
        ..sunucu[_cls] = [
          _mesaj('v1',
              zaman: DateTime.now().subtract(const Duration(hours: 1)),
              ogrenciAdi: 'Ali YILMAZ',
              govde: 'Hocam ödev ne zaman?'),
        ];
      final kap = ProviderContainer(overrides: [
        teacherProfileProvider.overrideWith((ref) => _SahteProfil(_profil)),
        cloudCommunicationRepositoryProvider.overrideWithValue(bulut),
        homeroomClassProvider.overrideWithValue(_rehberlik),
        classLinkedParentsProvider(_rehberlik).overrideWith((ref) async => [_bag()]),
        classAppointmentsCloudProvider(_cls).overrideWith((ref) async => const []),
        classStatusReportsCloudProvider(_cls).overrideWith((ref) async => const []),
      ]);
      addTearDown(kap.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: kap,
        child: const MaterialApp(home: Scaffold(body: GelenKutusuKarti(isDark: false))),
      ));
      await bekleKadar(tester, () => find.text('1 okunmamış mesaj').evaluate().isNotEmpty);
      expect(find.text('1 okunmamış mesaj'), findsOneWidget);
      expect(find.byKey(const ValueKey('bugun_gelen_kutusu_rozet')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('bugun_gelen_kutusu')));
      await bekleKadar(tester, () => find.byKey(ValueKey('gk_okunmamis_$_anahtar')).evaluate().isNotEmpty);
      expect(find.text('Ali YILMAZ · 5-A'), findsOneWidget);
      expect(find.text('Fatma YILMAZ: Hocam ödev ne zaman?'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('gk_sohbet_$_anahtar')));
      await bekleKadar(tester, () => find.byType(ParentTeacherChatModal).evaluate().isNotEmpty);
      await tester.pump(const Duration(milliseconds: 500));
      Navigator.of(tester.element(find.byType(ParentTeacherChatModal))).pop();
      await bekleKadar(tester, () => find.byKey(ValueKey('gk_okunmamis_$_anahtar')).evaluate().isEmpty);
      expect(find.byKey(ValueKey('gk_okunmamis_$_anahtar')), findsNothing);
      expect(find.text('Okunmamış mesaj yok'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      Navigator.of(tester.element(find.byType(GelenKutusuEkrani))).pop();
      await bekleKadar(tester, () => find.text('Yeni bir şey yok').evaluate().isNotEmpty);
      expect(find.text('Yeni bir şey yok'), findsOneWidget);
      expect(find.byKey(const ValueKey('bugun_gelen_kutusu_rozet')), findsNothing);
    });

    testWidgets('hepsi tek listede; süzgeç ve sınıf çipleri daraltır', (tester) async {
      await hazirDurumla(tester, const GelenKutusuEkrani(), _ornekDurum());

      const bildirim = 'Erken çıkış: Saat 12:30 hastaneye';
      const randevu = 'Konu: Ödev takibi';
      expect(find.text(bildirim), findsOneWidget);
      expect(find.text(randevu), findsOneWidget);
      expect(find.text('Ali YILMAZ · 5-A'), findsOneWidget);
      expect(find.text('Can ÖZ · 7-C'), findsOneWidget);
      expect(find.text('2 okunmamış mesaj'), findsOneWidget);
      expect(find.text('⭐ 5-A'), findsOneWidget, reason: 'rehberlik sınıfı çipte işaretli');

      await tester.tap(find.byKey(const ValueKey('gk_suzgec_mesajlar')));
      await tester.pump();
      expect(find.text(bildirim), findsNothing);
      expect(find.text(randevu), findsNothing);
      expect(find.text('Ali YILMAZ · 5-A'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('gk_suzgec_randevular')));
      await tester.pump();
      expect(find.text(randevu), findsOneWidget);
      expect(find.text('Ali YILMAZ · 5-A'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('gk_suzgec_tumu')));
      await tester.pump();
      await tester.tap(find.text('7-C'));
      await tester.pump();
      expect(find.text('Can ÖZ · 7-C'), findsOneWidget);
      expect(find.text('Ali YILMAZ · 5-A'), findsNothing);
      expect(find.text(bildirim), findsNothing, reason: 'bildirim 5-A sınıfının');
    });

    testWidgets('Veliler sayfasından açılınca yalnız o sınıf', (tester) async {
      await hazirDurumla(tester, const GelenKutusuEkrani(sinif: _kadroCls), _ornekDurum());
      expect(find.text('Can ÖZ · 7-C'), findsOneWidget);
      expect(find.text('Ali YILMAZ · 5-A'), findsNothing);
      expect(find.text('Konu: Ödev takibi'), findsNothing);
    });

    testWidgets('bulut yoksa açıklama, kutu boşsa yönlendirme, eksikse uyarı', (tester) async {
      await hazirDurumla(tester, const GelenKutusuEkrani(), GelenKutusuDurumu.bulutsuz);
      expect(find.textContaining('Google ile giriş yaptığınızda açılır'), findsOneWidget);

      await hazirDurumla(
        tester,
        const GelenKutusuEkrani(key: ValueKey('bos')),
        const GelenKutusuDurumu(
            bulutVar: true, siniflar: [], sohbetler: [], randevular: [], bildirimler: [], eksik: true),
      );
      expect(find.textContaining('Rehberlik sınıfınızda veli kodu dağıtın'), findsOneWidget);
      expect(find.textContaining('Bazı sınıflar güncellenemedi'), findsOneWidget);
    });

    testWidgets('Bugün kartı: sayılar ve rozet; yeni bir şey yoksa sade; bulut yoksa hiç yok', (tester) async {
      await hazirDurumla(tester, const Scaffold(body: GelenKutusuKarti(isDark: false)), _ornekDurum());
      expect(find.text('2 okunmamış mesaj · 1 randevu talebi · 1 veli bildirimi'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('bugun_gelen_kutusu_rozet')), matching: find.text('4')),
        findsOneWidget,
      );

      await hazirDurumla(
        tester,
        const Scaffold(body: GelenKutusuKarti(key: ValueKey('sade'), isDark: false)),
        const GelenKutusuDurumu(
            bulutVar: true, siniflar: [], sohbetler: [], randevular: [], bildirimler: [], eksik: false),
      );
      expect(find.text('Yeni bir şey yok'), findsOneWidget);
      expect(find.byKey(const ValueKey('bugun_gelen_kutusu_rozet')), findsNothing);

      await hazirDurumla(
        tester,
        const Scaffold(body: GelenKutusuKarti(key: ValueKey('bulutsuz'), isDark: false)),
        GelenKutusuDurumu.bulutsuz,
      );
      expect(find.text('Veli gelen kutusu'), findsNothing, reason: 'masaüstü yerel kipte kart yok');
    });
  });

  group('Kurallar ve indeksler (yayına gidecek dosyalar)', () {
    test('kadro satırları yalnız sahibine listelenir', () {
      final kurallar = File('firestore.rules').readAsStringSync().replaceAll('\r\n', '\n');
      expect(kurallar, contains('match /{path=**}/staff/{staffId} {\n      allow list: if request.auth != null\n'
          '        && resource.data.teacherUid == request.auth.uid;'));
      expect(kurallar.contains('match /school_admin_requests/'), isFalse, reason: 'okul yöneticiliği kalktı');
    });

    test('gelen kutusu sorgularının indeksleri tanımlı', () {
      final j = jsonDecode(File('firestore.indexes.json').readAsStringSync()) as Map<String, dynamic>;
      final indeksler = [
        for (final i in j['indexes'] as List)
          '${i['collectionGroup']}:${[for (final f in i['fields'] as List) '${f['fieldPath']}-${f['order']}'].join(',')}',
      ];
      expect(indeksler, contains('messages:teacherUid-ASCENDING,createdAt-DESCENDING'));
      expect(indeksler, contains('appointments:teacherUid-ASCENDING,createdAt-DESCENDING'));
      final kadro = (j['fieldOverrides'] as List).firstWhere(
          (f) => f['collectionGroup'] == 'staff' && f['fieldPath'] == 'teacherUid') as Map<String, dynamic>;
      expect([for (final i in kadro['indexes'] as List) i['queryScope']], contains('COLLECTION_GROUP'));
    });
  });
}

GelenKutusuDurumu _ornekDurum() => GelenKutusuDurumu(
      bulutVar: true,
      siniflar: const [
        GelenKutusuSinifi(classCloudId: _cls, ad: '5-A', kendi: true, aciklama: 'Rehberlik sınıfım'),
        GelenKutusuSinifi(classCloudId: _kadroCls, ad: '7-C', kendi: false, aciklama: 'Türkçe'),
      ],
      sohbetler: [
        SohbetOzeti(
          classCloudId: _cls,
          studentCloudId: 'stu1',
          parentUserId: 'veli1',
          studentName: 'Ali YILMAZ',
          parentName: 'Fatma YILMAZ',
          sonMesaj: 'Hocam ödev ne zaman?',
          sonZaman: _t(10),
          sonYazanVeli: true,
          okunmamis: 2,
        ),
        SohbetOzeti(
          classCloudId: _kadroCls,
          studentCloudId: 'stu7',
          parentUserId: 'veli7',
          studentName: 'Can ÖZ',
          parentName: 'Hasan ÖZ',
          sonMesaj: 'Teşekkürler',
          sonZaman: _t(9),
          sonYazanVeli: false,
          okunmamis: 0,
        ),
      ],
      randevular: [(classCloudId: _cls, randevu: _randevu('r1', teacherUid: _uid))],
      bildirimler: [(classCloudId: _cls, bildirim: _bildirim('b1'))],
      eksik: false,
    );

CloudMessage _mesaj(
  String id, {
  required DateTime zaman,
  bool ogretmen = false,
  String stu = 'stu1',
  String veli = 'veli1',
  String govde = '',
  String ogrenciAdi = '',
  String yazar = 'Fatma YILMAZ',
}) =>
    CloudMessage(
      id: id,
      studentCloudId: stu,
      parentUserId: veli,
      authorRole: ogretmen ? 'teacher' : 'parent',
      authorName: ogretmen ? 'Deneme ÖĞRETMEN' : yazar,
      authorUid: ogretmen ? _uid : veli,
      teacherUid: _uid,
      studentName: ogrenciAdi,
      body: govde.isEmpty ? 'mesaj $id' : govde,
      createdAt: zaman,
    );

CloudAppointment _randevu(String id, {String teacherUid = '', String ogretmenAdi = '', String durum = 'pending'}) =>
    CloudAppointment(
      id: id,
      studentCloudId: 'stu1',
      studentName: 'Ali YILMAZ',
      parentUserId: 'veli1',
      parentName: 'Fatma YILMAZ',
      teacherName: ogretmenAdi,
      appointmentDate: DateTime(2026, 10, 20),
      timeSlot: '13:30',
      topic: 'Ödev takibi',
      status: durum,
      createdAt: DateTime(2026, 10, 17),
      teacherUid: teacherUid,
    );

CloudStatusReport _bildirim(String id, {String durum = 'pending'}) => CloudStatusReport(
      id: id,
      studentCloudId: 'stu1',
      studentName: 'Ali YILMAZ',
      parentUserId: 'veli1',
      parentName: 'Fatma YILMAZ',
      type: 'early_leave',
      title: 'Erken çıkış',
      details: 'Saat 12:30 hastaneye',
      createdAt: DateTime(2026, 10, 18, 8),
      status: durum,
    );

ParentLinkModel _bag() => ParentLinkModel(
      id: 'bag1',
      parentUserId: 'veli1',
      parentName: 'Fatma YILMAZ',
      studentId: 1,
      studentName: 'Ali YILMAZ',
      studentNumber: 1,
      schoolId: 'okul1',
      schoolName: 'Okul',
      classId: 1,
      className: '5-A',
      linkedAt: DateTime(2026, 10, 1),
      linkedViaTokenCode: 'kod',
      classCloudId: _cls,
      studentCloudId: 'stu1',
      teacherUid: _uid,
    );

class _SahteProfil extends TeacherProfileNotifier {
  _SahteProfil(TeacherProfileModel profil) {
    state = profil;
  }

  @override
  Future<void> loadProfileFromStorage() async {}
}

/// Sunucunun gelen kutusu sorgusunu taklit eder: `teacherUid` eşit,
/// `createdAt > since`, yeniden eskiye.
class _SahteBulut extends CloudCommunicationRepository {
  final sunucu = <String, List<CloudMessage>>{};
  final randevular = <String, List<CloudAppointment>>{};
  final bozukSiniflar = <String>{};
  final sorgular = <String>[];
  final randevuSorgulari = <String>[];
  List<KadroSinifi> kadro = const [];
  var kadroBozuk = false;
  var kadroSorgusu = 0;

  /// Doluysa ağ yanıtı bu tamamlanana kadar gecikir.
  Completer<void>? kapi;

  @override
  Future<List<CloudMessage>> fetchTeacherInbox({
    required String classCloudId,
    required String teacherUid,
    DateTime? since,
    int limit = 100,
  }) async {
    sorgular.add('$classCloudId>${since?.toIso8601String() ?? '-'}');
    if (kapi != null) await kapi!.future;
    if (bozukSiniflar.contains(classCloudId)) throw Exception('bağlantı yok');
    final liste = [
      for (final m in sunucu[classCloudId] ?? const <CloudMessage>[])
        if (m.teacherUid == teacherUid && (since == null || m.createdAt.isAfter(since))) m,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return liste.take(limit).toList();
  }

  @override
  Future<List<KadroSinifi>> fetchMyStaffClasses(String teacherUid) async {
    kadroSorgusu++;
    if (kadroBozuk) throw Exception('bağlantı yok');
    return kadro;
  }

  /// Kural kadrodaki öğretmene yalnız `teacherUid == kendisi` sorgusunu
  /// açar; sunucu gibi süzer.
  @override
  Future<List<CloudAppointment>> fetchAppointments({
    required String classCloudId,
    String? studentCloudId,
    String? teacherUid,
    int limit = 50,
  }) async {
    randevuSorgulari.add('$classCloudId|${teacherUid ?? '-'}');
    return [
      for (final a in randevular[classCloudId] ?? const <CloudAppointment>[])
        if (teacherUid == null || a.teacherUid == teacherUid) a,
    ];
  }

  @override
  Future<List<CloudMessage>> fetchMessages({
    required String classCloudId,
    required String studentCloudId,
    String? teacherUid,
    DateTime? since,
    int limit = 50,
  }) async =>
      const [];
}
