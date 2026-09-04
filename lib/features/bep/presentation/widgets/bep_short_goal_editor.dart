import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/bep_option_banks.dart';
import '../../data/models/bep_models.dart';
import 'bep_option_chips.dart';
import 'bep_outcome_picker.dart';

class BepShortGoalEditor {
  BepShortGoalEditor._();

  static Future<BepShortGoal?> show(
    BuildContext context, {
    required int longGoalId,
    BepShortGoal? existing,
    required int gradeLevel,
    required String subjectCode,
  }) {
    return showDialog<BepShortGoal>(
      context: context,
      builder: (_) => _EditorDialog(
        longGoalId: longGoalId,
        existing: existing,
        gradeLevel: gradeLevel,
        subjectCode: subjectCode,
      ),
    );
  }
}

class _EditorDialog extends StatefulWidget {
  final int longGoalId;
  final BepShortGoal? existing;
  final int gradeLevel;
  final String subjectCode;

  const _EditorDialog({
    required this.longGoalId,
    this.existing,
    required this.gradeLevel,
    required this.subjectCode,
  });

  @override
  State<_EditorDialog> createState() => _EditorDialogState();
}

class _EditorDialogState extends State<_EditorDialog> {
  late final TextEditingController _condition;
  late final TextEditingController _behavior;
  late final TextEditingController _criterion;

  /// Yontem, materyal ve olcme ARTIK metin kutusu degil.
  ///
  /// Onceden tek bir "Yontem / materyal" kutusu vardi; PDF ise bunlari
  /// AYRI UC SUTUNA basiyordu. Iki sutun modelde hic yoktu, sabit
  /// metinle dolduruluyordu. Simdi ucu de bankadan secilir.
  String _method = '';
  String _materials = '';
  String _assessment = '';
  String? _outcomeCode;
  String? _outcomeDescription;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _condition = TextEditingController(text: e?.condition ?? 'Sınıf ortamında');
    _behavior = TextEditingController(text: e?.behavior ?? '');
    _criterion = TextEditingController(text: e?.criterion ?? '4 denemenin 3\'ünde');
    _method = e?.method ?? '';
    _materials = e?.materials ?? '';
    _assessment = e?.assessment ?? '';
    _outcomeCode = e?.outcomeCode;
    _outcomeDescription = e?.outcomeDescription;
  }

  @override
  void dispose() {
    _condition.dispose();
    _behavior.dispose();
    _criterion.dispose();
    super.dispose();
  }

  Future<void> _pickSeed() async {
    if (widget.gradeLevel < 1 || widget.subjectCode.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu planın kademesi veya dersi eksik.')),
      );
      return;
    }
    final hit = await BepOutcomePicker.show(
      context,
      gradeLevel: widget.gradeLevel,
      subjectCode: widget.subjectCode,
    );
    if (hit == null || !mounted) return;
    setState(() {
      _outcomeCode = hit.code;
      _outcomeDescription = hit.description;
      if (_behavior.text.trim().isEmpty) {
        _behavior.text = hit.description;
      }
    });
  }

  void _save() {
    final goal = BepShortGoal(
      id: widget.existing?.id,
      longGoalId: widget.longGoalId,
      condition: _condition.text.trim(),
      behavior: _behavior.text.trim(),
      criterion: _criterion.text.trim(),
      method: _method.trim(),
      materials: _materials.trim(),
      assessment: _assessment.trim(),
      outcomeCode: _outcomeCode,
      outcomeDescription: _outcomeDescription,
      orderIndex: widget.existing?.orderIndex ?? 0,
    );
    if (!goal.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Koşul, davranış ve ölçüt doldurulmalı.'),
        ),
      );
      return;
    }
    Navigator.pop(context, goal);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kısa dönemli amaç'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: _pickSeed,
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('MEB kazanımından tohumla'),
            ),
            if (_outcomeCode != null && _outcomeCode!.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tohum: $_outcomeCode',
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _condition,
              maxLength: 200,
              inputFormatters: [LengthLimitingTextInputFormatter(200)],
              decoration: const InputDecoration(
                labelText: 'Koşul',
                hintText: 'Sınıf ortamında / görsel destekle',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _behavior,
              maxLines: 3,
              maxLength: 400,
              decoration: const InputDecoration(
                labelText: 'Davranış',
                hintText: '2 basamaklı sayıları okur',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _criterion,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Ölçüt',
                hintText: '4 denemenin 3\'ünde',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            BepSingleChips(
              baslik: 'Hazır ölçütler',
              banka: bepOlcutBankasi,
              secili: _criterion.text.trim(),
              onChanged: (v) => setState(() => _criterion.text = v),
            ),
            const SizedBox(height: 14),
            BepOptionChips(
              baslik: 'Yöntem ve Teknik',
              banka: bepYontemBankasi,
              secili: _method,
              onChanged: (v) => setState(() => _method = v),
            ),
            const SizedBox(height: 14),
            BepOptionChips(
              baslik: 'Kullanılacak Materyaller',
              banka: bepMateryalBankasi,
              secili: _materials,
              onChanged: (v) => setState(() => _materials = v),
            ),
            const SizedBox(height: 14),
            BepOptionChips(
              baslik: 'Ölçme-Değerlendirme',
              banka: bepOlcmeBankasi,
              secili: _assessment,
              onChanged: (v) => setState(() => _assessment = v),
            ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Kaydet')),
      ],
    );
  }
}
