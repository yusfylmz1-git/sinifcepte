"""
SınıfCepte - Maarif Modeli pedagojik alan üretimi (özet, değerler, beceriler).

Bu mantık daha önce yalnızca lise_maarif_pipeline.py içinde yaşıyordu;
1-8. sınıf verisi de aynı alanlara ihtiyaç duyduğu için ortak modüle taşındı.
"""

from __future__ import annotations

import re

from turkish_text import fold

HOLIDAY_META = {
    "maarifSummary": "Bu hafta MEB resmî çalışma takvimi uyarınca eğitim öğretime ara verilmiştir.",
    "maarifValues": "Dinlenme, Aile Bağı",
    "maarifSkills": "SDB1.1 Öz Farkındalık",
    "differentiation": "Öğrencilerin serbest okuma ve kültürel etkinliklerle dinlenmesi tavsiye edilir.",
}

SOCIAL_META = {
    "maarifSummary": "MEB Sosyal Etkinlikler Haftası: Dönem sonu bilimsel, sanatsal, sportif ve kültürel etkinliklerle okul iklimi ve aidiyet pekiştirilir.",
    "maarifValues": "İş Birliği, Paylaşım, Estetik, Vatanseverlik",
    "maarifSkills": "SDB2.2 Toplumsal Katılım, SDB2.3 Takım Çalışması",
    "differentiation": "Öğrenci ilgi ve yeteneklerine göre kulüp ve grup bazlı serbest etkinlikler düzenlenir.",
}

OTP_META = {
    "maarifSummary": "Okul Temelli Planlama (OTP) Haftası: Okulun imkânları, yerel çevre şartları ve zümre kararları doğrultusunda derinleştirme veya telafi çalışmaları yürütülür.",
    "maarifValues": "Sorumluluk, Öz Denetim, Dayanışma",
    "maarifSkills": "KB2.10 Problem Çözme, AB1 Bilimsel Sorgulama",
    "differentiation": "Geri bildirim temelli bireysel destek veya ileri düzey zenginleştirme görevleri verilir.",
}

