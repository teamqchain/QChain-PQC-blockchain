// Unit tests for the per-field salt handling added for the source-of-truth
// backend (salted on-chain FieldHashes). Pure Dart — no device, keys or network.
import 'package:flutter_test/flutter_test.dart';
import 'package:qwallet_mobileapp/services/crypto_service.dart';

const _saltA = '0123456789abcdef0123456789abcdef';
const _saltB = 'fedcba9876543210fedcba9876543210';

Map<String, dynamic> _decrypted() => <String, dynamic>{
      'Degree Title': 'Bachelors in Computer Science',
      'College': 'College of Computing & Informatics',
      '_salts': <String, dynamic>{
        'Degree Title': _saltA,
        'College': _saltB,
      },
    };

void main() {
  setUp(CryptoService.clearFieldSalts);

  test('takeFieldSalts removes _salts from the attributes it returns', () {
    final attrs = CryptoService.takeFieldSalts('CRED-0007', _decrypted());
    expect(attrs.containsKey('_salts'), isFalse);
    expect(attrs, {
      'Degree Title': 'Bachelors in Computer Science',
      'College': 'College of Computing & Informatics',
    });
  });

  test('takeFieldSalts removes every underscore-prefixed key', () {
    final input = _decrypted()..['_anything'] = 'x';
    final attrs = CryptoService.takeFieldSalts('CRED-0007', input);
    expect(attrs.keys.where((k) => k.startsWith('_')), isEmpty);
  });

  test('saltsForDisclosure returns exactly the disclosed keys', () {
    CryptoService.takeFieldSalts('CRED-0007', _decrypted());
    expect(
      CryptoService.saltsForDisclosure('CRED-0007', ['College']),
      {'College': _saltB},
    );
    expect(
      CryptoService.saltsForDisclosure(
        'CRED-0007',
        ['Degree Title', 'College'],
      ),
      {'Degree Title': _saltA, 'College': _saltB},
    );
  });

  test('credentialID is trimmed for the salt cache', () {
    CryptoService.takeFieldSalts('  CRED-0007 ', _decrypted());
    expect(
      CryptoService.saltsForDisclosure('CRED-0007', ['College']),
      {'College': _saltB},
    );
  });

  test('saltsForDisclosure throws if the credential was never decrypted', () {
    expect(
      () => CryptoService.saltsForDisclosure('CRED-0099', ['College']),
      throwsStateError,
    );
  });

  test('saltsForDisclosure throws if a disclosed key has no salt', () {
    CryptoService.takeFieldSalts('CRED-0007', _decrypted());
    expect(
      () => CryptoService.saltsForDisclosure('CRED-0007', ['GPA']),
      throwsStateError,
    );
  });

  test('bodyDisclosedFields drops underscore, metadata and hidden keys', () {
    final body = CryptoService.bodyDisclosedFields(
      <String, dynamic>{
        'Degree Title': 'Bachelors in Computer Science',
        'College': 'College of Computing & Informatics',
        '_salts': {'College': _saltB},
        'holderName': 'Fatima',
        'expiryDate': '2030-06-30',
      },
      hiddenKeys: {'College'},
    );
    expect(body, {'Degree Title': 'Bachelors in Computer Science'});
  });
}
