# Village Outreach — Design System

## Overview

Village Outreach is a Smart Cities mutual-aid application designed to connect neighbors who need support with people who can help. Our visual identity focuses on warmth, accessibility, trust, and community connection.

## Approved UX Style Tile

The official design reference is [Village Outreach UX Style Tile](village_outreach_style_tile.png).

This style tile documents our approved brand colors, typography, iconography, interface components, feedback states, imagery, and visual textures.

## Color Palette

| Color | Hex | Primary Usage |
|---|---|---|
| Soft Forest Green | `#4A7C59` | Primary actions |
| Warm Sand Beige | `#F2E9D8` | Background surfaces |
| Muted Clay Orange | `#D99A6C` | Secondary actions |
| Deep Charcoal | `#2F2F2F` | Primary text |
| Sky Blue | `#7FB3D5` | Accent elements |
| Soft Olive | `#8C9A6E` | Supporting accents |
| Off White | `#FAF7F2` | Page backgrounds |
| Warm Gray | `#E5E2DD` | Borders and dividers |

The Flutter color definitions are maintained in `frontend/lib/core/theme/app_colors.dart`.

## Typography

- **Nunito:** Headings and section titles.
- **Inter:** Body text, forms, navigation, and buttons.
- **Raleway SemiBold:** Branding and limited accent elements.

Font files are stored in `frontend/assets/fonts/`.

## Logo Guidelines

Use the approved Village Outreach logo, located at `frontend/assets/brand/logo.png`.

Maintain its original proportions and sufficient clear space. Do not stretch, recolor, distort, or modify the logo without design approval. Ensure the logo remains visible against its background.

## Interface and Accessibility

Use rounded, approachable interface components and consistent spacing. Keep text readable, provide visible focus indicators, and use descriptive labels for navigation and forms.

Interactive controls should target a minimum size of 44 × 44 logical pixels. Status feedback should include clear text and icons rather than relying on color alone.

## Flutter Implementation

The app-wide design system is implemented in:

- `frontend/lib/core/theme/app_colors.dart`
- `frontend/lib/core/theme/app_typography.dart`
- `frontend/lib/core/theme/app_theme.dart`

The brand preview screen is located at `frontend/lib/features/brand_preview/brand_preview_screen.dart`.

This style tile is the team's visual reference. Future UI changes should remain consistent with the approved design system.
