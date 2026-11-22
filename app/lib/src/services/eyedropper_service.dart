import 'package:desktop_eyedropper/desktop_eyedropper.dart';
import 'package:wcag_contrast/wcag_contrast.dart';

/// Outcome of a screen color pick.
sealed class PickOutcome {
  const PickOutcome();
}

class Picked extends PickOutcome {
  const Picked(this.color);
  final RgbColor color;
}

class PickCancelled extends PickOutcome {
  const PickCancelled();
}

class PickFailed extends PickOutcome {
  const PickFailed(this.message);
  final String message;
}

/// Wraps [DesktopEyedropper] so the UI can be tested with a fake.
class EyedropperService {
  const EyedropperService();

  Future<PickOutcome> pick({required bool hideWindow}) async {
    try {
      final rgb = await DesktopEyedropper.pickColor(hideWindow: hideWindow);
      return rgb == null
          ? const PickCancelled()
          : Picked(RgbColor.fromInt(rgb));
    } on EyedropperUnsupportedException catch (e) {
      return PickFailed(e.message);
    } on EyedropperBusyException {
      return const PickCancelled();
    } catch (e) {
      return PickFailed('The eyedropper could not read the screen ($e).');
    }
  }
}
