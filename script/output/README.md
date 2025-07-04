# Aminal Renderings Output

This directory contains generated SVG files and visualizations for the Aminals project.

## Directory Structure

- `traits/` - Individual trait SVG files (wings, tails, ears, faces, etc.)
- `aminals/` - Composed Aminal SVG files showing complete characters
- `gallery.html` - HTML gallery showing all traits and composed Aminals
- `vrgda_curve_*` - VRGDA curve visualizations (from previous script)

## Viewing the Files

### Gallery View
Open `gallery.html` in a web browser to see all traits and composed Aminals in a grid layout.

### Individual SVGs
All SVG files can be opened directly in:
- Web browsers (Chrome, Firefox, Safari, etc.)
- Vector graphics editors (Inkscape, Illustrator, etc.)
- Image viewers that support SVG

## Generated Aminals

The composed Aminals demonstrate various trait combinations:

1. **Plain Aminal** - Basic round body with no accessories
2. **Bunny** - Chubby body with bunny ears and cute face
3. **Cat** - Slim body with cat ears, fluffy tail, and sleepy face
4. **Fire Dragon** - Round body with dragon wings, fire tail, devil horns, and cool face
5. **Angel Bunny** - Chubby body with angel wings, bunny ears, cute face, and sparkles
6. **Demon Cat** - Slim body with bat wings, lightning tail, devil horns, and cool face
7. **Sparkle Bunny** - Chubby body with bunny ears, fluffy tail, cute face, and sparkles
8. **Love Cat** - Round body with cat ears, fluffy tail, cute face, and heart aura
9. **Rainbow Dragon** - Round body with dragon wings, lightning tail, devil horns, cool face, and rainbow aura
10. **Celestial Angel** - Slim body with angel wings, bunny ears, sleepy face, sparkles, and rainbow aura

## Technical Details

These SVGs are generated using:
- Solidity contracts for composition logic
- Base64-encoded SVG data for trait isolation
- `<image>` tags for perfect composability
- Layered composition with proper z-ordering

The same rendering system is used onchain for the actual NFTs.