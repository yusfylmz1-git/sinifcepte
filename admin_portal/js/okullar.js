/**
 * Okullar ve Kişiler sekmesi.
 *
 * Kullanıcı (28 Eylül 2026): "Bize kayıtlı okulları ve kişileri
 * yönetebilmemiz çok önemli." Kurum koduyla okul, e-postayla kişi
 * aranıyor; okulda kimin kayıtlı ve kimin yönetici olduğu, o okulda
 * neler yapıldığı görünüyor.
 *
 * Kişisel veri (ad, e-posta) gösteriliyor: sunucu her görüntülemeyi
 * denetim kaydına yazıyor. Değiştiren işlemler yalnızca süper
 * yöneticide; düğmeler de yalnızca ona çıkıyor.
 */
(function () {
  'use strict';

  function tarihYaz(iso) {
    const t = new Date(iso);
    if (!iso || Number.isNaN(t.getTime())) return '—';
    return t.toLocaleString('tr-TR', {
      day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit',
    });
  }

  const YONETICILIK = {
    approved: '<span class="badge badge-period">Yönetici</span>',
    pending: '<span class="badge badge-break">Başvuru bekliyor</span>',
    rejected: '<span class="badge">Reddedildi</span>',
    geri_alindi: '<span class="badge">Geri alındı</span>',
  };

  const KAYIT_ADI = {
    school_admin_decision: 'Yöneticilik kararı',
    okul_dizininden_cikarma: 'Dizinden çıkarma',
    destek_kodu: 'Destek kodu verildi',
  };
  const KARAR_ADI = { onay: 'onay', red: 'ret', geri_al: 'geri alma' };

  const superMi = () => window.SinifCepteAdminAuth?.currentRole?.() === 'super';

  Object.assign(window.AdminApp.prototype, {
    async okulAra() {
      const kod = document.getElementById('okul-ara-kod')?.value || '';
      const bilgi = document.getElementById('okul-bilgi');
      const sonuc = document.getElementById('okul-sonuc');
      if (bilgi) bilgi.textContent = 'Okul okunuyor…';
      if (sonuc) sonuc.innerHTML = '';
      try {
        this._okul = await window.SinifCepteAdminAuth.schoolOverview(kod.trim());
        if (bilgi) bilgi.textContent = '';
        this.okulSonucCiz();
      } catch (e) {
        this._okul = null;
        if (bilgi) bilgi.textContent = this.yayinHatasi(e);
      }
    },

    /** Kişi kartındaki okula geç. */
    okulAc(okulId) {
      const alan = document.getElementById('okul-ara-kod');
      if (alan) alan.value = okulId;
      return this.okulAra();
    },

    okulSonucCiz() {
      const kutu = document.getElementById('okul-sonuc');
      const o = this._okul;
      if (!kutu || !o) return;
      const m = (x) => this.kacisliMetin(x);
      const a = (x) => this.kacisliOznitelik(x);
      const yoneticiSayisi = o.ogretmenler.filter((t) => t.yoneticilik === 'approved').length;

      const satirlar = o.ogretmenler.length
        ? o.ogretmenler.map((t) => `
            <tr>
              <td><strong>${m(t.ad)}</strong></td>
              <td>${m(t.brans) || '—'}</td>
              <td style="font-size: 12px;">${m(t.eposta)}</td>
              <td>${YONETICILIK[t.yoneticilik] || ''}</td>
              <td style="text-align: right;">${superMi()
                ? `<button class="btn btn-sm btn-danger" data-eylem="dizindenCikar" data-arg="${a(t.uid)}">Dizinden çıkar</button>`
                : ''}</td>
            </tr>`).join('')
        : '<tr><td colspan="5" style="color: var(--text-muted);">Bu okulda SınıfCepte\'ye kayıtlı öğretmen yok.</td></tr>';

      const kayitlar = o.kayitlar.length
        ? o.kayitlar.map((k) => `
            <tr>
              <td style="white-space: nowrap; font-size: 12px;">${m(tarihYaz(k.zaman))}</td>
              <td>${m(KAYIT_ADI[k.tur] || k.tur)}${k.karar ? ` — ${m(KARAR_ADI[k.karar] || k.karar)}` : ''}${k.talep ? ` (talep ${m(k.talep)})` : ''}</td>
              <td style="font-size: 12px;">${m(k.gerekce)}</td>
              <td style="font-size: 12px;">${m(k.eposta)}</td>
            </tr>`).join('')
        : '<tr><td colspan="4" style="color: var(--text-muted);">Kayıt yok.</td></tr>';

      kutu.innerHTML = `
        <h3 style="margin: 16px 0 4px;">${m(o.okulId)}</h3>
        <p style="margin: 0 0 12px; font-size: 13px; color: var(--text-muted);">
          ${o.ogretmenler.length} öğretmen kayıtlı · ${yoneticiSayisi} yönetici
        </p>
        <div class="table-responsive">
          <table class="data-table">
            <thead><tr><th>Ad</th><th>Branş</th><th>E-posta</th><th>Yöneticilik</th><th></th></tr></thead>
            <tbody>${satirlar}</tbody>
          </table>
        </div>
        ${this.destekKarti(o.okulId)}
        <h4 style="margin: 20px 0 8px;">Bu okulda yapılan işlemler</h4>
        <div class="table-responsive">
          <table class="data-table">
            <thead><tr><th>Tarih</th><th>İşlem</th><th>Gerekçe</th><th>Yapan</th></tr></thead>
            <tbody>${kayitlar}</tbody>
          </table>
        </div>`;
    },

    /**
     * Ana Program parolası unutulduysa ve anahtar yedeği yoksa.
     *
     * Kod imzalı; yalnızca bu kurum kodu ve okulun bilgisayarında
     * üretilen talep numarası için geçerli. Yalnızca MEB kurum kodlu
     * okullarda: Ana Program ilk kurulumda 6 haneli kurum kodu istiyor.
     */
    destekKarti(okulId) {
      if (!superMi() || !/^meb_\d{6}$/.test(okulId)) return '';
      const kurum = this.kacisliMetin(okulId.slice(4));
      return `
        <div class="panel-card" style="margin-top: 20px; box-shadow: none; border: 1px solid var(--border-color);">
          <h4 style="margin: 0 0 6px;">Ana Program parolası — destek kodu</h4>
          <p style="margin: 0 0 12px; font-size: 13px; line-height: 1.55; color: var(--text-muted);">
            Okul Ana Program parolasını unuttuysa ve anahtar yedeği yoksa.
            Okuldan, Ana Program'da <strong>Parolamı unuttum → Yedeğim yok</strong>
            penceresindeki talep numarasını isteyin. Kodu yalnızca okulun resmî
            e-postasına gönderin: <strong>${kurum}@meb.k12.tr</strong>.
          </p>
          <div style="display: flex; gap: 8px; flex-wrap: wrap;">
            <input type="text" id="destek-talep" class="form-control" placeholder="Talep no (ör. K7MQ-2XPA)" style="max-width: 200px;">
            <input type="text" id="destek-gerekce" class="form-control" placeholder="Kim istedi, nasıl teyit edildi" style="flex: 1; min-width: 220px;">
            <button class="btn btn-primary" data-eylem="destekKoduUret">Kod üret</button>
          </div>
          <div id="destek-sonuc" style="margin-top: 12px;"></div>
        </div>`;
    },

    async destekKoduUret() {
      const o = this._okul;
      if (!o) return;
      const kurum = o.okulId.slice(4);
      const talep = document.getElementById('destek-talep')?.value || '';
      const gerekce = document.getElementById('destek-gerekce')?.value || '';
      const kutu = document.getElementById('destek-sonuc');
      if (kutu) kutu.textContent = 'Kod üretiliyor…';
      try {
        const s = await window.SinifCepteAdminAuth.issueSupportCode(kurum, talep, gerekce);
        const talepBicimli = talep.trim().toUpperCase();
        this._destekMetni = [
          'Konu: SınıfCepte Ana Program destek kodu',
          '',
          'Merhaba,',
          '',
          `${kurum} kurum kodlu okulunuzun Ana Program parolası için destek kodunuz ` +
            'aşağıdadır. Ana Program\'da "Parolamı unuttum → Yedeğim yok" penceresine ' +
            `yapıştırıp yeni parolanızı belirleyin. Kod yalnızca ${talepBicimli} numaralı ` +
            'talep için, talep oluşturulduktan sonra 24 saat geçerlidir.',
          '',
          s.kod,
          '',
          'Bu kodu siz istemediyseniz lütfen bize bildirin.',
        ].join('\n');
        if (kutu) {
          kutu.innerHTML = `
            <p style="margin: 0 0 6px; font-size: 13px;">
              Alıcı: <strong>${this.kacisliMetin(s.eposta)}</strong>
            </p>
            <pre style="white-space: pre-wrap; word-break: break-all; font-size: 12px; padding: 10px; border: 1px solid var(--border-color); border-radius: 8px;">${this.kacisliMetin(this._destekMetni)}</pre>
            <button class="btn btn-secondary" data-eylem="destekMetniKopyala">E-posta metnini kopyala</button>`;
        }
      } catch (e) {
        if (kutu) kutu.textContent = this.yayinHatasi(e);
      }
    },

    async destekMetniKopyala() {
      if (!this._destekMetni) return;
      try {
        await navigator.clipboard.writeText(this._destekMetni);
        this.showToast('E-posta metni kopyalandı.', 'success');
      } catch {
        this.showToast('Kopyalanamadı; metni seçip elle kopyalayın.', 'error');
      }
    },

    async dizindenCikar(uid) {
      const o = this._okul;
      const t = o?.ogretmenler.find((x) => x.uid === uid);
      if (!t) return;
      const yonetici = t.yoneticilik === 'approved'
        ? '\n\nBu kişi okulun YÖNETİCİSİ. Dizinden çıkarmak yöneticiliği kaldırmaz; ' +
          'gerekiyorsa "Okul Yöneticileri" sekmesinden ayrıca geri alın.'
        : '';
      const gerekce = prompt(
        `${t.ad} (${t.eposta}) ${o.okulId} dizininden çıkarılacak.${yonetici}\n\n` +
          'Kişi okulunu uygulamada yeniden seçerse kayıt yeniden oluşur.\n\nGerekçe:'
      );
      if (gerekce === null) return;
      if (!gerekce.trim()) {
        this.showToast('Gerekçe yazılmadan çıkarılamaz.', 'error');
        return;
      }
      try {
        await window.SinifCepteAdminAuth.removeFromSchoolDirectory(o.okulId, uid, gerekce);
        this.showToast(`${t.ad} dizinden çıkarıldı.`, 'success');
      } catch (e) {
        this.showToast(this.yayinHatasi(e), 'error');
      }
      await this.okulAra();
    },

    async kisiAra() {
      const eposta = document.getElementById('kisi-ara-eposta')?.value || '';
      const kutu = document.getElementById('kisi-sonuc');
      if (!kutu) return;
      kutu.textContent = 'Kişi okunuyor…';
      const m = (x) => this.kacisliMetin(x);
      const a = (x) => this.kacisliOznitelik(x);
      try {
        const { kisi } = await window.SinifCepteAdminAuth.findPerson(eposta.trim());
        if (!kisi) {
          kutu.textContent = 'Bu e-postayla SınıfCepte hesabı yok.';
          return;
        }
        const y = kisi.yetkiler;
        const yetkiler = [
          y.adminRole ? `Panel: ${m(y.adminRole)}` : '',
          y.schoolAdminStatus === 'approved' ? `Okul yöneticisi: ${m(y.schoolId)}` : '',
        ].filter(Boolean).join(' · ') || 'Yok';
        const okullar = kisi.okullar.length
          ? kisi.okullar.map((k) => `
              <button class="btn btn-sm btn-secondary" data-eylem="okulAc" data-arg="${a(k.okulId)}">
                ${m(k.okulId)}${k.brans ? ` · ${m(k.brans)}` : ''}
              </button>`).join(' ')
          : 'Hiçbir okulun dizininde değil.';
        kutu.innerHTML = `
          <table class="data-table" style="margin-top: 12px;">
            <tbody>
              <tr><th style="width: 160px;">Ad</th><td>${m(kisi.ad) || '—'}</td></tr>
              <tr><th>E-posta</th><td>${m(kisi.eposta)}</td></tr>
              <tr><th>Hesap</th><td>${kisi.devreDisi ? '<span class="badge badge-official">Devre dışı</span>' : 'Etkin'}
                <small style="color: var(--text-muted);">· açılış ${m(tarihYaz(kisi.olusturma))} · son giriş ${m(tarihYaz(kisi.sonGiris))}</small></td></tr>
              <tr><th>Yetkiler</th><td>${yetkiler}</td></tr>
              <tr><th>Okullar</th><td>${okullar}</td></tr>
              <tr><th>Kimlik</th><td><small style="color: var(--text-muted);">${m(kisi.uid)}</small></td></tr>
            </tbody>
          </table>`;
      } catch (e) {
        kutu.textContent = this.yayinHatasi(e);
      }
    },
  });

  // Enter ile arama. Satır içi `onkeydown` CSP'ye takılırdı; dinleyici burada.
  document.addEventListener('keydown', (olay) => {
    if (olay.key !== 'Enter') return;
    const hedef = olay.target;
    if (hedef?.id === 'okul-ara-kod') window.adminApp?.okulAra();
    if (hedef?.id === 'kisi-ara-eposta') window.adminApp?.kisiAra();
  });
})();
