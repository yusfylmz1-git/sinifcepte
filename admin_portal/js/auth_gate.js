/**
 * Tek admin kabuğu: super | moderator.
 * Firebase bağlanınca claim okunur. Şimdilik yerel geliştirme için rol seçici.
 */
(function () {
  const STORAGE_KEY = 'sinifcepte_admin_role';

  function currentRole() {
    return localStorage.getItem(STORAGE_KEY) || '';
  }

  function applyRole(role) {
    document.body.dataset.adminRole = role;
    document.querySelectorAll('[data-admin-only="super"]').forEach((el) => {
      el.style.display = role === 'super' ? '' : 'none';
    });
    const badge = document.getElementById('admin-role-badge');
    if (badge) {
      badge.textContent = role === 'super' ? 'Süper Admin' : role === 'moderator' ? 'Moderatör' : 'Giriş yok';
    }
  }

  window.SinifCepteAdminAuth = {
    currentRole,
    signInAs(role) {
      if (role !== 'super' && role !== 'moderator') return;
      localStorage.setItem(STORAGE_KEY, role);
      applyRole(role);
    },
    signOut() {
      localStorage.removeItem(STORAGE_KEY);
      applyRole('');
    },
  };

  document.addEventListener('DOMContentLoaded', () => {
    applyRole(currentRole());
    if (!currentRole()) {
      const bar = document.createElement('div');
      bar.style.cssText = 'padding:8px 16px;background:#111827;color:#fff;font:13px/1.4 sans-serif;display:flex;gap:8px;align-items:center;flex-wrap:wrap;';
      bar.innerHTML = '<span>Firebase bağlanınca Google ile giriş gelecek. Geliştirme:</span>';
      const superBtn = document.createElement('button');
      superBtn.textContent = 'Süper Admin olarak aç';
      superBtn.onclick = () => { window.SinifCepteAdminAuth.signInAs('super'); bar.remove(); };
      const modBtn = document.createElement('button');
      modBtn.textContent = 'Moderatör olarak aç';
      modBtn.onclick = () => { window.SinifCepteAdminAuth.signInAs('moderator'); bar.remove(); };
      bar.append(superBtn, modBtn);
      document.body.prepend(bar);
    }
  });
})();
