import { closestPassing, contrastRatio, formatRatio, parseColor, toHex } from "./contrast.js";

const RELEASES = "https://github.com/MrMazzone/color-contrast-checker/releases/latest/download/";
const FILES = {
  windows: { file: "ColorContrastChecker-Windows-Setup.exe", label: "Download for Windows" },
  mac: { file: "ColorContrastChecker-macOS.dmg", label: "Download for macOS" },
  linux: { file: "ColorContrastChecker-Linux-x86_64.AppImage", label: "Download for Linux" },
};

function detectPlatform() {
  const ua = navigator.userAgent || "";
  const platform = (navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || "";
  if (/android|iphone|ipad|ipod/i.test(ua)) return "mobile";
  if (/mac/i.test(platform) || /mac os x/i.test(ua)) return "mac";
  if (/win/i.test(platform) || /windows/i.test(ua)) return "windows";
  if (/linux|x11|cros/i.test(platform + ua)) return "linux";
  return null;
}

function setupDownloadButtons() {
  const platform = detectPlatform();
  document.querySelectorAll("[data-download-primary]").forEach((el) => {
    const label = el.querySelector("[data-label]");
    if (platform && FILES[platform]) {
      el.href = RELEASES + FILES[platform].file;
      if (label) label.textContent = FILES[platform].label;
    } else {
      // Unknown or mobile: send people to the list of downloads.
      el.href = "download.html";
      if (label) label.textContent = platform === "mobile" ? "Get it for your desktop" : "Download";
    }
  });
  document.querySelectorAll(".platform[data-platform]").forEach((card) => {
    if (card.dataset.platform === platform) {
      card.dataset.current = "true";
      const head = card.querySelector("header");
      if (head && !head.querySelector(".badge")) {
        const badge = document.createElement("span");
        badge.className = "badge";
        badge.textContent = "Your system";
        head.appendChild(badge);
      }
    }
  });
}

const ICONS = {
  check:
    '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" d="M5 12.5l4.5 4.5L19 7.5"/></svg>',
  cross:
    '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" d="M7 7l10 10M17 7L7 17"/></svg>',
};

function setupChecker() {
  const root = document.querySelector("[data-checker]");
  if (!root) return;

  const els = {
    fgText: root.querySelector("#fg-text"),
    fgPick: root.querySelector("#fg-pick"),
    bgText: root.querySelector("#bg-text"),
    bgPick: root.querySelector("#bg-pick"),
    swap: root.querySelector("[data-swap]"),
    front: document.querySelector("[data-card-front]"),
    chipFg: document.querySelector("[data-chip-fg]"),
    chipBg: document.querySelector("[data-chip-bg]"),
    verdict: document.querySelector("[data-verdict]"),
    pills: root.querySelector("[data-pills]"),
    suggest: root.querySelector("[data-suggest]"),
    ratioText: root.querySelector("[data-ratio-text]"),
  };

  const state = {
    fg: parseColor(els.fgText.value) || { r: 124, g: 124, b: 248 },
    bg: parseColor(els.bgText.value) || { r: 255, g: 255, b: 255 },
  };

  const checks = [
    ["Normal text AA", 4.5],
    ["Normal text AAA", 7],
    ["Large text AA", 3],
    ["Large text AAA", 4.5],
    ["UI components AA", 3],
  ];

  function render() {
    const fgHex = toHex(state.fg);
    const bgHex = toHex(state.bg);
    const ratio = contrastRatio(state.fg, state.bg);
    const shown = formatRatio(ratio);

    els.front.style.color = fgHex;
    els.front.style.backgroundColor = bgHex;
    els.chipFg.style.backgroundColor = fgHex;
    els.chipFg.querySelector("span").textContent = fgHex;
    els.chipBg.style.backgroundColor = bgHex;
    els.chipBg.querySelector("span").textContent = bgHex;
    els.fgPick.value = fgHex.toLowerCase();
    els.bgPick.value = bgHex.toLowerCase();

    const stateName = ratio >= 4.5 ? "pass" : ratio >= 3 ? "limited" : "fail";
    const label =
      ratio >= 7 ? "Passes AA & AAA" : ratio >= 4.5 ? "Passes AA" : ratio >= 3 ? "Large text only" : "Fails WCAG";
    els.verdict.dataset.state = stateName;
    els.verdict.innerHTML =
      (ratio >= 4.5 ? ICONS.check : ICONS.cross) +
      `<span class="ratio">${shown}<small>:1</small></span><span class="verdict-label">${label}</span>`;
    els.ratioText.textContent = `Contrast ratio ${shown} to 1. ${label}.`;

    els.pills.innerHTML = checks
      .map(([name, min]) => {
        const ok = ratio >= min;
        return `<span class="pill" data-pass="${ok}">${ok ? ICONS.check : ICONS.cross}${name} ${
          ok ? "pass" : "fail"
        }</span>`;
      })
      .join("");

    if (ratio < 4.5) {
      const better = closestPassing(state.fg, state.bg, 4.5);
      if (better) {
        const hex = toHex(better);
        els.suggest.hidden = false;
        els.suggest.innerHTML =
          `<span>Closest text color that passes AA: <span class="swatch-dot" style="background:${hex}"></span>` +
          `<span class="mono">${hex}</span> (${formatRatio(contrastRatio(better, state.bg))}:1)</span>` +
          `<button type="button" data-use="${hex}">Use ${hex}</button>`;
      } else {
        els.suggest.hidden = false;
        els.suggest.textContent = "No shade of this hue passes on this background. Try a darker or lighter background.";
      }
    } else {
      els.suggest.hidden = true;
      els.suggest.innerHTML = "";
    }
  }

  function bindText(input, key) {
    const box = input.closest(".color-input");
    input.addEventListener("input", () => {
      const parsed = parseColor(input.value);
      box.dataset.invalid = parsed ? "false" : String(input.value.trim().length >= 3);
      if (parsed) {
        state[key] = parsed;
        render();
      }
    });
    input.addEventListener("change", () => {
      const parsed = parseColor(input.value);
      if (parsed) state[key] = parsed;
      input.value = toHex(state[key]);
      box.dataset.invalid = "false";
      render();
    });
  }

  function bindPicker(picker, text, key) {
    picker.addEventListener("input", () => {
      state[key] = parseColor(picker.value);
      text.value = toHex(state[key]);
      render();
    });
  }

  bindText(els.fgText, "fg");
  bindText(els.bgText, "bg");
  bindPicker(els.fgPick, els.fgText, "fg");
  bindPicker(els.bgPick, els.bgText, "bg");

  els.swap.addEventListener("click", () => {
    [state.fg, state.bg] = [state.bg, state.fg];
    els.fgText.value = toHex(state.fg);
    els.bgText.value = toHex(state.bg);
    render();
  });

  els.suggest.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-use]");
    if (!btn) return;
    state.fg = parseColor(btn.dataset.use);
    els.fgText.value = toHex(state.fg);
    render();
    els.fgText.focus();
  });

  render();
}

