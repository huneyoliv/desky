import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desky/features/store/store_screen.dart';
import 'package:desky/data/repositories/store_repository.dart';
import 'package:desky/data/models/studicon_item_model.dart';
import 'package:desky/shared/widgets/studicon_avatar.dart';

class FakeStoreRepository extends StoreRepository {
  @override
  Future<List<StudiconItemModel>> fetchMyStudicons(
    int currentEquippedId, {
    List<int>? ownedIdsFromUser,
    String language = 'pt',
  }) async {
    return [
      const StudiconItemModel(
        id: -1,
        name: 'Boneco Padrão (Laranja)',
        category: 'Padrão',
        priceFlames: 0,
        isOwned: true,
        isEquipped: true,
      ),
    ];
  }
}

void main() {
  testWidgets('StoreScreen renders default orange studicon asset correctly', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeRepositoryProvider.overrideWithValue(FakeStoreRepository()),
        ],
        child: const MaterialApp(
          home: StoreScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Avatar Padrão'), findsOneWidget);
    expect(find.byType(StudiconAvatar), findsOneWidget);

    final imageFinder = find.descendant(
      of: find.byType(StudiconAvatar),
      matching: find.byType(Image),
    );
    expect(imageFinder, findsOneWidget);

    final imageWidget = tester.widget<Image>(imageFinder);
    expect(imageWidget.image, isA<AssetImage>());
    final assetImage = imageWidget.image as AssetImage;
    expect(assetImage.assetName, 'assets/images/studicon/ic_user_on_s.png');
  });
}
