import '../../../domain/bill_reader.dart';
import '../../../domain/models/item.dart';

/// What the "Check the details" form starts from: the captured or picked
/// originals, what was read from them, and the type to preselect.
class AddDetailsArgs {
  const AddDetailsArgs({
    this.files = const [],
    this.reading,
    this.kind,
  });

  final List<PendingFile> files;
  final ScanReading? reading;
  final ItemKind? kind;
  ItemKind get effectiveKind => kind ?? reading?.kind ?? ItemKind.bill;
}

class CaptureReadingArgs {
  const CaptureReadingArgs(this.files, {this.kind});

  final List<PendingFile> files;
  final ItemKind? kind;
}
