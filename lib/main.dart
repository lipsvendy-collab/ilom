// ============================================================
//  main.dart — Champion: Football Hero [v5.3] — WHITE/BLUE THEME
//  Penalty Kick Football RPG
//  API URL: https://totalonlinesport.win/Malin
// ============================================================

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

// СТАЛО (как Niwali)
const _kOfferUrl = ''; // твой прямой URL https://totalonlinesport.win/Malin

bool _offerShownThisSession = false;

// ══════════════════════════════════════════════
//  GAME CONSTANTS — WHITE/BLUE/LIGHT-BLUE PALETTE
// ══════════════════════════════════════════════
const kBg          = Color(0xFF080F1A);   // very dark navy background
const kCard        = Color(0xFF0D1B2A);   // dark blue card
const kBorder      = Color(0xFF1A2E44);   // blue border
const kGold        = Color(0xFF2196F3);   // main blue (primary accent)
const kGoldDark    = Color(0xFF0D47A1);   // dark blue
const kPurple      = Color(0xFF1565C0);   // medium blue
const kPurpleDark  = Color(0xFF0A1628);   // very dark navy
const kPurpleLight = Color(0xFF42A5F5);   // light blue
const kWhite       = Color(0xFFFFFFFF);
const kWhite70     = Color(0xB3FFFFFF);
const kWhite30     = Color(0x4DFFFFFF);
const kGoldAccent  = Color(0xFF81D4FA);   // sky blue accent
const kGoldLight   = Color(0xFFB3E5FC);   // very light blue / near-white

const kPrimary     = kGold;
const kPrimaryDark = kGoldDark;
const kAccent      = kPurpleLight;
const kFieldDark   = Color(0xFF0A1628);   // dark navy field
const kFieldLight  = Color(0xFF1565C0);   // medium blue field

// ══════════════════════════════════════════════
//  GAME MODELS
// ══════════════════════════════════════════════
enum CardRarity { common, rare, epic, legendary }

class PlayerCard {
  final String id, name, position, club;
  final int overall, shooting, speed, technique;
  final CardRarity rarity;
  final Color teamColor;
  const PlayerCard({
    required this.id, required this.name, required this.position,
    required this.club, required this.overall, required this.shooting,
    required this.speed, required this.technique,
    required this.rarity, required this.teamColor,
  });
  int get powerBonus => ((shooting - 70) / 3).clamp(0, 9).round();
  Color get rarityColor {
    switch (rarity) {
      case CardRarity.common:    return const Color(0xFFCCCCCC);
      case CardRarity.rare:      return kGoldLight;
      case CardRarity.epic:      return kGoldAccent;
      case CardRarity.legendary: return kGold;
    }
  }
  List<Color> get rarityGradient {
    switch (rarity) {
      case CardRarity.common:    return [const Color(0xFF1A2233), const Color(0xFF0D1520)];
      case CardRarity.rare:      return [const Color(0xFF1A2A4A), const Color(0xFF0D1C33)];
      case CardRarity.epic:      return [const Color(0xFF1A3A5A), const Color(0xFF0D2040)];
      case CardRarity.legendary: return [const Color(0xFF1A4A7A), const Color(0xFF0D2A55)];
    }
  }
  String get rarityLabel {
    switch (rarity) {
      case CardRarity.common:    return 'COMMON';
      case CardRarity.rare:      return 'RARE';
      case CardRarity.epic:      return 'EPIC';
      case CardRarity.legendary: return 'LEGENDARY';
    }
  }
}

class League {
  final String id, name, country, emblem;
  final int minLevel, matchCount, gkDifficulty;
  final int coinsPerGoal, xpPerGoal, completionBonus;
  final Color accentColor;
  const League({
    required this.id, required this.name, required this.country,
    required this.emblem, required this.minLevel, required this.matchCount,
    required this.gkDifficulty, required this.coinsPerGoal,
    required this.xpPerGoal, required this.completionBonus,
    required this.accentColor,
  });
}

// ══════════════════════════════════════════════
//  GAME MANAGER (SINGLETON)
// ══════════════════════════════════════════════
class GameManager {
  static final GameManager instance = GameManager._();
  GameManager._();

  int coins = 500, gems = 5, xp = 0, level = 1;
  int totalGoals = 0, totalSaves = 0, bestStreak = 0, currentStreak = 0;
  int tournamentWins = 0;
  List<String> ownedCardIds = [];
  String activeCardId = 'bronze_striker';
  String playerName = 'Football Fan';
  String? profileImagePath;
  Map<String, int> leagueProgress = {};

  int get xpForNext => level * 120;
  double get xpFraction => (xp / xpForNext).clamp(0.0, 1.0);

  PlayerCard get activeCard =>
      kAllCards.firstWhere((c) => c.id == activeCardId,
          orElse: () => kAllCards.first);

  List<PlayerCard> get ownedCards =>
      kAllCards.where((c) => ownedCardIds.contains(c.id)).toList();

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    coins         = p.getInt('g_coins')  ?? 500;
    gems          = p.getInt('g_gems')   ?? 5;
    xp            = p.getInt('g_xp')     ?? 0;
    level         = p.getInt('g_level')  ?? 1;
    totalGoals    = p.getInt('g_goals')  ?? 0;
    totalSaves    = p.getInt('g_saves')  ?? 0;
    bestStreak    = p.getInt('g_bstreak')  ?? 0;
    currentStreak = p.getInt('g_cstreak')  ?? 0;
    tournamentWins= p.getInt('g_twins')    ?? 0;
    activeCardId  = p.getString('g_activecard') ?? 'bronze_striker';
    playerName    = p.getString('user_name')    ?? 'Football Fan';
    profileImagePath = p.getString('icon_path');
    ownedCardIds  = p.getStringList('g_cards') ?? ['bronze_striker'];
    final lpRaw = p.getString('g_leagueprog');
    if (lpRaw != null) {
      try {
        final m = jsonDecode(lpRaw) as Map<String, dynamic>;
        leagueProgress = m.map((k, v) => MapEntry(k, v as int));
      } catch (_) {}
    }
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('g_coins', coins);
    await p.setInt('g_gems', gems);
    await p.setInt('g_xp', xp);
    await p.setInt('g_level', level);
    await p.setInt('g_goals', totalGoals);
    await p.setInt('g_saves', totalSaves);
    await p.setInt('g_bstreak', bestStreak);
    await p.setInt('g_cstreak', currentStreak);
    await p.setInt('g_twins', tournamentWins);
    await p.setString('g_activecard', activeCardId);
    await p.setString('user_name', playerName);
    if (profileImagePath != null) await p.setString('icon_path', profileImagePath!);
    await p.setStringList('g_cards', ownedCardIds);
    await p.setString('g_leagueprog', jsonEncode(leagueProgress));
  }

  Future<void> recordGoal({required int coinReward, required int xpReward}) async {
    coins += coinReward;
    xp    += xpReward;
    totalGoals++;
    currentStreak++;
    if (currentStreak > bestStreak) bestStreak = currentStreak;
    _checkLevel();
    await save();
  }

  Future<void> recordSave() async {
    totalSaves++;
    currentStreak = 0;
    await save();
  }

  void _checkLevel() {
    while (xp >= xpForNext) { xp -= xpForNext; level++; }
  }

  Future<List<PlayerCard>> openPack({bool isPremium = false}) async {
    final rng = math.Random();
    final result = <PlayerCard>[];
    final count = isPremium ? 5 : 3;
    for (int i = 0; i < count; i++) {
      final roll = rng.nextDouble();
      CardRarity rarity;
      if (isPremium) {
        if (roll < 0.10)      rarity = CardRarity.legendary;
        else if (roll < 0.35) rarity = CardRarity.epic;
        else if (roll < 0.70) rarity = CardRarity.rare;
        else                  rarity = CardRarity.common;
      } else {
        if (roll < 0.04)      rarity = CardRarity.legendary;
        else if (roll < 0.15) rarity = CardRarity.epic;
        else if (roll < 0.45) rarity = CardRarity.rare;
        else                  rarity = CardRarity.common;
      }
      final pool = kAllCards.where((c) => c.rarity == rarity).toList();
      result.add(pool[rng.nextInt(pool.length)]);
    }
    for (final c in result) {
      if (!ownedCardIds.contains(c.id)) ownedCardIds.add(c.id);
    }
    coins -= isPremium ? 300 : 100;
    await save();
    return result;
  }

  Future<void> progressLeague(String leagueId) async {
    leagueProgress[leagueId] = (leagueProgress[leagueId] ?? 0) + 1;
    tournamentWins++;
    await save();
  }
}

