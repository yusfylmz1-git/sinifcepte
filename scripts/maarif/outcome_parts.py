"""
SınıfCepte - Kazanım metnini yapılandırılmış parçalara ayırır.

Kaynak planlarda bir haftanın hücresi çoğu zaman TEK bir düz metindir ve
içinde birden fazla kazanım ile onların süreç bileşenleri iç içe geçer:

    "Temel Geometrik Çizimler | MAT.5.1.2. ... a) Nokta, doğru ...
     b) ... MAT.5.1.3. ... a) ... b) ..."

Kart bunu tek paragraf olarak basınca hangi maddenin hangi kazanıma ait
olduğu anlaşılmıyordu. Burada metin şu yapıya çevrilir:

    [
      {"code": "MAT.5.1.2", "text": "...", "steps": ["a) ...", "b) ..."]},
      {"code": "MAT.5.1.3", "text": "...", "steps": [...]},
    ]

Böylece uygulama her kazanımı ayrı bir blok olarak gösterebilir.
"""

from __future__ import annotations

import re

# Kazanım kodu biçimleri kaynaktan kaynağa değişiyor:
#   'MAT.5.1.2.'  (branş öneki + son nokta)
#   'BEO.1.1.4'   (son nokta yok)
#   'MARP11.1.1'  (önek ile sınıf bitişik, son nokta yok)
#   '5.1.2.'      (önek yok)
# Sondaki noktayı ZORUNLU tutmak MARP/BEO gibi kodları görünmez yapıyordu;
# o kayıtlar tek blok kalıp haftalara bölünemiyordu.
_CODE = re.compile(
    r"(?:[A-ZÇĞİÖŞÜ]{2,6}\.?)?\d{1,2}(?:\.\d{1,2}){2,}\.?"
)

# Süreç bileşeni maddesi: 'a)' 'b)' 'ç)' — Türkçe harfler dâhil.
_STEP = re.compile(r"(?:^|\s)([a-zçğıöşü])\s*\)\s*")


def find_code_positions(text: str) -> list[tuple[int, str]]:
    """Metindeki gerçek kazanım kodu başlangıçlarını döner.

    Kodun ORTASINDAN eşleşme elenir: '10.1.1.1.' içinde '1.1.1.' de
    desene uyar; önündeki karakter rakam veya nokta ise atlanır.
    """
    positions: list[tuple[int, str]] = []
    for match in _CODE.finditer(text):
        begin = match.start()
        if begin > 0 and text[begin - 1] not in " \t|(":
            continue
        positions.append((begin, match.group().rstrip(".")))
    return positions


def split_steps(text: str) -> tuple[str, list[str]]:
    """Gövdeyi 'a) ... b) ...' maddelerine ayırır.

    Döner: (maddelerden önceki açıklama, madde listesi)
    """
    marks = list(_STEP.finditer(text))
    if not marks:
        return text.strip(), []

    head = text[:marks[0].start()].strip()
    steps: list[str] = []
    for index, match in enumerate(marks):
        finish = marks[index + 1].start() if index + 1 < len(marks) else len(text)
        piece = text[match.start():finish].strip(" |")
        if piece:
            steps.append(re.sub(r"\s+", " ", piece))
    return head, steps


def parse_outcomes(text: str) -> list[dict]:
    """Kazanım metnini yapılandırılmış bloklara ayırır."""
    if not text or not text.strip():
        return []

    cleaned = re.sub(r"\s+", " ", text).strip()
    positions = find_code_positions(cleaned)

    # Kod yoksa: tüm metin tek blok, yine de maddelere ayrılır.
    if not positions:
        head, steps = split_steps(cleaned)
        return [{"code": None, "text": head, "steps": steps}]

    blocks: list[dict] = []

    # İlk kodun önündeki metin ünite/konu başlığıdır; ayrı tutulur.
    lead = cleaned[:positions[0][0]].strip(" |")

    for index, (begin, code) in enumerate(positions):
        finish = positions[index + 1][0] if index + 1 < len(positions) else len(cleaned)
        chunk = cleaned[begin:finish].strip(" |")
        # Kodun kendisini gövdeden düş.
        body = chunk[len(code):].lstrip(" .|").strip()
        head, steps = split_steps(body)
        blocks.append({"code": code, "text": head, "steps": steps})

    if lead and blocks:
        blocks[0]["lead"] = lead
    return blocks


def outcome_codes(text: str) -> list[str]:
    """Metindeki benzersiz kazanım kodları (sırayı korur)."""
    return list(dict.fromkeys(code for _, code in find_code_positions(
        re.sub(r"\s+", " ", text or ""))))


__all__ = ["parse_outcomes", "outcome_codes", "find_code_positions", "split_steps"]
