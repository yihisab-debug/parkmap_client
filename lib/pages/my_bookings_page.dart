import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/booking.dart';
import '../services/firestore_service.dart';
import 'leave_review_page.dart';

class MyBookingsPage extends StatelessWidget {
  const MyBookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Мои бронирования')),
      body: StreamBuilder<List<Booking>>(
        stream: firestoreService.watchMyBookings(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Не удалось загрузить бронирования'));
          }
          final bookings = snapshot.data ?? [];
          if (bookings.isEmpty) {
            return const Center(child: Text('У вас пока нет бронирований'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final b = bookings[index];
              return _BookingCard(booking: b, firestoreService: firestoreService);
            },
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final FirestoreService firestoreService;
  const _BookingCard({required this.booking, required this.firestoreService});

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Активно';
      case 'cancelled':
        return 'Отменено';
      case 'completed':
        return 'Завершено';
      case 'refund_pending':
        return 'Жалоба на рассмотрении';
      case 'refunded':
        return 'Деньги возвращены';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      case 'refund_pending':
        return Colors.orange;
      case 'refunded':
        return Colors.blue;
      default:
        return Colors.black54;
    }
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Отменить бронирование?'),
        content: const Text('Вы действительно хотите отменить бронирование?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Нет')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Да, отменить')),
        ],
      ),
    );
    if (confirmed == true) {
      await firestoreService.cancelBooking(booking.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCancel = booking.status == 'active' &&
        booking.startDateTime.isAfter(DateTime.now());
    final canComplain = booking.status == 'active' || booking.status == 'completed';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(booking.parkingName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(DateFormat('d MMMM yyyy', 'ru').format(booking.date)),
            Text('${booking.startTime} — ${booking.endTime}'),
            Text('Место №${booking.spotNumber}'),
            const SizedBox(height: 6),
            Text('${booking.totalPrice} ₸',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Статус: ${_statusLabel(booking.status)}',
                style: TextStyle(
                    color: _statusColor(booking.status), fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                if (canCancel)
                  OutlinedButton(
                    onPressed: () => _confirmCancel(context),
                    child: const Text('Отменить'),
                  ),
                if (canComplain)
                  OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LeaveReviewPage(booking: booking),
                      ),
                    ),
                    child: const Text('Отзыв / жалоба'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