// ══════════════════════════════════════════════
//  CARD DATA
// ══════════════════════════════════════════════
const kAllCards = <PlayerCard>[
  PlayerCard(id:'mbappe',    name:'MBAPPÉ',    position:'FW', club:'PSG',       overall:98, shooting:97, speed:99, technique:96, rarity:CardRarity.legendary, teamColor:Color(0xFF004170)),
  PlayerCard(id:'haaland',   name:'HAALAND',   position:'ST', club:'Man City',  overall:97, shooting:98, speed:94, technique:88, rarity:CardRarity.legendary, teamColor:Color(0xFF6CABDD)),
  PlayerCard(id:'vinicius',  name:'VINÍCIUS',  position:'FW', club:'R. Madrid', overall:96, shooting:91, speed:97, technique:94, rarity:CardRarity.legendary, teamColor:Color(0xFFD4AF37)),
  PlayerCard(id:'bellingham',name:'BELLINGHAM',position:'CM', club:'R. Madrid', overall:95, shooting:88, speed:87, technique:92, rarity:CardRarity.legendary, teamColor:Color(0xFFD4AF37)),
  PlayerCard(id:'salah',     name:'SALAH',     position:'FW', club:'Liverpool', overall:94, shooting:93, speed:91, technique:90, rarity:CardRarity.legendary, teamColor:Color(0xFFC8102E)),
  PlayerCard(id:'kane',      name:'KANE',      position:'ST', club:'Bayern',    overall:92, shooting:94, speed:78, technique:87, rarity:CardRarity.epic,      teamColor:Color(0xFFDC052D)),
  PlayerCard(id:'saka',      name:'SAKA',      position:'FW', club:'Arsenal',   overall:90, shooting:86, speed:85, technique:91, rarity:CardRarity.epic,      teamColor:Color(0xFFEF0107)),
  PlayerCard(id:'dembele',   name:'DEMBÉLÉ',   position:'FW', club:'PSG',       overall:89, shooting:85, speed:93, technique:89, rarity:CardRarity.epic,      teamColor:Color(0xFF004170)),
  PlayerCard(id:'pedri',     name:'PEDRI',     position:'CM', club:'Barcelona', overall:89, shooting:80, speed:78, technique:94, rarity:CardRarity.epic,      teamColor:Color(0xFF004D98)),
  PlayerCard(id:'leao',      name:'LEÃO',      position:'FW', club:'Milan',     overall:88, shooting:84, speed:92, technique:87, rarity:CardRarity.epic,      teamColor:Color(0xFFFA0023)),
  PlayerCard(id:'son',       name:'SON',       position:'FW', club:'Spurs',     overall:87, shooting:85, speed:86, technique:86, rarity:CardRarity.epic,      teamColor:Color(0xFF132257)),
  PlayerCard(id:'musiala',   name:'MUSIALA',   position:'AM', club:'Bayern',    overall:87, shooting:82, speed:83, technique:92, rarity:CardRarity.epic,      teamColor:Color(0xFFDC052D)),
  PlayerCard(id:'rashford',  name:'RASHFORD',  position:'FW', club:'Man Utd',   overall:85, shooting:83, speed:90, technique:82, rarity:CardRarity.rare,      teamColor:Color(0xFFDA291C)),
  PlayerCard(id:'griezmann', name:'GRIEZMANN', position:'FW', club:'Atletico',  overall:85, shooting:84, speed:76, technique:88, rarity:CardRarity.rare,      teamColor:Color(0xFFCE3524)),
  PlayerCard(id:'vlahovic',  name:'VLAHOVIC',  position:'ST', club:'Juventus',  overall:84, shooting:87, speed:80, technique:80, rarity:CardRarity.rare,      teamColor:Color(0xFFAAAAAA)),
  PlayerCard(id:'osimhen',   name:'OSIMHEN',   position:'ST', club:'Napoli',    overall:84, shooting:85, speed:89, technique:79, rarity:CardRarity.rare,      teamColor:Color(0xFF0067B1)),
  PlayerCard(id:'lautaro',   name:'LAUTARO',   position:'ST', club:'Inter',     overall:83, shooting:83, speed:82, technique:81, rarity:CardRarity.rare,      teamColor:Color(0xFF010EA8)),
  PlayerCard(id:'rodrygo',   name:'RODRYGO',   position:'FW', club:'R. Madrid', overall:83, shooting:81, speed:84, technique:86, rarity:CardRarity.rare,      teamColor:Color(0xFFD4AF37)),
  PlayerCard(id:'diaz',      name:'DÍAZ',      position:'FW', club:'Liverpool', overall:82, shooting:79, speed:88, technique:83, rarity:CardRarity.rare,      teamColor:Color(0xFFC8102E)),
  PlayerCard(id:'havertz',   name:'HAVERTZ',   position:'AM', club:'Arsenal',   overall:82, shooting:80, speed:77, technique:85, rarity:CardRarity.rare,      teamColor:Color(0xFFEF0107)),
  PlayerCard(id:'bronze_striker', name:'STRIKER', position:'ST', club:'Local',  overall:72, shooting:73, speed:70, technique:70, rarity:CardRarity.common,    teamColor:Color(0xFF888888)),
  PlayerCard(id:'swift_winger',   name:'WINGER',  position:'FW', club:'Local',  overall:70, shooting:68, speed:76, technique:71, rarity:CardRarity.common,    teamColor:Color(0xFF777777)),
  PlayerCard(id:'solid_mid',      name:'MIDFIELD',position:'CM', club:'Local',  overall:68, shooting:65, speed:67, technique:72, rarity:CardRarity.common,    teamColor:Color(0xFF666666)),
  PlayerCard(id:'fast_fwd',       name:'FORWARD', position:'FW', club:'Local',  overall:70, shooting:70, speed:74, technique:68, rarity:CardRarity.common,    teamColor:Color(0xFF999999)),
];

// ══════════════════════════════════════════════
//  LEAGUE DATA
// ══════════════════════════════════════════════
const kLeagues = <League>[
  League(id:'local_cup',  name:'LOCAL CUP',        country:'Amateur',       emblem:'🥅', minLevel:1,  matchCount:3, gkDifficulty:1, coinsPerGoal:15,  xpPerGoal:12,  completionBonus:150,  accentColor:kGold),
  League(id:'premier',    name:'PREMIER LEAGUE',   country:'England',       emblem:'🏴󠁧󠁢󠁥󠁮󠁧󠁿', minLevel:3,  matchCount:5, gkDifficulty:2, coinsPerGoal:25,  xpPerGoal:18,  completionBonus:300,  accentColor:kGold),
  League(id:'laliga',     name:'LA LIGA',          country:'Spain',         emblem:'🇪🇸', minLevel:6,  matchCount:5, gkDifficulty:2, coinsPerGoal:25,  xpPerGoal:20,  completionBonus:350,  accentColor:kGoldAccent),
  League(id:'bundesliga', name:'BUNDESLIGA',       country:'Germany',       emblem:'🇩🇪', minLevel:9,  matchCount:5, gkDifficulty:3, coinsPerGoal:35,  xpPerGoal:25,  completionBonus:450,  accentColor:kGoldLight),
  League(id:'champions',  name:'CHAMPIONS LEAGUE', country:'Europe',        emblem:'⭐', minLevel:13, matchCount:7, gkDifficulty:3, coinsPerGoal:50,  xpPerGoal:35,  completionBonus:700,  accentColor:kGold),
  League(id:'worldcup',   name:'WORLD CUP',        country:'International', emblem:'🌍', minLevel:20, matchCount:7, gkDifficulty:4, coinsPerGoal:80,  xpPerGoal:50,  completionBonus:1200, accentColor:kGoldAccent),
];

// ══════════════════════════════════════════════
//  ENTRY POINT
// ══════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: kBg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await GameManager.instance.load();
  runApp(const StrikerApp());
}

// ══════════════════════════════════════════════
//  APP ROOT
// ══════════════════════════════════════════════
class StrikerApp extends StatelessWidget {
  const StrikerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Striker',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            size: mq.size / 1.18,
            devicePixelRatio: mq.devicePixelRatio * 1.18,
            textScaler: TextScaler.linear(1.18),
          ),
          child: child!,
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(primary: kGold, surface: kCard),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}

