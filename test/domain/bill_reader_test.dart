import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/domain/bill_reader.dart';
import 'package:paperdrawer/domain/models/item.dart';

void main() {
  test('reads the bill reference and serial as separate fields', () {
    final reading = readBill([
      'MEGASTORE ELECTRONICS',
      'INV 4615-A',
      'Invoice Date: 06 Nov 2026',
      'Product: Air cooler',
      'S/N: AQ-118/3',
      'WARRANTY: 1 YR',
      'TOTAL ₹8,750.50',
    ], today: DateTime.utc(2026, 11, 19));

    expect(reading.kind, ItemKind.bill);
    expect(reading.reference, '4615-A');
    expect(reading.serialNumber, 'AQ-118/3');
    expect(reading.warrantyMonths, 12);
    expect(reading.startsOn, DateTime.utc(2026, 11, 6));
    expect(reading.amountMinor, 875050);
    expect(reading.read, contains(ReadField.serialNumber));
  });

  test('leaves the serial blank when the scan only has an invoice', () {
    final reading = readBill([
      'Invoice No. 6621',
    ], today: DateTime.utc(2026, 11, 19));

    expect(reading.reference, '6621');
    expect(reading.serialNumber, isNull);
    expect(reading.read, isNot(contains(ReadField.serialNumber)));
  });
}
