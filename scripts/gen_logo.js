// One-shot launcher-icon generator.
// Renders an SVG to assets/icons/app_icon.png (1024x1024) which
// flutter_launcher_icons reads to fan out all platform sizes.
//
// Run from repo root:    node scripts/gen_logo.js

const fs = require('fs');
const path = require('path');
// sharp lives in backend/node_modules (installed there to avoid polluting
// the repo root). Resolve from there regardless of cwd.
const sharp = require(path.join(__dirname, '..', 'backend', 'node_modules', 'sharp'));

const OUT = path.join(__dirname, '..', 'flutter_app', 'assets', 'icons', 'app_icon.png');
const OUT_FG = path.join(__dirname, '..', 'flutter_app', 'assets', 'icons', 'app_icon_foreground.png');
fs.mkdirSync(path.dirname(OUT), { recursive: true });

// Full icon — copper plate + crossed knife/fork on a slate background.
// Designed to read at 48dp Android launcher size, not just at 1024.
const svg = `
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <radialGradient id="bg" cx="50%" cy="40%" r="80%">
      <stop offset="0%"  stop-color="#2A1810" />
      <stop offset="60%" stop-color="#150E08" />
      <stop offset="100%" stop-color="#0A0604" />
    </radialGradient>
    <radialGradient id="plate" cx="50%" cy="40%" r="60%">
      <stop offset="0%"  stop-color="#E8A268" />
      <stop offset="55%" stop-color="#C87B3A" />
      <stop offset="100%" stop-color="#8B4A1F" />
    </radialGradient>
    <radialGradient id="glow" cx="50%" cy="50%" r="60%">
      <stop offset="0%"   stop-color="#C87B3A" stop-opacity="0.55" />
      <stop offset="100%" stop-color="#C87B3A" stop-opacity="0.0" />
    </radialGradient>
    <linearGradient id="cutlery" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%"   stop-color="#F8E9D4" />
      <stop offset="100%" stop-color="#D9B89A" />
    </linearGradient>
  </defs>

  <!-- Slate background -->
  <rect width="1024" height="1024" rx="180" fill="url(#bg)" />

  <!-- Outer copper halo -->
  <circle cx="512" cy="512" r="420" fill="url(#glow)" />

  <!-- Plate rim (copper ring) -->
  <circle cx="512" cy="512" r="340" fill="none" stroke="url(#plate)" stroke-width="22" />

  <!-- Inner plate disc -->
  <circle cx="512" cy="512" r="310" fill="#1A1108" />

  <!-- Crossed knife + fork (the wordless brand mark) -->
  <g transform="translate(512 512) rotate(-15)" fill="url(#cutlery)">
    <!-- Fork (left, 4 tines + handle) -->
    <g transform="translate(-95 0)">
      <rect x="-22" y="-200" width="10" height="80" rx="4" />
      <rect x="-8"  y="-200" width="10" height="80" rx="4" />
      <rect x="6"   y="-200" width="10" height="80" rx="4" />
      <rect x="20"  y="-200" width="10" height="80" rx="4" />
      <rect x="-24" y="-130" width="56" height="40" rx="14" />
      <rect x="-10" y="-90"  width="28" height="280" rx="10" />
    </g>
    <!-- Knife (right) -->
    <g transform="translate(95 0)">
      <path d="M -22 -210 Q 18 -200 22 -90 L 14 -70 L -14 -70 Z" />
      <rect x="-10" y="-70" width="20" height="260" rx="8" />
    </g>
  </g>
</svg>`;

// Adaptive-icon foreground — same crest, transparent background so Android
// can frame it with its own circle/squircle mask.
const svgFg = `
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <radialGradient id="plate" cx="50%" cy="40%" r="60%">
      <stop offset="0%"  stop-color="#E8A268" />
      <stop offset="55%" stop-color="#C87B3A" />
      <stop offset="100%" stop-color="#8B4A1F" />
    </radialGradient>
    <linearGradient id="cutlery" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%"   stop-color="#F8E9D4" />
      <stop offset="100%" stop-color="#D9B89A" />
    </linearGradient>
  </defs>
  <circle cx="512" cy="512" r="320" fill="none" stroke="url(#plate)" stroke-width="22" />
  <circle cx="512" cy="512" r="298" fill="#1A1108" />
  <g transform="translate(512 512) rotate(-15)" fill="url(#cutlery)">
    <g transform="translate(-95 0)">
      <rect x="-22" y="-200" width="10" height="80" rx="4" />
      <rect x="-8"  y="-200" width="10" height="80" rx="4" />
      <rect x="6"   y="-200" width="10" height="80" rx="4" />
      <rect x="20"  y="-200" width="10" height="80" rx="4" />
      <rect x="-24" y="-130" width="56" height="40" rx="14" />
      <rect x="-10" y="-90"  width="28" height="280" rx="10" />
    </g>
    <g transform="translate(95 0)">
      <path d="M -22 -210 Q 18 -200 22 -90 L 14 -70 L -14 -70 Z" />
      <rect x="-10" y="-70" width="20" height="260" rx="8" />
    </g>
  </g>
</svg>`;

(async () => {
  await sharp(Buffer.from(svg)).png().toFile(OUT);
  await sharp(Buffer.from(svgFg)).png().toFile(OUT_FG);
  console.log(`Wrote ${OUT}`);
  console.log(`Wrote ${OUT_FG}`);
})();