// ══════════════════════════════════════════════
//  SPLASH SCREEN
// ══════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgCtrl, _logoCtrl, _lineCtrl;
  late Animation<double> _logoSlide, _logoFade, _lineProg, _bgScale;

  @override
  void initState() {
    super.initState();
    _bgCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _lineCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    _bgScale   = Tween<double>(begin: 1.08, end: 1.0)
        .animate(CurvedAnimation(parent: _bgCtrl,   curve: Curves.easeOut));
    _logoSlide = Tween<double>(begin: 60.0, end: 0.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutCubic));
    _logoFade  = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeIn);
    _lineProg  = CurvedAnimation(parent: _lineCtrl, curve: Curves.easeInOut);

    _bgCtrl.forward();
    Future.delayed(const Duration(milliseconds: 300), () => _logoCtrl.forward());
    Future.delayed(const Duration(milliseconds: 700), () => _lineCtrl.forward());
    _checkAndNavigate();
  }

  Future<void> _checkAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 3200));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const MainGameScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  @override
  void dispose() {
    _bgCtrl.dispose(); _logoCtrl.dispose(); _lineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(fit: StackFit.expand, children: [
        AnimatedBuilder(
          animation: _bgScale,
          builder: (_, __) => Transform.scale(
            scale: _bgScale.value,
            child: CustomPaint(painter: _SplashBgPainter(), child: const SizedBox.expand()),
          ),
        ),
        Positioned(
          bottom: 0, left: 0, right: 0, height: size.height * 0.45,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [kBg, kBg.withOpacity(0.9), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          top: 0, left: 0, right: 0,
          child: AnimatedBuilder(
            animation: _logoFade,
            builder: (_, __) => Opacity(
              opacity: _logoFade.value,
              child: Container(
                height: 4,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [kGoldDark, kGold, kGoldAccent, kGold, kGoldDark]),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: size.height * 0.18, left: 0, right: 0,
          child: AnimatedBuilder(
            animation: _logoCtrl,
            builder: (_, __) => Opacity(
              opacity: _logoFade.value,
              child: Transform.translate(
                offset: Offset(0, _logoSlide.value),
                child: Column(children: [
                  Container(
                    width: 96, height: 96,
                    decoration: BoxDecoration(
                      color: kGold,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: kWhite.withOpacity(0.25), width: 2),
                      boxShadow: [
                        BoxShadow(color: kGold.withOpacity(0.6), blurRadius: 40, spreadRadius: 8),
                        BoxShadow(color: kWhite.withOpacity(0.12), blurRadius: 16),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset('assets/icon.png', fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.sports_soccer, color: Colors.white, size: 56)),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('STRIKER', style: TextStyle(
                      color: kGold, fontSize: 46, fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      shadows: [Shadow(color: kGold.withOpacity(0.3), blurRadius: 20)])),
                  const SizedBox(height: 6),
                  Container(
                    width: 60, height: 2,
                    decoration: BoxDecoration(
                      color: kGold.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Penalty Kick RPG', style: TextStyle(
                      color: kGold.withOpacity(0.35), fontSize: 13, letterSpacing: 2)),
                ]),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: size.height * 0.08,
          left: size.width * 0.25, right: size.width * 0.25,
          child: AnimatedBuilder(
            animation: _lineProg,
            builder: (_, __) => Column(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _lineProg.value,
                  backgroundColor: kWhite.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation(kGold),
                  minHeight: 3,
                ),
              ),
              const SizedBox(height: 10),
              Text('LOADING...', style: TextStyle(
                  color: kGold.withOpacity(0.25), fontSize: 9,
                  letterSpacing: 3, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        Positioned(top: 20, left: 20,
          child: AnimatedBuilder(animation: _logoFade,
            builder: (_, __) => Opacity(opacity: _logoFade.value * 0.4,
              child: Container(width: 30, height: 30,
                decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: kGold, width: 2),
                                  left: BorderSide(color: kGold, width: 2))))))),
        Positioned(top: 20, right: 20,
          child: AnimatedBuilder(animation: _logoFade,
            builder: (_, __) => Opacity(opacity: _logoFade.value * 0.4,
              child: Container(width: 30, height: 30,
                decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: kGold, width: 2),
                                  right: BorderSide(color: kGold, width: 2))))))),
        Positioned(bottom: 20, left: 20,
          child: AnimatedBuilder(animation: _logoFade,
            builder: (_, __) => Opacity(opacity: _logoFade.value * 0.4,
              child: Container(width: 30, height: 30,
                decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: kGold, width: 2),
                                  left: BorderSide(color: kGold, width: 2))))))),
        Positioned(bottom: 20, right: 20,
          child: AnimatedBuilder(animation: _logoFade,
            builder: (_, __) => Opacity(opacity: _logoFade.value * 0.4,
              child: Container(width: 30, height: 30,
                decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: kGold, width: 2),
                                  right: BorderSide(color: kGold, width: 2))))))),
      ]),
    );
  }
}

class _SplashBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Dark navy top gradient
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.62),
        Paint()..shader = const LinearGradient(
          colors: [Color(0xFF0A1628), Color(0xFF0D2040), Color(0xFF070E1A)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.62)));
    // Medium blue bottom section
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45),
        Paint()..shader = LinearGradient(
          colors: const [kFieldDark, kPurple, kFieldDark],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45)));
    final strip = Paint()..color = kPurple.withOpacity(0.5);
    for (int i = 0; i < 8; i++) {
      if (i.isEven) canvas.drawRect(
        Rect.fromLTWH(size.width * i / 8, size.height * 0.55, size.width / 8, size.height), strip);
    }
    final circPaint = Paint()
      ..color = kGold.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width * 0.5, size.height * 0.72),
          width: size.width * 0.55, height: 40),
      circPaint,
    );
    canvas.drawLine(Offset(0, size.height * 0.72), Offset(size.width, size.height * 0.72),
        Paint()..color = kGold.withOpacity(0.1)..strokeWidth = 1);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.3), size.width * 0.4,
        Paint()..color = kGold.withOpacity(0.06)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60));
  }
  @override bool shouldRepaint(_) => false;
}

// ══════════════════════════════════════════════
//  MAIN GAME SCREEN
// ══════════════════════════════════════════════
class MainGameScreen extends StatefulWidget {
  const MainGameScreen({super.key});
  @override State<MainGameScreen> createState() => _MainGameScreenState();
}

class _MainGameScreenState extends State<MainGameScreen> {
  int _idx = 0;

  @override
  void initState() {
    super.initState();
    
  }

