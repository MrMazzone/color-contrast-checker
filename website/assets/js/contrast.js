// WCAG 2.1 contrast math — a small port of the app's wcag_contrast package.

/** Parses any CSS color the browser understands into {r, g, b} or null. */
export function parseColor(input) {
  const text = String(input || "").trim();
  if (!text) return null;
  const hex = text.replace(/^#/, "");
  if (/^[0-9a-f]{3}$|^[0-9a-f]{6}$/i.test(hex)) {
    const full = hex.length === 3 ? hex.replace(/./g, "$&$&") : hex;
    const n = parseInt(full, 16);
    return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 };
  }
  // Let the browser parse rgb(), hsl() and named colors.
  const ctx = parseColor._ctx || (parseColor._ctx = document.createElement("canvas").getContext("2d"));
  ctx.fillStyle = "#010203";
  ctx.fillStyle = text;
  const out = ctx.fillStyle;
  if (out === "#010203" && text.toLowerCase() !== "#010203") return null;
  if (out.startsWith("#")) {
    const n = parseInt(out.slice(1), 16);
    return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 };
  }
  const m = out.match(/rgba?\(([^)]+)\)/);
  if (!m) return null;
  const [r, g, b] = m[1].split(",").map((v) => Math.round(parseFloat(v)));
  return { r, g, b };
}

export function toHex({ r, g, b }) {
  return "#" + [r, g, b].map((v) => v.toString(16).padStart(2, "0")).join("").toUpperCase();
}

const lin = (c) => {
  const v = c / 255;
  return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
};

export function luminance({ r, g, b }) {
  return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
}

export function contrastRatio(a, b) {
  const la = luminance(a);
  const lb = luminance(b);
  return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

/** Truncates (never rounds up) so 4.499 shows as 4.49. */
export function formatRatio(ratio) {
  return (Math.floor(ratio * 100 + 1e-9) / 100).toFixed(2);
}

function rgbToHsl({ r, g, b }) {
  const rn = r / 255, gn = g / 255, bn = b / 255;
  const max = Math.max(rn, gn, bn), min = Math.min(rn, gn, bn);
  const l = (max + min) / 2;
  const d = max - min;
  if (d === 0) return { h: 0, s: 0, l };
  const s = d / (1 - Math.abs(2 * l - 1));
  let h;
  if (max === rn) h = 60 * (((gn - bn) / d) % 6);
  else if (max === gn) h = 60 * ((bn - rn) / d + 2);
  else h = 60 * ((rn - gn) / d + 4);
  return { h: (h + 360) % 360, s: Math.min(1, s), l };
}

function hslToRgb({ h, s, l }) {
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const hp = h / 60;
  const x = c * (1 - Math.abs((hp % 2) - 1));
  let r1 = 0, g1 = 0, b1 = 0;
  if (hp < 1) [r1, g1] = [c, x];
  else if (hp < 2) [r1, g1] = [x, c];
  else if (hp < 3) [g1, b1] = [c, x];
  else if (hp < 4) [g1, b1] = [x, c];
  else if (hp < 5) [r1, b1] = [x, c];
  else [r1, b1] = [c, x];
  const m = l - c / 2;
  const to8 = (v) => Math.round(Math.min(1, Math.max(0, v + m)) * 255);
  return { r: to8(r1), g: to8(g1), b: to8(b1) };
}

/**
 * The closest text color (same hue and saturation, different lightness) that
 * reaches `target` against `bg`, or null if none does.
 */
export function closestPassing(fg, bg, target) {
  const hsl = rgbToHsl(fg);
  let best = null;
  for (const dir of [-1, 1]) {
    for (let step = 1; step <= 400; step++) {
      const l = hsl.l + (dir * step) / 400;
      if (l < 0 || l > 1) break;
      const c = hslToRgb({ ...hsl, l });
      if (contrastRatio(c, bg) >= target) {
        const dist = Math.abs(l - hsl.l);
        if (!best || dist < best.dist) best = { color: c, dist };
        break;
      }
    }
  }
  return best ? best.color : null;
}
