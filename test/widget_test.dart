import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inventory_client/main.dart';

void main() {
  testWidgets('app builds', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: InventoryApp(),
      ),
    );

    expect(
      find.text('Inventory ERP — Phase 9.1'),
      findsOneWidget,
    );
  });
}
