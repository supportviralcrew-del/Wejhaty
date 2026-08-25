import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/widgets/glass_card.dart';
import 'package:tripproject/services/app_data_provider.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = AppDataProvider.instance;
    final isAr = provider.language == 'ar';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          isAr ? 'ألعاب' : 'Games',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.0,
          children: [
            _GameCard(
              title: isAr ? 'اختبار المعرفة' : 'Quiz',
              subtitle: isAr ? 'اختبر معلوماتك' : 'Test your knowledge',
              icon: Icons.quiz_rounded,
              color: AppColors.sunsetOrange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const QuizGame()),
                );
              },
            ),
            _GameCard(
              title: isAr ? 'تخمين الرقم' : 'Number Guess',
              subtitle: isAr ? 'خمن الرقم الصحيح' : 'Guess the number',
              icon: Icons.casino_rounded,
              color: AppColors.sunsetBlue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NumberGuessGame()),
                );
              },
            ),
            _GameCard(
              title: isAr ? 'الذاكرة' : 'Memory',
              subtitle: isAr ? 'اختبر ذاكرتك' : 'Test your memory',
              icon: Icons.psychology_rounded,
              color: AppColors.prayerCard,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MemoryGame()),
                );
              },
            ),
            _GameCard(
              title: isAr ? 'حساب سريع' : 'Quick Math',
              subtitle: isAr ? 'تحدي الرياضيات' : 'Math challenge',
              icon: Icons.calculate_rounded,
              color: AppColors.routeCard,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const QuickMathGame()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.3),
                  color.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quiz Game
// ---------------------------------------------------------------------------

class QuizGame extends StatefulWidget {
  const QuizGame({super.key});

  @override
  State<QuizGame> createState() => _QuizGameState();
}

class _QuizGameState extends State<QuizGame> {
  // A larger bank than any single round needs, so each session can draw a
  // fresh, non-repeating subset instead of always showing the same five.
  static final List<Map<String, dynamic>> _questionBank = [
    {
      'question': 'What is the capital of UAE?',
      'options': ['Dubai', 'Abu Dhabi', 'Sharjah', 'Ajman'],
      'answer': 1,
    },
    {
      'question': 'What is the largest desert in the world?',
      'options': ['Sahara', 'Arabian', 'Gobi', 'Antarctic'],
      'answer': 3,
    },
    {
      'question': 'How many continents are there?',
      'options': ['5', '6', '7', '8'],
      'answer': 2,
    },
    {
      'question': 'What is the longest river in the world?',
      'options': ['Amazon', 'Nile', 'Yangtze', 'Mississippi'],
      'answer': 1,
    },
    {
      'question': 'What planet is known as the Red Planet?',
      'options': ['Venus', 'Mars', 'Jupiter', 'Saturn'],
      'answer': 1,
    },
    {
      'question': 'Which ocean is the largest?',
      'options': ['Atlantic', 'Indian', 'Arctic', 'Pacific'],
      'answer': 3,
    },
    {
      'question': 'What is the tallest mountain in the world?',
      'options': ['K2', 'Everest', 'Kilimanjaro', 'Denali'],
      'answer': 1,
    },
    {
      'question': 'How many days are there in a leap year?',
      'options': ['364', '365', '366', '367'],
      'answer': 2,
    },
    {
      'question': 'What is the smallest country in the world?',
      'options': ['Monaco', 'San Marino', 'Vatican City', 'Malta'],
      'answer': 2,
    },
    {
      'question': 'Which gas do plants absorb from the air?',
      'options': ['Oxygen', 'Nitrogen', 'Carbon Dioxide', 'Hydrogen'],
      'answer': 2,
    },
    {
      'question': 'How many strings does a standard guitar have?',
      'options': ['4', '5', '6', '7'],
      'answer': 2,
    },
    {
      'question': 'What is the currency of Japan?',
      'options': ['Yuan', 'Won', 'Yen', 'Ringgit'],
      'answer': 2,
    },
  ];

  static const int _questionsPerRound = 6;

  final Random _random = Random();
  late List<Map<String, dynamic>> _questions;
  int _currentQuestion = 0;
  int _score = 0;
  bool _showResult = false;
  int? _selectedIndex;
  bool _answerLocked = false;

  @override
  void initState() {
    super.initState();
    _startNewRound();
  }