# Branş kodu -> (özet kalıbı, değerler, beceriler, farklılaştırma)
_PROFILES: dict[tuple[str, ...], tuple[str, str, str, str]] = {
    ("KIMYA", "FIZIK", "BIYOLOJI", "FEN"): (
        "bilimsel sorgulama, deney/modelleme ve günlük hayat bağlantıları kurularak işlenir. Öğrencilerin hipotez kurma ve sebep-sonuç ilişkilerini analiz etmesi hedeflenir.",
        "Bilimsellik, Doğa Sevgisi, Merak, Sorumluluk",
        "AB1 Bilimsel Sorgulama, KB2.4 Çözümleme, KB2.6 Bilgi Toplama",
        "Görsel modeller, animasyonlar ve kavram haritalarıyla somutlaştırma sağlanır.",
    ),
    ("TURKCE", "EDEBIYAT"): (
        "metin tahlili, eleştirel okuma ve yaratıcı yazma teknikleriyle işlenir. Dil zevki, kelime dağarcığı ve kendini doğru ifade etme becerisi ön plandadır.",
        "Estetik, Vatanseverlik, Duyarlılık, Nezaket",
        "AB3 Eleştirel Okuma, KB2.15 İfade Etme, SDB1.2 İletişim",
        "Farklı seviyelerdeki metinler ve sesli/görsel canlandırma teknikleriyle desteklenir.",
    ),
    ("MAT",): (
        "somut materyaller, görselleştirmeler ve gerçek hayat problemleriyle modellenir. Mantıksal akıl yürütme ve problem çözme stratejileri geliştirilir.",
        "Sabır, Akıl Yürütme, Çalışkanlık, Tutarlılık",
        "KB2.10 Matematiksel Modelleme, AB2 Akıl Yürütme, KB2.3 Karşılaştırma",
        "Kademeli zorluk seviyesindeki problem setleri ve somut manipülatiflerle zenginleştirilir.",
    ),
    ("TARIH", "SOSYAL", "INKILAP"): (
        "tarihsel empati, birincil kaynak analizi ve kronolojik düşünme yöntemleriyle işlenir. Millî bilinç ve vatandaşlık sorumluluğu pekiştirilir.",
        "Vatanseverlik, Adalet, Tarih Bilinci, Sorumluluk",
        "AB4 Tarihsel Empati, KB2.8 Kanıt Kullanma, SDB2.2 Toplumsal Katılım",
        "Tarihsel harita, görsel belge ve dijital arşiv incelemeleriyle desteklenir.",
    ),
    ("COGRAFYA",): (
        "harita okuryazarlığı, mekânsal düşünme ve doğa-insan etkileşimi ekseninde incelenir. Çevre duyarlılığı ve sürdürülebilirlik vurgulanır.",
        "Çevre Bilinci, Doğa Sevgisi, Sorumluluk, Sürdürülebilirlik",
        "AB5 Mekânsal Düşünme, KB2.14 Harita Okuma, SDB2.1 Çevre Duyarlılığı",
        "Tematik haritalar, CBS görselleri ve arazi gözlemleriyle zenginleştirilir.",
    ),
    ("FELSEFE",): (
        "felsefi sorgulama, kavramsal analiz ve argümantasyon yöntemleriyle ele alınır. Eleştirel ve tutarlı düşünme disiplini geliştirilir.",
        "Eleştirel Düşünme, Merak, Dürüstlük, Hoşgörü",
        "KB2.7 Argümantasyon, KB2.1 Analiz, SDB1.1 Öz Farkındalık",
        "Sokratesçi diyalog ve vaka tartışmalarıyla fikir üretimi teşvik edilir.",
    ),
    ("BILISIM", "HAREZMI", "TEKNO_TASARIM"): (
        "algoritmik düşünme, tasarım odaklı problem çözme ve dijital üretim etkinlikleriyle uygulamalı olarak işlenir.",
        "Dijital Etik, Üretkenlik, İş Birliği, Sorumluluk",
        "AB6 Algoritmik Düşünme, KB2.16 Dijital Üretim, SDB2.3 Takım Çalışması",
        "Aşamalı blok/metin kodlama görevleri ve proje temelli grup çalışmalarıyla uygulanır.",
    ),
    ("DIN", "KURAN", "SIYER", "ARAPCA"): (
        "ahlaki erdemler, evrensel değerler ve toplumsal dayanışma ilkeleri odağında hayatla bağ kurularak işlenir.",
        "Adalet, Merhamet, Dürüstlük, Yardımlaşma, Saygı",
        "AB7 Ahlaki Muhakeme, SDB1.3 Empati, KB2.2 Yorumlama",
        "Örnek olay incelemeleri ve hikâyeleme yöntemleriyle kavratılır.",
    ),
    ("INGILIZCE", "ALMANCA"): (
        "iletişimsel yaklaşım, interaktif diyaloglar ve bağlamsal kelime kullanımıyla 4 temel dil becerisi dengelenerek işlenir.",
        "Kültürel Farkındalık, İletişim, Özgüven, Hoşgörü",
        "AB8 İletişimsel Yeterlilik, SDB1.2 Etkileşim, KB2.5 Dinleme-Konuşma",
        "Rol oynama (role-play), görsel flashcard'lar ve dijital dinleme etkinlikleriyle desteklenir.",
    ),
    ("BEDEN", "GORSEL", "MUZIK", "SAGLIK"): (
        "bedensel koordinasyon, estetik algı ve yaratıcı ifade teknikleriyle uygulamalı ve dinamik olarak işlenir.",
        "Estetik, Sağlıklı Yaşam, Disiplin, Saygı",
        "AB9 Kinestetik ve Sanatsal Yeterlilik, SDB1.2 İfade Becerisi",
        "Bireysel yetenek ve ritimlere uygun basamaklandırılmış egzersizlerle işlenir.",
    ),
    ("HAYAT",): (
        "yakın çevre gözlemi, günlük yaşam becerileri ve değerler eğitimiyle somut yaşantılar üzerinden işlenir.",
        "Sorumluluk, Temizlik, Saygı, Yardımlaşma",
        "SDB1.1 Öz Farkındalık, SDB2.1 Çevre Duyarlılığı, KB2.6 Gözlem",
        "Oyunlaştırma, drama ve sınıf içi uygulamalarla pekiştirilir.",
    ),
}

_DEFAULT = (
    "aktif öğrenme yöntemleri, soru-cevap ve öğrenci merkezli etkinliklerle Maarif Modeli felsefesine uygun olarak işlenir.",
    "Sorumluluk, Merak, Çalışkanlık",
    "KB2.10 Problem Çözme, KB2.4 Çözümleme",
    "Görsel ve metinsel ek materyallerle çeşitlendirilir.",
)



