import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widgets.dart';

class NouveauTicketScreen extends StatefulWidget {
  const NouveauTicketScreen({super.key});

  @override
  State<NouveauTicketScreen> createState() => _NouveauTicketScreenState();
}

class _NouveauTicketScreenState extends State<NouveauTicketScreen>
    with SingleTickerProviderStateMixin {
  // State
  List<TirageModel> _tirages = [];
  TirageModel? _selectedTirage;
  final List<MiseModel> _mises = [];
  bool _isLoadingTirages = true;
  bool _isSaving = false;
  String? _error;

  // Form for adding a mise
  final _numeroController = TextEditingController();
  final _montantController = TextEditingController();
  String _selectedPosition = '1er';

  // Positions disponibles
  final _positions = ['1er', '2e', '3e', 'Mariage'];

  final _currencyFmt = NumberFormat.currency(
    locale: 'fr_HT',
    symbol: 'HTG ',
    decimalDigits: 0,
  );

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTirages();
  }

  @override
  void dispose() {
    _numeroController.dispose();
    _montantController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTirages() async {
    setState(() {
      _isLoadingTirages = true;
      _error = null;
    });
    try {
      final tirages = await ApiService.instance.getTirages();
      final ouvertes = tirages.where((t) => t.isOuvert && !t.isTermine).toList();
      if (!mounted) return;
      setState(() {
        _tirages = ouvertes;
        _isLoadingTirages = false;
        if (ouvertes.isNotEmpty) _selectedTirage = ouvertes.first;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoadingTirages = false;
      });
    }
  }

  void _addMise() {
    final numero = _numeroController.text.trim();
    final montantText = _montantController.text.trim();

    // Validation
    if (numero.isEmpty) {
      _showError('Entrez un numéro.');
      return;
    }
    final numVal = int.tryParse(numero);
    if (numVal == null || numVal < 1 || numVal > 99) {
      _showError('Numéro invalide (01–99).');
      return;
    }
    final montant = double.tryParse(montantText);
    if (montant == null || montant < AppConstants.minBetAmount) {
      _showError('Montant minimum: ${AppConstants.minBetAmount} HTG.');
      return;
    }
    if (montant > AppConstants.maxBetAmount) {
      _showError('Montant maximum: ${AppConstants.maxBetAmount} HTG.');
      return;
    }
    if (_mises.length >= AppConstants.maxBetsPerTicket) {
      _showError('Maximum ${AppConstants.maxBetsPerTicket} mises par ticket.');
      return;
    }

    setState(() {
      _mises.add(MiseModel(
        numero: numero.padLeft(2, '0'),
        montant: montant,
        position: _selectedPosition,
      ));
    });

    // Clear fields
    _numeroController.clear();
    _montantController.clear();
    HapticFeedback.mediumImpact();
  }

  void _removeMise(int index) {
    setState(() => _mises.removeAt(index));
  }

  void _showError(String msg) {
    setState(() => _error = msg);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _error = null);
    });
  }

  double get _totalMise =>
      _mises.fold(0, (sum, m) => sum + m.montant);

  Future<void> _validerTicket() async {
    if (_selectedTirage == null) {
      _showError('Sélectionnez un tirage.');
      return;
    }
    if (_mises.isEmpty) {
      _showError('Ajoutez au moins une mise.');
      return;
    }

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmer le ticket'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tirage: ${_selectedTirage!.type} — ${_selectedTirage!.heure}'),
            const SizedBox(height: 8),
            Text('${_mises.length} mise(s)'),
            const SizedBox(height: 4),
            Text(
              'Total: ${_currencyFmt.format(_totalMise)}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final ticket = await ApiService.instance.createTicket(
        tirageId: _selectedTirage!.id,
        mises: _mises,
      );

      if (!mounted) return;

      // Navigate to ticket detail / print view
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TicketSuccessScreen(ticket: ticket),
        ),
      );

      setState(() => _mises.clear());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nouveau Ticket'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Saisie'),
            Tab(text: 'Récapitulatif'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSaisieTab(),
          _buildRecapTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildSaisieTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Error banner
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 12),
          ],

          // Sélection tirage
          const SectionHeader(title: 'Tirage'),
          if (_isLoadingTirages)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else if (_tirages.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                  SizedBox(width: 10),
                  Text(
                    'Aucun tirage ouvert actuellement.',
                    style: TextStyle(color: AppColors.warning),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<TirageModel>(
                  value: _selectedTirage,
                  isExpanded: true,
                  dropdownColor: AppColors.surfaceElevated,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  items: _tirages.map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Text('${t.type} — ${t.heure}'),
                    );
                  }).toList(),
                  onChanged: (t) => setState(() => _selectedTirage = t),
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Ajouter une mise
          const SectionHeader(title: 'Ajouter une mise'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                // Numéro + Position
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _numeroController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: 'Numéro',
                          hintText: '00',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPosition,
                            isExpanded: true,
                            dropdownColor: AppColors.surfaceElevated,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontFamily: 'Poppins',
                              fontSize: 14,
                            ),
                            items: _positions.map((p) {
                              return DropdownMenuItem(value: p, child: Text(p));
                            }).toList(),
                            onChanged: (p) =>
                                setState(() => _selectedPosition = p!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Montant
                TextFormField(
                  controller: _montantController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Poppins',
                    fontSize: 15,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Montant (HTG)',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                    hintText: '0',
                  ),
                  onFieldSubmitted: (_) => _addMise(),
                ),

                const SizedBox(height: 16),

                // Quick amount chips
                Wrap(
                  spacing: 8,
                  children: [25, 50, 100, 200, 500].map((amt) {
                    return ActionChip(
                      label: Text('$amt'),
                      onPressed: () {
                        _montantController.text = amt.toString();
                      },
                      backgroundColor: AppColors.surfaceVariant,
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Add button
                GpcButton(
                  label: 'Ajouter la mise',
                  onPressed: _addMise,
                  icon: Icons.add_rounded,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Mises list preview
          if (_mises.isNotEmpty) ...[
            SectionHeader(
              title: '${_mises.length} mise(s)',
              action: 'Tout supprimer',
              onAction: () => setState(() => _mises.clear()),
            ),
            ..._mises.asMap().entries.map((e) => _MiseRow(
                  mise: e.value,
                  index: e.key,
                  onDelete: () => _removeMise(e.key),
                )),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildRecapTab() {
    if (_mises.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 16),
            Text(
              'Aucune mise ajoutée',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Allez dans l\'onglet Saisie pour ajouter des mises',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Tirage info
        if (_selectedTirage != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.cardGradient,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  '${_selectedTirage!.type} — ${_selectedTirage!.heure}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Mises list
        ..._mises.asMap().entries.map((e) => _MiseRow(
              mise: e.value,
              index: e.key,
              onDelete: () => _removeMise(e.key),
            )),

        const SizedBox(height: 16),

        // Total
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textOnPrimary,
                  letterSpacing: 1,
                ),
              ),
              Text(
                _currencyFmt.format(_totalMise),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppColors.textOnPrimary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Total display
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_mises.length} mise(s)',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                _currencyFmt.format(_totalMise),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GpcButton(
              label: 'Valider le ticket',
              onPressed: (_mises.isEmpty || _isSaving) ? null : _validerTicket,
              isLoading: _isSaving,
              icon: Icons.check_circle_outline_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mise Row ─────────────────────────────────────────────────────────────────
class _MiseRow extends StatelessWidget {
  final MiseModel mise;
  final int index;
  final VoidCallback onDelete;

  const _MiseRow({
    required this.mise,
    required this.index,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          NumeroBall(numero: mise.numero, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mise.position,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${mise.montant.toStringAsFixed(0)} HTG',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error, size: 20),
            onPressed: onDelete,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}

// ─── Ticket Success Screen ────────────────────────────────────────────────────
class TicketSuccessScreen extends StatelessWidget {
  final TicketModel ticket;

  const TicketSuccessScreen({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ticket créé')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Ticket validé !',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Code: ${ticket.code}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),
              GpcButton(
                label: 'Imprimer le ticket',
                onPressed: () {
                  // Print logic
                },
                icon: Icons.print_rounded,
              ),
              const SizedBox(height: 12),
              GpcButton(
                label: 'Nouveau ticket',
                onPressed: () => Navigator.pop(context),
                icon: Icons.add_rounded,
                outlined: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
