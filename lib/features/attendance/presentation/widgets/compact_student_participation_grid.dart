import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../data/models/classroom_participation_model.dart';
import '../../providers/classroom_participation_provider.dart';
import 'quick_student_eval_dialog.dart';
import '../../../../core/utils/turkish_text.dart';

/// SınıfCepte - Tek Sayfada Sıralı & Cinsiyet Temalı Mini Öğrenci Kartları Izgarası (UI-UX-MAX)
class CompactStudentParticipationGrid extends ConsumerWidget {
  final ClassroomParticipationSession session;
  final String searchQuery;

  const CompactStudentParticipationGrid({
    super.key,
    required this.session,
    this.searchQuery = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Arama Sorgusu Filtreleme (İsim veya Okul Numarası)
    final query = searchQuery.trim().toLowerCase();
    final evaluations = query.isEmpty
        ? session.evaluations
        : session.evaluations.where((e) {
            // `toLowerCase` Turkce'de yaniltiyordu.
            final nameMatches = trContains(e.studentName, searchQuery);
            final numMatches = e.studentNumber.toString().contains(query);
            return nameMatches || numMatches;
          }).toList();

    if (evaluations.isEmpty) {
      if (query.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
                const SizedBox(height: 12),
                Text(
                  '"$searchQuery" ile eşleşen öğrenci bulunamadı',
                  style: AppFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline_rounded,
                size: 52,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
              const SizedBox(height: 12),
              Text(
                'Bu sınıfta kayıtlı öğrenci bulunamadı.',
                style: AppFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sınıflar menüsünden öğrenci ekleyebilir veya e-Okul listesini içe aktarabilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Ekran genişliğine göre dinamik ve sığdırılabilir sütun sayısı
        final width = constraints.maxWidth;
        int crossAxisCount = 4;
        if (width < 340) {
          crossAxisCount = 3;
        } else if (width >= 340 && width < 480) {
          crossAxisCount = 4;
        } else if (width >= 480 && width < 720) {
          crossAxisCount = 5;
        } else {
          crossAxisCount = 6;
        }

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.76, // Kartların taşmadan sığmasını sağlayan ideal güvenli oran
          ),
          itemCount: evaluations.length,
          itemBuilder: (context, index) {
            final student = evaluations[index];
            return _buildStudentMiniCard(context, ref, student, isDark);
          },
        );
      },
    );
  }

  Widget _buildStudentMiniCard(
    BuildContext context,
    WidgetRef ref,
    StudentParticipationEvaluation student,
    bool isDark,
  ) {
    final isFemale = student.isFemale;

    // Cinsiyet Temalı Renk Paletleri
    final Color cardBg = isFemale
        ? (isDark ? const Color(0xFF2A1522) : const Color(0xFFFFF1F4))
        : (isDark ? const Color(0xFF132035) : const Color(0xFFF0F7FF));

    final Color cardBorder = isFemale
        ? (isDark ? const Color(0xFF88254A) : const Color(0xFFFECDD3))
        : (isDark ? const Color(0xFF1E3A6E) : const Color(0xFFBFDBFE));

    final Color avatarBg = isFemale
        ? const Color(0xFFFB7185)
        : const Color(0xFF38BDF8);

    final Color numberColor = isFemale
        ? (isDark ? const Color(0xFFFDA4AF) : const Color(0xFFE11D48))
        : (isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0284C7));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        // TEK DOKUNUS = +1 soz hakki.
        //
        // Eskiden dokunmak 962 satirlik diyalogu aciyordu; 30 ogrenci
        // icin ~120 dokunus gerekiyordu. Ders 40 dakika ve ogretmen
        // ayni anda ders anlatiyor. Modul bu yuzden cihazda SIFIR
        // kayitla duruyordu.
        onTap: () {
          HapticFeedback.selectionClick();
          ref
              .read(currentParticipationSessionProvider.notifier)
              .addSpeakingTurn(student.studentId);
        },
        // Yanlis ogrenciye dokunulursa geri alinir.
        onDoubleTap: () {
          HapticFeedback.lightImpact();
          ref
              .read(currentParticipationSessionProvider.notifier)
              .removeSpeakingTurn(student.studentId);
        },
        // UZUN BAS = detayli degerlendirme (odev, materyal, not).
        // Nadiren gerekir; ders sonunda ya da "bu cocuk bugun cok
        // dagilmis" dendiginde.
        onLongPress: () {
          HapticFeedback.mediumImpact();
          QuickStudentEvalDialog.show(
            context: context,
            evaluation: student,
            subjectName: session.subjectName,
            date: session.date,
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: isFemale
                    ? Colors.pink.withValues(alpha: isDark ? 0.08 : 0.04)
                    : Colors.blue.withValues(alpha: isDark ? 0.08 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Üst: Profil Simgesi & Okul No
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Küçük Profil Avatarı
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: avatarBg,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: avatarBg.withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        isFemale ? '👧' : '👦',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  // Okul Numarası
                  Flexible(
                    child: Text(
                      'No: ${student.studentNumber}',
                      style: AppFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: numberColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // 2. Orta: İsim ve Soyad İlk Harfi (Ahmet Y.)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Text(
                  student.shortName,
                  textAlign: TextAlign.center,
                  style: AppFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // 3. SOZ HAKKI — modulun asil derdi.
              //
              // Hic konusmayan ogrenci GRI NOKTA ile gorunur; ogretmen
              // bir bakista "kimi atladim" der. Eskiden bu bilgi hicbir
              // yerde yoktu.
              _buildSpeakingTurns(student, isDark),

              // 4. Alt: Durum Rozetleri Satırı (Ödev, Kitap, Zamanlama, Yıldız)
              _buildMiniStatusRow(student, isDark),
            ],
          ),
        ),
      ),
    );
  }

