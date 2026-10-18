/**
 * Bildirimler sekmesi — içerik bildirimleri ve destek talepleri.
 *
 * ## Neden (18 Ekim 2026)
 * Google Play kullanıcı içeriği kuralı: uygulamadan bildirilen mesaj ve
 * duyurular bir insanın önüne düşmeli. Destek talepleri de buluta
 * yazılıyordu ama panelde onları gösteren ekran yoktu; kimsenin
 * görmediği bir kuyuya düşüyorlardı. Okul yöneticiliği kalkınca boşalan
 * sekmenin yerine geldi.
 *
 * İçerik bildiriminde metin ve kişi, Firestore kuralında buluttaki asıl
 * mesajla karşılaştırılır; uydurma bildirim yazılamaz. Okuma ve kapatma
 * kuralda yalnız yöneticiye açık (`isAdmin`).
 *
 * `AdminApp`'e yöntem olarak ekleniyor: düğmeler `data-eylem` ile
 * `window.adminApp` üzerinden çalışıyor (js/eylemler.js).
 */
(function () {
  'use strict';

  const KATEGORI = {
    content_report: '🚩 İçerik bildirimi',
    code_issue: '🔑 Veli kodu sorunu',
    bug_report: '🐛 Uygulama hatası',
    suggestion: '💡 Öneri',
    other: '❓ Diğer',
  };
  const NEDEN = {
    hakaret: 'Hakaret veya taciz',
    uygunsuz: 'Uygunsuz içerik',
    spam: 'Dolandırıcılık veya istenmeyen mesaj',
    diger: 'Diğer',
  };
  const ROL = { teacher: 'Öğretmen', parent: 'Veli' };

  function tarihYaz(iso) {
    const t = new Date(iso);
    if (!iso || Number.isNaN(t.getTime())) return '—';
    return t.toLocaleString('tr-TR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  }

  /** Bildirilen içeriğin Firestore yolu (Console'da açmak için). */
  function icerikYolu(t) {
    if (!t.classCloudId || !t.contentId) return '';
    const alt = t.contentType === 'announcement' ? 'announcements' : 'messages';
    return `class_rooms/${t.classCloudId}/${alt}/${t.contentId}`;
  }

  Object.assign(window.AdminApp.prototype, {
    /** Talepleri sunucudan okur ve seçili süzgeçle tabloyu çizer. */
    async bildirimleriYukle() {
      const metin = document.getElementById('bildirim-bilgi');
      const tablo = document.getElementById('bildirim-tablo');
      if (metin) metin.textContent = 'Bildirimler okunuyor…';
      if (tablo) tablo.innerHTML = '';
      try {
        this._talepler = await window.SinifCepteAdminAuth.listSupportRequests();
        this.bildirimTablosuCiz(document.getElementById('bildirim-suzgec')?.value || 'acik');
      } catch (e) {
        this._talepler = [];
        if (metin) metin.textContent = `Bildirimler okunamadı: ${this.yayinHatasi(e)}`;
      }
    },

    bildirimTablosuCiz(suzgec = 'acik') {
      const tablo = document.getElementById('bildirim-tablo');
      const metin = document.getElementById('bildirim-bilgi');
      if (!tablo) return;
      const m = (x) => this.kacisliMetin(x);
      const o = (x) => this.kacisliOznitelik(x);

      const secilen = (this._talepler || []).filter((t) => {
        const acik = t.status !== 'resolved';
        if (suzgec === 'icerik') return acik && t.category === 'content_report';
        if (suzgec === 'hepsi') return true;
        return acik;
      });

      if (metin) {
        const icerik = secilen.filter((t) => t.category === 'content_report').length;
        metin.textContent = secilen.length
          ? `${secilen.length} kayıt (${icerik} içerik bildirimi). En yeni 200 talep okunur.`
          : 'Gösterilecek kayıt yok.';
      }

      tablo.innerHTML = secilen
        .map((t) => {
          const bildirim = t.category === 'content_report';
          const tur = bildirim
            ? `${KATEGORI.content_report}<br><small>${m(NEDEN[t.reason] || t.reason || '')}</small>`
            : m(KATEGORI[t.category] || t.category || '');
          const kimden = `${m(ROL[t.userRole] || t.userRole || '')}<br><small style="color: var(--text-muted)">${m(t.userId)}</small>`;
          const hakkinda = bildirim
            ? `<strong>${m(t.reportedName || '—')}</strong><br><small style="color: var(--text-muted)">${m(t.reportedUid)}</small>`
            : `<strong>${m(t.subject)}</strong>`;
          const yol = icerikYolu(t);
          const ayrinti = bildirim
            ? `${t.contentTitle ? `<strong>${m(t.contentTitle)}</strong><br>` : ''}«${m(t.excerpt)}»` +
              (t.message && t.message !== 'Ek not yok.' ? `<br><em>Not: ${m(t.message)}</em>` : '') +
              (yol ? `<br><small style="color: var(--text-muted)">${m(yol)}</small>` : '')
            : m(t.message);
          const islem = t.status === 'resolved'
            ? `<span style="font-size: 12px;"><strong>Kapatıldı</strong> ${m(tarihYaz(t.resolvedAt))}` +
              `${t.adminNote ? `<br>${m(t.adminNote)}` : ''}</span>`
            : `<button class="btn btn-sm btn-primary" data-eylem="bildirimiKapat" data-arg="${o(t.id)}">Kapat</button>`;
          return `
            <tr>
              <td style="white-space: nowrap; font-size: 12px;">${m(tarihYaz(t.createdAt))}</td>
              <td style="font-size: 12px;">${tur}</td>
              <td style="font-size: 12px;">${kimden}</td>
              <td style="font-size: 12px;">${hakkinda}</td>
              <td style="max-width: 360px; font-size: 12px; white-space: pre-wrap;">${ayrinti}</td>
              <td style="text-align: right; white-space: nowrap;">${islem}</td>
            </tr>`;
        })
        .join('');
    },

    /** Talebi kapatır; ne yapıldığı not olarak kalır. */
    async bildirimiKapat(id) {
      const not = window.prompt('Ne yapıldı? (ör. "Hesap kapatıldı", "İhlal yok")', '');
      if (not === null) return;
      try {
        await window.SinifCepteAdminAuth.resolveSupportRequest(id, not);
        this.showToast('Kapatıldı.', 'success');
      } catch (e) {
        this.showToast(this.yayinHatasi(e), 'error');
      }
      await this.bildirimleriYukle();
    },
  });
})();