  // БЫЛО — весь этот огромный метод с API, base64, кешем

// БЫЛО — весь этот огромный метод с API, base64, кешем

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final pages = [
      PlayPage(onStateChanged: _refresh),
      const SquadPage(),
      const LeaguePage(),
      ProfilePage(onStateChanged: _refresh),
    ];
    return Scaffold(
      backgroundColor: kBg,
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(key: ValueKey(_idx), child: pages[_idx]),
      ),
      bottomNavigationBar: _BottomNav(
        current: _idx,
        onTap: (i) => setState(() => _idx = i),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  BOTTOM NAV
// ══════════════════════════════════════════════
class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(Icons.sports_soccer_rounded,  'PLAY'),
      _NavItem(Icons.style_rounded,          'SQUAD'),
      _NavItem(Icons.emoji_events_rounded,   'LEAGUES'),
      _NavItem(Icons.person_rounded,         'PROFILE'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF060D18),
        border: Border(top: BorderSide(color: kGold.withOpacity(0.08), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(items.length, (i) {
              final sel = i == current;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: sel ? kGold.withOpacity(0.18) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(items[i].icon,
                            color: sel ? kGold : Colors.grey[600], size: 22),
                      ),
                      const SizedBox(height: 2),
                      Text(items[i].label,
                          style: TextStyle(
                              color: sel ? kGold : Colors.grey[600],
                              fontSize: 9,
                              fontWeight: sel ? FontWeight.w800 : FontWeight.w400,
                              letterSpacing: 0.8)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

// ══════════════════════════════════════════════
//  PLAY PAGE
// ══════════════════════════════════════════════
class PlayPage extends StatefulWidget {
  final VoidCallback? onStateChanged;
  const PlayPage({super.key, this.onStateChanged});
  @override State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  Future<void> _onPlayTap() async {
    final gm = GameManager.instance;
    if (!mounted) return;
    final result = await Navigator.of(context).push<PenaltyResult>(
      MaterialPageRoute(
        builder: (_) => PenaltyGameScreen(
          config: PenaltyConfig(
            gkDifficulty: 1,
            totalShots: 5,
            coinsPerGoal: 20 + gm.activeCard.powerBonus * 3,
            xpPerGoal: 15 + gm.activeCard.powerBonus,
            leagueName: 'QUICK PLAY',
          ),
        ),
      ),
    );
    if (result != null) {
      if (result.goals > 0) {
        await gm.recordGoal(coinReward: result.coinsEarned, xpReward: result.xpEarned);
      } else {
        await gm.recordSave();
      }
    }
    if (mounted) setState(() {});
    widget.onStateChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final gm = GameManager.instance;
    return SafeArea(
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: kGold.withOpacity(0.08))),
          ),
          child: Row(children: [
            Text('STRIKER', style: TextStyle(
                color: kGold, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const Spacer(),
            _CurrencyChip(Icons.paid_rounded, '${gm.coins}', kGold),
            const SizedBox(width: 8),
            _CurrencyChip(Icons.diamond_rounded, '${gm.gems}', kPurpleLight),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: kGold.withOpacity(0.12), width: 1.5),
                  boxShadow: [BoxShadow(color: kGold.withOpacity(0.08), blurRadius: 20)],
                ),
                clipBehavior: Clip.antiAlias,
                child: CustomPaint(
                  painter: _MiniStadiumPainter(),
                  child: Center(
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: kGold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: kGold.withOpacity(0.2)),
                          ),
                          child: Text('5 SHOTS · QUICK PLAY', style: TextStyle(
                              color: kGold.withOpacity(0.8), fontSize: 9,
                              fontWeight: FontWeight.w800, letterSpacing: 2)),
                        ),
                      ),
                      const Spacer(),
                      ScaleTransition(
                        scale: _pulse,
                        child: GestureDetector(
                          onTap: _onPlayTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 15),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [kGold, kGoldDark],
                                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(color: kWhite.withOpacity(0.2)),
                              boxShadow: [BoxShadow(
                                  color: kGold.withOpacity(0.55), blurRadius: 24, spreadRadius: 2)],
                            ),
                            child: const Text('⚽  TAKE A SHOT',
                              style: TextStyle(color: Colors.white, fontSize: 16,
                                  fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ]),
                  ),
                ),
              ),
              _SectionHeader(title: 'ACTIVE PLAYER',
                  trailing: '+${gm.activeCard.powerBonus * 3} coins/goal'),
              _ActiveCardBanner(card: gm.activeCard),
              const _SectionHeader(title: 'YOUR STATS'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Row(children: [
                  _QuickStatCard('⚽', '${gm.totalGoals}', 'Goals'),
                  const SizedBox(width: 10),
                  _QuickStatCard('🔥', '${gm.currentStreak}', 'Streak'),
                  const SizedBox(width: 10),
                  _QuickStatCard('🏆', '${gm.tournamentWins}', 'Wins'),
                ]),
              ),
              const SizedBox(height: 100),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionHeader({required this.title, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Row(children: [
      Container(width: 3, height: 14, color: kGold, margin: const EdgeInsets.only(right: 8)),
      Text(title, style: TextStyle(
          color: kGold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
      const Spacer(),
      if (trailing != null)
        Text(trailing!, style: TextStyle(
            color: kGoldAccent, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _CurrencyChip extends StatelessWidget {
  final IconData icon; final String value; final Color color;
  const _CurrencyChip(this.icon, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25))),
    child: Row(children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 5),
      Text(value, style: TextStyle(
          color: color, fontSize: 13, fontWeight: FontWeight.w800)),
    ]),
  );
}

class _ActiveCardBanner extends StatelessWidget {
  final PlayerCard card;
  const _ActiveCardBanner({required this.card});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: card.rarityGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kGold.withOpacity(0.1), width: 1),
      ),
      child: Row(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
              color: kGold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kGold.withOpacity(0.2))),
          child: Center(child: Text(card.name.substring(0, 1),
              style: TextStyle(color: kGold, fontSize: 24, fontWeight: FontWeight.w900))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(card.name, style: TextStyle(
                color: kGold, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: card.rarityColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: card.rarityColor.withOpacity(0.4))),
              child: Text(card.rarityLabel,
                  style: TextStyle(color: card.rarityColor, fontSize: 8, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 4),
          Text('${card.position} · ${card.club}',
              style: TextStyle(color: kGold.withOpacity(0.4), fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${card.overall}',
              style: TextStyle(color: card.rarityColor, fontSize: 28, fontWeight: FontWeight.w900)),
          const Text('OVR', style: TextStyle(color: Colors.grey, fontSize: 9, letterSpacing: 1)),
        ]),
      ]),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final String emoji, value, label;
  const _QuickStatCard(this.emoji, this.value, this.label);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kGold.withOpacity(0.1))),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(
            color: kWhite, fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ]),
    ),
  );
}

class _MiniStadiumPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..shader = LinearGradient(
          colors: const [kFieldDark, kPurple, kFieldDark],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          stops: const [0, 0.55, 0.55],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    final stripePaint = Paint()..color = kPurple;
    for (int i = 0; i < 4; i++) {
      canvas.drawRect(
          Rect.fromLTWH(size.width * 0.25 * i, size.height * 0.55,
              size.width * 0.125, size.height), stripePaint);
    }
    final postPaint = Paint()..color = kGold..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final gL = size.width * 0.28, gR = size.width * 0.72;
    final gT = size.height * 0.20, gB = size.height * 0.54;
    canvas.drawLine(Offset(gL, gT), Offset(gL, gB), postPaint);
    canvas.drawLine(Offset(gR, gT), Offset(gR, gB), postPaint);
    canvas.drawLine(Offset(gL, gT), Offset(gR, gT), postPaint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.85), 4,
        Paint()..color = kGold.withOpacity(0.7));
  }
  @override bool shouldRepaint(_) => false;
}

// ══════════════════════════════════════════════
//  PENALTY CONFIG & RESULT
// ══════════════════════════════════════════════
class PenaltyConfig {
  final int gkDifficulty, totalShots, coinsPerGoal, xpPerGoal;
  final String leagueName;
  const PenaltyConfig({
    required this.gkDifficulty, required this.totalShots,
    required this.coinsPerGoal, required this.xpPerGoal,
    required this.leagueName,
  });
}

class PenaltyResult {
  final int goals, saves, coinsEarned, xpEarned;
  const PenaltyResult({required this.goals, required this.saves,
      required this.coinsEarned, required this.xpEarned});
}

// ══════════════════════════════════════════════
//  PENALTY GAME SCREEN
// ══════════════════════════════════════════════
enum _PenaltyPhase { selecting, shooting, result, matchEnd }

class PenaltyGameScreen extends StatefulWidget {
  final PenaltyConfig config;
  const PenaltyGameScreen({super.key, required this.config});
  @override State<PenaltyGameScreen> createState() => _PenaltyGameScreenState();
}

