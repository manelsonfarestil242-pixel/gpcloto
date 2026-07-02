// ─── User Model ─────────────────────────────────────────────────────────────
class UserModel {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String role; // 'admin' | 'agent' | 'vendeur'
  final String? avatarUrl;
  final bool isActive;
  final DateTime createdAt;
  final double solde;
  final String? codeAgent;

  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    this.avatarUrl,
    required this.isActive,
    required this.createdAt,
    required this.solde,
    this.codeAgent,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? json['nom'] ?? '',
      phone: json['phone'] ?? json['telephone'] ?? '',
      email: json['email'],
      role: json['role'] ?? 'vendeur',
      avatarUrl: json['avatar_url'],
      isActive: json['is_active'] ?? json['actif'] ?? true,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      solde: (json['solde'] ?? 0.0).toDouble(),
      codeAgent: json['code_agent'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'role': role,
    'avatar_url': avatarUrl,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
    'solde': solde,
    'code_agent': codeAgent,
  };

  UserModel copyWith({
    String? name,
    String? email,
    double? solde,
    bool? isActive,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      phone: phone,
      email: email ?? this.email,
      role: role,
      avatarUrl: avatarUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      solde: solde ?? this.solde,
      codeAgent: codeAgent,
    );
  }
}

// ─── Tirage (Draw) Model ────────────────────────────────────────────────────
class TirageModel {
  final String id;
  final String type;       // BORLETTE, LOTO, etc.
  final DateTime date;
  final String heure;
  final List<String> numeros;
  final bool isOuvert;
  final bool isTermine;
  final double totalMise;
  final double totalGain;

  const TirageModel({
    required this.id,
    required this.type,
    required this.date,
    required this.heure,
    required this.numeros,
    required this.isOuvert,
    required this.isTermine,
    required this.totalMise,
    required this.totalGain,
  });

  factory TirageModel.fromJson(Map<String, dynamic> json) {
    return TirageModel(
      id: json['id']?.toString() ?? '',
      type: json['type'] ?? 'BORLETTE',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      heure: json['heure'] ?? '',
      numeros: List<String>.from(json['numeros'] ?? []),
      isOuvert: json['is_ouvert'] ?? json['ouvert'] ?? false,
      isTermine: json['is_termine'] ?? json['termine'] ?? false,
      totalMise: (json['total_mise'] ?? 0.0).toDouble(),
      totalGain: (json['total_gain'] ?? 0.0).toDouble(),
    );
  }

  String get numerosDisplay => numeros.isEmpty ? '—' : numeros.join(' · ');

  bool get isEnCours => isOuvert && !isTermine;
}

// ─── Bet / Mise Model ────────────────────────────────────────────────────────
class MiseModel {
  final String numero;
  final double montant;
  final String position; // '1er', '2e', '3e', 'mariage'

  const MiseModel({
    required this.numero,
    required this.montant,
    required this.position,
  });

  factory MiseModel.fromJson(Map<String, dynamic> json) {
    return MiseModel(
      numero: json['numero']?.toString() ?? '',
      montant: (json['montant'] ?? 0.0).toDouble(),
      position: json['position'] ?? '1er',
    );
  }

  Map<String, dynamic> toJson() => {
    'numero': numero,
    'montant': montant,
    'position': position,
  };
}

// ─── Ticket Model ────────────────────────────────────────────────────────────
class TicketModel {
  final String id;
  final String code;        // Code ticket imprimable
  final String tirageId;
  final String tirageType;
  final List<MiseModel> mises;
  final double totalMise;
  final double? totalGain;
  final String statut;      // 'en_attente' | 'gagnant' | 'perdant' | 'annule'
  final DateTime createdAt;
  final String vendeurId;
  final String? vendeurNom;
  final bool isImprime;

  const TicketModel({
    required this.id,
    required this.code,
    required this.tirageId,
    required this.tirageType,
    required this.mises,
    required this.totalMise,
    this.totalGain,
    required this.statut,
    required this.createdAt,
    required this.vendeurId,
    this.vendeurNom,
    required this.isImprime,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    return TicketModel(
      id: json['id']?.toString() ?? '',
      code: json['code'] ?? '',
      tirageId: json['tirage_id']?.toString() ?? '',
      tirageType: json['tirage_type'] ?? 'BORLETTE',
      mises: (json['mises'] as List<dynamic>? ?? [])
          .map((m) => MiseModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      totalMise: (json['total_mise'] ?? 0.0).toDouble(),
      totalGain: json['total_gain'] != null
          ? (json['total_gain'] as num).toDouble()
          : null,
      statut: json['statut'] ?? 'en_attente',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      vendeurId: json['vendeur_id']?.toString() ?? '',
      vendeurNom: json['vendeur_nom'],
      isImprime: json['is_imprime'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'tirage_id': tirageId,
    'tirage_type': tirageType,
    'mises': mises.map((m) => m.toJson()).toList(),
    'total_mise': totalMise,
    'total_gain': totalGain,
    'statut': statut,
    'created_at': createdAt.toIso8601String(),
    'vendeur_id': vendeurId,
    'vendeur_nom': vendeurNom,
    'is_imprime': isImprime,
  };

  bool get isGagnant => statut == 'gagnant';
  bool get isPerdant => statut == 'perdant';
  bool get isAnnule => statut == 'annule';
  bool get isEnAttente => statut == 'en_attente';
}

// ─── Stats / Dashboard Model ─────────────────────────────────────────────────
class StatsModel {
  final double totalVentes;
  final double totalGains;
  final int nombreTickets;
  final int nombreGagnants;
  final double benefice;
  final List<VenteJournaliere> ventesParJour;

  const StatsModel({
    required this.totalVentes,
    required this.totalGains,
    required this.nombreTickets,
    required this.nombreGagnants,
    required this.benefice,
    required this.ventesParJour,
  });

  factory StatsModel.fromJson(Map<String, dynamic> json) {
    return StatsModel(
      totalVentes: (json['total_ventes'] ?? 0.0).toDouble(),
      totalGains: (json['total_gains'] ?? 0.0).toDouble(),
      nombreTickets: json['nombre_tickets'] ?? 0,
      nombreGagnants: json['nombre_gagnants'] ?? 0,
      benefice: (json['benefice'] ?? 0.0).toDouble(),
      ventesParJour: (json['ventes_par_jour'] as List<dynamic>? ?? [])
          .map((v) => VenteJournaliere.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }
}

class VenteJournaliere {
  final DateTime date;
  final double montant;
  final int tickets;

  const VenteJournaliere({
    required this.date,
    required this.montant,
    required this.tickets,
  });

  factory VenteJournaliere.fromJson(Map<String, dynamic> json) {
    return VenteJournaliere(
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      montant: (json['montant'] ?? 0.0).toDouble(),
      tickets: json['tickets'] ?? 0,
    );
  }
}
