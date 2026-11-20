# Native Liquid Glass patches

The runtime sources come from [native_liquid_glass 0.3.1](https://pub.dev/packages/native_liquid_glass/versions/0.3.1).
The package keeps its upstream MIT license.

- `GlassEffectSuppressor.swift` restores interaction as soon as a view starts fading in and blocks interaction while it is covered. Reversing the fade starts at its current opacity.
- `LiquidGlassButtonSwiftUI.swift` uses the full button frame for touches. The glass still uses its configured shape.
