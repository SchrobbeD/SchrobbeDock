# Changelog

## 1.0.0

* **Initiële release van `schrobbedock_auth`**:
  * `SchrobbeDockAuthGuard` / `LicenseGate`: Uniforme authenticatie- en licentiebewaker voor alle Spoke apps.
  * `LoginRequiredView`: Gestandaardiseerd aanmeldscherm met directe SSO-redirect naar de centrale Hub.
  * `NoAccessView`: Toegangs- en licentiewall met inwisseling van uitnodigingscodes (`claim_invitation`) en indienen van toegangsaanvragen (`request_app_access`).
  * `SchrobbeDockUserMenu`: Kant-en-klare AppBar account- en profielwidget met avatar, Hub navigatie en uitlogactie.
