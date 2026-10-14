import 'package:flutter_test/flutter_test.dart';
import 'package:pokerchips/domain/player_naming.dart';

void main() {
  group('resolvePlayerName', () {
    test('未入力なら未使用の最小番号で「プレイヤーN」を割り当てる', () {
      expect(resolvePlayerName('', []), 'プレイヤー1');
      expect(resolvePlayerName('  ', ['プレイヤー1', 'Alice']), 'プレイヤー2');
      expect(resolvePlayerName('', ['プレイヤー2']), 'プレイヤー1');
    });

    test('入力された名前は前後の空白を除いてそのまま使う', () {
      expect(resolvePlayerName(' Alice ', ['Bob']), 'Alice');
    });

    test('同名がいれば番号を付けて区別する', () {
      expect(resolvePlayerName('Alice', ['Alice']), 'Alice(2)');
      expect(resolvePlayerName('Alice', ['Alice', 'Alice(2)']), 'Alice(3)');
    });
  });
}
