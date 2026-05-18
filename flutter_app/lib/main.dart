import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

void main() {
  runApp(const PokeVaultApp());
}

class PokeVaultApp extends StatelessWidget {
  const PokeVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PokéVault Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors
            .transparent, // Sfondo trasparente per far vedere l'animazione
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF59E0B),
          surface: Color(0xFF1F2937),
        ),
        fontFamily: 'Roboto',
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ScannerTab(),
    const VaultTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060912), // Colore scurissimo di base
      body: Stack(
        children: [
          // === INIZIO: I 4 POKÉMON LEGGENDARI/ICONICI FLUTTUANTI ===
          // Mewtwo (In alto a sinistra, lento e maestoso)
          const FloatingSprite(
            imageUrl:
                'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/150.png',
            size: 280,
            alignment: Alignment(-0.9, -0.8),
            durationMillis: 4000,
            offsetValue: 15.0,
          ),
          // Charizard (In alto a destra, possente)
          const FloatingSprite(
            imageUrl:
                'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/6.png',
            size: 300,
            alignment: Alignment(1.2, -0.3),
            durationMillis: 3500,
            offsetValue: 20.0,
          ),
          // Pikachu (In basso a sinistra, vivace)
          const FloatingSprite(
            imageUrl:
                'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/25.png',
            size: 200,
            alignment: Alignment(-0.8, 0.7),
            durationMillis: 2500,
            offsetValue: 12.0,
          ),
          // Squirtle (In basso a destra, tranquillo)
          const FloatingSprite(
            imageUrl:
                'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/7.png',
            size: 180,
            alignment: Alignment(0.9, 0.8),
            durationMillis: 4500,
            offsetValue: 18.0,
          ),
          // === FINE: POKÉMON FLUTTUANTI ===

          // Il contenuto reale dell'app appoggiato sopra l'animazione!
          IndexedStack(index: _currentIndex, children: _screens),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF0B0F19).withOpacity(0.95),
        selectedItemColor: const Color(0xFFF59E0B),
        unselectedItemColor: Colors.white38,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.document_scanner_outlined),
              activeIcon: Icon(Icons.document_scanner),
              label: 'Grading Lab'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'Caveau'),
        ],
      ),
    );
  }
}

// --- TAB 1: LO SCANNER PREMIUM ---
class ScannerTab extends StatefulWidget {
  const ScannerTab({super.key});

  @override
  State<ScannerTab> createState() => _ScannerTabState();
}

class _ScannerTabState extends State<ScannerTab> {
  int _step = 1;
  bool _loading = false;
  String _archetipo = "Collezionista Puro";

  File? _immagineFronte;
  File? _immagineRetro;

  Map<String, dynamic> _datiFronte = {};
  Map<String, dynamic> _datiReportCompleto = {};