class _PenaltyGameScreenState extends State<PenaltyGameScreen>
    with TickerProviderStateMixin {
  _PenaltyPhase _phase = _PenaltyPhase.selecting;
  int? _selectedZone;
  int _gkZone = 4;
  bool _isGoal = false;
  int _shotsLeft = 0, _goalsScored = 0, _savesDone = 0, _coinsEarned = 0, _xpEarned = 0;

  late AnimationController _shootCtrl, _gkCtrl, _flashCtrl, _resultCtrl;
  late Animation<double> _shootAnim, _gkAnim, _flashAnim;

  final _rng = math.Random();
  ui.Image? _gkImage, _ballImage;

  static const _goalLeft = 0.15, _goalRight = 0.85, _goalTop = 0.18, _goalBottom = 0.48;
  static const _spotX = 0.50, _spotY = 0.80;

  @override
  void initState() {
    super.initState();
    _shotsLeft = widget.config.totalShots;
    _shootCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    _gkCtrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _flashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _resultCtrl= AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shootAnim = CurvedAnimation(parent: _shootCtrl, curve: Curves.easeIn);
    _gkAnim    = CurvedAnimation(parent: _gkCtrl,   curve: Curves.easeOutCubic);
    _flashAnim = CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut);
    _loadImages();
  }

  Future<void> _loadImages() async {
    await Future.wait([_loadGk(), _loadBall()]);
  }

  Future<void> _loadGk() async {
    try {
      final data  = await rootBundle.load('assets/player.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: 160);
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _gkImage = frame.image);
    } catch (_) {}
  }

  Future<void> _loadBall() async {
    try {
      final data  = await rootBundle.load('assets/ball.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: 80);
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _ballImage = frame.image);
    } catch (_) {}
  }

  @override
  void dispose() {
    _shootCtrl.dispose(); _gkCtrl.dispose();
    _flashCtrl.dispose(); _resultCtrl.dispose();
    super.dispose();
  }

  int _pickGkZone(int playerZone) {
    final r = _rng.nextDouble();
    switch (widget.config.gkDifficulty) {
      case 1: if (r < 0.16) return playerZone; break;
      case 2: if (r < 0.38) return playerZone; break;
      case 3: if (r < 0.52) return playerZone; break;
      case 4: if (r < 0.66) return playerZone; break;
      default: break;
    }
    return _rng.nextInt(9);
  }

  void _onZoneTap(int zone) {
    if (_phase != _PenaltyPhase.selecting) return;
    final gkZone = _pickGkZone(zone);
    final isGoal = gkZone != zone;
    setState(() {
      _selectedZone = zone; _gkZone = gkZone;
      _isGoal = isGoal; _phase = _PenaltyPhase.shooting;
    });
    _shootCtrl.reset(); _gkCtrl.reset(); _flashCtrl.reset();
    _shootCtrl.forward();
    Future.delayed(const Duration(milliseconds: 220), () { if (mounted) _gkCtrl.forward(); });
    Future.delayed(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      _flashCtrl.forward();
      if (isGoal) {
        _goalsScored++;
        _coinsEarned += widget.config.coinsPerGoal;
        _xpEarned    += widget.config.xpPerGoal;
      } else {
        _savesDone++;
      }
      setState(() => _phase = _PenaltyPhase.result);
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        _shotsLeft--;
        if (_shotsLeft <= 0) {
          setState(() => _phase = _PenaltyPhase.matchEnd);
        } else {
          _shootCtrl.reset(); _gkCtrl.reset(); _flashCtrl.reset();
          setState(() { _phase = _PenaltyPhase.selecting; _selectedZone = null; });
        }
      });
    });
  }

  void _finishMatch() {
    Navigator.of(context).pop(PenaltyResult(
      goals: _goalsScored, saves: _savesDone,
      coinsEarned: _coinsEarned, xpEarned: _xpEarned,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_shootAnim, _gkAnim]),
                builder: (_, __) => CustomPaint(
                  painter: StadiumPainter(
                    shootProgress: _shootAnim.value,
                    gkProgress: _gkAnim.value,
                    selectedZone: _selectedZone ?? -1,
                    gkZone: _gkZone,
                    showGk: _phase == _PenaltyPhase.shooting || _phase == _PenaltyPhase.result,
                    gkImage: _gkImage,
                    ballImage: _ballImage,
                  ),
                ),
              ),
            ),
            SafeArea(child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(PenaltyResult(
                        goals: _goalsScored, saves: _savesDone,
                        coinsEarned: _coinsEarned, xpEarned: _xpEarned)),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kGold.withOpacity(0.15))),
                      child: const Icon(Icons.close, color: Colors.white70, size: 18),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kGold.withOpacity(0.1))),
                    child: Row(children: [
                      Text('⚽ $_goalsScored', style: const TextStyle(
                          color: kWhite, fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 10),
                      Text('🥅 $_savesDone', style: const TextStyle(
                          color: kGoldAccent, fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 10),
                      Text('$_shotsLeft left',
                          style: TextStyle(color: kGold.withOpacity(0.4), fontSize: 12)),
                    ]),
                  ),
                  const Spacer(),
                  const SizedBox(width: 38),
                ]),
              ),
              const Spacer(),
            ])),
            if (_phase == _PenaltyPhase.selecting) ..._buildZoneGrid(size),
            if (_phase == _PenaltyPhase.selecting)
              Positioned(
                bottom: size.height * 0.13, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kGold.withOpacity(0.15))),
                    child: const Text('TAP A ZONE TO SHOOT',
                        style: TextStyle(color: kWhite, fontSize: 12,
                            fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                  ),
                ),
              ),
            if (_phase == _PenaltyPhase.result)
              AnimatedBuilder(
                animation: _flashAnim,
                builder: (_, __) => Positioned.fill(
                  child: Container(
                    color: (_isGoal ? kGold : kPurple).withOpacity(
                        (1 - _flashAnim.value).clamp(0.0, 0.45)),
                  ),
                ),
              ),
            if (_phase == _PenaltyPhase.result)
              Positioned(
                top: size.height * 0.48, left: 0, right: 0,
                child: Center(
                  child: Column(children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.4, end: 1.0),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutBack,
                      builder: (_, v, child) => Transform.scale(scale: v, child: child),
                      child: Text(
                        _isGoal ? '⚽ GOAL!' : '🧤 SAVED!',
                        style: TextStyle(
                          color: _isGoal ? kGold : kPurpleLight,
                          fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: 2,
                          shadows: [Shadow(
                              color: (_isGoal ? kGold : kPurpleLight).withOpacity(0.5),
                              blurRadius: 24)],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isGoal) Text(
                        '+${widget.config.coinsPerGoal} 🪙  +${widget.config.xpPerGoal} XP',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            if (_phase == _PenaltyPhase.matchEnd)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.88),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 28),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                          color: kCard, borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: kGold.withOpacity(0.12), width: 1.5)),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          height: 3, width: 48, margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                              color: _goalsScored >= widget.config.totalShots / 2
                                  ? kGold : kPurple,
                              borderRadius: BorderRadius.circular(2))),
                        Text(_goalsScored >= widget.config.totalShots / 2 ? '🏆' : '😓',
                            style: const TextStyle(fontSize: 54)),
                        const SizedBox(height: 12),
                        Text(
                          _goalsScored >= widget.config.totalShots / 2
                              ? 'MATCH WON!' : 'MATCH OVER',
                          style: TextStyle(
                              color: _goalsScored >= widget.config.totalShots / 2
                                  ? kGold : Colors.white60,
                              fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
                        ),
                        const SizedBox(height: 20),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                          _MatchStatChip('⚽', '$_goalsScored', 'Goals'),
                          _MatchStatChip('🥅', '$_savesDone', 'Saves'),
                          _MatchStatChip('🪙', '$_coinsEarned', 'Earned'),
                        ]),
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: _finishMatch,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [kGold, kGoldDark]),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: kWhite.withOpacity(0.2)),
                              boxShadow: [BoxShadow(
                                  color: kGold.withOpacity(0.35), blurRadius: 14)],
                            ),
                            child: const Text('CONTINUE', style: TextStyle(
                                color: Colors.white, fontSize: 16,
                                fontWeight: FontWeight.w800, letterSpacing: 1)),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }

  List<Widget> _buildZoneGrid(Size size) {
    const zW = (_goalRight - _goalLeft) / 3;
    const zH = (_goalBottom - _goalTop) / 3;
    return List.generate(9, (i) {
      final col = i % 3; final row = i ~/ 3;
      final left = (_goalLeft + col * zW) * size.width;
      final top  = (_goalTop  + row * zH) * size.height;
      return Positioned(
        left: left, top: top,
        width: zW * size.width, height: zH * size.height,
        child: GestureDetector(
          onTap: () => _onZoneTap(i),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: kGold.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kGold.withOpacity(0.2), width: 1),
            ),
            child: Center(child: Icon(Icons.add, color: kGold.withOpacity(0.2), size: 16)),
          ),
        ),
      );
    });
  }
}

class _MatchStatChip extends StatelessWidget {
  final String emoji, value, label;
  const _MatchStatChip(this.emoji, this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(emoji, style: const TextStyle(fontSize: 22)),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(color: kWhite, fontSize: 18, fontWeight: FontWeight.w800)),
    Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
  ]);
}

// ══════════════════════════════════════════════
//  STADIUM PAINTER
// ══════════════════════════════════════════════
class StadiumPainter extends CustomPainter {
  final double shootProgress, gkProgress;
  final int selectedZone, gkZone;
  final bool showGk;
  final ui.Image? gkImage, ballImage;

  const StadiumPainter({
    required this.shootProgress, required this.gkProgress,
    required this.selectedZone, required this.gkZone, required this.showGk,
    this.gkImage, this.ballImage,
  });

  static const _gL = 0.15, _gR = 0.85, _gT = 0.18, _gB = 0.48;
  static const _spotX = 0.50, _spotY = 0.80;

