import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/moderasyon.dart';

/// Bildir ve engelle deposu (testte sahtesiyle değiştirilir).
final moderasyonDeposuProvider = Provider<ModerasyonDeposu>((ref) => ModerasyonDeposu());
