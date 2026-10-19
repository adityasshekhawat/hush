HUSH LOGO - FINAL (Tucked)

mark/        The mark on its own: colour, on-dark, mono-black, mono-white (SVG, vector)
wordmark/    "hush" in Bricolage Grotesque ExtraBold, tracking -45, already outlined (no font needed)
lockup/      Mark + wordmark, horizontal and stacked, in all four colour versions
app-icon/    macOS app icon on the standard 1024 grid (824 px body, soft shadow):
             lilac (primary), coral, ink. SVG + PNGs at 16, 32, 64, 128, 256, 512, 1024
menu-bar/    Template images for the menu bar, 18 pt at @1x, @2x and @3x, one per state:
             idle, mail (holding something), meeting, focus, sleep.
             Black on transparent with see-through eyes, named ...Template so macOS
             tints them automatically. Drop them into an asset catalog image set and
             set "Render As: Template Image".

Colours: Ink #2D2A35 · Oat #F4D9A6 · Coral #E8876A · Lilac #C9BBEC · Paper #FFFDF7

Rules: clear space = 1/4 of the mark's width on all sides. Minimum size 16 px for the
mark, 96 px wide for the lockup. Hush always sits bottom-right; never mirror, rotate,
recolour, or remove the face.

For the shipping app, build the .icns / asset-catalog icon from the 1024 PNG.