# --------------------------------------------------------------------------
# Özel hafta etkinlik önerileri (OTP / Sosyal Etkinlik)
# --------------------------------------------------------------------------
#
# ÖNEMLİ: OTP ve sosyal etkinlik haftalarında MEB İÇERİK BELİRLEMEZ; ne
# yapılacağına okulun zümresi karar verir. Buradakiler resmî kazanım DEĞİL,
# öğretmene fikir vermek için hazırlanmış ÖNERİLERDİR. Uygulama bunları
# "Örnek Etkinlik Önerileri" başlığıyla ve öneri olduğu belirtilerek
# gösterir; kazanım metniyle karıştırılmamalıdır.
#
# Gerekçe: Bu haftalarda 603 OTP + 402 sosyal etkinlik kaydının tamamı
# aynı iki cümleyi taşıyordu. Öğretmen kartı açtığında elinde hiçbir şey
# olmuyordu.

OTP_ACTIVITIES: dict[tuple[str, ...], tuple[str, ...]] = {
    ("KIMYA", "FIZIK", "BIYOLOJI", "FEN"): (
        "Dönem boyunca zorlanılan deneyleri yeniden yapma ve gözlem defterini gözden geçirme",
        "Kavram yanılgısı testi uygulayıp yanlış anlaşılan konuları küçük gruplarla tekrar etme",
        "Basit malzemelerle model/maket yaptırma (hücre, devre, güneş sistemi)",
        "Bilim insanı biyografisi ve güncel bir bilim haberi üzerine sınıf tartışması",
    ),
    ("MAT",): (
        "Dönem konularından karma problem seti çözümü ve hata analizi",
        "Zorlanan öğrencilerle birebir/küçük grup telafi çalışması",
        "Günlük hayattan veri toplayıp grafikle sunma (market fişi, hava durumu)",
        "Zekâ oyunları ve matematik bulmacalarıyla akıl yürütme atölyesi",
    ),
    ("TURKCE", "EDEBIYAT"): (
        "Serbest okuma saati ve okuduğunu paylaşma çemberi",
        "Yazım-noktalama hatalarının birlikte düzeltildiği atölye",
        "Yaratıcı yazma: hikâye tamamlama veya mektup yazma etkinliği",
        "Sınıf içi münazara veya şiir dinletisi hazırlığı",
    ),
    ("TARIH", "SOSYAL", "INKILAP"): (
        "Yerel tarih araştırması: mahallenin/şehrin tarihî mekânları",
        "Belgesel izleme ve tarihsel kaynak eleştirisi tartışması",
        "Zaman şeridi hazırlama ve dönem olaylarını sıralama",
        "Büyüklerle sözlü tarih görüşmesi ve sınıfta sunum",
    ),
    ("COGRAFYA",): (
        "Okul çevresinin haritasını çıkarma ve kroki çalışması",
        "Güncel bir doğal afet haberini nedenleri/sonuçlarıyla inceleme",
        "İklim verisi grafiği okuma ve yorumlama atölyesi",
    ),
    ("FELSEFE", "PSIKOLOJI", "SOSYOLOJI", "MANTIK"): (
        "Sokratesçi sorgulama: seçilen bir kavram üzerine sınıf tartışması",
        "Kısa film/vaka üzerinden etik ikilem çözümlemesi",
        "Argüman kurma ve mantık hatası bulma alıştırmaları",
    ),
    ("BILISIM", "HAREZMI", "TEKNO_TASARIM"): (
        "Dönem projesini geliştirme ve akran değerlendirmesi",
        "Blok/metin tabanlı kodlama ile küçük oyun veya animasyon yapımı",
        "Dijital güvenlik ve siber zorbalık üzerine vaka çalışması",
        "Yapay zekâ araçlarını sorumlu kullanma atölyesi",
    ),
    ("INGILIZCE", "ALMANCA", "ARAPCA"): (
        "Rol oynama (role-play) ile günlük konuşma pratiği",
        "Şarkı/kısa video ile dinleme etkinliği ve kelime tekrarı",
        "Kelime kartı oyunları ve eşleştirme yarışması",
        "Basit diyalog yazma ve sınıfta canlandırma",
    ),
    ("DIN", "KURAN", "SIYER", "PEYGAMBER", "TEMEL_DINI"): (
        "Değerler üzerine örnek olay incelemesi ve sınıf tartışması",
        "Ezberlenen bölümlerin tekrarı ve karşılıklı dinleme",
        "Yardımlaşma/paylaşma temalı sınıf içi uygulama planlama",
    ),
    ("BEDEN",): (
        "Temel hareket becerilerinin tekrarı ve istasyon çalışması",
        "Sınıf içi turnuva veya takım oyunları düzenleme",
        "Sağlıklı yaşam ve beslenme üzerine kısa sunum hazırlama",
    ),
    ("GORSEL", "MUZIK"): (
        "Dönem çalışmalarından sınıf sergisi/dinletisi hazırlama",
        "Yeni bir teknik deneme atölyesi (kolaj, ritim çalışması)",
        "Sanatçı/eser tanıtımı ve sınıfça yorumlama",
    ),
    ("HAYAT",): (
        "Okul ve yakın çevre gezisi, gözlem defteri tutma",
        "Görgü kuralları ve güvenlik konularında drama etkinliği",
        "Mevsim/trafik temalı sınıf panosu hazırlama",
    ),
}

