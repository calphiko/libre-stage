"""Shared logo-based palette extraction for PDF renderers."""

from pathlib import Path
import colorsys
import logging

from PIL import Image
from reportlab.lib import colors


logger = logging.getLogger("uvicorn.error")


DEFAULT_SCHEDULE_PALETTE = {
    "bg": colors.HexColor("#0B1220"),
    "card": colors.HexColor("#111827"),
    "primary": colors.HexColor("#60A5FA"),
    "text": colors.HexColor("#E2E8F0"),
    "muted": colors.HexColor("#94A3B8"),
    "header_bg": colors.HexColor("#1E293B"),
    "row_alt": colors.HexColor("#0F172A"),
    "line": colors.HexColor("#334155"),
    "fixed": colors.HexColor("#123129"),
}


DEFAULT_SETLIST_PALETTES = {
    "dark": {
        "bg": colors.HexColor("#0B1220"),
        "card": colors.HexColor("#111827"),
        "primary": colors.HexColor("#F97316"),
        "text": colors.HexColor("#E2E8F0"),
        "muted": colors.HexColor("#94A3B8"),
        "line": colors.HexColor("#7C3A16"),
        "set_header_bg": colors.HexColor("#2B1A10"),
        "comment": colors.HexColor("#FDBA74"),
        "warning": colors.HexColor("#FB923C"),
    },
    "print": {
        "bg": colors.white,
        "card": colors.white,
        "primary": colors.HexColor("#EA580C"),
        "text": colors.black,
        "muted": colors.HexColor("#4B5563"),
        "line": colors.HexColor("#D1D5DB"),
        "set_header_bg": colors.HexColor("#FFEDD5"),
        "comment": colors.HexColor("#C2410C"),
        "warning": colors.HexColor("#EA580C"),
    },
}


def find_logo_path(config: dict) -> Path | None:
    """Return first existing logo path from configured root and file names."""
    root_dir = config.get("root_dir")
    if root_dir is None:
        return None

    filenames = config.get("logo_filenames") or ("LogoCustom.png", "Logo.png")
    for filename in filenames:
        candidate = Path(root_dir) / filename
        if candidate.is_file():
            return candidate
    return None


def _mix_color(a: colors.Color, b: colors.Color, weight_b: float) -> colors.Color:
    w = max(0.0, min(1.0, weight_b))
    return colors.Color(
        red=a.red * (1 - w) + b.red * w,
        green=a.green * (1 - w) + b.green * w,
        blue=a.blue * (1 - w) + b.blue * w,
    )


def _relative_luminance(c: colors.Color) -> float:
    def channel(v: float) -> float:
        if v <= 0.03928:
            return v / 12.92
        return ((v + 0.055) / 1.055) ** 2.4

    r = channel(c.red)
    g = channel(c.green)
    b = channel(c.blue)
    return (0.2126 * r) + (0.7152 * g) + (0.0722 * b)


def _contrast_ratio(a: colors.Color, b: colors.Color) -> float:
    l1 = _relative_luminance(a)
    l2 = _relative_luminance(b)
    lighter = max(l1, l2)
    darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)


def _ensure_contrast(fg: colors.Color, bg: colors.Color, min_ratio: float) -> colors.Color:
    if _contrast_ratio(fg, bg) >= min_ratio:
        return fg

    if _contrast_ratio(colors.black, bg) >= _contrast_ratio(colors.white, bg):
        return colors.black
    return colors.white


def _extract_logo_accent(config: dict) -> tuple[float, float, float] | None:
    logo_path = config.get("logo_path")
    if logo_path is None:
        return None

    try:
        with Image.open(logo_path) as image:
            image = image.convert("RGBA")
            image.thumbnail((120, 120))

            best_score = -1.0
            best_rgb: tuple[float, float, float] | None = None
            for count, rgba in image.getcolors(maxcolors=120 * 120) or []:
                r, g, b, a = rgba
                if a < 96:
                    continue

                rf, gf, bf = r / 255.0, g / 255.0, b / 255.0
                _, saturation, value = colorsys.rgb_to_hsv(rf, gf, bf)
                if value < 0.14 or value > 0.92:
                    continue

                # Prefer saturated mid-bright colors as accent candidates.
                score = ((saturation * 0.8) + ((1.0 - abs(value - 0.55)) * 0.2)) * count
                if score > best_score:
                    best_score = score
                    best_rgb = (rf, gf, bf)

            return best_rgb
    except Exception:  # pragma: no cover - palette fallback is intentional
        logger.debug("Could not extract palette color from logo", exc_info=True)
        return None