// Tags download links so PostHog autocapture can break downloads down by platform and format.
// Runs after setupDownloadButtons() so the auto-detected primary button is tagged too.
const DOWNLOAD_TAGS = {
  "ColorContrastChecker-Windows-Setup.exe": ["windows", "installer"],
  "ColorContrastChecker-Windows-Portable.zip": ["windows", "zip"],
  "ColorContrastChecker-macOS.dmg": ["mac", "dmg"],
  "ColorContrastChecker-Linux-x86_64.AppImage": ["linux", "appimage"],
  "ColorContrastChecker-Linux-amd64.deb": ["linux", "deb"],
  "ColorContrastChecker-Linux-x86_64.tar.gz": ["linux", "tar.gz"],
};

function tagDownloadLinks() {
  document.querySelectorAll(`a[href^="${RELEASES}"]`).forEach((el) => {
    const tags = DOWNLOAD_TAGS[el.getAttribute("href").slice(RELEASES.length)];
    if (!tags) return;
    el.dataset.phCaptureAttributePlatform = tags[0];
    el.dataset.phCaptureAttributeFormat = tags[1];
    el.dataset.phCaptureAttributePlacement = el.hasAttribute("data-download-primary") ? "hero" : "platform-list";
  });
}

// PostHog web analytics. Cookieless: nothing is stored in cookies or local storage.
// The color checker is marked ph-no-capture in the HTML so colors are never sent.
// Skipped on local previews (anything not served over https).
function loadAnalytics() {
  if (location.protocol !== "https:") return;
  const s = document.createElement("script");
  s.src = "https://us-assets.i.posthog.com/static/array.js";
  s.async = true;
  s.crossOrigin = "anonymous";
  s.onload = () => {
    window.posthog.init("phc_xFY39vhaiknaR53sYzTyuVw3Xcid5efM5bBVkWvSXdCS", {
      api_host: "https://us.i.posthog.com",
      defaults: "2026-08-30",
      cookieless_mode: "always",
      disable_session_recording: true,
      disable_surveys: true,
    });
  };
  document.head.appendChild(s);
}

setupDownloadButtons();
tagDownloadLinks();
setupChecker();
loadAnalytics();

const year = document.querySelector("[data-year]");
if (year) year.textContent = String(new Date().getFullYear());