  final List<String> _archetipi = [
    "Collezionista Puro",
    "Investitore Squalo",
    "Ingegnere Nerd"
  ];

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937).withOpacity(
              0.85), // Semi-trasparente per far vedere i pokemon sotto
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                        overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Future<void> _scansionaFronte() async {
    final ImagePicker picker = ImagePicker();
    final XFile? foto = await picker.pickImage(source: ImageSource.gallery);
    if (foto == null) return;

    setState(() {
      _loading = true;
      _immagineFronte = File(foto.path);
    });

    try {
      var request = http.MultipartRequest(
          'POST', Uri.parse('http://192.168.1.5:8000/api/scan-front'));
      request.files.add(await http.MultipartFile.fromPath('file', foto.path));
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        setState(() {
          _datiFronte = jsonDecode(utf8.decode(response.bodyBytes));
          _step = 2;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Errore server"), backgroundColor: Colors.red));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _scansionaRetro() async {
    final ImagePicker picker = ImagePicker();
    final XFile? foto = await picker.pickImage(source: ImageSource.gallery);
    if (foto == null) return;

    setState(() {
      _loading = true;
      _immagineRetro = File(foto.path);
    });

    try {
      var request = http.MultipartRequest(
          'POST', Uri.parse('http://192.168.1.5:8000/api/scan-back'));
      request.files.add(await http.MultipartFile.fromPath('file', foto.path));
      request.fields['nome'] = _datiFronte['nome'];
      request.fields['prezzo_raw'] = _datiFronte['prezzo_raw_eur'].toString();
      request.fields['archetipo'] = _archetipo;

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        setState(() {
          _datiReportCompleto = jsonDecode(utf8.decode(response.bodyBytes));
          _step = 3;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Errore server"), backgroundColor: Colors.red));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _salvaNelCaveau() async {
    setState(() => _loading = true);
    try {
      var response = await http.post(
        Uri.parse('http://192.168.1.5:8000/api/vault/add'),
        body: {
          'nome': _datiFronte['nome'],
          'espansione': _datiFronte['espansione'],
          'voto': _datiReportCompleto['voto'],
          'valore': _datiReportCompleto['valore_corretto_eur'].toString(),
          'variante': _datiFronte['variante'],
        },
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("🎉 Card Blindata nel Caveau!"),
            backgroundColor: Colors.green));
        setState(() {
          _step = 1;
          _immagineFronte = null;
          _immagineRetro = null;
          _datiFronte = {};
          _datiReportCompleto = {};
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Errore salvataggio"), backgroundColor: Colors.red));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // FONDAMENTALE
      appBar: AppBar(
          title: const Text("POKÉVAULT PRO",
              style:
                  TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_step == 1) ...[
              Container(
                height: 200,
                decoration: BoxDecoration(
                    color: const Color(0xFF1F2937).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12)),
                child: const Icon(Icons.document_scanner,
                    size: 80, color: Color(0xFFF59E0B)),
              ),
              const SizedBox(height: 30),
              const Text("IMPOSTAZIONI AI",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white54)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                    color: const Color(0xFF1F2937).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(10)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _archetipo,
                    isExpanded: true,
                    icon: const Icon(Icons.smart_toy, color: Color(0xFFF59E0B)),
                    items: _archetipi
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _archetipo = v!),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFF59E0B)))
                  : ElevatedButton.icon(
                      onPressed: _scansionaFronte,
                      icon: const Icon(Icons.camera_alt),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      label: const Text("SCANSIONA FRONTE CARTA",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    )
            ],
            if (_step == 2) ...[
              if (_immagineFronte != null)
                Container(
                  height: 300,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8))
                      ]),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(_immagineFronte!, fit: BoxFit.contain)),
                ),
              const Text("ANALISI FRONTE COMPLETATA",
                  style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.5)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildMetricCard(
                      "CARTA",
                      _datiFronte['nome'] ?? "Sconosciuto",
                      Icons.style,
                      Colors.purpleAccent),
                  const SizedBox(width: 10),
                  _buildMetricCard(
                      "ESPANSIONE",
                      _datiFronte['espansione'] ?? "Sconosciuto",
                      Icons.auto_awesome_mosaic,
                      Colors.orangeAccent),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildMetricCard("RARITÀ", _datiFronte['variante'] ?? "-",
                      Icons.star, Colors.yellowAccent),
                  const SizedBox(width: 10),
                  _buildMetricCard(
                      "VALORE GREZZO",
                      "€ ${_datiFronte['prezzo_raw_eur']}",
                      Icons.euro,
                      Colors.greenAccent),
                ],
              ),
              const SizedBox(height: 30),
              const Divider(color: Colors.white12),
              const SizedBox(height: 20),
              const Text("FASE 2: CENTRATURA E RETRO",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent)),
              const SizedBox(height: 20),
              _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Colors.cyanAccent))
                  : ElevatedButton.icon(
                      onPressed: _scansionaRetro,
                      icon: const Icon(Icons.flip_to_back),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      label: const Text("SCANSIONA RETRO E VALUTA",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    )
            ],
            if (_step == 3) ...[
              Row(
                children: [
                  if (_immagineFronte != null)
                    Expanded(
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(_immagineFronte!,
                                height: 160, fit: BoxFit.contain))),
                  const SizedBox(width: 10),
                  if (_immagineRetro != null)
                    Expanded(
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(_immagineRetro!,
                                height: 160, fit: BoxFit.contain))),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    const Color(0xFF1F2937).withOpacity(0.9),
                    const Color(0xFF111827).withOpacity(0.9)
                  ]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFF59E0B).withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(_datiReportCompleto['voto'],
                        style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFF59E0B))),
                    const Text("GRADO STIMATO",
                        style:
                            TextStyle(color: Colors.white54, letterSpacing: 2)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(children: [
                          const Text("L/R",
                              style: TextStyle(color: Colors.white54)),
                          Text("${_datiReportCompleto['bilanciamento_x']}",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold))
                        ]),
                        Column(children: [
                          const Text("T/B",
                              style: TextStyle(color: Colors.white54)),
                          Text("${_datiReportCompleto['bilanciamento_y']}",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold))
                        ]),
                        Column(children: [
                          const Text("VALORE",
                              style: TextStyle(color: Colors.greenAccent)),
                          Text(
                              "€ ${_datiReportCompleto['valore_corretto_eur']}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.greenAccent))
                        ]),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text("REPORT ESPERTO",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Text("${_datiReportCompleto['report_agente']}",
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, height: 1.5)),
              const SizedBox(height: 24),
              const Text("ANALISI ARBITRAGGIO MERCATO",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent,
                      fontSize: 12,
                      letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Text("${_datiReportCompleto['analisi_arbitraggio']}",
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                      fontStyle: FontStyle.italic)),
              const SizedBox(height: 35),
              _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFF59E0B)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _salvaNelCaveau,
                          icon: const Icon(Icons.lock),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                          ),
                          label: const Text("SALVA NEL CAVEAU",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => setState(() {
                            _step = 1;
                            _immagineFronte = null;
                            _immagineRetro = null;
                          }),
                          child: const Text("SCARTA E RIPROVA",
                              style: TextStyle(color: Colors.white54)),
                        )
                      ],
                    ),
            ],
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}

