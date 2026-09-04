import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/search_debouncer.dart';
import '../../../outcomes/data/models/curriculum_outcome_model.dart';
import '../../../outcomes/data/repositories/curriculum_outcome_repository.dart';

/// MEB kazanımını BEP kısa amacına tohum olarak seçer.
class BepOutcomePicker {
  BepOutcomePicker._();

  static Future<UniqueOutcomeHit?> show(
    BuildContext context, {
    required int gradeLevel,
    String? subjectCode,
  }) {
    return showModalBottomSheet<UniqueOutcomeHit>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PickerBody(
        gradeLevel: gradeLevel,
        subjectCode: subjectCode,
      ),
    );
  }
}

class _PickerBody extends StatefulWidget {
  final int gradeLevel;
  final String? subjectCode;

  const _PickerBody({required this.gradeLevel, this.subjectCode});

  @override
  State<_PickerBody> createState() => _PickerBodyState();
}

class _PickerBodyState extends State<_PickerBody> {
  final _repo = CurriculumOutcomeRepository();
  final _debouncer = SearchDebouncer();
  final _query = TextEditingController();
  List<UniqueOutcomeHit> _hits = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final hits = await _repo.searchUniqueOutcomes(
        gradeLevel: widget.gradeLevel,
        subjectCode: widget.subjectCode,
        query: q,
      );
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MEB kazanımından tohumla',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kazanım BEP değildir. Seçilen metin davranış cümlesine kopyalanır; koşul ve ölçütü siz yazarsınız. '
                '${widget.gradeLevel}. sınıf${widget.subjectCode == null ? '' : ' · ${widget.subjectCode}'}.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _query,
                decoration: const InputDecoration(
                  hintText: 'Kod veya metin ara',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _debouncer.run(() => _search(v)),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _hits.isEmpty
                        ? const Center(child: Text('Kazanım bulunamadı'))
                        : ListView.builder(
                            itemCount: _hits.length,
                            itemBuilder: (ctx, i) {
                              final h = _hits[i];
                              return ListTile(
                                title: Text(
                                  h.label,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  h.unitTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => Navigator.pop(context, h),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