_OTP_DEFAULT_ACTIVITIES = (
    "Dönem boyunca eksik kalan konuların tekrarı ve telafisi",
    "Zorlanan öğrencilerle küçük grup destek çalışması",
    "Konuyu ileri taşımak isteyenlere zenginleştirme görevi",
    "Öğrenci ürünlerinin gözden geçirilmesi ve geri bildirim",
)

SOCIAL_ACTIVITIES: dict[tuple[str, ...], tuple[str, ...]] = {
    ("KIMYA", "FIZIK", "BIYOLOJI", "FEN"): (
        "Bilim şenliği: basit deney gösterileri",
        "Okul bahçesinde doğa gözlemi veya geri dönüşüm kampanyası",
    ),
    ("MAT",): (
        "Matematik oyunları turnuvası (sudoku, tangram, strateji oyunları)",
        "Sınıflar arası zekâ oyunları yarışması",
    ),
    ("TURKCE", "EDEBIYAT"): (
        "Şiir dinletisi veya kitap fuarı standı",
        "Kısa tiyatro/skeç sahneleme",
    ),
    ("TARIH", "SOSYAL", "INKILAP"): (
        "Tarihî mekân gezisi veya müze ziyareti",
        "Kültürel miras temalı sergi hazırlama",
    ),
    ("BILISIM", "HAREZMI", "TEKNO_TASARIM"): (
        "Robotik/kodlama gösterisi ve proje sergisi",
        "Dijital poster tasarım yarışması",
    ),
    ("INGILIZCE", "ALMANCA", "ARAPCA"): (
        "Yabancı dil şarkı/skeç gösterisi",
        "Kültür tanıtım köşesi hazırlama",
    ),
    ("BEDEN",): (
        "Sınıflar arası spor turnuvası",
        "Halk oyunları veya dans gösterisi",
    ),
    ("GORSEL", "MUZIK"): (
        "Yıl sonu sergisi veya konser hazırlığı",
        "Sınıf korosu / enstrüman dinletisi",
    ),
}

_SOCIAL_DEFAULT_ACTIVITIES = (
    "Sınıf/okul düzeyinde kültürel veya sanatsal etkinlik",
    "Grup çalışmasıyla proje sunumu",
    "Sosyal sorumluluk temalı kısa uygulama",
)



# --------------------------------------------------------------------------
# Haftaya özgü özet üretimi
# --------------------------------------------------------------------------
#
# Özet eskiden yalnızca ÜNİTE adından üretiliyordu. Bir ünite 4-5 hafta
# sürdüğü için o haftaların özeti kelimesi kelimesine aynı çıkıyordu:
#
#   w1 "Bu hafta 'Bilişim Teknolojilerinin Hayatımızdaki Yeri' konusu; ..."
#   w2 "Bu hafta 'Bilişim Teknolojilerinin Hayatımızdaki Yeri' konusu; ..."
#
# Oysa haftanın kendi alt konusu kazanım metninin başında duruyor
# ("Dijital Sağlık", "Dijital Vatandaşlık Uygulamaları") ve kullanılmıyordu.
# Artık önce o alt konu, yoksa kazanımın kendi cümlesi kullanılır.

# Kazanım kodu kalıbı: 'BTY.5.1.2.' / '10.1.1.'
_CODE_AT_START = re.compile(
    r"^\s*(?:[A-ZÇĞİÖŞÜ]{2,6}\.)?\d{1,2}(?:\.\d{1,2}){1,}\.\s*")

