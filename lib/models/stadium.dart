import 'package:cloud_firestore/cloud_firestore.dart';

class Stadium {
  final String id;
  final String name;
  final String? city;
  final double latitude;
  final double longitude;
  final String? address;
  final String? imageUrl;
  final String? description;
  final String? mapImageUrl;

  const Stadium({
    required this.id,
    required this.name,
    this.city,
    required this.latitude,
    required this.longitude,
    this.address,
    this.imageUrl,
    this.description,
    this.mapImageUrl,
  });

  factory Stadium.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data()! as Map<String, dynamic>;
    return Stadium(
      id: doc.id,
      name: map['name'] as String? ?? '',
      city: map['city'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      address: map['address'] as String?,
      imageUrl: map['imageUrl'] as String?,
      description: map['description'] as String?,
      mapImageUrl: map['mapImageUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'imageUrl': imageUrl,
        'description': description,
        'mapImageUrl': mapImageUrl,
      };
}
