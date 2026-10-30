# Application icon assets

`WebDock-AppIcon-master.png` is the transparent globe, orbital ribbon and Dock artwork.
`WebDock.icns` contains ten standard macOS representations from 16 to 1024 pixels, with alpha.

Regenerate the standalone ICNS and the 1024-pixel app artwork with:

```sh
bash scripts/generate_app_icon.sh
```

The native macOS tools `sips` and `iconutil` perform the conversion. No external image library is required.

The application uses `Sources/WebDock/Resources/WebDock.icon`, compiled by Xcode into modern
icon resources and earlier-macOS representations. Its raster layer disables additional glass
and shadow, uses the blue background and fills the system mask with a scale of 1.3. Keep the
standalone ICNS and compiled artwork in sync by using the regeneration script.
