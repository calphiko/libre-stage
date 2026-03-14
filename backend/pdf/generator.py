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
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfbase.pdfmetrics import stringWidth
from datetime import datetime

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
    Y_START = 90
    Y_STEP = 15
    Y_LIMIT = 800

    def __init__(self, gig, schedule, singer_colors):
        self.gig = gig
        self.schedule = schedule
        self.singer_colors = singer_colors

    def _calc_set_height(self, gigset, set_idx):
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
        # Optional: Platz für Pause oben dran?
        if set_idx > 0:
            prev_times = self.schedule.get(self.gig.sets[set_idx-1].position, [])
            curr_times = self.schedule.get(gigset.position, [])
            if prev_times and curr_times:
                prev_end = prev_times[-1]
                curr_start = curr_times[0]
                pause = int(round((curr_start - prev_end).total_seconds() / 60))
                if pause > 0:
                    height += self.Y_STEP
        # Set-Name
        height += self.Y_STEP
        # Songs
        height += len(gigset.set.songs) * self.Y_STEP
        # Leerzeile nach Set
        height += int(self.Y_STEP * 1.5)
        return height

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

        def draw_header():
            c.setFont(title_font, 11)
            c.drawString(30, 25, f"{self.gig.name} am {self.gig.datum:%d.%m.%Y}")
            c.setFont(self.FONT, self.FONT_SIZE)
            c.drawString(30, 40, f"Stand {datetime.now():%H:%M Uhr am %d.%m.%Y}")
            # Legende
            x = 40
            c.drawString(x, 60, "Lead-Sänger: ")
            x += stringWidth("Lead-Sänger: ", self.FONT, self.FONT_SIZE)
            for singer, col in self.singer_colors.items():
                c.setFillColor(col)
                c.drawString(x, 60, singer)
                x += stringWidth(singer + " ", self.FONT, self.FONT_SIZE)
            c.setFillColor("black")

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
            h_left = self._calc_set_height(left_set, left_idx)
            h_right = self._calc_set_height(right_set, right_idx) if right_set else 0
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
                # Pause davor?
                if idx > 0:
                    prev_gigset = gig_sets_sorted[idx-1]
                    prev_set = prev_gigset.set
                    prev_times = self.schedule.get(prev_gigset.position, [])
                    curr_times = self.schedule.get(gigset.position, [])

                    if prev_times and curr_times:
                        # Startzeit des letzten Songs im vorherigen Set
                        prev_last_song_start = prev_times[-1]

                        # Dauer des letzten Songs ermitteln
                        prev_setsongs = sorted(prev_set.songs, key=lambda ss: ss.position)
                        if prev_setsongs:
                            last_song = prev_setsongs[-1].song
                            last_song_duration = last_song.duration
                            if last_song_duration:
                                from datetime import timedelta
                                duration = timedelta(
                                    hours=last_song_duration.hour if hasattr(last_song_duration, "hour") else 0,
                                    minutes=last_song_duration.minute if hasattr(last_song_duration, "minute") else 0,
                                    seconds=last_song_duration.second if hasattr(last_song_duration, "second") else 0
                                )
                            else:
                                duration = timedelta(minutes=4)

                            # Ende des vorherigen Sets = Startzeit letzter Song + Dauer
                            prev_end = prev_last_song_start + duration
                        else:
                            prev_end = prev_last_song_start

                        curr_start = curr_times[0]
                        pause_duration = (curr_start - prev_end).total_seconds() / 60
                        pause = int(round(pause_duration))

                        if pause > 0:
                            c.setFont(self.FONT, self.FONT_SIZE)
                            c.setFillColor("grey")
                            c.drawString(x, y, f"Pause: {pause} min")
                            y += self.Y_STEP
                            c.setFillColor("black")
                # Set-Überschrift
                set_obj = gigset.set
                set_pos = gigset.position
                set_name = set_obj.setlist_name or f"Set {set_pos}"
                start_times = self.schedule.get(set_pos, [])
                set_start_str = start_times[0].strftime('%H:%M') if start_times else ''
                c.setFont("Helvetica-Bold", self.FONT_SIZE)
                c.drawString(x+10, y, f"{set_name} - {set_start_str}")
                y += self.Y_STEP
                setsonglist = sorted(set_obj.songs, key=lambda ss: ss.position)
                for idx_song, setsong in enumerate(setsonglist):
                    song = setsong.song
                    song_time = start_times[idx_song] if start_times and idx_song < len(start_times) else ""
                    singer = (song.singer_lead or "").split(" ")[0]
                    color = self.singer_colors.get(singer, "black")

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
                    c.setFillColor(color)
                    c.drawString(x+35, y, title)

                    # Bei übersprungenen Songs: durchstreichen
                    if is_uebersprungen:
                        title_width = stringWidth(title, self.FONT, self.FONT_SIZE)
                        c.line(x+35, y-3, x+35+title_width, y-3)

                    c.setFillColor("grey")
                    dur = song.duration.strftime("%M:%S") if song.duration else "04:00"
                    # Startzeit anzeigen
                    if song_time:
                        c.drawRightString(x+20, y, song_time.strftime('%H:%M'))
                    c.drawRightString(x+260, y, dur)
                    if getattr(song, "brass", 0):
                        c.setFillColor("red")
                        c.drawString(x+30, y, "•")
                    c.setFillColor("black")
                    y += self.Y_STEP
                y += int(self.Y_STEP * 1.5)  # nach dem Set

            # Seitenzahl unten rechts
            c.setFont(self.FONT, self.FONT_SIZE)
            c.drawRightString(width - 30, height - 20, f"Seite {page_num}/{total_pages}")
            c.showPage()
        c.save()
        buffer.seek(0)
        return buffer
