import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import 'history_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  AdminPanelScreen
//  Tabs: Questions · Categories · Schools
//  Features: Add, Delete, Search, no overflow
// ═══════════════════════════════════════════════════════════════
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  static const _baseUrl = 'http://liuquiz.atwebpages.com/';

  // ── question form ─────────────────────────────────────────────
  final _qText = TextEditingController();
  final _optA  = TextEditingController();
  final _optB  = TextEditingController();
  final _optC  = TextEditingController();
  final _optD  = TextEditingController();
  String _correct = 'A';
  int    _level   = 1;
  String? _catId;

  // ── search ────────────────────────────────────────────────────
  final _qSearchCtrl = TextEditingController();
  final _cSearchCtrl = TextEditingController();
  final _sSearchCtrl = TextEditingController();
  String _qQuery = '';
  String _cQuery = '';
  String _sQuery = '';

  // ── lists ─────────────────────────────────────────────────────
  List _categories = [];
  List _schools    = [];
  List _questions  = [];
  bool _loadingCat = true;
  bool _loadingSch = true;
  bool _loadingQ   = true;
  bool _addingQ    = false;

  // ── admin games ───────────────────────────────────────────────
  List _adminGames   = [];
  bool _loadingGames = true;

  int _selectedIndex = 0;

  // ── filtered views ────────────────────────────────────────────
  List get _filteredQuestions => _qQuery.isEmpty
      ? _questions
      : _questions.where((q) {
          final text = '${q['question_text']} ${q['category_name']}'
              .toLowerCase();
          return text.contains(_qQuery.toLowerCase());
        }).toList();

  List get _filteredCategories => _cQuery.isEmpty
      ? _categories
      : _categories.where((c) =>
          c['category_name'].toLowerCase().contains(_cQuery.toLowerCase()))
          .toList();

  List get _filteredSchools => _sQuery.isEmpty
      ? _schools
      : _schools.where((s) =>
          s['school_name'].toLowerCase().contains(_sQuery.toLowerCase()))
          .toList();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadSchools();
    _loadQuestions();
    _loadAdminGames();
    _qSearchCtrl.addListener(() => setState(() => _qQuery = _qSearchCtrl.text));
    _cSearchCtrl.addListener(() => setState(() => _cQuery = _cSearchCtrl.text));
    _sSearchCtrl.addListener(() => setState(() => _sQuery = _sSearchCtrl.text));
  }

  @override
  void dispose() {
    _qText.dispose(); _optA.dispose(); _optB.dispose();
    _optC.dispose(); _optD.dispose();
    _qSearchCtrl.dispose(); _cSearchCtrl.dispose(); _sSearchCtrl.dispose();
    super.dispose();
  }

  // ── Load ──────────────────────────────────────────────────────
  Future<void> _loadCategories() async {
    try {
      final res = await http.get(Uri.parse('${_baseUrl}get_categories.php'));
      if (!mounted) return;
      setState(() { _categories = jsonDecode(res.body); _loadingCat = false; });
    } catch (_) { if (mounted) setState(() => _loadingCat = false); }
  }

  Future<void> _loadSchools() async {
    try {
      final res = await http.get(Uri.parse('${_baseUrl}get_schools.php'));
      if (!mounted) return;
      setState(() { _schools = jsonDecode(res.body); _loadingSch = false; });
    } catch (_) { if (mounted) setState(() => _loadingSch = false); }
  }

  Future<void> _loadQuestions() async {
    try {
      final res = await http.get(Uri.parse('${_baseUrl}get_all_questions.php'));
      if (!mounted) return;
      setState(() { _questions = jsonDecode(res.body); _loadingQ = false; });
    } catch (_) { if (mounted) setState(() => _loadingQ = false); }
  }

  // ── Add ───────────────────────────────────────────────────────
  Future<void> _addQuestion() async {
    if (_qText.text.trim().isEmpty || _optA.text.trim().isEmpty ||
        _optB.text.trim().isEmpty || _optC.text.trim().isEmpty ||
        _optD.text.trim().isEmpty || _catId == null) {
      _snack('Please fill all fields and select a category.');
      return;
    }
    setState(() => _addingQ = true);
    try {
      final res = await http.post(
        Uri.parse('${_baseUrl}add_question.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'question_text':  _qText.text.trim(),
          'option_a':       _optA.text.trim(),
          'option_b':       _optB.text.trim(),
          'option_c':       _optC.text.trim(),
          'option_d':       _optD.text.trim(),
          'correct_answer': _correct,
          'level':          _level.toString(),
          'category_id':    _catId!,
        },
      );
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if (data['status'] == 'success') {
        _snack('Question added!', ok: true);
        _qText.clear(); _optA.clear(); _optB.clear();
        _optC.clear(); _optD.clear();
        setState(() => _catId = null);
        _loadQuestions();
      } else {
        _snack('Error: ${data['message'] ?? 'unknown'}');
      }
    } catch (_) { _snack('Network error.'); }
    if (mounted) setState(() => _addingQ = false);
  }

  Future<void> _addCategory() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => _InputDialog(
        title: 'New Category', hint: 'e.g. Animals',
        ctrl: ctrl, icon: '🏷️',
        onConfirm: () async {
          if (ctrl.text.trim().isEmpty) return;
          try {
            final res = await http.post(
              Uri.parse('${_baseUrl}add_category.php'),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: {'category_name': ctrl.text.trim()},
            );
            final data = jsonDecode(res.body);
            if (data['status'] == 'success') {
              await _loadCategories();
              if (mounted) _snack('Category added!', ok: true);
            } else {
              if (mounted) _snack('Error: ${data['message'] ?? 'unknown'}');
            }
          } catch (_) { if (mounted) _snack('Network error — check XAMPP.'); }
        },
      ),
    );
  }

  Future<void> _addSchool() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => _InputDialog(
        title: 'New School', hint: 'e.g. Harvard',
        ctrl: ctrl, icon: '🏫',
        onConfirm: () async {
          if (ctrl.text.trim().isEmpty) return;
          try {
            final res = await http.post(
              Uri.parse('${_baseUrl}add_school.php'),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: {'school_name': ctrl.text.trim()},
            );
            final data = jsonDecode(res.body);
            if (data['status'] == 'success') {
              await _loadSchools();
              if (mounted) _snack('School added!', ok: true);
            } else {
              if (mounted) _snack('Error: ${data['message'] ?? 'unknown'}');
            }
          } catch (_) { if (mounted) _snack('Network error — check XAMPP.'); }
        },
      ),
    );
  }

  // ── Delete ────────────────────────────────────────────────────
  Future<void> _deleteQuestion(dynamic q) async {
    final confirmed = await _confirm(
      'Delete Question?',
      '"${q['question_text']}"',
    );
    if (!confirmed) return;
    try {
      final res = await http.post(
        Uri.parse('${_baseUrl}delete_question.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'question_id': q['question_id'].toString()},
      );
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if (data['status'] == 'success') {
        setState(() =>
            _questions.removeWhere((x) => x['question_id'] == q['question_id']));
        _snack('Question deleted', ok: true);
      } else {
        _snack('Error: ${data['message'] ?? 'unknown'}');
      }
    } catch (_) { _snack('Network error.'); }
  }

  Future<void> _deleteCategory(dynamic c) async {
    final confirmed = await _confirm(
      'Delete Category?',
      '"${c['category_name']}"\n\nAll questions in this category will also be deleted.',
    );
    if (!confirmed) return;
    try {
      final res = await http.post(
        Uri.parse('${_baseUrl}delete_category.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'category_id': c['category_id'].toString()},
      );
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if (data['status'] == 'success') {
        setState(() =>
            _categories.removeWhere((x) => x['category_id'] == c['category_id']));
        _snack('Category deleted', ok: true);
        _loadQuestions(); // questions may have been cascade-deleted
      } else {
        _snack('Error: ${data['message'] ?? 'unknown'}');
      }
    } catch (_) { _snack('Network error.'); }
  }

  Future<void> _deleteSchool(dynamic s) async {
    final confirmed = await _confirm(
      'Delete School?',
      '"${s['school_name']}"',
    );
    if (!confirmed) return;
    try {
      final res = await http.post(
        Uri.parse('${_baseUrl}delete_school.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'school_id': s['school_id'].toString()},
      );
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if (data['status'] == 'success') {
        setState(() =>
            _schools.removeWhere((x) => x['school_id'] == s['school_id']));
        _snack('School deleted', ok: true);
      } else {
        _snack('Error: ${data['message'] ?? 'unknown'}');
      }
    } catch (_) { _snack('Network error.'); }
  }

  // ── Helpers ───────────────────────────────────────────────────
  Future<bool> _confirm(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.bgCard,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text(title,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900)),
            content: Text(body,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 14)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('DELETE',
                    style: TextStyle(
                        color: AppColors.wrong,
                        fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _snack(String msg, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.correctBg : AppColors.bgSurface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Games ─────────────────────────────────────────────────────
  Future<void> _loadAdminGames() async {
    if (!mounted) return;
    setState(() => _loadingGames = true);
    try {
      final res = await http.get(
          Uri.parse('${_baseUrl}get_games.php?status=all'));
      if (!mounted) return;
      setState(() { _adminGames = jsonDecode(res.body); _loadingGames = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingGames = false);
    }
  }

  void _showCreateGameSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateGameSheet(
        baseUrl: _baseUrl,
        categories: _categories,
        questions: _questions,
        onCreated: () {
          _loadAdminGames();
          _snack('Game created!', ok: true);
        },
      ),
    );
  }

  Future<void> _deleteGame(dynamic g) async {
    final confirmed = await _confirm(
      'Delete Game?',
      '"${g['game_name']}"\n\nThis will delete all teams, questions and scores.',
    );
    if (!confirmed) return;
    try {
      final res = await http.post(
        Uri.parse('${_baseUrl}delete_game.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'game_id': g['game_id'].toString()},
      );
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if (data['status'] == 'success') {
        setState(() =>
            _adminGames.removeWhere((x) => x['game_id'] == g['game_id']));
        _snack('Game deleted', ok: true);
      } else {
        _snack('Error: ${data['message'] ?? 'unknown'}');
      }
    } catch (_) { _snack('Network error.'); }
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Row(
            children: [
              _LeftNav(
                selected: _selectedIndex,
                onSelect: (i) {
                  if (i == 4) {
                    // History — open as full screen
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const HistoryScreen()));
                  } else {
                    setState(() => _selectedIndex = i);
                  }
                },
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _questionsTab(),
                    _categoriesTab(),
                    _schoolsTab(),
                    _gamesTab(),
                    const SizedBox.shrink(), // placeholder for history (navigates away)
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Questions tab ─────────────────────────────────────────────
  // The entire tab is one ListView so nothing overflows.
  Widget _questionsTab() {
    final filtered = _filteredQuestions;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        // ── Add form ──────────────────────────────────────────
        _SectionLabel('Add Question'),
        const SizedBox(height: 10),
        _AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fl('Question Text'),
              const SizedBox(height: 8),
              TextField(
                controller: _qText,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: const InputDecoration(
                    hintText: 'Type your question here...'),
              ),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(child: _optField(_optA, 'Option A', 'A')),
                const SizedBox(width: 12),
                Expanded(child: _optField(_optB, 'Option B', 'B')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _optField(_optC, 'Option C', 'C')),
                const SizedBox(width: 12),
                Expanded(child: _optField(_optD, 'Option D', 'D')),
              ]),
              const SizedBox(height: 16),

              _fl('Correct Answer'),
              const SizedBox(height: 8),
              Row(
                children: ['A', 'B', 'C', 'D'].map((k) {
                  final sel = _correct == k;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _correct = k),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.correctBg : AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel
                                ? AppColors.correct.withOpacity(0.5)
                                : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Center(
                          child: Text(k,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: sel ? AppColors.correct : AppColors.textMuted,
                              )),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),
              _fl('Difficulty Level'),
              const SizedBox(height: 8),
              Row(
                children: [1, 2, 3].map((v) {
                  final sel = _level == v;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _level = v),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.purple.withOpacity(0.2)
                              : AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel
                                ? AppColors.purple.withOpacity(0.5)
                                : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Center(
                          child: Text('Level $v',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: sel ? AppColors.purple : AppColors.textMuted,
                              )),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),
              _fl('Category'),
              const SizedBox(height: 8),
              _loadingCat
                  ? const LinearProgressIndicator(color: AppColors.purple)
                  : DropdownButtonFormField<String>(
                      value: _catId,
                      dropdownColor: AppColors.bgCard,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: AppColors.purple),
                      decoration: const InputDecoration(
                        hintText: 'Select category',
                        prefixIcon: Icon(Icons.category_outlined,
                            color: AppColors.purple, size: 20),
                      ),
                      items: _categories.map<DropdownMenuItem<String>>((c) {
                        return DropdownMenuItem<String>(
                          value: c['category_id'].toString(),
                          child: Text(c['category_name']),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _catId = v),
                    ),

              const SizedBox(height: 18),
              _addingQ
                  ? Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppColors.purple, AppColors.pink]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        ),
                      ),
                    )
                  : GradientButton(
                      label: 'ADD QUESTION',
                      icon: Icons.add_circle_outline,
                      onTap: _addQuestion,
                    ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Questions list ────────────────────────────────────
        Row(children: [
          _SectionLabel('All Questions'),
          const SizedBox(width: 8),
          _CountBadge(_questions.length),
        ]),
        const SizedBox(height: 10),

        // search bar
        _SearchBar(ctrl: _qSearchCtrl, hint: 'Search questions…'),
        const SizedBox(height: 10),

        if (_loadingQ)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator(color: AppColors.purple)),
          )
        else if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text('No questions found',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
          )
        else
          ...filtered.map((q) => _QuestionCard(
                q: q,
                onDelete: () => _deleteQuestion(q),
              )),
      ],
    );
  }

  Widget _optField(TextEditingController ctrl, String label, String letter) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Container(
          margin: const EdgeInsets.all(10),
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: Text(letter,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textMuted)),
          ),
        ),
      ),
    );
  }

  // ── Categories tab ────────────────────────────────────────────
  Widget _categoriesTab() {
    final filtered = _filteredCategories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: Column(
            children: [
              GradientButton(
                label: 'ADD CATEGORY',
                icon: Icons.add,
                onTap: _addCategory,
              ),
              const SizedBox(height: 12),
              _SearchBar(ctrl: _cSearchCtrl, hint: 'Search categories…'),
              const SizedBox(height: 4),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
          child: Row(children: [
            _SectionLabel('Categories'),
            const SizedBox(width: 8),
            _CountBadge(_categories.length),
          ]),
        ),
        Expanded(
          child: _loadingCat
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.purple))
              : filtered.isEmpty
                  ? const Center(
                      child: Text('No categories found',
                          style: TextStyle(color: AppColors.textMuted)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        return _ListItemCard(
                          icon: '🏷️',
                          iconColor: AppColors.purple,
                          label: c['category_name'] ?? '',
                          subLabel: 'ID ${c['category_id']}',
                          onDelete: () => _deleteCategory(c),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ── Schools tab ───────────────────────────────────────────────
  Widget _schoolsTab() {
    final filtered = _filteredSchools;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: Column(
            children: [
              GradientButton(
                label: 'ADD SCHOOL',
                icon: Icons.add,
                onTap: _addSchool,
              ),
              const SizedBox(height: 12),
              _SearchBar(ctrl: _sSearchCtrl, hint: 'Search schools…'),
              const SizedBox(height: 4),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
          child: Row(children: [
            _SectionLabel('Schools'),
            const SizedBox(width: 8),
            _CountBadge(_schools.length),
          ]),
        ),
        Expanded(
          child: _loadingSch
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.purple))
              : filtered.isEmpty
                  ? const Center(
                      child: Text('No schools found',
                          style: TextStyle(color: AppColors.textMuted)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final s = filtered[i];
                        return _ListItemCard(
                          icon: '🏫',
                          iconColor: AppColors.gold,
                          label: s['school_name'] ?? '',
                          subLabel: 'ID ${s['school_id']}',
                          onDelete: () => _deleteSchool(s),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ── Games tab ──────────────────────────────────────────────────
  Widget _gamesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: GradientButton(
            label: 'CREATE GAME',
            icon: Icons.add_circle_outline,
            onTap: _showCreateGameSheet,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
          child: Row(children: [
            _SectionLabel('All Games'),
            const SizedBox(width: 8),
            _CountBadge(_adminGames.length),
            const Spacer(),
            GestureDetector(
              onTap: _loadAdminGames,
              child: const Icon(Icons.refresh_rounded,
                  size: 18, color: AppColors.textMuted),
            ),
          ]),
        ),
        Expanded(
          child: _loadingGames
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.purple))
              : _adminGames.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🎮', style: TextStyle(fontSize: 48)),
                          SizedBox(height: 12),
                          Text('No games yet',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                          SizedBox(height: 4),
                          Text('Tap "Create Game" to add one.',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                      itemCount: _adminGames.length,
                      itemBuilder: (_, i) => _GameAdminCard(
                        game: _adminGames[i],
                        onDelete: () => _deleteGame(_adminGames[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _fl(String text) => Text(text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 0.4,
      ));
}

// ── Shared sub-widgets ────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      ));
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge(this.count);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.purple.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$count',
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.purple)),
      );
}

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  const _SearchBar({required this.ctrl, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
        suffixIcon: ctrl.text.isNotEmpty
            ? GestureDetector(
                onTap: ctrl.clear,
                child: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final Widget child;
  const _AdminCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: child,
      );
}

class _QuestionCard extends StatelessWidget {
  final dynamic q;
  final VoidCallback onDelete;
  const _QuestionCard({required this.q, required this.onDelete});

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuestionDetailSheet(q: q, onDelete: onDelete),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    q['category_name'] ?? 'Unknown',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.purple),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Lvl ${q['level']}',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold),
                  ),
                ),
                const Spacer(),
                Text('ID ${q['question_id']}',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.wrong.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline,
                        size: 16, color: AppColors.wrong),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              q['question_text'] ?? '',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 13, color: AppColors.correct),
                const SizedBox(width: 4),
                Text(
                  'Answer: ${q['correct_answer']}',
                  style: const TextStyle(fontSize: 12, color: AppColors.correct),
                ),
                const Spacer(),
                const Text('Tap to see details',
                    style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    size: 14, color: AppColors.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Question detail bottom sheet ──────────────────────────────
class _QuestionDetailSheet extends StatelessWidget {
  final dynamic q;
  final VoidCallback onDelete;
  const _QuestionDetailSheet({required this.q, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final correct = q['correct_answer'] as String? ?? '';
    final options = [
      ('A', q['option_a'] as String? ?? ''),
      ('B', q['option_b'] as String? ?? ''),
      ('C', q['option_c'] as String? ?? ''),
      ('D', q['option_d'] as String? ?? ''),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.quiz_outlined,
                      color: AppColors.purple, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Question Details',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  ),
                  // delete button in sheet header
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onDelete();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.wrong.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete_outline,
                          size: 18, color: AppColors.wrong),
                    ),
                  ),
                ],
              ),
            ),

            Container(height: 1, color: AppColors.border),

            // scrollable body
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // meta pills
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _MetaPill(
                          label: q['category_name'] ?? 'Unknown',
                          color: AppColors.purple),
                      _MetaPill(
                          label: 'Level ${q['level']}',
                          color: AppColors.gold),
                      _MetaPill(
                          label: 'ID ${q['question_id']}',
                          color: AppColors.textMuted),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // question text
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.purple.withOpacity(0.25)),
                    ),
                    child: Text(
                      q['question_text'] ?? '',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text('Options',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 10),

                  // options
                  ...options.map(((String letter, String text) opt) {
                    final isCorrect = opt.$1 == correct;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? AppColors.correctBg
                            : AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCorrect
                              ? AppColors.correct.withOpacity(0.4)
                              : Colors.white.withOpacity(0.07),
                          width: isCorrect ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: isCorrect
                                  ? AppColors.correct.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(opt.$1,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: isCorrect
                                          ? AppColors.correct
                                          : AppColors.textMuted)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(opt.$2,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isCorrect
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isCorrect
                                        ? AppColors.correct
                                        : Colors.white)),
                          ),
                          if (isCorrect)
                            const Icon(Icons.check_circle,
                                size: 18, color: AppColors.correct),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  final Color color;
  const _MetaPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _ListItemCard extends StatelessWidget {
  final String icon;
  final Color iconColor;
  final String label;
  final String subLabel;
  final VoidCallback onDelete;

  const _ListItemCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subLabel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
          Text(subLabel,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.wrong.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.delete_outline,
                  size: 17, color: AppColors.wrong),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Left navigation sidebar ───────────────────────────────────
class _LeftNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onBack;

  const _LeftNav({
    required this.selected,
    required this.onSelect,
    required this.onBack,
  });

  static const _items = [
    (icon: Icons.quiz_outlined,           label: 'Questions'),
    (icon: Icons.label_outline,           label: 'Categories'),
    (icon: Icons.school_outlined,         label: 'Schools'),
    (icon: Icons.sports_esports_rounded,  label: 'Games'),
    (icon: Icons.history_rounded,         label: 'History'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  size: 15, color: Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gold.withOpacity(0.3)),
            ),
            child: const Text('ADMIN',
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: AppColors.gold,
                    letterSpacing: 1)),
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 16),
          for (int i = 0; i < _items.length; i++) ...[
            _NavItem(
              icon: _items[i].icon,
              label: _items[i].label,
              isSelected: selected == i,
              onTap: () => onSelect(i),
            ),
            const SizedBox(height: 8),
          ],
          const Spacer(),
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text('v1.0',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [AppColors.purple, AppColors.pink],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20,
                color: isSelected ? Colors.white : AppColors.textMuted),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.textMuted),
                textAlign: TextAlign.center,
                maxLines: 2),
          ],
        ),
      ),
    );
  }
}