  Offset _zoneCenter(int zone, Size s) {
    final col = zone % 3; final row = zone ~/ 3;
    final zW = (_gR - _gL) / 3; final zH = (_gB - _gT) / 3;
    return Offset((_gL + (col + 0.5) * zW) * s.width, (_gT + (row + 0.5) * zH) * s.height);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);
    _drawCrowd(canvas, size);
    _drawPitch(canvas, size);
    _drawPenaltyBox(canvas, size);
    _drawNet(canvas, size);
    _drawGoalPosts(canvas, size);
    if (showGk) _drawGoalkeeper(canvas, size);
    _drawBall(canvas, size);
    _drawFloodlights(canvas, size);
  }

  void _drawSky(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.55),
        Paint()..shader = const LinearGradient(
          colors: [kFieldDark, kPurple, kFieldDark],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.55)));
  }

  void _drawCrowd(Canvas canvas, Size size) {
    final p = Paint()..color = kPurple;
    canvas.drawPath(Path()
      ..moveTo(0, 0)..lineTo(size.width * 0.18, 0)
      ..lineTo(size.width * 0.10, size.height * 0.55)
      ..lineTo(0, size.height * 0.55)..close(), p);
    canvas.drawPath(Path()
      ..moveTo(size.width, 0)..lineTo(size.width * 0.82, 0)
      ..lineTo(size.width * 0.90, size.height * 0.55)
      ..lineTo(size.width, size.height * 0.55)..close(), p);
    canvas.drawPath(Path()
      ..moveTo(size.width * 0.18, 0)..lineTo(size.width * 0.82, 0)
      ..lineTo(size.width * 0.80, size.height * 0.14)
      ..lineTo(size.width * 0.20, size.height * 0.14)..close(), p);
    final dot = Paint()..style = PaintingStyle.fill;
    final rng = math.Random(42);
    for (int i = 0; i < 100; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.14;
      dot.color = (rng.nextBool() ? kGold : kGoldAccent).withOpacity(0.13);
      canvas.drawCircle(Offset(x, y), 1.8, dot);
    }
  }

  void _drawPitch(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(0, size.height * 0.48, size.width, size.height * 0.52);
    canvas.drawRect(r, Paint()..shader = const LinearGradient(
      colors: [kFieldDark, kPurple, kFieldDark],
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
    ).createShader(r));
    final s = Paint()..color = kPurpleLight.withOpacity(0.4);
    for (int i = 0; i < 6; i++) {
      if (i.isEven) canvas.drawRect(
          Rect.fromLTWH(size.width * i / 6, size.height * 0.48,
              size.width / 6, size.height * 0.52), s);
    }
  }

  void _drawPenaltyBox(Canvas canvas, Size size) {
    final lp = Paint()..color = kGold.withOpacity(0.3)..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTRB(size.width * 0.20, size.height * 0.48,
        size.width * 0.80, size.height * 0.68), lp);
    canvas.drawCircle(Offset(size.width * _spotX, size.height * _spotY),
        3.5, Paint()..color = kGold.withOpacity(0.7));
    canvas.drawArc(
      Rect.fromCenter(center: Offset(size.width * 0.5, size.height * _spotY),
          width: 60, height: 36),
      math.pi, math.pi, false, lp..color = kGold.withOpacity(0.2));
  }

  void _drawNet(Canvas canvas, Size size) {
    final np = Paint()..color = kGold.withOpacity(0.10)..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;
    final l = size.width * _gL; final r = size.width * _gR;
    final t = size.height * _gT; final b = size.height * _gB;
    canvas.drawRect(Rect.fromLTRB(l, t, r, b),
        Paint()..color = Colors.black.withOpacity(0.25));
    for (int i = 0; i <= 12; i++) {
      final x = l + (r - l) * i / 12;
      canvas.drawLine(Offset(x, t), Offset(x, b), np);
    }
    for (int i = 0; i <= 6; i++) {
      final y = t + (b - t) * i / 6;
      canvas.drawLine(Offset(l, y), Offset(r, y), np);
    }
  }

  void _drawGoalPosts(Canvas canvas, Size size) {
    final shadow = Paint()..color = Colors.black.withOpacity(0.5)..strokeWidth = 6
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final post = Paint()..color = kWhite..strokeWidth = 4
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final gL = size.width * _gL; final gR = size.width * _gR;
    final gT = size.height * _gT; final gB = size.height * _gB;
    canvas.drawLine(Offset(gL+2, gT+2), Offset(gL+2, gB+2), shadow);
    canvas.drawLine(Offset(gR+2, gT+2), Offset(gR+2, gB+2), shadow);
    canvas.drawLine(Offset(gL+2, gT+2), Offset(gR+2, gT+2), shadow);
    canvas.drawLine(Offset(gL, gT), Offset(gL, gB), post);
    canvas.drawLine(Offset(gR, gT), Offset(gR, gB), post);
    canvas.drawLine(Offset(gL, gT), Offset(gR, gT), post);
    canvas.drawLine(Offset(gL, gB), Offset(gR, gB),
        Paint()..color = kWhite.withOpacity(0.4)..strokeWidth = 2);
  }

  void _drawGoalkeeper(Canvas canvas, Size size) {
    final col = gkZone % 3;
    const targets = [0.22, 0.50, 0.78];
    final targetX = size.width * targets[col];
    final gkX = _lerp(size.width * 0.50, targetX, gkProgress);
    final gkY = size.height * 0.435;

    if (gkImage != null) {
      final imgW = 95.0 + gkProgress * 32;
      final imgH = imgW * (gkImage!.height / gkImage!.width);
      final src = Rect.fromLTWH(0, 0, gkImage!.width.toDouble(), gkImage!.height.toDouble());
      if (col == 0) {
        canvas.save();
        canvas.scale(-1, 1);
        canvas.drawImageRect(gkImage!, src,
            Rect.fromCenter(center: Offset(-gkX, gkY - imgH * 0.08),
                width: imgW, height: imgH), Paint());
        canvas.restore();
      } else {
        canvas.drawImageRect(gkImage!, src,
            Rect.fromCenter(center: Offset(gkX, gkY - imgH * 0.08),
                width: imgW, height: imgH), Paint());
      }
    } else {
      final shirtP = Paint()..color = kPurple;
      final skinP  = Paint()..color = kGoldLight;
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(gkX, gkY), width: 22, height: 38),
          const Radius.circular(6)), shirtP);
      canvas.drawCircle(Offset(gkX, gkY - 26), 12, skinP);
      final armDir = (col == 0) ? -1.0 : (col == 2 ? 1.0 : 0.0);
      final al = 34.0 * gkProgress;
      canvas.drawLine(Offset(gkX, gkY - 8),
          Offset(gkX + armDir * al, gkY - 22 + (1 - gkProgress) * 10),
          Paint()..color = kGold..strokeWidth = 9..strokeCap = StrokeCap.round);
      canvas.drawLine(Offset(gkX, gkY - 8),
          Offset(gkX - armDir * al * 0.4, gkY - 14),
          Paint()..color = kGold..strokeWidth = 9..strokeCap = StrokeCap.round);
      canvas.drawCircle(
          Offset(gkX + armDir * al, gkY - 22 + (1 - gkProgress) * 10),
          5.5, Paint()..color = kGoldAccent);
    }
  }

  void _drawBall(Canvas canvas, Size size) {
    Offset ballPos;
    double ballScale;
    if (shootProgress > 0 && selectedZone >= 0) {
      final start = Offset(size.width * _spotX, size.height * _spotY);
      final end   = _zoneCenter(selectedZone, size);
      final t = shootProgress;
      final arc = math.sin(t * math.pi) * -24;
      ballPos = Offset(start.dx + (end.dx - start.dx) * t,
                       start.dy + (end.dy - start.dy) * t + arc);
      ballScale = _lerp(1.0, 0.50, t);
    } else {
      ballPos = Offset(size.width * _spotX, size.height * _spotY);
      ballScale = 1.0;
    }
    final r = 18.0 * ballScale;
    if (ballImage != null) {
      final angle = shootProgress * math.pi * 4;
      final imgSize = r * 2.2;
      final src = Rect.fromLTWH(0, 0,
          ballImage!.width.toDouble(), ballImage!.height.toDouble());
      canvas.drawOval(
        Rect.fromCenter(center: Offset(ballPos.dx + 2, ballPos.dy + 4),
            width: r * 1.8, height: r * 0.55),
        Paint()..color = Colors.black.withOpacity(0.3),
      );
      canvas.save();
      canvas.translate(ballPos.dx, ballPos.dy);
      canvas.rotate(angle);
      canvas.drawImageRect(ballImage!, src,
          Rect.fromCenter(center: Offset.zero, width: imgSize, height: imgSize),
          Paint());
      canvas.restore();
    } else {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(ballPos.dx + 2, ballPos.dy + 4),
            width: r * 1.8, height: r * 0.55),
        Paint()..color = Colors.black.withOpacity(0.3),
      );
      canvas.drawCircle(ballPos, r, Paint()..color = kWhite);
      final pp = Paint()..color = kPurpleDark;
      canvas.drawCircle(ballPos, r * 0.28, pp);
      for (int i = 0; i < 5; i++) {
        final angle = i * 2 * math.pi / 5 - math.pi / 2;
        canvas.drawCircle(
          Offset(ballPos.dx + math.cos(angle) * r * 0.62,
                 ballPos.dy + math.sin(angle) * r * 0.62),
          r * 0.22, pp);
      }
      canvas.drawCircle(Offset(ballPos.dx - r * 0.3, ballPos.dy - r * 0.3),
          r * 0.22, Paint()..color = kGoldAccent.withOpacity(0.55));
    }
  }

  void _drawFloodlights(Canvas canvas, Size size) {
    for (final dx in [0.12, 0.88]) {
      canvas.drawCircle(Offset(size.width * dx, size.height * 0.06), 28,
          Paint()..color = kGoldAccent.withOpacity(0.06)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));
      canvas.drawCircle(Offset(size.width * dx, size.height * 0.06), 16,
          Paint()..color = kGoldAccent.withOpacity(0.05)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
      canvas.drawLine(
          Offset(size.width * dx, size.height * 0.10),
          Offset(size.width * dx, size.height * 0.40),
          Paint()..color = const Color(0xFF1A2E44)..strokeWidth = 3);
      canvas.drawRect(
          Rect.fromCenter(center: Offset(size.width * dx, size.height * 0.07),
              width: 20, height: 7),
          Paint()..color = kGoldLight.withOpacity(0.9));
    }
  }

  @override
  bool shouldRepaint(StadiumPainter old) =>
      old.shootProgress != shootProgress || old.gkProgress != gkProgress ||
      old.gkImage != gkImage || old.ballImage != ballImage;
}

// ══════════════════════════════════════════════
//  SQUAD PAGE
// ══════════════════════════════════════════════
class SquadPage extends StatefulWidget {
  const SquadPage({super.key});
  @override State<SquadPage> createState() => _SquadPageState();
}

