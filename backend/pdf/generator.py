# libre-stage - Band rehearsal and gig management software
# Copyright (C) 2026  libre-stage contributors
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

"""
PDF setlist generator.

Renders a printable two-column setlist as a PDF using ReportLab.
Singer-specific colours, live-mode annotations (inserted / skipped songs,
feedback ratings) and a per-page schedule are included automatically.
"""

from io import BytesIO
from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfbase.pdfmetrics import stringWidth
from datetime import datetime, timedelta
from backend.utils.pdf_palette import find_logo_path, resolve_setlist_palette
from backend.utils.setlist_timing import get_pause_before_set

class SetlistPDF:
    """
    Two-column PDF setlist renderer for a single gig.

    The rendered document contains:

    - A header with gig name, date, timestamp and singer colour legend.
    - One column per two sets laid out side by side.
    - Per-song start times derived from the pre-computed schedule.
    - Live-mode annotations: ``[NEU]`` prefix for inserted songs,
      strikethrough for skipped songs, and ``[o]`` / ``[+]`` / ``[++]``
      feedback markers.
    - Page numbers (``Seite X/Y``) in the bottom-right corner.

    Args:
        gig (Gig): The gig to render.
        schedule (dict[int, list[datetime]]): Pre-computed start times per
            set position, as returned by
            :meth:`~backend.services.setlist.SetlistService.calc_schedule`.
        singer_colors (dict[str, str]): Mapping of first-name → hex colour
            string used to colour-code lead-singer names.
    """

    FONT = "Helvetica"
    FONT_SIZE = 8

    COLS = 2
    COL_WIDTH = 260
    X_BASES = [40, 320]
    Y_START = 124
    Y_STEP = 15
    Y_LIMIT = 800

    PALETTES = {
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
            "strike": colors.HexColor("#F8FAFC"),
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
            "strike": colors.black,
        },
    }

    def __init__(self, gig, schedule, singer_colors, style_mode="dark", slot_durations=None):
        self.gig = gig
        self.schedule = schedule
        self.singer_colors = singer_colors
        self.slot_durations = slot_durations or {}
        self.style_mode = style_mode if style_mode in self.PALETTES else "dark"
        self.root_dir = Path(__file__).resolve().parents[2]
        self.logo_path = find_logo_path({"root_dir": self.root_dir})
        self.palette = resolve_setlist_palette(
            {
                "druckfreundlich": self.style_mode == "print",
                "style_mode": self.style_mode,
                "default_palettes": self.PALETTES,
                "logo_path": self.logo_path,
            }
        )

    def _calc_set_height(self, gigset, set_idx, gig_sets_sorted):
        """
        Calculate the vertical space (in points) required to render a
        single set block, including an optional pause row and a trailing
        gap after the last song.

        Args:
            gigset: The :class:`~backend.models.GigSet` to measure.
            set_idx (int): 0-based index of this set in the sorted gig
                set list (used to determine whether a pause row is needed).

        Returns:
            int: Required height in PDF points.
        """
        height = 0
        # Optional: Platz für Pause nach dem Set
        if set_idx < len(gig_sets_sorted) - 1:
            pause = get_pause_before_set(gigset, gig_sets_sorted[set_idx + 1], self.schedule)
            if pause:
                height += self.Y_STEP
        # Set-Name
        height += self.Y_STEP
        # Songs
        height += len(gigset.set.songs) * self.Y_STEP
        # Leerzeile nach Set
        height += int(self.Y_STEP * 1.5)
        return height

    @staticmethod
    def _truncate_text_to_width(text: str, max_width: float, font_name: str, font_size: int) -> str:
        """Truncate text to fit in the available width, appending '...' when needed."""
        if not text or max_width <= 0:
            return ""
        if stringWidth(text, font_name, font_size) <= max_width:
            return text

        ellipsis = "..."
        ellipsis_width = stringWidth(ellipsis, font_name, font_size)
        if ellipsis_width > max_width:
            return ""

        cut = text
        while cut and stringWidth(cut, font_name, font_size) + ellipsis_width > max_width:
            cut = cut[:-1]
        return f"{cut}{ellipsis}" if cut else ""

    @staticmethod
    def _format_slot_duration(value: timedelta) -> str:
        total_seconds = max(0, int(value.total_seconds()))
        minutes, seconds = divmod(total_seconds, 60)
        return f"{minutes:02}:{seconds:02}"

    def build(self) -> BytesIO:
        """
        Render the setlist to an in-memory PDF and return it.

        Raises:
            Any ReportLab exception propagates to the caller.

        Returns:
            BytesIO: A buffer positioned at offset 0 containing the
            complete PDF document.
        """
        buffer = BytesIO()
        c = canvas.Canvas(buffer, pagesize=A4, bottomup=0)
        width, height = A4

        try:
            pdfmetrics.registerFont(TTFont("Verdana", "Verdana.ttf"))
            title_font = "Verdana"
        except Exception: # pragma: no cover
            title_font = "Helvetica-Bold" # pragma: no cover

        logo_reader = None
        logo_size = None

        def _get_logo_reader():
            nonlocal logo_reader, logo_size
            if logo_reader is not None:
                return logo_reader

            if self.logo_path is None:
                return None

            try:
                logo_reader = ImageReader(str(self.logo_path))
                logo_size = logo_reader.getSize()
                return logo_reader
            except Exception:  # pragma: no cover - watermark must not break export
                return None

        def draw_watermark():
            img = _get_logo_reader()
            if img is None or not logo_size:
                return

            img_width, img_height = logo_size
            max_width = width * 0.55
            max_height = height * 0.55
            ratio = min(max_width / img_width, max_height / img_height)
            render_w = img_width * ratio
            render_h = img_height * ratio
            x = (width - render_w) / 2
            y = (height - render_h) / 2

            c.saveState()
            # Print mode stays more subtle to keep hardcopy contrast high.
            if hasattr(c, "setFillAlpha"):
                alpha = 0.04 if self.style_mode == "print" else 0.06
                c.setFillAlpha(alpha)
                c.setStrokeAlpha(alpha)

            # With bottomup=0, images are vertically flipped unless we compensate.
            c.translate(x, y + render_h)
            c.scale(1, -1)
            c.drawImage(
                img,
                0,
                0,
                width=render_w,
                height=render_h,
                preserveAspectRatio=True,
                mask="auto",
            )
            c.restoreState()

        def draw_header():
            c.setFillColor(self.palette["bg"])
            c.rect(0, 0, width, height, stroke=0, fill=1)

            draw_watermark()

            card_height = 74
            card_x = 30
            card_y = 24
            card_w = width - 60
            c.setFillColor(self.palette["card"])
            c.roundRect(card_x, card_y, card_w, card_height, 8, stroke=0, fill=1)
            c.setStrokeColor(self.palette["line"])
            c.setLineWidth(0.8)
            c.roundRect(card_x, card_y, card_w, card_height, 8, stroke=1, fill=0)

            c.setFillColor(self.palette["primary"])
            c.rect(card_x, card_y, card_w, 8, stroke=0, fill=1)

            c.setFillColor(self.palette["text"])
            c.setFont(title_font, 12)
            c.drawString(card_x + 12, card_y + 22, "Setliste")

            c.setFont(self.FONT, 9)
            c.setFillColor(self.palette["muted"])
            c.drawString(card_x + 12, card_y + 36, f"Gig: {self.gig.name} am {self.gig.datum:%d.%m.%Y}")
            c.drawString(card_x + 12, card_y + 49, f"Export: {datetime.now():%d.%m.%Y %H:%M}")

            c.setFont(self.FONT, self.FONT_SIZE)
            c.setFillColor(self.palette["text"])
            x = card_x + 12
            y_legend = card_y + 62
            c.drawString(x, y_legend, "Lead-Saenger:")
            x += stringWidth("Lead-Saenger: ", self.FONT, self.FONT_SIZE)
            for singer, col in self.singer_colors.items():
                c.setFillColor(col)
                c.drawString(x, y_legend, singer)
                x += stringWidth(singer + " ", self.FONT, self.FONT_SIZE)

            c.setStrokeColor(self.palette["line"])
            c.setLineWidth(0.8)
            c.line(30, 108, width - 30, 108)

        def draw_footer(page_num: int, total_pages: int):
            footer_prefix = "Generated by libreStage | "
            footer_domain = "pakleds-patentoffice.de"
            footer_url = "https://pakleds-patentoffice.de"
            footer_font = self.FONT
            footer_size = 8
            footer_y = height - 20

            c.setFont(footer_font, footer_size)
            c.setFillColor(self.palette["muted"])
            full_text = f"{footer_prefix}{footer_domain}"
            full_width = stringWidth(full_text, footer_font, footer_size)
            prefix_width = stringWidth(footer_prefix, footer_font, footer_size)
            start_x = (width - full_width) / 2
            c.drawString(start_x, footer_y, footer_prefix)
            c.setFillColor(self.palette["primary"])
            c.drawString(start_x + prefix_width, footer_y, footer_domain)
            c.linkURL(
                footer_url,
                (start_x + prefix_width, footer_y - 2, start_x + full_width, footer_y + footer_size + 1),
                relative=0,
                thickness=0,
            )

            c.setFillColor(self.palette["muted"])
            c.drawRightString(width - 30, height - 20, f"Seite {page_num}/{total_pages}")

        gig_sets_sorted = sorted(self.gig.sets, key=lambda gs: gs.position)
        total_sets = len(gig_sets_sorted)

        # === Seiten-Logik: wir bauen alle Seiten zuerst, damit wir die Gesamtseitenzahl kennen ===
        pages = []
        current_page = []
        y = self.Y_START
        set_idx = 0
        # Jede Zeile = 2 Sets, linker und rechter, oder rechter ggf. leer
        while set_idx < total_sets:
            left_idx, right_idx = set_idx, set_idx+1
            left_set = gig_sets_sorted[left_idx]
            right_set = gig_sets_sorted[right_idx] if right_idx < total_sets else None

            # Set-Höhen bestimmen
            h_left = self._calc_set_height(left_set, left_idx, gig_sets_sorted)
            h_right = self._calc_set_height(right_set, right_idx, gig_sets_sorted) if right_set else 0
            max_h = max(h_left, h_right)
            # Seitenumbruch?
            if y + max_h > self.Y_LIMIT and y != self.Y_START: # pragma: no cover
                pages.append(current_page)# pragma: no cover
                current_page = []# pragma: no cover
                y = self.Y_START# pragma: no cover
            # Daten für diese Zeile merken
            current_page.append((left_set, left_idx, self.X_BASES[0], y))
            if right_set:
                current_page.append((right_set, right_idx, self.X_BASES[1], y))
            y += max_h
            set_idx += 2
        # letzte Seite
        if current_page:
            pages.append(current_page)

        # === Nun Seiten wirklich zeichnen: ===
        total_pages = len(pages)
        for page_num, page_sets in enumerate(pages, start=1):
            # Kopf
            draw_header()
            # Jede Seite: alle Sets in page_sets, sortiert nach x
            for item in page_sets:
                gigset, idx, x, y0 = item
                y = y0
                # Set-Überschrift
                set_obj = gigset.set
                set_pos = gigset.position
                set_name = set_obj.setlist_name or f"Set {set_pos}"
                start_times = self.schedule.get(set_pos, [])
                set_start_str = start_times[0].strftime('%H:%M') if start_times else ''

                c.setFillColor(self.palette["set_header_bg"])
                c.roundRect(x + 4, y - 10, self.COL_WIDTH - 10, 12, 3, stroke=0, fill=1)
                c.setFont("Helvetica-Bold", self.FONT_SIZE)
                c.setFillColor(self.palette["primary"])
                c.drawString(x+10, y, f"{set_name} - {set_start_str}")
                y += self.Y_STEP
                setsonglist = sorted(set_obj.songs, key=lambda ss: ss.position)
                for idx_song, setsong in enumerate(setsonglist):
                    song = setsong.song
                    song_time = start_times[idx_song] if start_times and idx_song < len(start_times) else ""
                    singer = (song.singer_lead or "").split(" ")[0]
                    color = self.singer_colors.get(singer, self.palette["text"])

                    # Live-Mode-Status verarbeiten
                    is_uebersprungen = getattr(setsong, 'uebersprungen', False)
                    is_eingeschoben = getattr(setsong, 'eingeschoben', False)
                    feedback = getattr(setsong, 'feedback', None)

                    # Feedback-Text (Unicode-Symbole statt Emojis)
                    feedback_text = ""
                    if feedback == 1:
                        feedback_text = " [o]"  # neutral
                    elif feedback == 2:
                        feedback_text = " [+]"  # gut
                    elif feedback == 3:
                        feedback_text = " [++]"  # top

                    c.setFont(self.FONT, self.FONT_SIZE)

                    # Title mit Markierungen
                    title_prefix = "[NEU] " if is_eingeschoben else ""
                    title = f"{title_prefix}{song.title}{feedback_text}".strip()

                    # Sängerfarbe setzen
                    title_x = x + 37

                    # Tonart in schmaler, grauer Spalte direkt vor dem Titel
                    tone_key = (song.tone_key or "").strip()
                    if tone_key:
                        c.setFillColor(self.palette["muted"])
                        c.drawRightString(title_x - 8, y, tone_key)

                    c.setFillColor(color)
                    c.drawString(title_x, y, title)
                    title_width = stringWidth(title, self.FONT, self.FONT_SIZE)

                    # Bei übersprungenen Songs: durchstreichen
                    if is_uebersprungen:
                        c.saveState()
                        # In print mode den Strich bewusst dunkel zeichnen, auf Screen kontrastreicher.
                        c.setStrokeColor(self.palette.get("strike", self.palette["text"]))
                        c.setLineWidth(1.2 if self.style_mode == "print" else 1.0)
                        c.line(title_x, y - 3, title_x + title_width, y - 3)
                        c.restoreState()

                    # Song-Kommentar in Rot zwischen Titel und Dauer anzeigen
                    slot_duration = None
                    if set_pos in self.slot_durations and idx_song < len(self.slot_durations[set_pos]):
                        slot_duration = self.slot_durations[set_pos][idx_song]
                    dur = self._format_slot_duration(slot_duration) if slot_duration is not None else (
                        song.duration.strftime("%M:%S") if song.duration else "04:00"
                    )
                    duration_right_x = x + 260
                    duration_left_x = duration_right_x - stringWidth(dur, self.FONT, self.FONT_SIZE)
                    comment_text = (song.comment or "").strip()
                    if comment_text:
                        comment_left_limit = title_x + title_width + 6
                        comment_right_x = duration_left_x - 6
                        max_comment_width = comment_right_x - comment_left_limit
                        draw_comment = self._truncate_text_to_width(
                            comment_text,
                            max_comment_width,
                            self.FONT,
                            self.FONT_SIZE,
                        )
                        if draw_comment:
                            c.setFillColor(self.palette["comment"])
                            c.drawRightString(comment_right_x, y, draw_comment)

                    c.setFillColor(self.palette["muted"])
                    # Startzeit anzeigen
                    if song_time:
                        c.drawRightString(x+15, y, song_time.strftime('%H:%M'))
                    c.drawRightString(duration_right_x, y, dur)
                    if getattr(song, "brass", 0):
                        c.setFillColor(self.palette["warning"])
                        c.drawString(x+32, y, "•")
                    c.setFillColor(self.palette["text"])
                    y += self.Y_STEP

                # Pause nach dem Set anzeigen (statt vor dem naechsten Set)
                if idx < total_sets - 1:
                    pause = get_pause_before_set(gigset, gig_sets_sorted[idx + 1], self.schedule)
                    if pause:
                        c.setFont(self.FONT, self.FONT_SIZE)
                        c.setFillColor(self.palette["muted"])
                        c.drawString(x, y, f"Pause: {pause} min")
                        y += self.Y_STEP
                        c.setFillColor(self.palette["text"])

                y += int(self.Y_STEP * 1.5)  # nach dem Set

            draw_footer(page_num, total_pages)
            c.showPage()
        c.save()
        buffer.seek(0)
        return buffer