// ── Game Admin Card ───────────────────────────────────────────
class _GameAdminCard extends StatelessWidget {
  final dynamic game;
  final VoidCallback onDelete;
  const _GameAdminCard({required this.game, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final status    = game['status']?.toString() ?? 'waiting';
    final mode      = (game['game_mode'] ?? 'multi').toString();
    final teams     = List<Map>.from(game['teams'] ?? []);
    final sched     = game['scheduled_at'];
    String? schedStr;
    if (sched != null && sched.toString().isNotEmpty) {
      try {
        final d = DateTime.parse(sched.toString().replaceFirst(' ', 'T'));
        schedStr =
            '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
            '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    final statusColor = status == 'waiting'
        ? AppColors.gold
        : status == 'active'
            ? AppColors.correct
            : AppColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  game['game_name']?.toString() ?? '',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(status.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: statusColor)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.wrong.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline,
                      size: 16, color: AppColors.wrong),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _InfoChip(
                  icon: Icons.quiz_rounded,
                  label: '${game['question_count']} Qs'),
              _InfoChip(
                  icon: Icons.timer_rounded,
                  label: '${game['game_duration']}s'),
              _InfoChip(
                icon: mode == 'single'
                    ? Icons.person_rounded
                    : Icons.groups_rounded,
                label: mode == 'single' ? 'Single' : 'Multi',
              ),
              if (schedStr != null)
                _InfoChip(
                    icon: Icons.schedule_rounded,
                    label: schedStr,
                    color: const Color(0xFF38BDF8)),
            ],
          ),
          if (teams.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: teams
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.purple.withOpacity(0.3)),
                        ),
                        child: Text(
                          t['team_name']?.toString() ?? '',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.purple,
                              fontWeight: FontWeight.w700),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon,
      required this.label,
      this.color = AppColors.textMuted});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      );
}

