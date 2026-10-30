# WebDock application icon

Updated on 2026-10-30 for 0.4.1 (6), using the globe-and-Dock artwork supplied by the user
(f6ec7f54-d32b-4302-bce9-dd77773e51af.png). Built-in image_gen edit mode removed the exterior
white background/shadow; it was not a new logo design. WebDock-AppIcon-master.png is the selected
transparent result. The original upload is unchanged.

WebDock.icns is the standalone export: ten standard macOS representations, 16–1024 pixels,
with alpha. Regenerate it and the 1024px app artwork with scripts/generate_app_icon.sh (sips +
iconutil; no external image library). The exact final background-removal prompt is below.

The previous legacy icon received a large silver-white backing plate on this macOS 27 host,
even when referenced directly as an ICNS. The app therefore uses the standard WebDock.icon
source in Sources/WebDock/Resources/, compiled by Xcode 26+ into modern Assets.car and a legacy
WebDock.icns. Its single raster layer retains the supplied artwork, disables extra glass/shadow,
and uses 1.3 scale to fill the system's mask instead of nesting a padded icon inside it. The
background is blue. Xcode also generates the earlier-macOS multi-size representations.

The native About panel on XMAC macOS 27.0.1 was checked at 0.4.1 (6): blue tile reaches its
outer edge with no silver-white outer plate. This does not establish the Intel Ventura result;
that remains in the device acceptance checklist. The standalone export retains conventional
transparent margins for ordinary ICNS use and is separate from the compiler's app resources.

Apple references: [Icon Composer integration](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer),
[icon canvas and automatic masking](https://developer.apple.com/videos/play/wwdc2025/361/).

Final prompt (verbatim):

Use case: background-extraction. Create a final clean production PNG cutout of this exact blue rounded-square globe-and-dock icon. Keep the blue tile's full opaque rounded square as one smooth continuous silhouette, with the same blue globe and four-tile glass dock design inside. Replace the entire white background and ALL exterior shadows with pure transparent alpha. Critically: the transparent area must be empty and uniformly zero alpha, with NO blue speckles, no edge dirt, no floating pixels, no haze, no shadow. Use a crisp smooth mathematically clean rounded-square perimeter, with only a one-pixel antialias edge. Do not extract individual glass elements; keep everything inside the blue square fully opaque exactly as shown. Preserve the user's layout and colors. Center the single cutout with transparent margins. No white or silver border or backing plate. No new objects or text.