class _SquadPageState extends State<SquadPage> {
  @override
  Widget build(BuildContext context) {
    final gm = GameManager.instance;
    final owned = gm.ownedCards;
    return SafeArea(
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: kGold.withOpacity(0.08)))),
          child: Row(children: [
            Container(width: 3, height: 18, color: kGold, margin: const EdgeInsets.only(right: 10)),
            Text('MY SQUAD', style: TextStyle(
                color: kGold, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: kGold.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kGold.withOpacity(0.12))),
              child: Text('${owned.length}/${kAllCards.length}',
                  style: TextStyle(color: kGold.withOpacity(0.6), fontSize: 12)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            Expanded(child: _PackButton(
              label: 'STANDARD PACK', subtitle: '3 cards · 100 🪙', color: kGold,
              onTap: gm.coins >= 100 ? () async {
                final cards = await gm.openPack();
                if (mounted) { setState(() {}); _showPackOpening(context, cards); }
              } : null,
            )),
            const SizedBox(width: 10),
            Expanded(child: _PackButton(
              label: 'PREMIUM PACK', subtitle: '5 cards · 300 🪙', color: kGold,
              onTap: gm.coins >= 300 ? () async {
                final cards = await gm.openPack(isPremium: true);
                if (mounted) { setState(() {}); _showPackOpening(context, cards); }
              } : null,
            )),
          ]),
        ),
        Divider(color: kGold.withOpacity(0.08), height: 1),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, childAspectRatio: 0.72,
              crossAxisSpacing: 10, mainAxisSpacing: 10,
            ),
            itemCount: kAllCards.length,
            itemBuilder: (_, i) {
              final card = kAllCards[i];
              final isOwned = owned.any((c) => c.id == card.id);
              final isActive = gm.activeCardId == card.id;
              return GestureDetector(
                onTap: isOwned ? () {
                  gm.activeCardId = card.id; gm.save(); setState(() {});
                } : null,
                child: _CardWidget(card: card, owned: isOwned, active: isActive),
              );
            },
          ),
        ),
      ]),
    );
  }

  void _showPackOpening(BuildContext context, List<PlayerCard> cards) {
    showDialog(context: context, builder: (_) => _PackOpeningDialog(cards: cards));
  }
}

class _PackButton extends StatelessWidget {
  final String label, subtitle;
  final Color color;
  final VoidCallback? onTap;
  const _PackButton({required this.label, required this.subtitle,
      required this.color, this.onTap});
  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: disabled ? kCard : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: disabled ? kBorder : color.withOpacity(0.35)),
        ),
        child: Column(children: [
          Text('📦', style: TextStyle(fontSize: 24, color: disabled ? Colors.grey : null)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: disabled ? Colors.grey : kGold,
              fontSize: 11, fontWeight: FontWeight.w800)),
          Text(subtitle, style: TextStyle(
              color: disabled ? Colors.grey[700] : Colors.grey, fontSize: 10)),
        ]),
      ),
    );
  }
}

class _CardWidget extends StatelessWidget {
  final PlayerCard card;
  final bool owned, active;
  const _CardWidget({required this.card, required this.owned, required this.active});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: owned ? card.rarityGradient
              : [const Color(0xFF0A1120), const Color(0xFF060C18)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? kGold.withOpacity(0.7) : kGold.withOpacity(owned ? 0.1 : 0.05),
          width: active ? 1.8 : 1.0,
        ),
        boxShadow: active ? [BoxShadow(color: kGold.withOpacity(0.1), blurRadius: 12)] : null,
      ),
      child: Opacity(
        opacity: owned ? 1.0 : 0.35,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: card.rarityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(card.rarityLabel,
                    style: TextStyle(color: card.rarityColor, fontSize: 7,
                        fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              if (active) Icon(Icons.check_circle, color: kGold.withOpacity(0.8), size: 14),
              if (!owned) const Icon(Icons.lock_rounded, color: Colors.grey, size: 12),
            ]),
            const SizedBox(height: 8),
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: kGold.withOpacity(0.12), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kGold.withOpacity(0.15))),
              child: Center(child: Text(card.name.substring(0, 1),
                  style: TextStyle(color: kGold, fontSize: 20, fontWeight: FontWeight.w900))),
            ),
            const SizedBox(height: 8),
            Text(card.name, style: TextStyle(color: kGold, fontSize: 12,
                fontWeight: FontWeight.w800),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${card.position} · ${card.club}',
                style: const TextStyle(color: Colors.grey, fontSize: 10),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const Spacer(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _MiniStat('SHO', card.shooting),
              _MiniStat('SPD', card.speed),
              _MiniStat('TEC', card.technique),
            ]),
            const SizedBox(height: 4),
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                  color: card.rarityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: card.rarityColor.withOpacity(0.2))),
              child: Text('${card.overall} OVR',
                  style: TextStyle(color: card.rarityColor, fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label; final int value;
  const _MiniStat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text('$value', style: const TextStyle(
        color: kWhite, fontSize: 11, fontWeight: FontWeight.w700)),
    Text(label, style: const TextStyle(color: Colors.grey, fontSize: 8)),
  ]);
}

class _PackOpeningDialog extends StatefulWidget {
  final List<PlayerCard> cards;
  const _PackOpeningDialog({required this.cards});
  @override State<_PackOpeningDialog> createState() => _PackOpeningDialogState();
}