def resolve_schedule_palette(config: dict) -> dict[str, colors.Color]:
    """Build schedule PDF palette from default values plus optional logo accent."""
    default_palette = config.get("default_palette") or DEFAULT_SCHEDULE_PALETTE
    palette = dict(default_palette)

    accent_rgb = _extract_logo_accent({"logo_path": config.get("logo_path")})
    if accent_rgb is None:
        return palette

    accent = colors.Color(*accent_rgb)
    if _relative_luminance(accent) < 0.26:
        accent = _mix_color(accent, colors.white, 0.30)
    if _relative_luminance(accent) > 0.70:
        accent = _mix_color(accent, colors.black, 0.24)

    base_bg = colors.HexColor("#0A0F1A")
    bg = _mix_color(base_bg, accent, 0.10)
    card = _mix_color(base_bg, accent, 0.18)
    header_bg = _mix_color(base_bg, accent, 0.26)

    text = _ensure_contrast(colors.HexColor("#E2E8F0"), card, 7.0)
    muted = _ensure_contrast(_mix_color(text, accent, 0.38), card, 4.5)

    palette["bg"] = bg
    palette["card"] = card
    palette["primary"] = accent
    palette["text"] = text
    palette["muted"] = muted
    palette["header_bg"] = header_bg
    palette["row_alt"] = _mix_color(card, colors.black, 0.16)
    palette["line"] = _mix_color(_ensure_contrast(colors.HexColor("#64748B"), card, 2.0), accent, 0.20)
    palette["fixed"] = _mix_color(_mix_color(card, accent, 0.24), colors.HexColor("#14532D"), 0.20)
    return palette


def resolve_setlist_palette(config: dict) -> dict[str, colors.Color]:
    """Build setlist PDF palette with optional print-friendly mode and logo accent."""
    druckfreundlich = bool(config.get("druckfreundlich", config.get("print_friendly", False)))
    style_mode = "print" if druckfreundlich else config.get("style_mode", "dark")
    if style_mode not in ("dark", "print"):
        style_mode = "dark"

    default_palettes = dict(DEFAULT_SETLIST_PALETTES)
    default_palettes.update(config.get("default_palettes") or {})
    palette = dict(default_palettes.get(style_mode, default_palettes["dark"]))

    accent_rgb = _extract_logo_accent({"logo_path": config.get("logo_path")})
    if accent_rgb is None:
        return palette

    accent = colors.Color(*accent_rgb)

    if style_mode == "dark":
        if _relative_luminance(accent) < 0.26:
            accent = _mix_color(accent, colors.white, 0.30)
        if _relative_luminance(accent) > 0.70:
            accent = _mix_color(accent, colors.black, 0.24)

        base_bg = colors.HexColor("#0A0F1A")
        card = _mix_color(base_bg, accent, 0.18)
        palette["bg"] = _mix_color(base_bg, accent, 0.10)
        palette["card"] = card
        palette["primary"] = accent
        palette["line"] = _mix_color(_ensure_contrast(colors.HexColor("#64748B"), card, 2.0), accent, 0.20)
        palette["text"] = _ensure_contrast(colors.HexColor("#E2E8F0"), card, 7.0)
        palette["muted"] = _ensure_contrast(_mix_color(palette["text"], accent, 0.38), card, 4.5)
        palette["set_header_bg"] = _mix_color(base_bg, accent, 0.26)
        palette["comment"] = _mix_color(accent, colors.white, 0.28)
        palette["warning"] = _mix_color(accent, colors.white, 0.16)
        return palette

    if _relative_luminance(accent) < 0.22:
        accent = _mix_color(accent, colors.white, 0.22)
    if _relative_luminance(accent) > 0.78:
        accent = _mix_color(accent, colors.black, 0.35)

    palette["primary"] = accent
    palette["set_header_bg"] = _mix_color(colors.white, accent, 0.16)
    palette["line"] = _mix_color(colors.HexColor("#D1D5DB"), accent, 0.18)
    palette["comment"] = _mix_color(accent, colors.black, 0.20)
    palette["warning"] = _mix_color(accent, colors.black, 0.08)
    return palette


