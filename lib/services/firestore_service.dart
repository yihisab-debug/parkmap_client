import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/parking_spot.dart';
import '../models/booking.dart';
import '../models/review.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<ParkingLot>> watchParkingLots() {
    return _db.collection('parkingLots').snapshots().map((snap) => snap.docs
        .map((d) => ParkingLot.fromMap(d.id, d.data()))
        .toList());
  }

  Future<ParkingLot?> getParkingLot(String id) async {
    final doc = await _db.collection('parkingLots').doc(id).get();
    if (!doc.exists) return null;
    return ParkingLot.fromMap(doc.id, doc.data()!);
  }

  Future<int> getCurrentFreeSpots(ParkingLot lot) async {
    final now = DateTime.now();
    final bookings = await getBookingsForLotAndDate(lot.id, now);
    final occupiedNow = bookings
        .where((b) => now.isAfter(b.startDateTime) && now.isBefore(b.endDateTime))
        .map((b) => b.spotNumber)
        .toSet();
    return lot.totalSpots - occupiedNow.length;
  }

  Stream<List<Booking>> watchMyBookings(String userId) {
    return _db
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final bookings =
          snap.docs.map((d) => Booking.fromMap(d.id, d.data())).toList();
      bookings.sort((a, b) => b.date.compareTo(a.date));
      return bookings;
    });
  }

  Future<List<Booking>> getBookingsForLotAndDate(
      String parkingId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final snap = await _db
        .collection('bookings')
        .where('parkingId', isEqualTo: parkingId)
        .where('status', isEqualTo: 'active')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();
    return snap.docs.map((d) => Booking.fromMap(d.id, d.data())).toList();
  }

  bool _timeRangesOverlap(String startA, String endA, String startB, String endB) {
    int toMinutes(String t) {
      final p = t.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }
    final sA = toMinutes(startA), eA = toMinutes(endA);
    final sB = toMinutes(startB), eB = toMinutes(endB);
    return sA < eB && sB < eA;
  }

  Future<Set<int>> getOccupiedSpotNumbers({
    required String parkingId,
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    final bookings = await getBookingsForLotAndDate(parkingId, date);
    final occupied = <int>{};
    for (final b in bookings) {
      if (_timeRangesOverlap(startTime, endTime, b.startTime, b.endTime)) {
        occupied.add(b.spotNumber);
      }
    }
    return occupied;
  }

  Future<String> createBookingAndCharge({
    required String userId,
    required String userName,
    required String parkingId,
    required String parkingName,
    required DateTime date,
    required String startTime,
    required String endTime,
    required int spotNumber,
    required int totalPrice,
  }) async {
    final userRef = _db.collection('users').doc(userId);
    final bookingRef = _db.collection('bookings').doc();

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final balance = (userSnap.data()?['balance'] ?? 0) as int;
      if (balance < totalPrice) {
        throw Exception('Недостаточно средств на балансе. Пополните кошелёк.');
      }

      tx.update(userRef, {'balance': balance - totalPrice});
      tx.set(bookingRef, Booking(
        id: bookingRef.id,
        parkingId: parkingId,
        parkingName: parkingName,
        userId: userId,
        userName: userName,
        date: date,
        startTime: startTime,
        endTime: endTime,
        spotNumber: spotNumber,
        totalPrice: totalPrice,
        status: 'active',
      ).toMap());
    });

    return bookingRef.id;
  }

  Future<void> cancelBooking(String bookingId) async {
    await _db.collection('bookings').doc(bookingId).update({
      'status': 'cancelled',
    });
  }

  Future<void> topUpBalance(String userId, int amount) async {
    final userRef = _db.collection('users').doc(userId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final balance = (snap.data()?['balance'] ?? 0) as int;
      tx.update(userRef, {'balance': balance + amount});
    });
  }

  Future<void> addReview(Review review) async {
    await _db.collection('reviews').add(review.toMap());
  }

  Stream<List<Review>> watchMyReviews(String userId) {
    return _db
        .collection('reviews')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final reviews =
          snap.docs.map((d) => Review.fromMap(d.id, d.data())).toList();
      reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reviews;
    });
  }
}
