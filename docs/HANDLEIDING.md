# SchrobbeDock - Handleiding voor Gebruikers & Beheerders

> **Documenttype**: Praktische Handleiding  
> **Toepassing**: Centrale Hub ([robbedillen.be](https://robbedillen.be)) en aangesloten applicaties  
> **Versie**: v1.0.0

---

# DEEL 1: Handleiding voor Eindgebruikers

Welkom bij SchrobbeDock! Deze handleiding helpt je om snel en veilig aan de slag te gaan.

---

### 1. Registreren & Eerste Keer Aanmelden

Toegang tot SchrobbeDock verloopt op basis van **uitnodigingen**. Je hebt een uitnodigingslink of 8-cijferige code ontvangen van de beheerder.

#### Optie A: Registreren met E-mail & Wachtwoord
1. Ga naar [robbedillen.be/#/register](https://robbedillen.be/#/register).
2. Vul je uitnodigingscode in (indien niet automatisch ingevuld via de link).
3. Vul je persoonsgegevens in: voornaam, achternaam, e-mailadres en telefoonnummer.
4. Kies een sterk wachtwoord (minimaal 8 tekens) en klik op **"Account Aanmaken & Doorgaan naar 2FA"**.

#### Optie B: Aanmelden met Google (Aanbevolen)
1. Ga naar [robbedillen.be/#/register](https://robbedillen.be/#/register) en vul eerst je uitnodigingscode in.
2. Klik op **"Aanmelden & Registreren met Google"**.
3. Kies je gewenste Google-account.
4. Je code wordt automatisch gekoppeld aan je nieuwe account en je landt direct op het dashboard.

---

### 2. Twee-Staps-Verificatie (2FA / TOTP) Instellen

Voor optimale beveiliging van je account is Two-Factor Authentication verplicht voor accounts met een wachtwoord:

1. Na registratie kom je op het scherm **2FA Koppelen**.
2. Open je favoriete authenticator-app op je telefoon (bijv. *Google Authenticator*, *Microsoft Authenticator* of *1Password*).
3. Scan de getoonde **QR-code** (of voer handmatig de geheime tekstcode in).
4. Vul de gegenereerde 6-cijferige verificatiecode in.
5. Zodra je het 6e cijfer typt, controleert het systeem de code automatisch en wordt 2FA geactiveerd!

---

### 3. Het Dashboard & Applicaties Openen

Na het inloggen kom je op het centrale **Dashboard**:

* **Apps Openen**: Klik op een applicatiekaart om de betreffende Spoke app te openen.
* **Licentie- & Versie-informatie**: Klik op het kleine **`(i)` icoontje** rechtsboven op een app-kaart om te zien:
  * Welke rol je bezit (bijv. *Gebruiker* of *Beheerder*).
  * Tot wanneer je licentie geldig is.
  * Welke versie van de app momenteel actief is.
* **Extra Code Inwisselen**: Heb je een uitnodigingscode ontvangen voor een nieuwe app? Klik in de bovenbalk op **"Code Inwisselen"**, typ de code in en de nieuwe app verschijnt direct op je scherm.

---

### 4. Uiterlijk & Thema Aanpassen

Personaliseer je werkruimte naar wens:

1. Klik rechtsboven op je **Profielfoto / Avatar** en kies **"Uiterlijk & Thema"**.
2. Kies je modus: *Systeemvoorkeur*, altijd *Licht* of altijd *Donker* (Deep Slate).
3. Kies uit één van de ontworpen kleurtemplates:
   * **Warm Amber & Roest** (Standaard handelsmerk)
   * **Ocean Deep** (Maritiem blauw)
   * **Emerald Forest** (Smaragdgroen)
   * **Midnight Violet** (Dieppaars)
   * **Slate Monolith** (Industrieel neutraal grijs)
4. Of kies een eigen accentkleur via de ingebouwde **Color Picker**.
5. *Jouw thema-instellingen worden automatisch gesynchroniseerd over al je aangesloten Spoke apps!*

---

### 5. Problemen of Ideeën Melden & Opvolgen

Werkt er iets niet naar behoren of heb je een suggestie?

1. Klik op het **vraagteken / feedback-icoontje** (onderaan het scherm of in de AppBar).
2. Beschrijf kort wat er gebeurt of wat je suggestie is.
3. *Optioneel*: Voeg een schermafbeelding toe (automatisch of kies een bestand van je apparaat).
4. Klik op **Verzenden**. De melding wordt automatisch doorgestuurd naar het ontwikkelingsteam.
5. **Opvolgen**: Ga in het menu naar **"Mijn Meldingen"** om de actuele status van je melding te volgen en direct te chatten met de ontwikkelaars.

---

### 6. Account Beëindigen (Recht op Vergetelheid / AVG)

Wil je je account definitief stopzetten?
1. Ga via je avatar naar **"Mijn Profiel"**.
2. Scroll naar de rode **Gevarenzone** onderaan de pagina.
3. Klik op **"Account Verwijderen"**.
4. Typ het woord `VERWIJDER` over ter bevestiging.
5. Al je gegevens, licenties en actieve sessies worden per direct en definitief gewist uit al onze databases.

---

# DEEL 2: Handleiding voor Platformbeheerders

Als **Platform Admin** beheer je de toegang, licenties en meldingen voor het hele ecosysteem.

---

### 1. Beheerdersdashboard Betreden

Beheerfuncties zijn te vinden onder de **Admin** knoppen in de navigatiebalk. 
* *Let op*: Toegang tot admin-routes (`/admin/*`) vereist altijd een geverifieerde 2FA-sessie (Zero-Trust).

---

### 2. Uitnodigingen Aanmaken & Toegang Verlenen (`/admin/invites`)

1. Ga naar **Admin ➔ Uitnodigingen**.
2. Klik op **"Nieuwe Uitnodiging Aanmaken"**.
3. Vul de velden in:
   * **Bestemmeling (`recipient_name`)**: De naam van de persoon (bijv. *"Jan Peeters"*). Dit is puur voor je eigen administratie zodat je weet wie welke code heeft gekregen.
   * **Applicatie (`app_id`)**: Voor welke Spoke app de licentie geldt.
   * **Rol (`role`)**: Welke rechten de gebruiker krijgt (standaard: `user`).
   * **Geldigheidsduur**: Bepaal de vervaldatum van de uitnodiging.
4. Klik op **Aanmaken**.
5. Het systeem genereert direct een unieke code én een kant-en-klaar bericht inclusief directe registratielink:
   > *"Kopieer het kant-en-klare bericht met 1 klik en stuur dit via WhatsApp, Teams of e-mail naar de genodigde."*

---

### 3. Uitnodigingsstatus Monitoren & Intrekken

In het uitnodigingenoverzicht zie je direct:
* **Openstaand**: Nog niet geclaimd door de ontvanger.
* **Geclaimd**: Verzilverd. Je ziet precies wie (e-mailadres) de code heeft ingewisseld en op welk tijdstip.
* **Verlopen**: Codes waarvan de geldigheid is verstreken.
* **Intrekken**: Klik op het prullenbak-icoon bij een openstaande code om deze per direct ongeldig te maken.

---

### 4. 2FA Reset Procedure (Gebruiker Buitengesloten)

Heeft een gebruiker zijn telefoon verloren of kan hij zijn 2FA-code niet meer genereren?

1. Ga naar **Admin ➔ Uitnodigingen** en open het tabblad **"Gebruikers & 2FA"**.
2. Zoek de betreffende gebruiker op in de lijst.
3. Klik op de knop **"2FA Resetten"**.
4. Bevestig de waarschuwing.
5. De geregistreerde 2FA-factor van de gebruiker wordt veilig verwijderd. Bij de volgende inlogpoging kan de gebruiker een nieuw apparaat koppelen.

---

### 5. Centraal Feedback- & Probleembeheer (`/admin/feedback`)

Alle storingsmeldingen uit de Hub en alle Spoke apps komen hier samen:

* **Filteren**: Filter eenvoudig op app (`app_slug`), meldingstype (*bug*, *feature*) of status (*open*, *in_progress*, *resolved*).
* **Details & Diagnostiek**: Klap een melding open om het besturingssysteem, de browserversie en eventuele stacktraces van de crash te bekijken.
* **Status Wijzigen**: Zet een ticket op *In Behandeling* of *Opgelost*. Deze status synchroniseert automatisch real-time tweeweg met het gekoppelde **GitHub Issue** in de repository van de app!
* **Chatten**: Reageer direct op de melder via de ingebouwde chat. Reacties worden tevens als comment op GitHub geplaatst.
* **AVG Verwijderen (Hard Delete)**: Moet een testmelding of vertrouwelijke data (bijv. per ongeluk meegestuurd wachtwoord) definitief gewist worden? Klik op de rode knop *Melding Verwijderen* en typ `VERWIJDER`. Dit wist het record in de database, alle screenshots in storage én verwijdert het GitHub Issue via de API.

---

### 6. Live Versie Validatie & Cache Legen

In de beheerbalk zie je altijd de actieve softwareversie en Git commit hash (bijv. `v1.0.0 (3df4523)`).

* Klik op de versie-badge om de **Systeem Info Modal** te openen.
* Zie je wijzigingen na een deployment nog niet direct wegens browsercaching? Klik op **"Cache Legen & Geforceerd Herladen"**. Dit unregisters eventuele service workers en ververst de applicatie geforceerd met de nieuwste live assets.
