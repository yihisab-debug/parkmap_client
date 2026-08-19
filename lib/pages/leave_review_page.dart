import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/booking.dart';
import '../models/review.dart';
import '../services/firestore_service.dart';

class LeaveReviewPage extends StatefulWidget {
  final Booking booking;
  const LeaveReviewPage({super.key, required this.booking});

  @override
  State<LeaveReviewPage> createState() => _LeaveReviewPageState();
}

class _LeaveReviewPageState extends State<LeaveReviewPage> {
  final _firestoreService = FirestoreService();
  final _commentController = TextEditingController();
  String _type = 'review';
  int _rating = 5;
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_commentController.text.trim().isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);
    try {
      await _firestoreService.addReview(Review(
        id: '',
        userId: user.uid,
        userName: user.displayName ?? user.email ?? 'Клиент',
        bookingId: widget.booking.id,
        parkingId: widget.booking.parkingId,
        type: _type,
        rating: _type == 'review' ? _rating : null,
        comment: _commentController.text.trim(),
        status: _type == 'complaint' ? 'pending' : 'accepted',
        createdAt: DateTime.now(),
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_type == 'review'
                ? 'Спасибо за отзыв!'
                : 'Жалоба отправлена администратору'),
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Отзыв / жалоба')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.booking.parkingName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'review', label: Text('Отзыв'), icon: Icon(Icons.star)),
                ButtonSegment(
                    value: 'complaint', label: Text('Жалоба'), icon: Icon(Icons.report)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            if (_type == 'review') ...[
              const Text('Оценка'),
              Row(
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return IconButton(
                    icon: Icon(
                      star <= _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () => setState(() => _rating = star),
                  );
                }),
              ),
            ] else
              const Text(
                'Жалоба будет рассмотрена администратором. Если жалоба будет принята, '
                'деньги за это бронирование вернутся на ваш баланс.',
                style: TextStyle(color: Colors.grey),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: _type == 'review'
                    ? 'Расскажите, как всё прошло...'
                    : 'Опишите, что произошло...',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_type == 'review' ? 'Отправить отзыв' : 'Отправить жалобу'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