  /// Söz hakkı göstergesi.
  ///
  /// Üçe kadar yıldız çizilir; fazlası sayıyla gösterilir (⭐×5).
  /// Hiç konuşmamış öğrenci gri nokta alır — ekranda "boş" görünmesi
  /// öğretmene kimi atladığını anlatır.
  Widget _buildSpeakingTurns(
    StudentParticipationEvaluation student,
    bool isDark,
  ) {
    if (student.isSilent) {
      return Text(
        '·',
        style: AppFonts.outfit(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
          height: 1.0,
        ),
      );
    }

    const renk = Color(0xFFF59E0B);

    if (student.speakingTurns <= 3) {
      return Text(
        '⭐' * student.speakingTurns,
        style: const TextStyle(fontSize: 10, height: 1.1),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('⭐', style: TextStyle(fontSize: 10)),
        const SizedBox(width: 1),
        Text(
          '×${student.speakingTurns}',
          style: AppFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: renk,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  /// Kartın en altındaki mini durum simgeleri
  Widget _buildMiniStatusRow(StudentParticipationEvaluation student, bool isDark) {
    // Ödev Rengi
    Color hwColor;
    String hwText;
    switch (student.homeworkStatus) {
      // Isaretlenmemis: notr gri nokta. Onceden varsayilan "done" oldugu
      // icin ogretmen hicbir sey yapmadan da yesil onay goruyordu.
      case HomeworkStatus.unknown:
        hwColor = const Color(0xFF94A3B8);
        hwText = '·';
        break;
      case HomeworkStatus.done:
        hwColor = const Color(0xFF10B981);
        hwText = '✓';
        break;
      case HomeworkStatus.partial:
        hwColor = const Color(0xFFF59E0B);
        hwText = '±';
        break;
      case HomeworkStatus.none:
        hwColor = const Color(0xFFEF4444);
        hwText = '✗';
        break;
      case HomeworkStatus.notGiven:
        hwColor = Colors.grey;
        hwText = '-';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 1. Ödev İkonu
            Text(
              hwText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: hwColor,
              ),
            ),
            const SizedBox(width: 3),

            // 2. Kitap/Defter Durumu
            Text(
              student.materialsStatus == MaterialsStatus.ready ? '📚' : '❌',
              style: const TextStyle(fontSize: 8.5),
            ),
            const SizedBox(width: 3),

            // 3. Katılım Yıldız Göstergesi (⭐⭐⭐ / ⭐⭐ / ⭐ / -)
            if (student.starsCount > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  student.starsCount,
                  (_) => const Icon(Icons.star_rounded, size: 8.5, color: Color(0xFFF59E0B)),
                ),
              )
            else
              const Text(
                '·',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
              ),

            // 4. Özel Not Rozeti (Varsa)
            if (student.note != null && student.note!.trim().isNotEmpty) ...[
              const SizedBox(width: 2),
              const Text(
                '📝',
                style: TextStyle(fontSize: 8),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
