# ScanAction

The app's main entry point for adding anything: a lime "Scan" control that sits where each platform expects its primary action.

**iOS**
- **Placement:** trailing item in the navigation bar on Vault and Claims.
- **Look:** a lime pill with the scan-corners icon and "Scan", 36pt visual height, 44pt+ hit area, `radius-md`.
- **Scroll:** stays in the inline bar when the large title collapses.

**Android**
- **Placement:** extended FAB at the bottom right, 16dp from the edges, above the navigation bar.
- **Look:** `fab` 56dp, `radius-md`, `lime` with `on-lime`, `shadow-fab`.
- **Scroll:** collapses to a 56dp icon-only FAB on scroll down, and expands on scroll up.

**Both**
- **Action:** tapping opens the BottomSheet "Add to your drawer". Long-press goes straight to the camera.
- **Visibility:** hidden on Settings and inside flows. Never two Scan controls on screen.
- **Accessibility label:** "Scan or add a document".
