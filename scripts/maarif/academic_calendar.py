"""
SınıfCepte - MEB Resmî Çalışma Takvimi Üretici

Akademik yıl haftalarını TEK bir yerden üretir. Daha önce bu tablo
curriculum_normalizer_pipeline.py ve lise_maarif_pipeline.py içinde
2026-2027 için elle yazılmış hâlde iki kez kopyalanmıştı; yeni yıla
geçmek için iki dosyada 39 satırın elle değiştirilmesi gerekiyordu.

Artık haftalar `build_calendar(academic_year)` ile hesaplanır ve
yıla özgü sapmalar (MEB'in her yıl tebliğle duyurduğu ara tatil
tarihleri) `overrides/<yil>.json` dosyasından okunur.
"""

from __future__ import annotations

import datetime
import json
import os
import re

TOTAL_WEEKS = 39

OVERRIDE_DIR = os.path.join(os.path.dirname(__file__), "overrides")

TURKISH_MONTHS = {
    1: "Ocak", 2: "Şubat", 3: "Mart", 4: "Nisan", 5: "Mayıs", 6: "Haziran",
    7: "Temmuz", 8: "Ağustos", 9: "Eylül", 10: "Ekim", 11: "Kasım", 12: "Aralık",
}


class CalendarError(ValueError):
    """Takvim üretilemediğinde yükseltilir."""


def parse_academic_year(academic_year: str) -> tuple[int, int]:
    """'2026-2027' -> (2026, 2027). Hatalı biçimi sessizce kabul etmez."""
    match = re.fullmatch(r"(\d{4})-(\d{4})", (academic_year or "").strip())
    if not match:
        raise CalendarError(
            f"Geçersiz eğitim öğretim yılı: {academic_year!r}. Beklenen biçim: '2026-2027'."
        )
    start_year, end_year = int(match.group(1)), int(match.group(2))
    if end_year != start_year + 1:
        raise CalendarError(
            f"Eğitim öğretim yılı ardışık olmalı: {academic_year!r} (örn. '2026-2027')."
        )
    return start_year, end_year


def default_start_monday(start_year: int) -> datetime.date:
    """MEB'in olağan açılışı: Eylül'ün ikinci pazartesisi.

    Bu yalnızca varsayılandır. MEB açılışı tebliğle belirler ve kimi yıl
    bu kuraldan sapar; gerçek tarih overrides/<yil>.json içindeki
    "startDate" ile ezilir.
    """
    sep1 = datetime.date(start_year, 9, 1)
    first_monday = sep1 + datetime.timedelta(days=(0 - sep1.weekday()) % 7)
    if first_monday.day <= 7:
        first_monday += datetime.timedelta(days=7)
    return first_monday


def load_overrides(academic_year: str) -> dict:
    path = os.path.join(OVERRIDE_DIR, f"{academic_year}.json")
    if not os.path.exists(path):
        return {}
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def format_range(start: datetime.date, end: datetime.date) -> str:
    """'14 - 18 Eylül 2026' / '28 Eylül - 2 Ekim 2026' / ay+yıl değişimi."""
    if start.year != end.year:
        return (f"{start.day} {TURKISH_MONTHS[start.month]} {start.year} - "
                f"{end.day} {TURKISH_MONTHS[end.month]} {end.year}")
    if start.month != end.month:
        return (f"{start.day} {TURKISH_MONTHS[start.month]} - "
                f"{end.day} {TURKISH_MONTHS[end.month]} {end.year}")
    return f"{start.day} - {end.day} {TURKISH_MONTHS[start.month]} {start.year}"


def build_calendar(academic_year: str) -> dict[int, dict]:
    """Bir eğitim öğretim yılının 39 haftasını üretir.

    Dönen sözlük: {hafta_no: {start, end, formatted, month, term,
                              is_holiday, is_otp, is_social_event,
                              holiday_note, teaching_week}}
    """
    start_year, _ = parse_academic_year(academic_year)
    overrides = load_overrides(academic_year)

    if overrides.get("startDate"):
        start_monday = datetime.date.fromisoformat(overrides["startDate"])
        if start_monday.weekday() != 0:
            raise CalendarError(
                f"{academic_year} startDate pazartesi olmalı: {overrides['startDate']}"
            )
    else:
        start_monday = default_start_monday(start_year)

    holiday_weeks = {int(k): v for k, v in (overrides.get("holidayWeeks") or {}).items()}
    otp_weeks = set(overrides.get("otpWeeks") or [])
    social_weeks = set(overrides.get("socialEventWeeks") or [])
    second_term_week = int(overrides.get("secondTermStartWeek") or 21)
    notes = {int(k): v for k, v in (overrides.get("weekNotes") or {}).items()}

    calendar: dict[int, dict] = {}
    teaching_week = 0

    for week in range(1, TOTAL_WEEKS + 1):
        start = start_monday + datetime.timedelta(days=(week - 1) * 7)
        end = start + datetime.timedelta(days=4)  # Pazartesi - Cuma

        is_holiday = week in holiday_weeks
        is_otp = week in otp_weeks
        is_social = week in social_weeks

        # Ders haftası sayacı yalnızca eğitim yapılan haftalarda ilerler;
        # tatil haftaları teachingWeekNumber almaz (None).
        if is_holiday:
            teaching = None
        else:
            teaching_week += 1
            teaching = teaching_week

        label = format_range(start, end)
        suffix = holiday_weeks.get(week) or notes.get(week)
        formatted = f"{label} ({suffix})" if suffix else label

        calendar[week] = {
            "start": start.isoformat(),
            "end": end.isoformat(),
            "formatted": formatted,
            "month": TURKISH_MONTHS[start.month],
            "term": 1 if week < second_term_week else 2,
            "is_holiday": is_holiday,
            "is_otp": is_otp,
            "is_social_event": is_social,
            "holiday_note": holiday_weeks.get(week),
            "teaching_week": teaching,
        }

    return calendar


def summer_break_text(academic_year: str) -> str:
    calendar = build_calendar(academic_year)
    last_end = datetime.date.fromisoformat(calendar[TOTAL_WEEKS]["end"])
    start = last_end + datetime.timedelta(days=3)
    _, end_year = parse_academic_year(academic_year)
    next_open = default_start_monday(end_year)
    return (f"{start.day} {TURKISH_MONTHS[start.month]} - "
            f"{next_open.day} {TURKISH_MONTHS[next_open.month]} {end_year}")


if __name__ == "__main__":
    import sys

    year = sys.argv[1] if len(sys.argv) > 1 else "2026-2027"
    cal = build_calendar(year)
    for no, info in cal.items():
        tags = []
        if info["is_holiday"]:
            tags.append("TATİL")
        if info["is_otp"]:
            tags.append("OTP")
        if info["is_social_event"]:
            tags.append("SOSYAL")
        print(f"{no:2d}. {info['formatted']:<46} "
              f"ders:{info['teaching_week'] or '-':>3} {' '.join(tags)}")
