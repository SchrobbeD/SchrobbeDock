import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacybeleid'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            children: [
              // Header Card
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest.withAlpha(128),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shield_outlined,
                              size: 32, color: colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'SchrobbeDock Privacybeleid',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Laatst bijgewerkt: oktober 2026 • Conform AVG / GDPR & Google API Services User Data Policy',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _buildSection(
                theme: theme,
                title: '1. Inleiding',
                content:
                    'SchrobbeDock (bereikbaar via robbedillen.be) is een modulair applicatieplatform bestaande uit een centrale Hub en aangesloten applicaties (Spokes). Wij hechten de hoogste waarde aan de bescherming van uw persoonsgegevens en transparantie over de wijze waarop gegevens worden verwerkt.',
              ),

              _buildSection(
                theme: theme,
                title: '2. Welke gegevens verzamelen wij?',
                content:
                    'Wij verwerken uitsluitend de minimale gegevens die noodzakelijk zijn om het platform veilig en functioneel aan te bieden:\n\n'
                    '• Accountgegevens: Bij handmatige registratie verwerken wij uw voornaam, achternaam, e-mailadres, telefoonnummer en adres.\n'
                    '• Gegevens via Google Sign-In (OAuth): Indien u inlogt via Google, ontvangen wij van Google uitsluitend uw naam, e-mailadres, account-ID en eventuele avatar-URL. Wij vragen géén toegang tot Google Drive, uw contacten, agenda of andere privégegevens.\n'
                    '• Licentie- & Rollengegevens: Welke applicaties u mag openen en welke rol (bijv. gebruiker, beheerder) u binnen die applicaties bezit.\n'
                    '• Diagnostische & Feedbackgegevens: Indien u een probleem of suggestie meldt via het feedbackmeldpunt, kunnen browser- en besturingssysteemversie en door u geüploade schermafbeeldingen worden meegestuurd ter ondersteuning van probleemoplossing.',
              ),

              _buildSection(
                theme: theme,
                title: '3. Doeleinden van de gegevensverwerking',
                content:
                    'Uw gegevens worden uitsluitend gebruikt voor:\n\n'
                    '1. Het veilig verifiëren van uw identiteit en het aanbieden van Single Sign-On over aangesloten apps.\n'
                    '2. Het afdwingen van Two-Factor Authentication (MFA/TOTP) ter bescherming tegen ongeautoriseerde toegang.\n'
                    '3. Het toekennen van licenties en autorisaties via onze centrale database.\n'
                    '4. Het leveren van technische ondersteuning en opvolging van bugmeldingen.',
              ),

              _buildSection(
                theme: theme,
                title: '4. Google API Limited Use Disclosure',
                content:
                    'Het gebruik en de overdracht van gegevens ontvangen via Google API\'s door SchrobbeDock naar enige andere applicatie voldoet te allen tijde aan het Google API Services User Data Policy, inclusief de vereisten voor Beperkt Gebruik (Limited Use Requirements).\n\n'
                    '• Wij verkopen of verhuren uw persoonsgegevens NOOIT aan derden.\n'
                    '• Wij gebruiken uw gegevens NOOIT voor advertentiedoeleinden, marketingprofilering of gerichte reclame.\n'
                    '• Wij gebruiken uw Google-gebruikersgegevens NOOIT voor het trainen van generatieve AI- of machine learning modellen.',
              ),

              _buildSection(
                theme: theme,
                title: '5. Gegevensbeveiliging & Opslag',
                content:
                    'Alle data wordt versleuteld verzonden via SSL/TLS en veilig opgeslagen in een PostgreSQL database beheerd via Supabase binnen de Europese Economische Ruimte (EER). Toegang tot data op databaseniveau is strikt geïsoleerd via PostgreSQL Row Level Security (RLS) policies.',
              ),

              _buildSection(
                theme: theme,
                title: '6. Uw rechten & Recht op Vergetelheid (Zelfstandig Verwijderen)',
                content:
                    'Conform de Algemene Verordening Gegevensbescherming (AVG) heeft u recht op inzage, rectificatie en volledige verwijdering van uw persoonsgegevens.\n\n'
                    'Zelfstandig Account Verwijderen: U kunt op elk gewenst moment in uw accountprofiel (/profile) klikken op "Account Verwijderen". Hierdoor worden uw inloggegevens, actieve sessies, licenties en profielgegevens per direct en onomkeerbaar gewist uit al onze systemen en back-ends.',
              ),

              _buildSection(
                theme: theme,
                title: '7. Contact & Vragen',
                content:
                    'Voor vragen over dit privacybeleid of de verwerking van uw gegevens kunt u contact opnemen met het SchrobbeDock beheer via robbedillen.be of via e-mail op privacy@robbedillen.be.',
              ),

              const SizedBox(height: 24),
              Center(
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/login');
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Begrepen & Terugkeren'),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required ThemeData theme,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