// ── Player / Team entry helpers ───────────────────────────────
class _PlayerEntry {
  final TextEditingController nameCtrl;
  String? schoolId;
  _PlayerEntry() : nameCtrl = TextEditingController();
  void dispose() => nameCtrl.dispose();
}

class _TeamEntry {
  final TextEditingController nameCtrl;
  final List<_PlayerEntry> players;
  String? schoolId;   // used by single mode
  _TeamEntry()
      : nameCtrl = TextEditingController(),
        players   = [_PlayerEntry()];
  void dispose() {
    nameCtrl.dispose();
    for (final p in players) p.dispose();
  }
}

// ── Create Game Sheet ─────────────────────────────────────────
class _CreateGameSheet extends StatefulWidget {
  final String baseUrl;
  final List categories;
  final List questions;
  final VoidCallback onCreated;

  const _CreateGameSheet({
    required this.baseUrl,
    required this.categories,
    required this.questions,
    required this.onCreated,
  });

  @override
  State<_CreateGameSheet> createState() => _CreateGameSheetState();
}

class _CreateGameSheetState extends State<_CreateGameSheet> {
  final _nameCtrl = TextEditingController();
  String    _mode     = 'multi';
  int       _duration = 30;
  DateTime? _scheduledAt;
  String?   _catId;
  bool      _creating = false;

