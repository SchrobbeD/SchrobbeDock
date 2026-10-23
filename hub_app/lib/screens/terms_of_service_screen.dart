import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gebruiksvoorwaarden'),
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
                          Icon(Icons.gavel_outlined,
                              size: 32, color: colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'SchrobbeDock Gebruiksvoorwaarden',
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
                        'Laatst bijgewerkt: oktober 2026 • Algemene Platform- en Licentievoorwaarden',
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
                title: '1. Toepasselijkheid',
                content:
                    'Deze Gebruiksvoorwaarden zijn van toepassing op elk bezoek aan en elk gebruik van het SchrobbeDock platform (robbedillen.be), inclusief de centrale Hub en alle aangesloten applicaties (Spokes). Door het platform te bezoeken of een account aan te maken, verklaart u zich akkoord met deze voorwaarden.',
              ),

              _buildSection(
                theme: theme,
                title: '2. Toegang, Accounts & Uitnodigingen',
                content:
                    '• Toegang tot het SchrobbeDock ecosysteem verloopt op basis van uitnodigingen en centrale licentietoewijzing.\n'
                    '• Het aanmaken van een account geeft uitsluitend toegang tot applicaties en modules waarvoor u expliciet een geldige licentie of rol heeft ontvangen.\n'
                    '• U bent zelf verantwoordelijk voor de vertrouwelijkheid van uw inloggegevens (wachtwoord en 2FA/TOTP geheimen) en alle activiteiten die onder uw account plaatsvinden.',
              ),

              _buildSection(
                theme: theme,
                title: '3. Aanvaardbaar Gebruik',
                content:
                    'U verplicht zich om het platform uitsluitend te gebruiken conform de geldende wetgeving en met respect voor de integriteit van het systeem. Het is ten strengste verboden om:\n\n'
                    '• Ongeautoriseerde pogingen te ondernemen om data van andere gebruikers of organisaties in te zien of te wijzigen (inclusief omzeiling van Row Level Security policies).\n'
                    '• Geautomatiseerde scrapers, bots of load testing tools te gebruiken zonder voorafgaande schriftelijke toestemming van de beheerder.\n'
                    '• Schadelijke code, virussen of exploits in te voeren of feedbackformulieren te misbruiken voor spam.',
              ),

              _buildSection(
                theme: theme,
                title: '4. Licenties & Intellectueel Eigendom',
                content:
                    'Alle rechten van intellectuele eigendom met betrekking tot het platform, inclusief software, ontwerp, logo\'s en documentatie, berusten bij SchrobbeDock en haar licentiegevers. Aan u wordt uitsluitend een niet-exclusief, herroepelijk en niet-overdraagbaar recht verleend om de software te gebruiken binnen de grenzen van uw toegekende licentie.',
              ),

              _buildSection(
                theme: theme,
                title: '5. Beschikbaarheid & Onderhoud',
                content:
                    'SchrobbeDock spant zich in om een continue en veilige werking van het platform te garanderen. Wij behouden ons het recht voor om het platform tijdelijk buiten gebruik te stellen voor noodzakelijk onderhoud, upgrades of beveiligingspatches zonder dat dit leidt tot enige aansprakelijkheid voor schade.',
              ),

              _buildSection(
                theme: theme,
                title: '6. Beëindiging & Deactivatie',
                content:
                    'U kunt uw account te allen tijde zelfstandig beëindigen via de optie "Account Verwijderen" in uw profielinstellingen. Platformbeheerders behouden zich het recht voor om accounts of licenties met onmiddellijke ingang op te schorten of in te trekken bij overtreding van deze voorwaarden.',
              ),

              _buildSection(
                theme: theme,
                title: '7. Toepasselijk Recht',
                content:
                    'Op deze voorwaarden en alle geschillen die voortvloeien uit of verband houden met het gebruik van SchrobbeDock is uitsluitend het Belgisch recht van toepassing.',
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
