import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_3d/models/product_listing.dart';

/// Simulates a Firestore [Timestamp] that has a [toDate] method.
class _FakeTimestamp {
  final DateTime _dt;
  _FakeTimestamp(this._dt);
  DateTime toDate() => _dt;
}

void main() {
  // ---------------------------------------------------------------------------
  // Model3D
  // ---------------------------------------------------------------------------
  group('Model3D', () {
    group('fromMap', () {
      test('parses all fields', () {
        final map = {
          'status': 'ready',
          'glbUrl': 'https://cdn.example.com/m.glb',
          'usdzUrl': 'https://cdn.example.com/m.usdz',
          'thumbnailUrl': 'https://cdn.example.com/thumb.jpg',
        };
        final model = Model3D.fromMap(map);
        expect(model.status, 'ready');
        expect(model.glbUrl, 'https://cdn.example.com/m.glb');
        expect(model.usdzUrl, 'https://cdn.example.com/m.usdz');
        expect(model.thumbnailUrl, 'https://cdn.example.com/thumb.jpg');
      });

      test('defaults status to unknown when missing', () {
        final model = Model3D.fromMap({});
        expect(model.status, 'unknown');
      });

      test('defaults status to unknown when null', () {
        final model = Model3D.fromMap({'status': null});
        expect(model.status, 'unknown');
      });

      test('optional url fields are null when missing', () {
        final model = Model3D.fromMap({'status': 'processing'});
        expect(model.glbUrl, isNull);
        expect(model.usdzUrl, isNull);
        expect(model.thumbnailUrl, isNull);
      });
    });

    group('isReady', () {
      test('true when status is ready and glbUrl is set', () {
        final model = Model3D(status: 'ready', glbUrl: 'https://cdn.example.com/m.glb');
        expect(model.isReady, isTrue);
      });

      test('false when status is ready but glbUrl is null', () {
        final model = Model3D(status: 'ready');
        expect(model.isReady, isFalse);
      });

      test('false when status is processing', () {
        final model = Model3D(status: 'processing', glbUrl: 'https://cdn.example.com/m.glb');
        expect(model.isReady, isFalse);
      });

      test('false when status is failed', () {
        final model = Model3D(status: 'failed');
        expect(model.isReady, isFalse);
      });

      test('false when status is unknown', () {
        final model = Model3D(status: 'unknown', glbUrl: 'https://cdn.example.com/m.glb');
        expect(model.isReady, isFalse);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // ProductListing
  // ---------------------------------------------------------------------------
  group('ProductListing.fromFirestore', () {
    test('parses a complete document', () {
      final data = {
        'title': 'Test Chair',
        'description': 'A comfortable chair',
        'price': 299.99,
        'category': 'muebles',
        'sellerId': 'seller_1',
        'sellerName': 'John Doe',
        'sellerRating': 4.5,
        'photos': [
          'https://cdn.example.com/p1.jpg',
          'https://cdn.example.com/p2.jpg',
        ],
        'model3d': {
          'status': 'ready',
          'glbUrl': 'https://cdn.example.com/m.glb',
        },
        'createdAt': DateTime(2024, 1, 15),
      };

      final listing = ProductListing.fromFirestore('listing_1', data);

      expect(listing.id, 'listing_1');
      expect(listing.title, 'Test Chair');
      expect(listing.description, 'A comfortable chair');
      expect(listing.price, 299.99);
      expect(listing.category, 'muebles');
      expect(listing.sellerId, 'seller_1');
      expect(listing.sellerName, 'John Doe');
      expect(listing.sellerRating, 4.5);
      expect(listing.photos.length, 2);
      expect(listing.model3d, isNotNull);
      expect(listing.createdAt, DateTime(2024, 1, 15));
    });

    test('applies defaults for all missing fields', () {
      final listing = ProductListing.fromFirestore('listing_2', {});

      expect(listing.id, 'listing_2');
      expect(listing.title, '');
      expect(listing.description, '');
      expect(listing.price, 0.0);
      expect(listing.category, 'otros');
      expect(listing.sellerId, '');
      expect(listing.sellerName, isNull);
      expect(listing.sellerRating, isNull);
      expect(listing.photos, isEmpty);
      expect(listing.model3d, isNull);
    });

    test('parses model3d as null when data key is absent', () {
      final listing = ProductListing.fromFirestore('id', {'model3d': null});
      expect(listing.model3d, isNull);
    });

    group('createdAt parsing', () {
      test('accepts a DateTime value directly', () {
        final dt = DateTime(2024, 6, 1);
        final listing = ProductListing.fromFirestore('id', {'createdAt': dt});
        expect(listing.createdAt, dt);
      });

      test('parses an ISO 8601 string', () {
        final listing =
            ProductListing.fromFirestore('id', {'createdAt': '2024-03-20T10:00:00.000'});
        expect(listing.createdAt.year, 2024);
        expect(listing.createdAt.month, 3);
        expect(listing.createdAt.day, 20);
      });

      test('falls back to DateTime.now() for null', () {
        final before = DateTime.now().subtract(const Duration(seconds: 1));
        final listing = ProductListing.fromFirestore('id', {'createdAt': null});
        final after = DateTime.now().add(const Duration(seconds: 1));
        expect(listing.createdAt.isAfter(before), isTrue);
        expect(listing.createdAt.isBefore(after), isTrue);
      });

      test('falls back to DateTime.now() for an invalid string', () {
        final before = DateTime.now().subtract(const Duration(seconds: 1));
        final listing =
            ProductListing.fromFirestore('id', {'createdAt': 'not-a-date'});
        final after = DateTime.now().add(const Duration(seconds: 1));
        expect(listing.createdAt.isAfter(before), isTrue);
        expect(listing.createdAt.isBefore(after), isTrue);
      });

      test('calls toDate() on Timestamp-like objects', () {
        final fakeTs = _FakeTimestamp(DateTime(2024, 6, 15));
        final listing = ProductListing.fromFirestore('id', {'createdAt': fakeTs});
        expect(listing.createdAt, DateTime(2024, 6, 15));
      });
    });
  });

  group('ProductListing.hasAr', () {
    ProductListing _listing({Model3D? model3d}) => ProductListing(
          id: '1',
          title: 'T',
          description: 'D',
          price: 10,
          category: 'muebles',
          sellerId: 's1',
          photos: [],
          model3d: model3d,
          createdAt: DateTime.now(),
        );

    test('true when model3d is ready with a glbUrl', () {
      expect(
        _listing(model3d: Model3D(status: 'ready', glbUrl: 'https://cdn.example.com/m.glb'))
            .hasAr,
        isTrue,
      );
    });

    test('false when model3d is null', () {
      expect(_listing().hasAr, isFalse);
    });

    test('false when model3d is not ready', () {
      expect(
        _listing(model3d: Model3D(status: 'processing')).hasAr,
        isFalse,
      );
    });

    test('false when model3d is ready but has no glbUrl', () {
      expect(
        _listing(model3d: Model3D(status: 'ready')).hasAr,
        isFalse,
      );
    });
  });

  group('ProductListing.firstPhoto', () {
    ProductListing _listing(List<String> photos) => ProductListing(
          id: '1',
          title: 'T',
          description: 'D',
          price: 10,
          category: 'muebles',
          sellerId: 's1',
          photos: photos,
          createdAt: DateTime.now(),
        );

    test('returns the first photo url when list is non-empty', () {
      expect(
        _listing(['https://cdn.example.com/p1.jpg', 'https://cdn.example.com/p2.jpg'])
            .firstPhoto,
        'https://cdn.example.com/p1.jpg',
      );
    });

    test('returns empty string when photos list is empty', () {
      expect(_listing([]).firstPhoto, '');
    });
  });
}
