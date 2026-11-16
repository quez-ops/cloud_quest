import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/challenge_service.dart';
import '../services/coach_service.dart';
import '../services/reward_service.dart';

class ChallengeScreen extends StatefulWidget {
  final User user;
  const ChallengeScreen({super.key, required this.user});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  final _challengeService = ChallengeService();
  final _rewardService = RewardService();
  final _coachService = CoachService();
  final _authService = AuthService();
  final _questionController = TextEditingController();

  bool _loadingQuest = true;
  bool _completing = false;
  bool _askingCoach = false;

  String _title = "Today's Challenge";
  String _prompt = 'Loading challenge...';
  bool _completed = false;
  int _points = 0;
  String? _badgeId;
  String _statusBanner = '';
  String _coachReply = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loadingQuest = true);
    try {
      final data = await _challengeService.loadToday();
      final challenge = data['challenge'] as Map<String, dynamic>?;
      final progress = data['progress'] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _title = challenge?['title'] ?? 'No challenge seeded yet';
        _prompt = challenge?['prompt'] ??
            'Seed challenges/today in Firestore Emulator (title, prompt).';
        _completed = progress?['completed'] == true;
        _points = (progress?['points'] as num?)?.toInt() ?? 0;
        _badgeId = progress?['badgeId'] as String?;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusBanner = 'Error loading quest: $e');
    } finally {
      if (mounted) setState(() => _loadingQuest = false);
    }
  }

  // Explicit learner action triggers server-side reward transaction
  Future<void> _handleComplete() async {
    setState(() {
      _completing = true;
      _statusBanner = '';
    });
    try {
      final res = await _rewardService.completeChallenge();
      if (!mounted) return;
      final already = res['alreadyCompleted'] == true;
      setState(() {
        _completed = true;
        _points = (res['points'] as num).toInt();
        _badgeId = res['badgeId'] as String?;
        _statusBanner = already
            ? 'Already completed! Reward remains $_points pts ($_badgeId).'
            : 'Quest completed! Earned $_points pts and "$_badgeId" badge.';
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _statusBanner = 'Reward error: ${e.message}');
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Future<void> _handleGetHint() async {
    setState(() => _askingCoach = true);
    try {
      final reply = await _coachService.getQuestHint(_questionController.text);
      if (!mounted) return;
      setState(() => _coachReply = reply);
    } on FirebaseFunctionsException catch (error) {
      debugPrint('Quest Coach request failed: ${error.code}');
      if (!mounted) return;
      // Graceful fallback when tool or model fails
      setState(() => _coachReply = 'The coach is unavailable. Try again.');
    } finally {
      if (mounted) setState(() => _askingCoach = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Quest'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => _authService.logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: _loadingQuest
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Signed in as: ${widget.user.email ?? widget.user.uid}'),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Points: $_points',
                              style: Theme.of(context).textTheme.titleMedium),
                          Text('Badge: ${_badgeId ?? "None"}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(_title,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(_prompt),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _completing ? null : _handleComplete,
                    child: Text(_completing
                        ? 'Submitting...'
                        : (_completed
                            ? 'Complete challenge (Retry test)'
                            : 'Complete challenge')),
                  ),
                  if (_statusBanner.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_statusBanner,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                  const Divider(height: 32),
                  Text('AI Quest Coach',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _questionController,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      labelText: 'Ask the Quest Coach for a hint',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _askingCoach ? null : _handleGetHint,
                    child: Text(_askingCoach ? 'Thinking...' : 'Get hint'),
                  ),
                  if (_coachReply.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_coachReply),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
