/**
 * Tek admin kabuğu: super | moderator.
 * Firebase bağlanınca claim okunur. Şimdilik yerel geliştirme için rol seçici.
 */
(function () {
  const STORAGE_KEY = 'sinifcepte_admin_role';

  function currentRole() {
    return localStorage.getItem(STORAGE_KEY) || 'super';
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
      applyRole('super');
    },
  };

  document.addEventListener('DOMContentLoaded', () => {
    applyRole(currentRole());
  });
})();