// --- TAB 2: IL CAVEAU ---
class VaultTab extends StatefulWidget {
  const VaultTab({super.key});

  @override
  State<VaultTab> createState() => _VaultTabState();
}

class _VaultTabState extends State<VaultTab> {
  List<dynamic> _collezione = [];
  bool _loading = false;

  Future<void> _caricaCaveau() async {
    setState(() => _loading = true);
    try {
      var response =
          await http.get(Uri.parse('http://192.168.1.5:8000/api/vault'));
      if (response.statusCode == 200) {
        setState(() {
          _collezione = jsonDecode(utf8.decode(response.bodyBytes));
        });
      }
    } catch (e) {
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _caricaCaveau();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // FONDAMENTALE
      appBar: AppBar(
        title: const Text("IL MIO CAVEAU",
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFFF59E0B)),
              onPressed: _caricaCaveau)
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
          : _collezione.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.security,
                          size: 80, color: Colors.white12),
                      const SizedBox(height: 20),
                      const Text("Il tuo caveau è vuoto.",
                          style:
                              TextStyle(color: Colors.white54, fontSize: 18)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _collezione.length,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  itemBuilder: (context, index) {
                    var carta = _collezione[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                          color: const Color(0xFF1F2937).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(
                              carta['voto'].toString().replaceAll("PSA ", ""),
                              style: const TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                        ),
                        title: Text(carta['nome'],
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text(
                            "${carta['set_name']} • ${carta['variante']}",
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text("VALORE",
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 10)),
                            Text("€ ${carta['valore']}",
                                style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// =========================================================================
// IL WIDGET MAGICO: Gestisce l'animazione fluttuante delle immagini!
// =========================================================================
class FloatingSprite extends StatefulWidget {
  final String imageUrl;
  final double size;
  final Alignment alignment;
  final int durationMillis;
  final double offsetValue;

  const FloatingSprite({
    super.key,
    required this.imageUrl,
    required this.size,
    required this.alignment,
    required this.durationMillis,
    required this.offsetValue,
  });

  @override
  State<FloatingSprite> createState() => _FloatingSpriteState();
}

class _FloatingSpriteState extends State<FloatingSprite>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Creiamo un loop infinito che va avanti e indietro
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.durationMillis),
      vsync: this,
    )..repeat(reverse: true);

    // Creiamo un movimento su e giù morbidissimo
    _animation =
        Tween<double>(begin: -widget.offsetValue, end: widget.offsetValue)
            .animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.alignment,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          // Trasla l'immagine sull'asse Y in base al valore dell'animazione
          return Transform.translate(
            offset: Offset(0, _animation.value),
            child: child,
          );
        },
        child: Opacity(
          opacity:
              0.15, // La rende una filigrana perfetta che non disturba la lettura
          child: Image.network(
            widget.imageUrl,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
