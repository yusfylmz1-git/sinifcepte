/**
 * Yönetim paneli girişi — gerçek Firebase Auth.
 *
 * ## Neden değişti
 * Eski hâli rol seçiciydi:
 *
 *     signInAs(role) { localStorage.setItem(STORAGE_KEY, role); }
 *
 * Tarayıcı konsolundan `localStorage.setItem('sinifcepte_admin_role',
 * 'super')` yazan herkes süper yönetici görünüyordu. Panel yalnızca
 * yerelde çalışırken bu bir soruna yol açmadı; ama panel artık Remote
 * Config yayınlıyor ve o yayın 30.000 öğretmeni etkiliyor.
 *
 * ## Yetki nereden geliyor
 * `adminRole` custom claim'inden. Claim yalnızca Admin SDK ile
 * yazılabilir (`scripts/admin/bootstrap_super_admin.mjs`) — tarayıcıdan
 * değiştirilemez. `firestore.rules` içindeki `isSuper()` de aynı
 * claim'e bakıyor, yani panel ile veritabanı aynı kaynağı kullanıyor.
 *
 * Asıl koruma burada değil sunucuda: `publishRemoteConfig` fonksiyonu
 * claim'i KENDİ doğruluyor. Buradaki kontrol yalnızca arayüz içindir —
 * yetkisiz kullanıcıya boş panel göstermek yerine açık mesaj vermek.
 */
import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js';
import {
  getAuth,
  GoogleAuthProvider,
  signInWithPopup,
  signOut as fbSignOut,
  onAuthStateChanged,
} from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js';
import {
  getFunctions,
  httpsCallable,
} from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-functions.js';

/**
 * Web istemci yapılandırması.
 *
 * Gizli değil: `lib/firebase_options.dart` içindeki değerlerin aynısı ve
 * her Firebase web uygulamasında istemciye iner. Güvenlik anahtarlarla
 * değil, Auth + kurallar + claim ile sağlanır.
 */
const firebaseConfig = {
  apiKey: 'AIzaSyBjANe_mwiLEy1Y2y3_ccgYrE_vu5CNL80',
  appId: '1:80400507045:web:d3598cb8714bcee98f2d4c',
  messagingSenderId: '80400507045',
  projectId: 'sinifcepte',
  authDomain: 'sinifcepte.firebaseapp.com',
  storageBucket: 'sinifcepte.firebasestorage.app',
};

/** Cloud Functions bölgesi — `functions/index.js` ile aynı olmalı. */
const BOLGE = 'europe-west1';

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const functions = getFunctions(app, BOLGE);

/** Oturumdaki kullanıcı ve rolü. Giriş yoksa rol boştur. */
let durum = { user: null, role: '' };

function rolUygula(role) {
  document.body.dataset.adminRole = role || 'yok';

  // Süper yöneticiye özel alanlar.
  document.querySelectorAll('[data-admin-only="super"]').forEach((el) => {
    el.style.display = role === 'super' ? '' : 'none';
  });

  // Giriş yapılmadan panel içeriği görünmemeli.
  const kabuk = document.getElementById('admin-shell');
  const kapi = document.getElementById('admin-login-gate');
  if (kabuk) kabuk.style.display = role ? '' : 'none';
  if (kapi) kapi.style.display = role ? 'none' : 'flex';

  const badge = document.getElementById('admin-role-badge');
  if (badge) {
    badge.textContent =
      role === 'super'
        ? 'Süper Admin'
        : role === 'moderator'
          ? 'Moderatör'
          : 'Giriş yok';
  }

  const hesap = document.getElementById('admin-account-email');
  if (hesap) hesap.textContent = durum.user?.email || '';
}

function hataGoster(mesaj) {
  const el = document.getElementById('admin-login-error');
  if (el) {
    el.textContent = mesaj;
    el.style.display = mesaj ? 'block' : 'none';
  }
}

/**
 * Kullanıcının claim'ini okur.
 *
 * `true` ile zorla tazeleniyor: `setCustomUserClaims` çağrıldıktan sonra
 * mevcut token ~1 saat boyunca eski claim'i taşır. Yönetici yetkiyi yeni
 * almışsa beklemek zorunda kalmasın.
 */
async function rolOku(user) {
  try {
    const sonuc = await user.getIdTokenResult(true);
    const role = sonuc.claims?.adminRole;
    return role === 'super' || role === 'moderator' ? role : '';
  } catch (e) {
    console.error('Claim okunamadı:', e);
    return '';
  }
}

