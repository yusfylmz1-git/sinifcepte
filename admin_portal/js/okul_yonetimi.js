/**
 * Okul Yöneticileri sekmesi — yöneticilik başvurularına panelden karar.
 *
 * ## Neden (Y17, ikinci yarı)
 * Karar yalnızca süper yöneticinin bilgisayarındaki komut satırı
 * betiğiyle veriliyordu (servis hesabı anahtarı + terminal). Karar
 * (28 Eylül 2026): onay sunucu fonksiyonuyla, panelden.
 *
 * Yetkiyi sunucu veriyor (`decideSchoolAdmin`, custom claim); panel
 * yalnızca "şunu onayla" diyor. Moderatör listeyi görür, karar düğmeleri
 * yalnızca süper yöneticiye çıkar — asıl denetim sunucuda.
 *
 * `AdminApp`'e yöntem olarak ekleniyor: düğmeler `data-eylem` ile
 * `window.adminApp` üzerinden çalışıyor (js/eylemler.js).
 */
(function () {
  'use strict';

  const DURUM_ADI = { pending: 'Bekleyen', approved: 'Onaylanan', rejected: 'Reddedilen' };

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

  Object.assign(window.AdminApp.prototype, {
    /** Seçili durumdaki başvuruları sunucudan okur ve tabloyu çizer. */
    async yoneticileriYukle() {
      const durum = document.getElementById('yonetici-durum')?.value || 'pending';
      const metin = document.getElementById('yonetici-bilgi');
      const tablo = document.getElementById('yonetici-tablo');
      if (metin) metin.textContent = 'Başvurular okunuyor…';
      if (tablo) tablo.innerHTML = '';
      try {
        const sonuc = await window.SinifCepteAdminAuth.listSchoolAdminRequests(durum);
        this._basvurular = sonuc?.basvurular || [];
        this.yoneticiTablosuCiz(durum);
        if (metin) {
          metin.textContent = this._basvurular.length
            ? `${this._basvurular.length} ${DURUM_ADI[durum].toLocaleLowerCase('tr-TR')} başvuru.`
            : `${DURUM_ADI[durum]} başvuru yok.`;
        }
      } catch (e) {
        this._basvurular = [];
        if (metin) metin.textContent = `Başvurular okunamadı: ${this.yayinHatasi(e)}`;
      }
    },

    yoneticiTablosuCiz(durum) {
      const tablo = document.getElementById('yonetici-tablo');
      if (!tablo) return;
      const m = (x) => this.kacisliMetin(x);
      const o = (x) => this.kacisliOznitelik(x);
      const karar = window.SinifCepteAdminAuth?.currentRole?.() === 'super';

      tablo.innerHTML = this._basvurular
        .map((b) => {
          const kanit = [
            b.dizindeMi
              ? '<span class="badge badge-period">✓ Okulun öğretmen dizininde</span>'
              : '<span class="badge badge-official">Dizinde yok</span>',
            b.okulKimligiGecerli
              ? ''
              : '<span class="badge badge-official">Okul kimliği geçersiz</span>',
          ].join(' ');

          let islem = '<span style="color: var(--text-muted); font-size: 12px;">Karar süper yöneticide</span>';
          if (karar && durum === 'pending') {
            islem = `
              <button class="btn btn-sm btn-primary" data-eylem="yoneticiOnayla" data-arg="${o(b.uid)}"
                ${b.okulKimligiGecerli ? '' : 'disabled title="Okul kimliği geçersiz: öğretmen okulunu listeden seçip yeniden başvurmalı"'}>Onayla</button>
              <button class="btn btn-sm btn-danger" data-eylem="yoneticiReddet" data-arg="${o(b.uid)}">Reddet</button>`;
          } else if (karar && durum === 'approved') {
            islem = `<button class="btn btn-sm btn-danger" data-eylem="yoneticiGeriAl" data-arg="${o(b.uid)}">Yetkiyi geri al</button>`;
          } else if (durum === 'rejected') {
            islem = `<span style="font-size: 12px;">${b.geriAlindi ? '<strong>Geri alındı.</strong> ' : ''}${m(b.gerekce)}</span>`;
          }

          const tarih = durum === 'pending' ? b.tarih : b.kararTarihi;
          return `
            <tr>
              <td><strong>${m(b.ad)}</strong><br><small style="color: var(--text-muted)">${m(b.eposta)}</small></td>
              <td>${m(b.okulAdi)}<br><small style="color: var(--text-muted)">${m(b.okulId)} · ${m(b.il)}${b.ilce ? ' / ' + m(b.ilce) : ''}</small></td>
              <td>${kanit}</td>
              <td style="max-width: 240px; font-size: 12px;">${m(b.not) || '—'}</td>
              <td style="white-space: nowrap; font-size: 12px;">${m(tarihYaz(tarih))}</td>
              <td style="text-align: right; white-space: nowrap;">${islem}</td>
            </tr>`;
        })
        .join('');
    },

    _basvuruBul(uid) {
      return (this._basvurular || []).find((b) => b.uid === uid);
    },

    async _yoneticiKarar(uid, karar, gerekce, basari) {
      try {
        await window.SinifCepteAdminAuth.decideSchoolAdmin(uid, karar, gerekce);
        this.showToast(basari, 'success');
      } catch (e) {
        this.showToast(this.yayinHatasi(e), 'error');
      }
      await this.yoneticileriYukle();
    },

    async yoneticiOnayla(uid) {
      const b = this._basvuruBul(uid);
      if (!b) return;
      const uyari = b.dizindeMi
        ? ''
        : '\n\nDİKKAT: Bu kişi okulun öğretmen dizininde kayıtlı DEĞİL.';
      const onay = confirm(
        `${b.ad} (${b.eposta})\n${b.okulAdi} — ${b.okulId}\n\n` +
          'Bu okulun yöneticisi olarak onaylanacak: okulun şikâyetlerini görür, ' +
          `öğretmen onaylarını yönetir.${uyari}\n\nOnaylansın mı?`
      );
      if (!onay) return;
      await this._yoneticiKarar(
        uid,
        'onay',
        '',
        `${b.ad} onaylandı. Öğretmen uygulamada "Yetkiyi yenile"ye basmalı ` +
          '(ya da en geç 1 saat içinde kendiliğinden geçer).'
      );
    },

    async yoneticiReddet(uid) {
      const b = this._basvuruBul(uid);
      if (!b) return;
      const gerekce = prompt(
        `${b.ad} — ${b.okulAdi}\n\nRet gerekçesi (öğretmen bunu görecek):`
      );
      if (gerekce === null) return;
      if (!gerekce.trim()) {
        this.showToast('Gerekçe yazılmadan reddedilemez.', 'error');
        return;
      }
      await this._yoneticiKarar(uid, 'red', gerekce, `${b.ad} başvurusu reddedildi.`);
    },

    async yoneticiGeriAl(uid) {
      const b = this._basvuruBul(uid);
      if (!b) return;
      const gerekce = prompt(
        `${b.ad} — ${b.okulAdi}\n\nYöneticilik geri alınacak. Gerekçe (öğretmen bunu görecek):`
      );
      if (gerekce === null) return;
      if (!gerekce.trim()) {
        this.showToast('Gerekçe yazılmadan geri alınamaz.', 'error');
        return;
      }
      await this._yoneticiKarar(
        uid,
        'geri_al',
        gerekce,
        `${b.ad} için yöneticilik geri alındı. Etkisi en geç 1 saat içinde başlar.`
      );
    },
  });
})();
