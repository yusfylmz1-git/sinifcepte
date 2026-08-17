import 'package:flutter/material.dart';

class LessonModel {
  final int? id; // SQLite ID
  final String? docId; // Cloud ID (if needed later)
  final String lessonName;
  final String className;
  final String day;
  final int lessonHourIndex;
  final Color color;

  LessonModel({
    this.id,
    this.docId,
    required this.lessonName,
    required this.className,
    required this.day,
    required this.lessonHourIndex,
    required this.color,
  });

  int get colorValue => color.toARGB32();

  LessonModel copyWith({
    int? id,
    String? docId,
    String? lessonName,
    String? className,
    String? day,
    int? lessonHourIndex,
    Color? color,
  }) {
    return LessonModel(
      id: id ?? this.id,
      docId: docId ?? this.docId,
      lessonName: lessonName ?? this.lessonName,
      className: className ?? this.className,
      day: day ?? this.day,
      lessonHourIndex: lessonHourIndex ?? this.lessonHourIndex,
      color: color ?? this.color,
    );
  }

  factory LessonModel.fromMap(Map<String, dynamic> map, {String? firebaseId}) {
    return LessonModel(
      id: map['id'],
      docId: firebaseId ?? map['doc_id'],
      lessonName: map['ders_adi'] ?? map['dersAdi'] ?? '',
      className: map['sinif'] ?? '',
      day: map['gun'] ?? '',
      lessonHourIndex: map['ders_saati_index'] ?? map['dersSaatiIndex'] ?? 0,
      color: Color(map['renk'] ?? 0xFF2196F3),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doc_id': docId,
      'ders_adi': lessonName,
      'sinif': className,
      'gun': day,
      'ders_saati_index': lessonHourIndex,
      'renk': color.toARGB32(),
      'olusturulma_tarihi': DateTime.now().toIso8601String(),
    };
  }
}
