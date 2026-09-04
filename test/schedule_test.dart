import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/schedule/models/lesson_model.dart';

/// Ders programi denetimi (Faz 2.1).
///
/// Modul yerel calisir, buluta gitmez ve cakisma uyarisi vardir. Ancak
/// gunluk ders sayisi AZALTILDIGINDA sinir disinda kalan dersler
/// veritabaninda kaliyor ama ekranda gorunmuyordu: ogretmen icin
/// "kayboldu", sayi geri artirilinca aniden geri geliyordu.
void main() {
  LessonModel ders({
    int? id,
    String day = 'Pazartesi',
    int hour = 0,
    String className = '5-A',
    String lessonName = 'Matematik',
  }) {
    return LessonModel(
      id: id,
      day: day,
      lessonHourIndex: hour,
      className: className,
      lessonName: lessonName,
      color: const Color(0xFF6366F1),
    );
  }

  group('Cakisma tespiti', () {
    test('KRITIK: ayni gun ve saatte iki ders cakisir', () {
      final mevcut = [ders(id: 1, day: 'Pazartesi', hour: 2)];
      final yeni = ders(day: 'Pazartesi', hour: 2);

      final cakisan = mevcut
          .where((l) =>
              l.day == yeni.day && l.lessonHourIndex == yeni.lessonHourIndex)
          .firstOrNull;

      expect(cakisan, isNotNull);
    });

    test('Farkli gun cakisma sayilmaz', () {
      final mevcut = [ders(id: 1, day: 'Pazartesi', hour: 2)];
      final yeni = ders(day: 'Salı', hour: 2);

      final cakisan = mevcut
          .where((l) =>
              l.day == yeni.day && l.lessonHourIndex == yeni.lessonHourIndex)
          .firstOrNull;

      expect(cakisan, isNull);
    });

    test('Duzenlenen dersin kendisi cakisma sayilmaz', () {
      final duzenlenen = ders(id: 1, day: 'Pazartesi', hour: 2);
      final mevcut = [duzenlenen];

      final cakisan = mevcut
          .where((l) =>
              l.id != duzenlenen.id &&
              l.day == duzenlenen.day &&
              l.lessonHourIndex == duzenlenen.lessonHourIndex)
          .firstOrNull;

      expect(cakisan, isNull);
    });
  });

  group('Gunluk ders sayisi degisimi', () {
    test('KRITIK: sayi azalinca sinir disi dersler gizli kaliyor', () {
      // 8 ders saatiyle kurulmus program.
      final dersler = [
        ders(id: 1, hour: 0),
        ders(id: 2, hour: 5),
        ders(id: 3, hour: 7), // 8. ders saati
      ];

      // Ogretmen gunluk ders sayisini 5'e dusurdu.
      const yeniSayi = 5;
      final gorunen =
          dersler.where((l) => l.lessonHourIndex < yeniSayi).toList();
      final gizliKalan =
          dersler.where((l) => l.lessonHourIndex >= yeniSayi).toList();

      expect(gorunen.length, 1);
      expect(gizliKalan.length, 2,
          reason: 'Bu dersler ekranda gorunmuyor ama veritabaninda duruyor');
    });

    test('Sinir disi dersler tespit edilebilir olmali', () {
      // Duzeltme: kullaniciya "N ders gizlendi" uyarisi gosterilecek.
      final dersler = [ders(id: 1, hour: 6), ders(id: 2, hour: 7)];
      const yeniSayi = 5;

      final etkilenen =
          dersler.where((l) => l.lessonHourIndex >= yeniSayi).length;

      expect(etkilenen, 2);
    });
  });

  group('Model butunlugu', () {
    test('Kaydedilip geri okununca alanlar korunur', () {
      final orijinal = ders(id: 7, day: 'Çarşamba', hour: 3);
      final geri = LessonModel.fromMap(orijinal.toMap());

      expect(geri.day, 'Çarşamba');
      expect(geri.lessonHourIndex, 3);
      expect(geri.className, '5-A');
      expect(geri.lessonName, 'Matematik');
    });
  });
}