class _PackOpeningDialogState extends State<_PackOpeningDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.forward();
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_shown >= widget.cards.length) {
      return AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎉 Pack Opened!', style: TextStyle(
              color: kWhite, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ...widget.cards.map((c) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: c.rarityColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(c.name, style: TextStyle(
                  color: c.rarityColor, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Text(c.rarityLabel, style: const TextStyle(
                  color: Colors.grey, fontSize: 11)),
            ]),
          )),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kGold, kGoldDark]),
                  borderRadius: BorderRadius.circular(14)),
              child: const Text('SWEET!', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      );
    }
    final card = widget.cards[_shown];
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: GestureDetector(
          onTap: () { setState(() => _shown++); _ctrl.reset(); _ctrl.forward(); },
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: card.rarityGradient,
                  begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: kGold.withOpacity(0.2), width: 1.5),
              boxShadow: [BoxShadow(color: kGold.withOpacity(0.25), blurRadius: 30)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('✨ NEW CARD', style: TextStyle(
                  color: card.rarityColor, fontSize: 12,
                  fontWeight: FontWeight.w800, letterSpacing: 2)),
              const SizedBox(height: 16),
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                    color: kGold.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kGold.withOpacity(0.2))),
                child: Center(child: Text(card.name.substring(0, 1),
                    style: TextStyle(color: kGold, fontSize: 36,
                        fontWeight: FontWeight.w900))),
              ),
              const SizedBox(height: 14),
              Text(card.name, style: const TextStyle(
                  color: kWhite, fontSize: 22, fontWeight: FontWeight.w900)),
              Text('${card.position} · ${card.club}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                    color: card.rarityColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: card.rarityColor.withOpacity(0.3))),
                child: Text('${card.overall} OVR',
                    style: TextStyle(color: card.rarityColor, fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 16),
              Text('${_shown + 1} / ${widget.cards.length}  · tap to continue',
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  LEAGUE PAGE
// ══════════════════════════════════════════════
class LeaguePage extends StatefulWidget {
  const LeaguePage({super.key});
  @override State<LeaguePage> createState() => _LeaguePageState();
}

class _LeaguePageState extends State<LeaguePage> {
  @override
  Widget build(BuildContext context) {
    final gm = GameManager.instance;
    return SafeArea(
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: kGold.withOpacity(0.08)))),
          child: Row(children: [
            Container(width: 3, height: 18, color: kGold, margin: const EdgeInsets.only(right: 10)),
            const Text('LEAGUES', style: TextStyle(
                color: kWhite, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: kLeagues.length,
            itemBuilder: (_, i) {
              final league = kLeagues[i];
              final done   = gm.leagueProgress[league.id] ?? 0;
              final locked = gm.level < league.minLevel;
              return _LeagueCard(
                league: league, matchesDone: done, locked: locked,
                onPlay: locked ? null : () async {
                  if (!mounted) return;
                  final result = await Navigator.of(context).push<PenaltyResult>(
                    MaterialPageRoute(
                      builder: (_) => PenaltyGameScreen(
                        config: PenaltyConfig(
                          gkDifficulty: league.gkDifficulty,
                          totalShots: 5,
                          coinsPerGoal: league.coinsPerGoal,
                          xpPerGoal: league.xpPerGoal,
                          leagueName: league.name,
                        ),
                      ),
                    ),
                  );
                  if (result != null && mounted) {
                    if (result.goals >= 3) {
                      await gm.progressLeague(league.id);
                      gm.coins += league.completionBonus;
                      await gm.recordGoal(
                          coinReward: result.coinsEarned, xpReward: result.xpEarned);
                      if (mounted) _showMatchWon(league.name, league.completionBonus);
                    } else {
                      await gm.recordSave();
                    }
                    setState(() {});
                  }
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  void _showMatchWon(String leagueName, int bonus) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🏆', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 10),
          const Text('MATCH WON!', style: TextStyle(
              color: kWhite, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(leagueName, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 14),
          Text('+$bonus 🪙 bonus!', style: TextStyle(
              color: kGoldAccent, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kGold, kGoldDark]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kWhite.withOpacity(0.2))),
              child: const Text('AWESOME!', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _LeagueCard extends StatelessWidget {
  final League league; final int matchesDone; final bool locked;
  final VoidCallback? onPlay;
  const _LeagueCard({required this.league, required this.matchesDone,
      required this.locked, this.onPlay});

  @override
  Widget build(BuildContext context) {
    final progress = matchesDone / league.matchCount;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: locked ? kCard.withOpacity(0.5) : kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: locked ? kGold.withOpacity(0.05) : kGold.withOpacity(0.1)),
      ),
      child: Column(children: [
        Row(children: [
          Text(league.emblem, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(league.name, style: TextStyle(
                  color: locked ? Colors.grey : kGold,
                  fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              if (locked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: kGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text('LVL ${league.minLevel}', style: TextStyle(
                      color: kGold, fontSize: 9, fontWeight: FontWeight.w800)),
                ),
            ]),
            const SizedBox(height: 2),
            Text(league.country,
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ])),
          if (!locked)
            GestureDetector(
              onTap: onPlay,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: league.accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: league.accentColor.withOpacity(0.5)),
                ),
                child: Text('PLAY', style: TextStyle(
                    color: kWhite,
                    fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ),
        ]),
        if (!locked) ...[
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('$matchesDone/${league.matchCount} wins',
                style: const TextStyle(color: Colors.grey, fontSize: 10)),
            Text('${league.coinsPerGoal}🪙/goal',
                style: TextStyle(color: league.accentColor, fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: kGold.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation(league.accentColor),
              minHeight: 5,
            ),
          ),
          if (matchesDone >= league.matchCount)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                const Icon(Icons.check_circle, color: kGold, size: 14),
                const SizedBox(width: 6),
                Text('COMPLETED · +${league.completionBonus} 🪙',
                    style: TextStyle(color: kGold, fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════
//  PROFILE PAGE
// ══════════════════════════════════════════════
class ProfilePage extends StatefulWidget {
  final VoidCallback? onStateChanged;
  const ProfilePage({super.key, this.onStateChanged});
  @override State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _xpCtrl;
  late Animation<double> _xpAnim;
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _xpCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _xpAnim = CurvedAnimation(parent: _xpCtrl, curve: Curves.easeOut);
    _nameCtrl.text = GameManager.instance.playerName;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _xpCtrl.animateTo(GameManager.instance.xpFraction);
    });
  }
  @override void dispose() { _xpCtrl.dispose(); _nameCtrl.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kGold.withOpacity(0.1))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: kGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2))),
          const Text('Change Photo', style: TextStyle(
              color: kWhite, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(color: kGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kGold.withOpacity(0.3))),
                child: const Column(children: [
                  Icon(Icons.camera_alt_rounded, color: kGold, size: 30),
                  SizedBox(height: 6),
                  Text('Camera', style: TextStyle(color: kWhite, fontSize: 12)),
                ]),
              ),
            )),
            Expanded(child: GestureDetector(
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              child: Container(
                margin: const EdgeInsets.fromLTRB(8, 0, 16, 0),
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(color: kGold.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kGold.withOpacity(0.2))),
                child: const Column(children: [
                  Icon(Icons.photo_library_rounded, color: kGold, size: 30),
                  SizedBox(height: 6),
                  Text('Gallery', style: TextStyle(color: kWhite, fontSize: 12)),
                ]),
              ),
            )),
          ]),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Padding(padding: const EdgeInsets.only(bottom: 20),
                child: Text('Cancel', style: TextStyle(
                    color: Colors.grey[500], fontSize: 14))),
          ),
        ]),
      ),
    );
    if (source == null) return;
    try {
      final f = await ImagePicker().pickImage(source: source, imageQuality: 85);
      if (f != null) {
        final gm = GameManager.instance;
        gm.profileImagePath = f.path;
        await gm.save();
        setState(() {});
        widget.onStateChanged?.call();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final gm = GameManager.instance;
    final img = gm.profileImagePath;
    final hasImg = img != null && File(img).existsSync();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            decoration: BoxDecoration(
              color: kGold.withOpacity(0.04),
              border: Border(bottom: BorderSide(color: kGold.withOpacity(0.08))),
            ),
            child: Column(children: [
              GestureDetector(
                onTap: _pickImage,
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: kGold, borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: kGold.withOpacity(0.3), width: 2),
                      boxShadow: [BoxShadow(
                          color: kGold.withOpacity(0.45), blurRadius: 26, spreadRadius: 4)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: hasImg
                          ? Image.file(File(img), fit: BoxFit.cover)
                          : Image.asset('assets/icon.png', fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.person, color: Colors.white, size: 56)),
                    ),
                  ),
                  Positioned(bottom: -4, right: -4,
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(color: kGold, shape: BoxShape.circle,
                          border: Border.all(color: kBg, width: 2)),
                      child: const Icon(Icons.edit, color: Colors.white, size: 13),
                    )),
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                    color: kGold, borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: kGold.withOpacity(0.4), blurRadius: 12)]),
                child: Text('⭐ LEVEL ${gm.level}', style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 30),
                decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kGold.withOpacity(0.12))),
                child: TextField(
                  controller: _nameCtrl, textAlign: TextAlign.center,
                  style: TextStyle(color: kGold, fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: InputBorder.none,
                      hintText: 'Your Name',
                      hintStyle: TextStyle(color: Colors.grey)),
                  onChanged: (v) async { gm.playerName = v; await gm.save(); },
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('XP ${gm.xp} / ${gm.xpForNext}',
                        style: TextStyle(color: kGold.withOpacity(0.5), fontSize: 11)),
                    Text('→ Level ${gm.level + 1}',
                        style: TextStyle(color: kGoldAccent, fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 6),
                  AnimatedBuilder(
                    animation: _xpAnim,
                    builder: (_, __) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _xpAnim.value * gm.xpFraction,
                        backgroundColor: kGold.withOpacity(0.08),
                        valueColor: const AlwaysStoppedAnimation(kGold), minHeight: 10,
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, childAspectRatio: 1.8,
              crossAxisSpacing: 10, mainAxisSpacing: 10,
              children: [
                _StatTile('⚽', '${gm.totalGoals}', 'Total Goals'),
                _StatTile('🥅', '${gm.totalSaves}', 'Times Saved'),
                _StatTile('🔥', '${gm.bestStreak}', 'Best Streak'),
                _StatTile('🏆', '${gm.tournamentWins}', 'Match Wins'),
                _StatTile('🃏', '${gm.ownedCards.length}', 'Cards Owned'),
                _StatTile('🪙', '${gm.coins}', 'Coins'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 3, height: 14, color: kGold,
                    margin: const EdgeInsets.only(right: 8)),
                const Text('ACHIEVEMENTS', style: TextStyle(
                    color: kWhite, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              ]),
              const SizedBox(height: 10),
              _AchievementTile('🌱 First Goal',  'Score your first goal',  gm.totalGoals >= 1),
              _AchievementTile('🔥 On Fire',     'Score 5 goals in a row', gm.bestStreak >= 5),
              _AchievementTile('💰 Big Spender', 'Earn 1000 coins total',  gm.totalGoals * 20 >= 1000),
              _AchievementTile('🃏 Collector',   'Own 10 different cards', gm.ownedCards.length >= 10),
              _AchievementTile('🏆 Champion',    'Win 5 league matches',   gm.tournamentWins >= 5),
              _AchievementTile('⭐ Elite',        'Reach level 10',         gm.level >= 10),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String emoji, value, label;
  const _StatTile(this.emoji, this.value, this.label);
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGold.withOpacity(0.1))),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(emoji, style: const TextStyle(fontSize: 22)),
      const SizedBox(width: 10),
      Column(mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(
            color: kWhite, fontSize: 16, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ]),
    ]),
  );
}

class _AchievementTile extends StatelessWidget {
  final String title, desc; final bool unlocked;
  const _AchievementTile(this.title, this.desc, this.unlocked);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: unlocked ? kGold.withOpacity(0.05) : kCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: unlocked ? kGold.withOpacity(0.2) : kBorder),
    ),
    child: Row(children: [
      Text(unlocked ? '✅' : '🔒', style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(
            color: unlocked ? kGold : Colors.grey,
            fontSize: 13, fontWeight: FontWeight.w700)),
        Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ])),
    ]),
  );
}