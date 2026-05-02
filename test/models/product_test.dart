import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_3d/models/product.dart';

void main() {
  // ---------------------------------------------------------------------------
  // ProductCategory
  // ---------------------------------------------------------------------------
  group('ProductCategory', () {
    test('has correct labels', () {
      expect(ProductCategory.muebles.label, 'Muebles');
      expect(ProductCategory.decoracion.label, 'Decoración');
      expect(ProductCategory.electrodomesticos.label, 'Electrodomésticos');
      expect(ProductCategory.iluminacion.label, 'Iluminación');
      expect(ProductCategory.otros.label, 'Otros');
    });

    test('has correct slugs', () {
      expect(ProductCategory.muebles.slug, 'muebles');
      expect(ProductCategory.decoracion.slug, 'decoracion');
      expect(ProductCategory.electrodomesticos.slug, 'electro');
      expect(ProductCategory.iluminacion.slug, 'iluminacion');
      expect(ProductCategory.otros.slug, 'otros');
    });
  });

  // ---------------------------------------------------------------------------
  // ProductDraft
  // ---------------------------------------------------------------------------
  group('ProductDraft', () {
    test('has correct default values', () {
      final draft = ProductDraft();
      expect(draft.title, '');
      expect(draft.description, '');
      expect(draft.price, isNull);
      expect(draft.category, ProductCategory.muebles);
      expect(draft.photos, isEmpty);
    });

    group('isValid', () {
      test('returns true when all fields are valid', () {
        final draft = ProductDraft(
          title: 'Valid Title',
          description: 'A description',
          price: 100.0,
          photos: [File('/a'), File('/b')],
        );
        expect(draft.isValid, isTrue);
      });

      test('returns true with exactly 4 photos', () {
        final draft = ProductDraft(
          title: 'Valid Title',
          price: 100.0,
          photos: [File('/a'), File('/b'), File('/c'), File('/d')],
        );
        expect(draft.isValid, isTrue);
      });

      test('returns false when title is too short', () {
        final draft = ProductDraft(
          title: 'ab',
          price: 100.0,
          photos: [File('/a'), File('/b')],
        );
        expect(draft.isValid, isFalse);
      });

      test('returns false when title is only whitespace', () {
        final draft = ProductDraft(
          title: '   ',
          price: 100.0,
          photos: [File('/a'), File('/b')],
        );
        expect(draft.isValid, isFalse);
      });

      test('returns false when price is null', () {
        final draft = ProductDraft(
          title: 'Valid Title',
          photos: [File('/a'), File('/b')],
        );
        expect(draft.isValid, isFalse);
      });

      test('returns false when price is zero', () {
        final draft = ProductDraft(
          title: 'Valid Title',
          price: 0,
          photos: [File('/a'), File('/b')],
        );
        expect(draft.isValid, isFalse);
      });

      test('returns false when price is negative', () {
        final draft = ProductDraft(
          title: 'Valid Title',
          price: -5.0,
          photos: [File('/a'), File('/b')],
        );
        expect(draft.isValid, isFalse);
      });

      test('returns false when fewer than 2 photos', () {
        final draft = ProductDraft(
          title: 'Valid Title',
          price: 100.0,
          photos: [File('/a')],
        );
        expect(draft.isValid, isFalse);
      });

      test('returns false when no photos', () {
        final draft = ProductDraft(
          title: 'Valid Title',
          price: 100.0,
        );
        expect(draft.isValid, isFalse);
      });

      test('returns false when more than 4 photos', () {
        final draft = ProductDraft(
          title: 'Valid Title',
          price: 100.0,
          photos: [File('/a'), File('/b'), File('/c'), File('/d'), File('/e')],
        );
        expect(draft.isValid, isFalse);
      });
    });

    group('validationError', () {
      test('returns null when draft is valid', () {
        final draft = ProductDraft(
          title: 'Valid Title',
          price: 100.0,
          photos: [File('/a'), File('/b')],
        );
        expect(draft.validationError, isNull);
      });

      test('reports short title error', () {
        final draft = ProductDraft(
          title: 'ab',
          price: 100.0,
          photos: [File('/a'), File('/b')],
        );
        expect(draft.validationError, contains('3 caracteres'));
      });

      test('reports null price error', () {
        final draft = ProductDraft(
          title: 'Valid Title',
          photos: [File('/a'), File('/b')],
        );
        expect(draft.validationError, contains('precio'));
      });

      test('reports zero price error', () {
        final draft = ProductDraft(
          title: 'Valid Title',
          price: 0,
          photos: [File('/a'), File('/b')],
        );
        expect(draft.validationError, contains('precio'));
      });

      test('reports negative price error', () {
        final draft = ProductDraft(
          title: 'Valid Title',
          price: -10.0,
          photos: [File('/a'), File('/b')],
        );
        expect(draft.validationError, contains('precio'));
      });

      test('reports too few photos error', () {
        final draft = ProductDraft(
          title: 'Valid Title',
          price: 100.0,
          photos: [File('/a')],
        );
        expect(draft.validationError, contains('2 fotos'));
      });

      test('reports too many photos error', () {
        final draft = ProductDraft(
          title: 'Valid Title',
          price: 100.0,
          photos: [File('/a'), File('/b'), File('/c'), File('/d'), File('/e')],
        );
        expect(draft.validationError, contains('4 fotos'));
      });

      test('title validation checks trimmed length', () {
        // "  a" trims to "a" which is length 1 → invalid
        final draft = ProductDraft(
          title: '  a',
          price: 100.0,
          photos: [File('/a'), File('/b')],
        );
        expect(draft.validationError, contains('3 caracteres'));
      });
    });
  });

  // ---------------------------------------------------------------------------
  // Model3DStatus
  // ---------------------------------------------------------------------------
  group('Model3DStatus.fromString', () {
    test('parses queued', () =>
        expect(Model3DStatus.fromString('queued'), Model3DStatus.queued));

    test('parses processing', () =>
        expect(Model3DStatus.fromString('processing'), Model3DStatus.processing));

    test('parses ready', () =>
        expect(Model3DStatus.fromString('ready'), Model3DStatus.ready));

    test('parses failed', () =>
        expect(Model3DStatus.fromString('failed'), Model3DStatus.failed));

    test('returns unknown for null', () =>
        expect(Model3DStatus.fromString(null), Model3DStatus.unknown));

    test('returns unknown for unrecognized string', () =>
        expect(Model3DStatus.fromString('pending'), Model3DStatus.unknown));

    test('returns unknown for empty string', () =>
        expect(Model3DStatus.fromString(''), Model3DStatus.unknown));
  });

  group('Model3DStatus.displayText', () {
    test('queued text', () =>
        expect(Model3DStatus.queued.displayText, 'En cola...'));

    test('processing text', () =>
        expect(Model3DStatus.processing.displayText, 'Generando modelo 3D'));

    test('ready text', () =>
        expect(Model3DStatus.ready.displayText, 'Modelo listo'));

    test('failed text', () =>
        expect(Model3DStatus.failed.displayText, 'Error al generar'));

    test('unknown text', () =>
        expect(Model3DStatus.unknown.displayText, 'Estado desconocido'));
  });

  // ---------------------------------------------------------------------------
  // ProductStatus.fromJson
  // ---------------------------------------------------------------------------
  group('ProductStatus.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'productId': 'prod_1',
        'status': 'processing',
        'progress': 50,
        'glbUrl': 'https://example.com/model.glb',
        'usdzUrl': 'https://example.com/model.usdz',
        'error': null,
      };
      final status = ProductStatus.fromJson(json);
      expect(status.productId, 'prod_1');
      expect(status.status, Model3DStatus.processing);
      expect(status.progress, 50);
      expect(status.glbUrl, 'https://example.com/model.glb');
      expect(status.usdzUrl, 'https://example.com/model.usdz');
      expect(status.error, isNull);
    });

    test('defaults progress to 0 when missing', () {
      final status = ProductStatus.fromJson({'productId': 'p1', 'status': 'queued'});
      expect(status.progress, 0);
    });

    test('defaults progress to 0 when null', () {
      final status =
          ProductStatus.fromJson({'productId': 'p1', 'status': 'queued', 'progress': null});
      expect(status.progress, 0);
    });

    test('parses failed status with error', () {
      final json = {
        'productId': 'p1',
        'status': 'failed',
        'progress': 0,
        'error': 'Mesh reconstruction failed',
      };
      final status = ProductStatus.fromJson(json);
      expect(status.status, Model3DStatus.failed);
      expect(status.error, 'Mesh reconstruction failed');
    });

    test('parses ready status with urls', () {
      final json = {
        'productId': 'p2',
        'status': 'ready',
        'progress': 100,
        'glbUrl': 'https://cdn.example.com/m.glb',
        'usdzUrl': 'https://cdn.example.com/m.usdz',
      };
      final status = ProductStatus.fromJson(json);
      expect(status.status, Model3DStatus.ready);
      expect(status.progress, 100);
      expect(status.glbUrl, 'https://cdn.example.com/m.glb');
      expect(status.usdzUrl, 'https://cdn.example.com/m.usdz');
    });
  });

  // ---------------------------------------------------------------------------
  // UploadResult.fromJson
  // ---------------------------------------------------------------------------
  group('UploadResult.fromJson', () {
    test('parses all fields', () {
      final json = {'productId': 'prod_1', 'jobId': 'job_1', 'estimatedMinutes': 5};
      final result = UploadResult.fromJson(json);
      expect(result.productId, 'prod_1');
      expect(result.jobId, 'job_1');
      expect(result.estimatedMinutes, 5);
    });

    test('defaults estimatedMinutes to 3 when null', () {
      final json = {'productId': 'p1', 'jobId': 'j1', 'estimatedMinutes': null};
      final result = UploadResult.fromJson(json);
      expect(result.estimatedMinutes, 3);
    });

    test('defaults estimatedMinutes to 3 when missing', () {
      final json = {'productId': 'p1', 'jobId': 'j1'};
      final result = UploadResult.fromJson(json);
      expect(result.estimatedMinutes, 3);
    });
  });
}