  void _startNewRound() {
    final shuffledBank = List<Map<String, dynamic>>.from(_questionBank)..shuffle(_random);
    final picked = shuffledBank.take(_questionsPerRound).toList();

    // Shuffle each question's answer options too, so the correct answer
    // isn't always sitting in the same slot round after round.
    _questions = picked.map((q) {
      final options = List<String>.from(q['options'] as List);
      final correctText = options[q['answer'] as int];
      options.shuffle(_random);
      return {
        'question': q['question'],
        'options': options,
        'answer': options.indexOf(correctText),
      };
    }).toList();

    _currentQuestion = 0;
    _score = 0;
    _showResult = false;
    _selectedIndex = null;
    _answerLocked = false;
  }

  void _selectAnswer(int index) {
    if (_answerLocked) return;
    final correctIndex = _questions[_currentQuestion]['answer'] as int;

    setState(() {
      _selectedIndex = index;
      _answerLocked = true;
      if (index == correctIndex) _score++;
    });

    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      if (_currentQuestion < _questions.length - 1) {
        setState(() {
          _currentQuestion++;
          _selectedIndex = null;
          _answerLocked = false;
        });
      } else {
        setState(() => _showResult = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAr = AppDataProvider.instance.language == 'ar';
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(isAr ? 'اختبار المعرفة' : 'Quiz',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _showResult ? _buildResult(isAr, colorScheme) : _buildQuestion(isAr, colorScheme),
    );
  }

  Widget _buildResult(bool isAr, ColorScheme colorScheme) {
    final percentage = _score / _questions.length;
    final resultColor = percentage >= 0.6 ? Colors.green : AppColors.sunsetOrange;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: resultColor.withValues(alpha: 0.12),
            ),
            child: Text(
              '$_score/${_questions.length}',
              style: GoogleFonts.poppins(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: resultColor,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isAr ? 'النتيجة النهائية' : 'Final Score',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => setState(_startNewRound),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(isAr ? 'جولة جديدة' : 'New Round',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(bool isAr, ColorScheme colorScheme) {
    final question = _questions[_currentQuestion];
    final options = question['options'] as List<String>;
    final correctIndex = question['answer'] as int;
    final progress = (_currentQuestion) / _questions.length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colorScheme.onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(AppColors.sunsetOrange),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isAr
                ? 'السؤال ${_currentQuestion + 1}/${_questions.length}'
                : 'Question ${_currentQuestion + 1}/${_questions.length}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            question['question'] as String,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 32),
          ...options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;

            Color? bg;
            IconData? trailingIcon;
            Color? iconColor;

            if (_answerLocked) {
              if (index == correctIndex) {
                bg = Colors.green.withValues(alpha: 0.15);
                trailingIcon = Icons.check_circle_rounded;
                iconColor = Colors.green;
              } else if (index == _selectedIndex) {
                bg = colorScheme.error.withValues(alpha: 0.12);
                trailingIcon = Icons.cancel_rounded;
                iconColor = colorScheme.error;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: GlassCard(
                  onTap: () => _selectAnswer(index),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (trailingIcon != null)
                        Icon(trailingIcon, color: iconColor, size: 22),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Number Guess Game
// ---------------------------------------------------------------------------

class NumberGuessGame extends StatefulWidget {
  const NumberGuessGame({super.key});

  @override
  State<NumberGuessGame> createState() => _NumberGuessGameState();
}

class _NumberGuessGameState extends State<NumberGuessGame> {
  final Random _random = Random();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late int _targetNumber;
  int _attempts = 0;
  bool _won = false;
  final List<_GuessRecord> _history = [];

  @override
  void initState() {
    super.initState();
    _targetNumber = _random.nextInt(100) + 1;
    _resetGame();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _resetGame() {
    // A fresh, uniformly random target every round — no correlation with the
    // previous one, and no reliance on the clock.
    int next;
    do {
      next = _random.nextInt(100) + 1;
    } while (next == _targetNumber);
    setState(() {
      _targetNumber = next;
      _attempts = 0;
      _won = false;
      _history.clear();
      _controller.clear();
    });
    _focusNode.requestFocus();
  }

  void _checkGuess() {
    final guess = int.tryParse(_controller.text);
    if (guess == null || guess < 1 || guess > 100 || _won) return;

    setState(() {
      _attempts++;
      if (guess == _targetNumber) {
        _won = true;
        _history.insert(0, _GuessRecord(guess, _GuessResult.correct));
      } else if (guess < _targetNumber) {
        _history.insert(0, _GuessRecord(guess, _GuessResult.low));
      } else {
        _history.insert(0, _GuessRecord(guess, _GuessResult.high));
      }
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAr = AppDataProvider.instance.language == 'ar';
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(isAr ? 'تخمين الرقم' : 'Number Guess',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _resetGame),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              isAr ? 'رقم بين 1 و 100' : 'Pick a number between 1 and 100',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isAr ? 'المحاولات: $_attempts' : 'Attempts: $_attempts',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            if (_won)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.celebration_rounded, color: Colors.green),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        isAr
                            ? 'صحيح! وجدته في $_attempts محاولة'
                            : 'Correct! Found it in $_attempts attempts',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.poppins(fontSize: 15),
                      onSubmitted: (_) => _checkGuess(),
                      decoration: InputDecoration(
                        labelText: isAr ? 'تخمينك' : 'Your guess',
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _checkGuess,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isAr ? 'تحقق' : 'Check',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            if (_won)
              TextButton.icon(
                onPressed: _resetGame,
                icon: const Icon(Icons.replay_rounded),
                label: Text(isAr ? 'لعبة جديدة' : 'New Game',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 8),
            if (_history.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final record = _history[index];
                    final (icon, color, label) = switch (record.result) {
                      _GuessResult.correct => (
                      Icons.check_circle_rounded,
                      Colors.green,
                      isAr ? 'صحيح' : 'Correct'
                      ),
                      _GuessResult.low => (
                      Icons.arrow_upward_rounded,
                      AppColors.sunsetBlue,
                      isAr ? 'أعلى' : 'Higher'
                      ),
                      _GuessResult.high => (
                      Icons.arrow_downward_rounded,
                      AppColors.sunsetOrange,
                      isAr ? 'أقل' : 'Lower'
                      ),
                    };
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Text(
                              '${record.guess}',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              label,
                              style: GoogleFonts.poppins(fontSize: 13, color: color),
                            ),
                            const SizedBox(width: 6),
                            Icon(icon, size: 16, color: color),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _GuessResult { correct, low, high }

class _GuessRecord {
  final int guess;
  final _GuessResult result;
  _GuessRecord(this.guess, this.result);
}

// ---------------------------------------------------------------------------
// Memory Game
// ---------------------------------------------------------------------------

class MemoryGame extends StatefulWidget {
  const MemoryGame({super.key});

  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<MemoryGame> {
  final Random _random = Random();
  final List<String> _emojis = ['🚗', '✈️', '🏨', '🗺️', '📷', '🎒', '🍔', '☕'];
  late List<Map<String, dynamic>> _cards;
  int _flippedCount = 0;
  int _matchedCount = 0;
  int _moves = 0;
  List<int> _flippedIndices = [];
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  void _initGame() {
    final shuffled = [..._emojis, ..._emojis]..shuffle(_random);
    setState(() {
      _cards = shuffled.map((emoji) => {'emoji': emoji, 'flipped': false, 'matched': false}).toList();
      _flippedCount = 0;
      _matchedCount = 0;
      _moves = 0;
      _flippedIndices = [];
      _isChecking = false;
    });
  }

  void _flipCard(int index) {
    if (_isChecking || _cards[index]['flipped'] || _cards[index]['matched']) return;

    setState(() {
      _cards[index]['flipped'] = true;
      _flippedIndices.add(index);
      _flippedCount++;
    });

    if (_flippedCount == 2) {
      _isChecking = true;
      _moves++;
      _checkMatch();
    }
  }

  void _checkMatch() {
    final firstIndex = _flippedIndices[0];
    final secondIndex = _flippedIndices[1];

    if (_cards[firstIndex]['emoji'] == _cards[secondIndex]['emoji']) {
      setState(() {
        _cards[firstIndex]['matched'] = true;
        _cards[secondIndex]['matched'] = true;
        _matchedCount += 2;
        _flippedCount = 0;
        _flippedIndices = [];
        _isChecking = false;
      });

      if (_matchedCount == _cards.length) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            final isAr = AppDataProvider.instance.language == 'ar';
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text(isAr ? 'لقد فزت!' : 'You Won!',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                content: Text(
                  isAr ? 'أنجزته في $_moves محاولة' : 'Solved in $_moves moves',
                  style: GoogleFonts.poppins(),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _initGame();
                    },
                    child: Text(isAr ? 'العب مجددًا' : 'Play Again',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          }
        });
      }
    } else {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _cards[firstIndex]['flipped'] = false;
            _cards[secondIndex]['flipped'] = false;
            _flippedCount = 0;
            _flippedIndices = [];
            _isChecking = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = AppDataProvider.instance.language == 'ar';
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(isAr ? 'الذاكرة' : 'Memory',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _initGame),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              isAr ? 'المحاولات: $_moves' : 'Moves: $_moves',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _cards.length,
                itemBuilder: (context, index) {
                  final card = _cards[index];
                  final revealed = card['flipped'] || card['matched'];
                  return GlassCard(
                    onTap: () => _flipCard(index),
                    padding: const EdgeInsets.all(8),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          revealed ? card['emoji'] : '❓',
                          key: ValueKey(revealed),
                          style: TextStyle(
                            fontSize: 30,
                            color: card['matched']
                                ? Colors.green
                                : colorScheme.onSurface.withValues(alpha: revealed ? 1 : 0.35),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick Math Game
// ---------------------------------------------------------------------------

class QuickMathGame extends StatefulWidget {
  const QuickMathGame({super.key});

  @override
  State<QuickMathGame> createState() => _QuickMathGameState();
}

class _QuickMathGameState extends State<QuickMathGame> {
  static const int _totalQuestions = 10;

  final Random _random = Random();
  int _num1 = 0;
  int _num2 = 0;
  String _operation = '+';
  int _answer = 0;
  int _score = 0;
  int _questionCount = 0;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _message = '';
  bool _lastCorrect = false;

  @override
  void initState() {
    super.initState();
    _generateQuestion();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _generateQuestion() {
    // Difficulty ramps gently with the score, and every value is drawn
    // independently so the same pair never gets generated twice in a row.
    final level = _score ~/ 3;
    final maxOperand = min(12 + level * 4, 40);

    const operations = ['+', '-', '×', '÷'];
    String operation;
    int num1;
    int num2;
    int answer;

    do {
      operation = operations[_random.nextInt(operations.length)];
      switch (operation) {
        case '+':
          num1 = _random.nextInt(maxOperand) + 1;
          num2 = _random.nextInt(maxOperand) + 1;
          answer = num1 + num2;
          break;
        case '-':
          num1 = _random.nextInt(maxOperand) + 1;
          num2 = _random.nextInt(maxOperand) + 1;
          if (num2 > num1) {
            final temp = num1;
            num1 = num2;
            num2 = temp;
          }
          answer = num1 - num2;
          break;
        case '×':
          num1 = _random.nextInt(12) + 1;
          num2 = _random.nextInt(12) + 1;
          answer = num1 * num2;
          break;
        case '÷':
          num2 = _random.nextInt(11) + 2; // divisor, avoid 0/1
          final quotient = _random.nextInt(11) + 1;
          num1 = num2 * quotient;
          answer = quotient;
          break;
        default:
          num1 = 0;
          num2 = 0;
          answer = 0;
      }
    } while (num1 == _num1 && num2 == _num2 && operation == _operation);

    setState(() {
      _operation = operation;
      _num1 = num1;
      _num2 = num2;
      _answer = answer;
      _controller.clear();
      _message = '';
    });
    _focusNode.requestFocus();
  }

  void _checkAnswer() {
    final userAnswer = int.tryParse(_controller.text);
    if (userAnswer == null) return;
    final isAr = AppDataProvider.instance.language == 'ar';

    setState(() {
      _questionCount++;
      _lastCorrect = userAnswer == _answer;
      if (_lastCorrect) {
        _score++;
        _message = isAr ? 'صحيح!' : 'Correct!';
      } else {
        _message = isAr ? 'خطأ! الإجابة كانت $_answer' : 'Wrong! Answer was $_answer';
      }
    });

    if (_questionCount >= _totalQuestions) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                isAr ? 'النتيجة: $_score/$_totalQuestions' : 'Score: $_score/$_totalQuestions',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              content: Text(isAr ? 'انتهت اللعبة!' : 'Game Over!', style: GoogleFonts.poppins()),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _score = 0;
                      _questionCount = 0;
                    });
                    _generateQuestion();
                  },
                  child: Text(isAr ? 'العب مجددًا' : 'Play Again',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        }
      });
    } else {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) _generateQuestion();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = AppDataProvider.instance.language == 'ar';
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(isAr ? 'حساب سريع' : 'Quick Math',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _questionCount / _totalQuestions,
                minHeight: 6,
                backgroundColor: colorScheme.onSurface.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(AppColors.routeCard),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$_questionCount/$_totalQuestions  ·  ${isAr ? "النقاط" : "Score"}: $_score',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              '$_num1 $_operation $_num2 = ?',
              style: GoogleFonts.poppins(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: AppColors.sunsetOrange,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
              onSubmitted: (_) => _checkAnswer(),
              decoration: InputDecoration(
                labelText: isAr ? 'الإجابة' : 'Answer',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkAnswer,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isAr ? 'تحقق' : 'Check',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 16),
            AnimatedOpacity(
              opacity: _message.isNotEmpty ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                _message,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _lastCorrect ? Colors.green : colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}