  // Teams with nested players
  late List<_TeamEntry> _teams;

  // Sheet loads its own fresh data
  List _sheetCategories = [];
  List _sheetQuestions  = [];
  List _sheetSchools    = [];
  bool _loadingData     = true;

  @override
  void initState() {
    super.initState();
    _teams = [_TeamEntry(), _TeamEntry()]; // default: 2 teams for multi
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _loadingData = true);

    try {
      final res = await http.get(Uri.parse('${widget.baseUrl}get_categories.php'));
      if (mounted) setState(() => _sheetCategories = jsonDecode(res.body));
    } catch (_) {}

    try {
      final res = await http.get(Uri.parse('${widget.baseUrl}get_all_questions.php'));
      if (mounted) setState(() => _sheetQuestions = jsonDecode(res.body));
    } catch (_) {}

    try {
      final res = await http.get(Uri.parse('${widget.baseUrl}get_schools.php'));
      if (mounted) setState(() => _sheetSchools = jsonDecode(res.body));
    } catch (_) {}

    if (mounted) setState(() => _loadingData = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final t in _teams) t.dispose();
    super.dispose();
  }

  // Switch mode and reset teams accordingly
  void _switchMode(String mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      for (final t in _teams) t.dispose();
      if (mode == 'single') {
        _teams = [_TeamEntry()]; // 1 team for single player
      } else {
        _teams = [_TeamEntry(), _TeamEntry()]; // 2 teams for multi
      }
    });
  }

  List<String> get _questionIds {
    if (_catId == null) return [];
    return _sheetQuestions
        .where((q) => q['category_id'].toString() == _catId)
        .map<String>((q) => q['question_id'].toString())
        .toList();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { _snack('Enter a game name'); return; }

    // Build teams payload with nested players
    final teams = <Map<String, dynamic>>[];

    if (_mode == 'single') {
      // Single mode: one team name + optional school
      final tname = _teams[0].nameCtrl.text.trim();
      if (tname.isEmpty) { _snack('Enter a team name'); return; }
      final entry = <String, dynamic>{'name': tname, 'players': []};
      if (_teams[0].schoolId != null) entry['school_id'] = int.parse(_teams[0].schoolId!);
      teams.add(entry);
    } else {
      // Multiplayer: named teams with players
      for (final team in _teams) {
        final tname = team.nameCtrl.text.trim();
        if (tname.isEmpty) continue;
        final players = <Map<String, dynamic>>[];
        for (final p in team.players) {
          final pname = p.nameCtrl.text.trim();
          if (pname.isEmpty) continue;
          final pe = <String, dynamic>{'name': pname};
          if (p.schoolId != null) pe['school_id'] = int.parse(p.schoolId!);
          players.add(pe);
        }
        final teamEntry = <String, dynamic>{'name': tname, 'players': players};
        if (team.schoolId != null) teamEntry['school_id'] = int.parse(team.schoolId!);
        teams.add(teamEntry);
      }
      if (teams.length < 2) { _snack('Add at least 2 team names'); return; }
    }

    if (_catId == null) { _snack('Select a category for questions'); return; }
    final qIds = _questionIds;
    if (qIds.isEmpty) { _snack('No questions in selected category'); return; }

    setState(() => _creating = true);
    try {
      // Build scheduled_at string if set
      String? schedStr;
      if (_scheduledAt != null) {
        final dt = _scheduledAt!;
        schedStr =
            '${dt.year.toString().padLeft(4, '0')}-'
            '${dt.month.toString().padLeft(2, '0')}-'
            '${dt.day.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:'
            '${dt.minute.toString().padLeft(2, '0')}:00';
      }

      // Send as form data — more compatible with shared hosting than JSON body
      final formBody = <String, String>{
        'game_name':     name,
        'game_mode':     _mode,
        'game_duration': _duration.toString(),
        'teams':         jsonEncode(teams),
        'question_ids':  jsonEncode(qIds.map(int.parse).toList()),
      };
      if (schedStr != null) formBody['scheduled_at'] = schedStr;

      final res = await http.post(
        Uri.parse('${widget.baseUrl}create_game.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: formBody,
      );
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if (data['status'] == 'success') {
        Navigator.pop(context);
        widget.onCreated();
      } else {
        _snack('Error: ${data['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _snack('Error: $e');
    }
    if (mounted) setState(() => _creating = false);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.bgSurface,
    ));
  }

  Future<void> _pickDateTime() async {
    final now  = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.purple,
            surface: AppColors.bgCard,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.purple,
            surface: AppColors.bgCard,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledAt = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String _formatDt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
      '  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  // ── Player row: name field + school dropdown + optional remove ─
  Widget _buildPlayerRow(int ti, int pi) {
    final player    = _teams[ti].players[pi];
    final canRemove = _teams[ti].players.length > 1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: Text('${pi + 1}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted)),
          ),
        ),
        const SizedBox(width: 6),
        // Name field
        Expanded(
          flex: 5,
          child: TextField(
            controller: player.nameCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Player ${pi + 1} name',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 6),
        // School dropdown
        Expanded(
          flex: 4,
          child: _sheetSchools.isEmpty
              ? Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: const Center(
                    child: Text('No schools',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textMuted)),
                  ),
                )
              : DropdownButtonFormField<String>(
                  value: player.schoolId,
                  dropdownColor: AppColors.bgCard,
                  isExpanded: true,
                  isDense: true,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: AppColors.gold, size: 16),
                  decoration: const InputDecoration(
                    hintText: 'School',
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 10, vertical: 9),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('— None —',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ),
                    ..._sheetSchools.map<DropdownMenuItem<String>>((s) =>
                        DropdownMenuItem<String>(
                          value: s['school_id'].toString(),
                          child: Text(
                            s['school_name'].toString(),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        )),
                  ],
                  onChanged: (v) => setState(() => player.schoolId = v),
                ),
        ),
        if (canRemove) ...[
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() =>
                _teams[ti].players.removeAt(pi).dispose()),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.wrong.withOpacity(0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.close,
                  size: 12, color: AppColors.wrong),
            ),
          ),
        ],
      ],
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 0.4));

  Widget _modeBtn(String mode, String label) {
    final sel = _mode == mode;
    return GestureDetector(
      onTap: () => _switchMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: sel
              ? AppColors.purple.withOpacity(0.2)
              : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel
                ? AppColors.purple.withOpacity(0.6)
                : Colors.white.withOpacity(0.08),
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                  color: sel ? AppColors.purple : AppColors.textMuted)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qCount = _questionIds.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // header row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.sports_esports_rounded,
                      color: AppColors.purple, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Create New Game',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.border),

            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  // ── Game Name
                  _label('Game Name'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'e.g. Quiz Championship 2025',
                      prefixIcon: Icon(Icons.sports_esports_rounded,
                          color: AppColors.purple, size: 20),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Mode
                  _label('Game Mode'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _modeBtn('multi', '👥 Multiplayer')),
                    const SizedBox(width: 10),
                    Expanded(child: _modeBtn('single', '👤 Single Player')),
                  ]),
                  const SizedBox(height: 20),

                  // ── Duration
                  _label('Time per Question'),
                  const SizedBox(height: 8),
                  Row(
                    children: [15, 30, 45, 60].map((s) {
                      final sel = _duration == s;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _duration = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.purple.withOpacity(0.2)
                                  : AppColors.bgSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: sel
                                    ? AppColors.purple.withOpacity(0.5)
                                    : Colors.white.withOpacity(0.08),
                              ),
                            ),
                            child: Center(
                              child: Text('${s}s',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: sel
                                          ? AppColors.purple
                                          : AppColors.textMuted)),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── Schedule
                  _label('Schedule (optional)'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDateTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 15),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _scheduledAt != null
                              ? AppColors.purple.withOpacity(0.5)
                              : Colors.white.withOpacity(0.08),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 18,
                              color: _scheduledAt != null
                                  ? AppColors.purple
                                  : AppColors.textMuted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _scheduledAt == null
                                  ? 'Tap to set date & time'
                                  : _formatDt(_scheduledAt!),
                              style: TextStyle(
                                  color: _scheduledAt != null
                                      ? Colors.white
                                      : AppColors.textMuted,
                                  fontSize: 14),
                            ),
                          ),
                          if (_scheduledAt != null)
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _scheduledAt = null),
                              child: const Icon(Icons.close,
                                  size: 16, color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Category / Questions
                  Row(children: [
                    _label('Questions Category'),
                    const Spacer(),
                    if (_loadingData)
                      const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.purple),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  _loadingData
                      ? Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.bgSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          child: const Center(
                            child: Text('Loading categories…',
                                style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13)),
                          ),
                        )
                      : _sheetCategories.isEmpty
                          ? GestureDetector(
                              onTap: _loadData,
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.bgSurface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: AppColors.wrong.withOpacity(0.4)),
                                ),
                                child: const Center(
                                  child: Text('Tap to retry loading categories',
                                      style: TextStyle(
                                          color: AppColors.wrong,
                                          fontSize: 13)),
                                ),
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: _catId,
                              dropdownColor: AppColors.bgCard,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15),
                              icon: const Icon(Icons.keyboard_arrow_down,
                                  color: AppColors.purple),
                              decoration: const InputDecoration(
                                hintText: 'Select category',
                                prefixIcon: Icon(Icons.category_outlined,
                                    color: AppColors.purple, size: 20),
                              ),
                              items: _sheetCategories
                                  .map<DropdownMenuItem<String>>((c) =>
                                      DropdownMenuItem<String>(
                                        value: c['category_id'].toString(),
                                        child: Text(c['category_name']),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _catId = v),
                            ),
                  if (_catId != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '$qCount question${qCount == 1 ? '' : 's'} will be included',
                      style: TextStyle(
                          fontSize: 12,
                          color: qCount > 0
                              ? AppColors.correct
                              : AppColors.wrong,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ── Single player: team name + school ─────────────
                  if (_mode == 'single') ...[
                    _label('Team Name'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _teams[0].nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Team Alpha',
                        prefixIcon: Icon(Icons.groups_rounded,
                            color: AppColors.purple, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _label('School (optional)'),
                    const SizedBox(height: 8),
                    _loadingData
                        ? const SizedBox.shrink()
                        : DropdownButtonFormField<String>(
                            value: _teams[0].schoolId,
                            dropdownColor: AppColors.bgCard,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                            icon: const Icon(Icons.keyboard_arrow_down,
                                color: AppColors.gold),
                            decoration: const InputDecoration(
                              hintText: 'Select school',
                              prefixIcon: Icon(Icons.school_outlined,
                                  color: AppColors.gold, size: 20),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('— None —',
                                    style: TextStyle(
                                        color: AppColors.textMuted)),
                              ),
                              ..._sheetSchools.map<DropdownMenuItem<String>>(
                                (s) => DropdownMenuItem<String>(
                                  value: s['school_id'].toString(),
                                  child: Text(s['school_name'].toString()),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _teams[0].schoolId = v),
                          ),
                  ],

                  // ── Multiplayer: team cards with nested players ────
                  if (_mode == 'multi') ...[
                    Row(children: [
                      _label('Teams & Players'),
                      const Spacer(),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _teams.add(_TeamEntry())),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.purple.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add,
                                  size: 14, color: AppColors.purple),
                              SizedBox(width: 4),
                              Text('Add Team',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.purple,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    for (int ti = 0; ti < _teams.length; ti++) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.purple.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Team header
                            Container(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 10, 8, 10),
                              decoration: BoxDecoration(
                                color: AppColors.purple.withOpacity(0.12),
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16)),
                              ),
                              child: Column(
                                children: [
                                  Row(children: [
                                    Container(
                                      width: 26, height: 26,
                                      decoration: BoxDecoration(
                                        color: AppColors.purple.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: Center(
                                        child: Text('${ti + 1}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _teams[ti].nameCtrl,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700),
                                        decoration: InputDecoration(
                                          hintText: 'Team ${ti + 1} name',
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 10),
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    if (_teams.length > 2) ...[
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () => setState(() =>
                                            _teams.removeAt(ti).dispose()),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.wrong
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.close,
                                              size: 14, color: AppColors.wrong),
                                        ),
                                      ),
                                    ],
                                  ]),
                                  // School dropdown for this team
                                  if (!_loadingData && _sheetSchools.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: _teams[ti].schoolId,
                                      dropdownColor: AppColors.bgCard,
                                      isExpanded: true,
                                      isDense: true,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                      icon: const Icon(
                                          Icons.keyboard_arrow_down,
                                          color: AppColors.gold, size: 16),
                                      decoration: const InputDecoration(
                                        hintText: 'Team school (optional)',
                                        prefixIcon: Icon(
                                            Icons.school_outlined,
                                            color: AppColors.gold, size: 16),
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 8),
                                        isDense: true,
                                      ),
                                      items: [
                                        const DropdownMenuItem<String>(
                                          value: null,
                                          child: Text('— None —',
                                              style: TextStyle(
                                                  color: AppColors.textMuted,
                                                  fontSize: 12)),
                                        ),
                                        ..._sheetSchools.map<DropdownMenuItem<String>>(
                                          (s) => DropdownMenuItem<String>(
                                            value: s['school_id'].toString(),
                                            child: Text(
                                              s['school_name'].toString(),
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (v) => setState(
                                          () => _teams[ti].schoolId = v),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Players list
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                children: [
                                  for (int pi = 0;
                                      pi < _teams[ti].players.length;
                                      pi++) ...[
                                    _buildPlayerRow(ti, pi),
                                    const SizedBox(height: 8),
                                  ],
                                  GestureDetector(
                                    onTap: () => setState(() =>
                                        _teams[ti].players.add(_PlayerEntry())),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.04),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.white
                                                .withOpacity(0.1)),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.person_add_outlined,
                                              size: 14,
                                              color: AppColors.textMuted),
                                          SizedBox(width: 6),
                                          Text('Add Player',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textMuted)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 24),

                  // ── Create button
                  _creating
                      ? Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [AppColors.purple, AppColors.pink]),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            ),
                          ),
                        )
                      : GradientButton(
                          label: 'CREATE GAME',
                          icon: Icons.sports_esports_rounded,
                          onTap: _create,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable input dialog ─────────────────────────────────────
class _InputDialog extends StatelessWidget {
  final String title;
  final String hint;
  final String icon;
  final TextEditingController ctrl;
  final Future<void> Function() onConfirm;

  const _InputDialog({
    required this.title,
    required this.hint,
    required this.icon,
    required this.ctrl,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18)),
        ],
      ),
      content: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textMuted)),
        ),
        TextButton(
          onPressed: () async {
            await onConfirm();
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('ADD',
              style: TextStyle(
                  color: AppColors.purple, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}
