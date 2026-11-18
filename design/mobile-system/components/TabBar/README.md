# TabBar

The floating dock contains Vault, Claims, Settings, and the Scan or add action.

- **Surface:** a dark, translucent pill with clipped backdrop blur and a directional rim. It sits above the bottom safe area with side gutters and a maximum width on larger screens.
- **Tabs:** a custom `icon-md` glyph above a `tab-label`. The selected tab has a lime icon and a pill that moves with selection. The Claims count appears inline in `signal` when action is needed.
- **Scan or add:** a lime-tinted button that opens the existing add sheet. In the local drawer, a long press opens the camera.
- **Accessibility:** controls grow with text size. The Claims semantic label includes the count. High contrast uses an opaque dock, and reduced motion moves the selection pill immediately.