window.SinifCepteAdminAuth = {
  currentRole: () => durum.role,
  currentUser: () => durum.user,

  /** Google ile giriş. */
  async signIn() {
    hataGoster('');
    try {
      const provider = new GoogleAuthProvider();
      await signInWithPopup(auth, provider);
      // Rol atamasını onAuthStateChanged yapar.
    } catch (e) {
      if (e.code === 'auth/popup-closed-by-user') return;
      if (e.code === 'auth/unauthorized-domain') {
        hataGoster(
          'Bu adres Firebase Authentication’da yetkili değil. ' +
            'Console → Authentication → Settings → Authorized domains ' +
            'listesine ekleyin.'
        );
        return;
      }
      hataGoster(`Giriş başarısız: ${e.message}`);
    }
  },

  async signOut() {
    await fbSignOut(auth);
  },

  /**
   * Remote Config yayını — sunucudaki fonksiyonu çağırır.
   *
   * Anahtar tarayıcıya inmez; yetki fonksiyonda doğrulanır.
   *
   * `onceki`: değiştirilen her AYAR için panelin gördüğü canlı değer.
   * Bu arada başkası değiştirdiyse sunucu yayını reddeder (K8).
   */
  async publishRemoteConfig(params, onceki = undefined) {
    const cagir = httpsCallable(functions, 'publishRemoteConfig');
    const sonuc = await cagir(onceki === undefined ? { params } : { params, onceki });
    return sonuc.data;
  },

  /**
   * Panelin yönettiği Remote Config parametrelerinin CANLI değerleri.
   *
   * Panel ekranı ve yayınları yerel kayıttan değil bundan kuruyor:
   * yerel kayıt başka bir tarayıcıda yapılan değişikliği bilmiyordu.
   */
  async readRemoteConfig() {
    const cagir = httpsCallable(functions, 'readRemoteConfig');
    const sonuc = await cagir({});
    return sonuc.data;
  },

  /** Okul yöneticiliği başvuruları (durum: pending | approved | rejected). */
  async listSchoolAdminRequests(durum) {
    const cagir = httpsCallable(functions, 'listSchoolAdminRequests');
    const sonuc = await cagir({ durum });
    return sonuc.data;
  },

  /**
   * Okul yöneticiliği kararı: 'onay' | 'red' | 'geri_al'.
   *
   * Claim sunucuda yazılıyor; buradan yalnızca istek gidiyor.
   */
  async decideSchoolAdmin(uid, karar, gerekce = '') {
    const cagir = httpsCallable(functions, 'decideSchoolAdmin');
    const sonuc = await cagir({ uid, karar, gerekce });
    return sonuc.data;
  },

  /** Okul görünümü: kayıtlı öğretmenler, yöneticilik, geçmiş. */
  async schoolOverview(okul) {
    const cagir = httpsCallable(functions, 'schoolOverview');
    const sonuc = await cagir({ okul });
    return sonuc.data;
  },

  /** E-postayla kişi: hesap, yetkiler, okullar. */
  async findPerson(eposta) {
    const cagir = httpsCallable(functions, 'findPerson');
    const sonuc = await cagir({ eposta });
    return sonuc.data;
  },

  /**
   * Ana Program parolası için destek kodu (yalnızca süper yönetici).
   * İmza sunucuda; gizli anahtar tarayıcıya inmez.
   */
  async issueSupportCode(kurumKodu, talep, gerekce) {
    const cagir = httpsCallable(functions, 'issueSupportCode');
    const sonuc = await cagir({ kurumKodu, talep, gerekce });
    return sonuc.data;
  },

  /** Öğretmeni okulun dizininden çıkarır (yalnızca süper yönetici). */
  async removeFromSchoolDirectory(okulId, uid, gerekce) {
    const cagir = httpsCallable(functions, 'removeFromSchoolDirectory');
    const sonuc = await cagir({ okulId, uid, gerekce });
    return sonuc.data;
  },

  /**
   * ÖSYM takvimini çeker ve mevcut veriyle karşılaştırır.
   *
   * YAYINLAMAZ — yalnızca farkları döndürür. Yayın ayrı bir çağrı ve
   * yöneticinin onayını gerektirir.
   */
  async fetchOsymTakvim(mevcut) {
    const cagir = httpsCallable(functions, 'fetchOsymTakvim');
    const sonuc = await cagir({ mevcut });
    return sonuc.data;
  },
};

onAuthStateChanged(auth, async (user) => {
  if (!user) {
    durum = { user: null, role: '' };
    rolUygula('');
    return;
  }

  const role = await rolOku(user);
  if (!role) {
    // Giriş yapıldı ama yetki yok: hesabı açık bırakmak yanıltıcı olur.
    durum = { user: null, role: '' };
    rolUygula('');
    hataGoster(
      `${user.email} hesabının yönetici yetkisi yok. ` +
        'Yetki almak için süper yöneticiye başvurun.'
    );
    await fbSignOut(auth);
    return;
  }

  durum = { user, role };
  hataGoster('');
  rolUygula(role);
});

// Giriş bilgisi gelene kadar panel gizli kalsın: yetkisiz kullanıcı
// içeriği bir an bile görmemeli.
document.addEventListener('DOMContentLoaded', () => rolUygula(''));
