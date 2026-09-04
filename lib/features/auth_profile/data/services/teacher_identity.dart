import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/cloud/cloud_ids.dart';
import '../../../../core/firebase/firebase_bootstrap.dart';
import '../models/teacher_profile_model.dart';

/// Öğretmenin bulut kimliğini tek bir yerden çözer.
///
/// ## Neden gerekliydi
/// Kimlik iki farklı şekilde çözülüyordu: referans kodu üretimi
/// `FirebaseAuth.instance.currentUser?.uid` kullanırken, kadro ekranı
/// ve diğer yerler `teacherProfile.id` kullanıyordu. İkisi farklı
/// olduğunda sınıfın bulut kimliği (`cls_{uid}_{id}`) de farklı çıkıyor
/// ve veriler İKİ AYRI sınıf odasına yazılıyordu: veli bir odaya
/// bakarken kadro satırı diğerine yazılıyor, bu yüzden veli sınıf
/// öğretmenini hiç göremiyordu.
///
/// Kural motoru da `cls_{uid}_*` desenine dayandığı için yanlış kimlik
/// yalnızca "veri görünmüyor" değil, "yazma reddedildi" hatası da
/// doğurur.
class TeacherIdentity {
  const TeacherIdentity._();

  /// Bulut işlemlerinde kullanılacak öğretmen kimliği.
  ///
  /// Öncelik sırası bilinçlidir:
  ///  1. Canlı Firebase oturumu — kural motorunun gördüğü kimlik budur.
  ///  2. Profildeki kimlik — oturum henüz hazır değilse (açılış anı).
  ///
  /// Hiçbiri geçerli değilse boş döner; çağıran taraf bulut işlemini
  /// atlamalıdır (masaüstü yerel modu böyle çalışır).
  static String resolve(TeacherProfileModel profile) {
    if (FirebaseBootstrap.ready) {
      final live = FirebaseAuth.instance.currentUser?.uid;
      if (live != null && live.isNotEmpty) return live;
    }

    if (CloudIds.isValidUid(profile.id)) return profile.id;
    return '';
  }

  /// Bulut işlemleri yapılabilir mi?
  static bool canUseCloud(TeacherProfileModel profile) =>
      CloudIds.isValidUid(resolve(profile));
}