# Süreç bileşeni: 'a) ...'
_STEP_START = re.compile(r"\s[a-zçğıöşü]\s*\)\s")


def week_focus(outcome_description: str, topic_title: str = "",
               unit_title: str = "") -> str:
    """Haftanın odağını belirler.

    Öncelik sırası:
      1. Kazanım metninin başındaki alt konu etiketi ('... | KOD ...')
      2. Kazanımın kendi ilk cümlesi (kod atılarak)
      3. Konu başlığı, sonra ünite adı
    """
    text = (outcome_description or "").strip()

    # 1) '<alt konu> | <kod> <kazanım>' kalıbı
    if "|" in text:
        head = text.split("|", 1)[0].strip()
        # Baş kısım kod içermiyorsa gerçek bir alt konu etiketidir.
        if head and not _CODE_AT_START.match(head) and len(head) <= 90:
            return head

    # 2) Kazanımın ilk cümlesi
    body = _CODE_AT_START.sub("", text.split("|")[-1].strip())
    # Metin doğrudan süreç bileşeniyle başlıyorsa ('a) Nokta tanır')
    # bu bir konu başlığı değildir; ünite adına düşülür.
    if re.match(r"^\s*[a-zçğıöşü]\s*\)", body):
        return (topic_title or unit_title or "Konu").strip()
    step = _STEP_START.search(body)
    if step:
        body = body[:step.start()]
    for mark in (". ", "; "):
        cut = body.find(mark)
        if 15 < cut < 110:
            body = body[:cut]
            break
    body = body.strip(" .;")
    if 12 <= len(body) <= 110:
        return body

    # 3) Yedek
    return (topic_title or unit_title or "Konu").strip()


def _activities_for(subject_code: str, table: dict, fallback: tuple) -> tuple[str, ...]:
    code = (subject_code or "").upper()
    for codes, items in table.items():
        if code in codes:
            return items
    return fallback


def suggested_activities(subject_code: str, *, is_otp: bool = False,
                         is_social: bool = False) -> list[str]:
    """Özel hafta için branşa uygun ÖNERİ etkinlik listesi.

    Resmî kazanım değildir; öğretmene fikir vermek içindir.
    """
    if is_otp:
        return list(_activities_for(subject_code, OTP_ACTIVITIES,
                                    _OTP_DEFAULT_ACTIVITIES))
    if is_social:
        return list(_activities_for(subject_code, SOCIAL_ACTIVITIES,
                                    _SOCIAL_DEFAULT_ACTIVITIES))
    return []


def _profile_for(subject_code: str) -> tuple[str, str, str, str]:
    code = (subject_code or "").upper()
    for codes, profile in _PROFILES.items():
        if code in codes:
            return profile
    return _DEFAULT


def build_meta(subject_code: str, unit_title: str = "", topic_title: str = "",
               outcome_description: str = "",
               *, is_otp: bool = False, is_social: bool = False,
               is_holiday: bool = False) -> dict[str, str]:
    """Bir kazanım kaydı için Maarif pedagojik alanlarını üretir."""
    if is_holiday:
        return dict(HOLIDAY_META)

    # OTP ve sosyal etkinlik haftalarında MEB içerik belirlemez; branşa
    # uygun ÖNERİLER üretilir. Önceden 603 OTP kaydının tamamı aynı iki
    # cümleyi taşıyordu ve öğretmenin eline hiçbir şey geçmiyordu.
    if is_social:
        meta = dict(SOCIAL_META)
        meta["suggestedActivities"] = suggested_activities(
            subject_code, is_social=True)
        return meta
    if is_otp:
        meta = dict(OTP_META)
        meta["suggestedActivities"] = suggested_activities(
            subject_code, is_otp=True)
        return meta

    # Haftanın kendi odağı; aynı ünitenin farklı haftaları artık aynı
    # özeti taşımaz.
    topic = week_focus(outcome_description, topic_title, unit_title)
    tail, values, skills, differentiation = _profile_for(subject_code)
    return {
        "maarifSummary": f"Bu hafta '{topic}' konusu; {tail}",
        "maarifValues": values,
        "maarifSkills": skills,
        "differentiation": differentiation,
    }


__all__ = ["build_meta", "suggested_activities", "week_focus", "fold",
           "HOLIDAY_META", "SOCIAL_META", "OTP_META"]
