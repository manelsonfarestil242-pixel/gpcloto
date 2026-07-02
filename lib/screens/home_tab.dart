import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widgets.dart';

// Re-export HomeTab (used by router as the "/" tab inside MainShell)
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  StatsModel? _stats;
  List<TirageModel> _tiragesToday = [];
  bool _isLoading = true;
  String? _error;

  final _currencyFmt = NumberFormat.currency(
    locale: 'fr_HT',
    symbol: 'HTG ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final results = await Future.wait([
        ApiService.instance.getStats(),
        ApiService.instance.getTirages(date: today),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as StatsModel;
        _tiragesToday = results[1] as List<TirageModel>;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Impossible de charger les données.'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            // Hero AppBar
            SliverAppBar(
              expandedHeight: 210,
              pinned: true,
              backgroundColor: AppColors.surface,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  decoration: const BoxDecoration(gradient: AppColors.heroGradient),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const GpcLotoLogo(size: 34, showText: false),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bonjour, ${user?.name.split(' ').first ?? ''}',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins', fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(DateTime.now()),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            if (user != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _currencyFmt.format(user.solde),
                                  style: const TextStyle(
                                    fontFamily: 'Poppins', fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textOnPrimary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Quick actions
                        Row(
                          children: [
                            _QuickBtn(icon: Icons.add_circle_outline_rounded, label: 'Nouveau ticket', color: AppColors.primary, onTap: () {}),
                            const SizedBox(width: 10),
                            _QuickBtn(icon: Icons.qr_code_scanner_rounded, label: 'Vérifier', color: AppColors.secondary, onTap: () {}),
                            const SizedBox(width: 10),
                            _QuickBtn(icon: Icons.print_rounded, label: 'Imprimer', color: AppColors.info, onTap: () {}),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            if (_error != null)
              SliverToBoxAdapter(child: ErrorBanner(message: _error!, onRetry: _load)),

            // Stats
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: "Aujourd'hui"),
                    if (_isLoading)
                      GridView.count(
                        crossAxisCount: 2, shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12, mainAxisSpacing: 12,
                        childAspectRatio: 1.6,
                        children: List.generate(4, (_) =>
                            const ShimmerBox(width: double.infinity, height: 90, radius: 16)),
                      )
                    else if (_stats != null)
                      GridView.count(
                        crossAxisCount: 2, shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12, mainAxisSpacing: 12,
                        childAspectRatio: 1.6,
                        children: [
                          StatCard(label: 'Ventes', value: _currencyFmt.format(_stats!.totalVentes),
                              icon: Icons.trending_up_rounded, iconColor: AppColors.primary, subtitle: 'Aujourd\'hui'),
                          StatCard(label: 'Gains payés', value: _currencyFmt.format(_stats!.totalGains),
                              icon: Icons.emoji_events_rounded, iconColor: AppColors.secondary),
                          StatCard(label: 'Tickets', value: '${_stats!.nombreTickets}',
                              icon: Icons.confirmation_num_outlined, iconColor: AppColors.info),
                          StatCard(label: 'Bénéfice', value: _currencyFmt.format(_stats!.benefice),
                              icon: Icons.account_balance_wallet_outlined,
                              iconColor: _stats!.benefice >= 0 ? AppColors.success : AppColors.error),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // Tirages du jour
            const SliverToBoxAdapter(
              child: SectionHeader(title: 'Tirages du jour', action: 'Voir tout'),
            ),
            if (_isLoading)
              SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  child: ShimmerBox(width: double.infinity, height: 68, radius: 14),
                ),
                childCount: 3,
              ))
            else if (_tiragesToday.isEmpty)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(36),
                    child: Column(children: [
                      const Icon(Icons.event_busy_rounded, size: 44, color: AppColors.textMuted),
                      const SizedBox(height: 10),
                      const Text('Aucun tirage aujourd\'hui',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    ]),
                  ),
                ),
              )
            else
              SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) => _TirageRow(tirage: _tiragesToday[i]),
                childCount: _tiragesToday.length,
              )),

            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

class _TirageRow extends StatelessWidget {
  final TirageModel tirage;
  const _TirageRow({required this.tirage});

  @override
  Widget build(BuildContext context) {
    final statusColor = tirage.isEnCours
        ? AppColors.success
        : (tirage.isTermine ? AppColors.textMuted : AppColors.warning);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tirage.isEnCours ? AppColors.success.withOpacity(0.3) : AppColors.border,
        ),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(
            child: Text(
              tirage.type.substring(0, 1),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tirage.type, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
          Text(tirage.heure, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ])),
        if (tirage.isTermine && tirage.numeros.isNotEmpty)
          Row(children: tirage.numeros.take(3).map((n) =>
            Padding(padding: const EdgeInsets.only(left: 4),
              child: NumeroBall(numero: n, size: 30, isHighlight: true))).toList())
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(
              tirage.isEnCours ? 'En cours' : (tirage.isOuvert ? 'Ouvert' : 'Fermé'),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
            ),
          ),
      ]),
    );
  }
}
