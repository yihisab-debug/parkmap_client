import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/review.dart';
import '../services/firestore_service.dart';

class MyReviewsPage extends StatelessWidget {
  const MyReviewsPage({super.key});

  String _statusLabel(Review r) {
    if (r.type == 'review') return 'Отзыв';
    switch (r.status) {
      case 'pending':
        return 'Жалоба: на рассмотрении';
      case 'accepted':
        return r.refunded ? 'Жалоба принята, деньги возвращены' : 'Жалоба принята';
      case 'rejected':
        return 'Жалоба отклонена';
      default:
        return r.status;
    }
  }

  Color _statusColor(Review r) {
    if (r.type == 'review') return Colors.amber[800]!;
    switch (r.status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.black54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Мои отзывы и жалобы')),
      body: StreamBuilder<List<Review>>(
        stream: firestoreService.watchMyReviews(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final reviews = snapshot.data ?? [];
          if (reviews.isEmpty) {
            return const Center(child: Text('Вы пока не оставляли отзывов или жалоб'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final r = reviews[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(
                    r.type == 'review' ? Icons.star : Icons.report,
                    color: r.type == 'review' ? Colors.amber : Colors.red,
                  ),
                  title: Text(r.comment),
                  subtitle: Text(
                      '${DateFormat('d MMM yyyy, HH:mm', 'ru').format(r.createdAt)}\n${_statusLabel(r)}'),
                  isThreeLine: true,
                  trailing: r.rating != null ? Text('${r.rating} ★') : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
