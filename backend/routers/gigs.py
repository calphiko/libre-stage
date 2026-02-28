from fastapi import APIRouter, Depends, HTTPException, Response, Query
from fastapi.responses import StreamingResponse
from datetime import time
import logging
from sqlalchemy.orm import Session

from typing import List

from backend.pdf.generator import SetlistPDF
from backend.services.setlist import SetlistService
from backend.utils.check_permissions import check_admin, check_editor

from backend import models, schemas, auth

import openpyxl
from openpyxl.styles import Font, Alignment
from io import BytesIO

import os
from dotenv import load_dotenv

router = APIRouter(
    prefix="/gigs", tags=["gigs"], dependencies=[Depends(auth.get_current_user_dep)]
)

logger = logging.getLogger("uvicorn.error")
# suppress progress polls to reduce log clutter
block_endpoints = ["/gigs/log"]

load_dotenv(".env")

MM_CHANNEL = os.getenv("MM_CHANNEL_GIGS")

class LogFilter(logging.Filter):  # pragma: no cover
    def filter(self, record):
        if record.args and len(record.args) >= 3:
            if record.args[2] in block_endpoints:  # type: ignore
                return False
        return True


uvicorn_logger = logging.getLogger("uvicorn.access")
uvicorn_logger.addFilter(LogFilter())


@router.get("/", response_model=List[schemas.GigOut])
def list_gigs(
        db: Session = Depends(auth.get_db),
        current_user=Depends(auth.get_current_user),
        jahr: int = Query(None, description="Das Jahr der Gigs"),
):
    logger.info("Fetching gigs from database")
    query = db.query(models.Gig).order_by(models.Gig.datum.desc())
    if jahr is not None:
        # Wir gehen davon aus, dass 'datum' als 'YYYY-MM-DD' (Text) gespeichert ist
        query = query.filter(models.Gig.datum.startswith(str(jahr)))
    return query.all()

@router.post("/livemode_available_batch")
def get_livemode_available_batch(
    gig_ids: List[int],
    db: Session = Depends(auth.get_db),
    current_user=Depends(auth.get_current_user)
):
    """
    Batch-Endpoint: Gibt Live-Mode-Status für mehrere Gigs auf einmal zurück.
    Body: { "gig_ids": [1, 2, 3, ...] }
    Returns: { "1": {...}, "2": {...}, ... }
    """
    from datetime import date

    # Normale User haben KEINEN Zugriff
    is_admin = check_admin(current_user)
    if not is_admin:
        # Gebe für alle Gigs "not available" zurück
        return {
            str(gig_id): {
                "available": False,
                "reason": "insufficient_permissions",
                "can_force": False
            }
            for gig_id in gig_ids
        }

    # Hole alle Gigs in einem Query
    gigs = db.query(models.Gig).filter(models.Gig.id.in_(gig_ids)).all()
    gigs_by_id = {gig.id: gig for gig in gigs}

    today = date.today()
    result = {}

    for gig_id in gig_ids:
        gig = gigs_by_id.get(gig_id)

        if not gig:
            result[str(gig_id)] = {
                "available": False,
                "reason": "gig_not_found",
                "can_force": False
            }
            continue

        # gig.datum ist bereits ein date-Objekt
        gig_date = gig.datum if isinstance(gig.datum, date) else date.fromisoformat(str(gig.datum))
        is_gig_day = today == gig_date

        result[str(gig_id)] = {
            "available": is_gig_day,
            "reason": "gig_day" if is_gig_day else "not_gig_day",
            "can_force": True,
            "gig_date": gig_date.isoformat()
        }

    return result

@router.get("/{gig_id}/livemode_available")
def is_livemode_available(
    gig_id: int,
    force: bool = Query(False, description="Editor/Admin override"),
    db: Session = Depends(auth.get_db),
    current_user=Depends(auth.get_current_user)
):
    from datetime import date

    gig = db.query(models.Gig).get(gig_id)
    if not gig:
        raise HTTPException(status_code=404, detail="Gig not found")

    # Normale User haben KEINEN Zugriff
    is_editor_or_admin = check_editor(current_user)
    if not is_editor_or_admin:
        return {
            "available": False,
            "reason": "insufficient_permissions",
            "can_force": False
        }

    # Editor/Admin mit Force-Flag
    if force:
        return {
            "available": True,
            "forced": True,
            "reason": "manually_unlocked"
        }

    # Automatische Verfügbarkeit: Gig-Tag
    today = date.today()
    # gig.datum ist bereits ein date-Objekt
    gig_date = gig.datum if isinstance(gig.datum, date) else date.fromisoformat(str(gig.datum))
    is_gig_day = today == gig_date

    return {
        "available": is_gig_day,
        "reason": "gig_day" if is_gig_day else "not_gig_day",
        "can_force": True,
        "gig_date": gig_date.isoformat()
    }

@router.put("/{gig_id}", response_model=schemas.GigOut)
def update_gig(
        gig_id: int,
        gig: schemas.GigIn,
        db: Session = Depends(auth.get_db),
        current=Depends(auth.get_current_user)
):
    if not check_editor(current):
        logger.error(f"Permission denied: User {current['user_name']} is not editor")
        raise HTTPException(status_code=401, detail="User role does not allow to update a gig!")

    logger.info(f"Updating gig in database with gig_id={gig_id}")
    db_gig = db.query(models.Gig).get(gig_id)

    if not db_gig:
        raise HTTPException(status_code=404, detail="Gig not found")

    for k, v in gig.model_dump(exclude_unset=True).items():
        setattr(db_gig, k, v)
    db.commit()
    db.refresh(db_gig)

    return db_gig


def parse_name(full_name: str) -> dict:
    """
    Teilt einen vollständigen Namen in Vor- und Nachname auf.
    Falls nur ein Name vorhanden ist, wird dieser als Nachname verwendet.
    """
    if not full_name or not full_name.strip():
        return {'vorname': '', 'nachname': ''}

    # Mehrere Namen durch Komma/Semikolon getrennt -> nur ersten nehmen
    if ',' in full_name:
        full_name = full_name.split(',')[0].strip()
    elif ';' in full_name:
        full_name = full_name.split(';')[0].strip()
    elif '/' in full_name:
        full_name = full_name.split('/')[0].strip()

    parts = full_name.strip().split()

    if len(parts) == 0:
        return {'vorname': '', 'nachname': ''}
    elif len(parts) == 1:
        return {'vorname': '', 'nachname': parts[0]}
    else:
        # Letzter Teil ist Nachname, Rest ist Vorname
        return {
            'vorname': ' '.join(parts[:-1]),
            'nachname': parts[-1]
        }


@router.get("/{gig_id}/gemalist")
def download_gemalist(
        gig_id: int,
        db: Session = Depends(auth.get_db),
        current=Depends(auth.get_current_user)
):
    logger.info(f"Generating GEMA list for gig_id={gig_id}")

    # Gig laden mit allen Sets und Songs
    gig = db.query(models.Gig).filter(models.Gig.id == gig_id).first()
    if not gig:
        raise HTTPException(status_code=404, detail="Gig not found")

    # Excel-Workbook erstellen
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "GEMA-Meldung"

    # Header-Informationen (Zeilen 1-18 wie in Vorlage)
    ws['A1'] = 'Excel-Vorlage zum Hochladen von Titeln'
    ws['C1'] = 'Version: 1.2'
    ws['K1'] = 'Live'
    ws['L1'] = 'Ja'
    ws['M1'] = 'Ja'
    ws['N1'] = 'F'

    # Gig-Informationen in Kopfbereich einfügen
    ws['A18'] = 'Setlist'

    # Header-Zeile (Zeile 19)
    headers = [
        'WERKNUMMER / WERKFASSUNGSNUMMER',
        'TITEL*',
        'SATZANGABE / SONSTIGE(R) Titel',
        'ANZAHL MUSIKER / SÄNGER*',
        'SPIELDAUER* (MM:SS)',
        'INTERPRET / KOMPONIST* (Nachname)',
        'INTERPRET / KOMPONIST (Vorname)',
        'TEXTDICHTER (Nachname)',
        'TEXTDICHTER (Vorname)',
        'BEARBEITER (Nachname)',
        'BEARBEITER (Vorname)',
        'VERLAG',
        'LIVE/TONTRÄGER',
        'VERÖFFENTLICHTES WERK',
        'POTPOURRI/FRAGMENT'
    ]

    for col_idx, header in enumerate(headers, start=1):
        cell = ws.cell(row=19, column=col_idx, value=header)
        cell.font = Font(bold=True)
        cell.alignment = Alignment(wrap_text=True, vertical='top')

    # Datenzeilen ab Zeile 20
    current_row = 20

    # Alle Sets durchgehen (sortiert nach Position)
    for gigset in sorted(gig.sets, key=lambda x: x.position):
        set_obj = gigset.set

        # Alle Songs im Set durchgehen (sortiert nach Position)
        for setsong in sorted(set_obj.songs, key=lambda ss: ss.position):
            if setsong.uebersprungen:
                continue  # Übersprungene Songs nicht melden
            song = setsong.song

            # Spalte A: Werknummer (optional, leer lassen)
            ws.cell(row=current_row, column=1, value='')

            # Spalte B: TITEL* (Pflichtfeld)
            ws.cell(row=current_row, column=2, value=song.title or '')

            # Spalte C: SATZANGABE (optional)
            ws.cell(row=current_row, column=3, value='')

            # Spalte D: ANZAHL MUSIKER (optional, kann leer bleiben bei Pop/Rock)
            ws.cell(row=current_row, column=4, value='')

            # Spalte E: SPIELDAUER* (MM:SS) (Pflichtfeld)
            if song.duration:
                if isinstance(song.duration, time):
                    duration_str = song.duration.strftime("%M:%S")
                else:
                    duration_str = "00:00"
            else:
                duration_str = "00:00"
            ws.cell(row=current_row, column=5, value=duration_str)

            # Spalte F: INTERPRET / KOMPONIST* Nachname (Pflichtfeld)
            # Composer aufteilen in Vor- und Nachname
            composer_parts = parse_name(song.composer)
            ws.cell(row=current_row, column=6, value=composer_parts['nachname'])

            # Spalte G: INTERPRET / KOMPONIST Vorname
            ws.cell(row=current_row, column=7, value=composer_parts['vorname'])

            # Spalte H: TEXTDICHTER Nachname
            texter_parts = parse_name(song.texter)
            ws.cell(row=current_row, column=8, value=texter_parts['nachname'])

            # Spalte I: TEXTDICHTER Vorname
            ws.cell(row=current_row, column=9, value=texter_parts['vorname'])

            # Spalte J: BEARBEITER Nachname
            arrangement_parts = parse_name(song.arrangement)
            ws.cell(row=current_row, column=10, value=arrangement_parts['nachname'])

            # Spalte K: BEARBEITER Vorname
            ws.cell(row=current_row, column=11, value=arrangement_parts['vorname'])

            # Spalte L: VERLAG
            ws.cell(row=current_row, column=12, value=song.publisher or '')

            # Spalte M: LIVE/TONTRÄGER
            ws.cell(row=current_row, column=13, value='Live')

            # Spalte N: VERÖFFENTLICHTES WERK (J/N)
            ws.cell(row=current_row, column=14, value='J')

            # Spalte O: POTPOURRI/FRAGMENT (J/N)
            ws.cell(row=current_row, column=15, value='N')

            current_row += 1

    # Spaltenbreiten anpassen
    ws.column_dimensions['A'].width = 15
    ws.column_dimensions['B'].width = 40
    ws.column_dimensions['C'].width = 30
    ws.column_dimensions['D'].width = 12
    ws.column_dimensions['E'].width = 15
    ws.column_dimensions['F'].width = 20
    ws.column_dimensions['G'].width = 20
    ws.column_dimensions['H'].width = 20
    ws.column_dimensions['I'].width = 20
    ws.column_dimensions['J'].width = 20
    ws.column_dimensions['K'].width = 20
    ws.column_dimensions['L'].width = 25
    ws.column_dimensions['M'].width = 15
    ws.column_dimensions['N'].width = 18
    ws.column_dimensions['O'].width = 18

    # Excel in Memory speichern
    output = BytesIO()
    wb.save(output)
    output.seek(0)

    # Dateiname mit Gig-Informationen
    filename = f"GEMA_Meldung_{gig.name}_{gig.datum.strftime('%Y-%m-%d')}.xlsx"

    return StreamingResponse(
        output,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )


@router.get("/{gig_id}/setlist.pdf", response_class=Response)
def download_setlist(gig_id: int, db: Session = Depends(auth.get_db), current=Depends(auth.get_current_user)):
    logger.info(f"Generating setlist PDF for gig_id={gig_id}")
    service = SetlistService(db)  # <- sync Session
    gig = service.load_gig(gig_id)
    #gig.debug_dump()

    if not gig:
        logger.error(f"Gig with id={gig_id} not found for PDF generation")
        raise HTTPException(status_code=404, detail="Gig not found")

    schedule = service.calc_schedule(gig)

    service.dump_gig_struct(gig)

    # Dynamische Sänger-Farben: Farben werden aus einer Palette zugewiesen
    SINGER_COLOR_PALETTE = [
        "#29B619", "#227FFF", "#E644C3", "#FF8C00", "#8B5CF6",
        "#059669", "#DC2626", "#CA8A04", "#0891B2", "#6366F1",
    ]

    singers = sorted({
        (setsong.song.singer_lead or "").replace("+"," ").replace(",", " ").split(" ")[0]
        for gs in gig.sets
        for setsong in gs.set.songs
        if setsong.song.singer_lead
    })

    singer_colors = {
        singer: SINGER_COLOR_PALETTE[i % len(SINGER_COLOR_PALETTE)]
        for i, singer in enumerate(singers)
    }

    pdf_bytes = SetlistPDF(gig, schedule, singer_colors).build().getvalue()
    headers = {"Content-Disposition": f"inline; filename=Setliste_{gig.name}.pdf"}
    return Response(
        pdf_bytes,
        media_type="application/pdf",
        headers=headers
    )


@router.get("/{gig_id}/setlist", response_model=schemas.GigSetlistOut)
def get_gig_setlist(
    gig_id: int,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user)
):
    logger.info(f"Fetching gig setlist from database with gig_id={gig_id}")
    gig = db.query(models.Gig).get(gig_id)
    if not gig:
        logger.error(f"Gig with id={gig_id} not found")
        raise HTTPException(status_code=404, detail="Gig not found")

    # Prüfe auf korrupte SetSongs (ohne Song-Referenz) und entferne sie
    for gigset in gig.sets:
        set_obj = gigset.set
        corrupted_setsongs = [ss for ss in set_obj.songs if not ss.song]
        if corrupted_setsongs:
            logger.warning(f"Found {len(corrupted_setsongs)} corrupted SetSongs in Set {set_obj.id}, removing them")
            for ss in corrupted_setsongs:
                db.delete(ss)
            db.commit()

    return gig.to_dict()  # siehe vorige Antwort

# @app.put("/append_song_to_set", response_model=schemas.GigSetlistOut)
# def append_song_to_set(
#     data: schemas.SongToSetIn,
#     db: Session = Depends(auth.get_db),
#     current=Depends(auth.get_current_user)
# ):
#     db_gig = db.query(models.Gig).filter_by(id=data.gigId).first()
#     print(f"Appending {data.sondId} to {data.setId} on position {data.position}!")
#     return db_gig


@router.put("/{gig_id}/update_setlist/", response_model=schemas.GigSetlistOut)
def update_gig_setlist(
    gig_id: int,
    gig: schemas.GetSetlistIn,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user)
):
    logger.info(f"Updating gig setlist in database with gig_id={gig_id}")
    db_gig = db.query(models.Gig).filter_by(id=gig_id).first()
    if not db_gig:
        logger.error(f"Gig with id={gig_id} not found for setlist update")
        raise HTTPException(status_code=404, detail="Gig not found")

    if not check_editor(current):
        logger.error(f"Permission denied: User {current['user_name']} is not editor")
        raise HTTPException(status_code=403, detail="Not enough permissions")

    # Aktuelle Sets des Gigs
    old_gigsets = db.query(models.GigSet).filter_by(id_gig=gig_id).all()
    existing_sets = {gs.set.id: gs.set for gs in old_gigsets}
    old_gigset_ids = [gs.id for gs in old_gigsets]

    # Input-Set-IDs und -Songs extrahieren
    input_set_ids = set(sd.set_id for sd in gig.sets if getattr(sd, 'set_id', None))

    # 1. Entferne nur GigSet-Verknüpfungen, die im neuen Input fehlen
    for gigset in old_gigsets:
        if gigset.set.id not in input_set_ids:
            db.delete(gigset)
    db.commit()

    # 2. Sets löschen, die nicht mehr genutzt werden
    for set_id in existing_sets:
        if set_id not in input_set_ids:
            db.query(models.SetSong).filter_by(id_set=set_id).delete()
            db.query(models.Set).filter_by(id=set_id).delete()
    db.commit()

    # 3. Update/Erstelle Sets und Songs
    new_gigsets = []
    for set_pos, set_data in enumerate(gig.sets, start=1):
        # Existierendes Set, falls vorhanden
        if getattr(set_data, 'set_id', None) and set_data.set_id in existing_sets:
            set_obj = existing_sets[set_data.set_id]
            # Update Eigenschaften des Sets
            set_obj.name = set_data.set_name
            set_obj.pause = time.fromisoformat(set_data.pause) if set_data.pause else None
            set_obj.setlist_name = set_data.setlist_name
            db.flush()

            # Speichere Live-Mode-Daten der bestehenden SetSongs
            old_setsongs = db.query(models.SetSong).filter_by(id_set=set_obj.id).all()
            livemode_data = {}  # Key: song_id, Value: {eingeschoben, uebersprungen, feedback}
            for old_ss in old_setsongs:
                livemode_data[old_ss.id_song] = {
                    'eingeschoben': old_ss.eingeschoben,
                    'uebersprungen': old_ss.uebersprungen,
                    'feedback': old_ss.feedback
                }

            # Update Songs im Set: Entferne alle alten, füge neue hinzu
            db.query(models.SetSong).filter_by(id_set=set_obj.id).delete()
        else:
            # Neues Set anlegen
            set_obj = models.Set(
                name=set_data.set_name,
                pause=time.fromisoformat(set_data.pause) if set_data.pause else None,
                setlist_name=set_data.setlist_name,
            )
            db.add(set_obj)
            db.flush()
            livemode_data = {}  # Keine alten Daten bei neuem Set

        # Jetzt Songs der Reihe nach neu anlegen
        for song_pos, song_data in enumerate(set_data.songs, start=1):
            song = db.query(models.Song).filter_by(id=song_data.song_id).first()
            if not song:
                raise HTTPException(status_code=400, detail=f"Song not found")

            # Hole alte Live-Mode-Daten wenn vorhanden
            old_data = livemode_data.get(song.id, {})

            setsong = models.SetSong(
                id_set=set_obj.id,
                id_song=song.id,
                position=song_pos,
                eingeschoben=old_data.get('eingeschoben'),
                uebersprungen=old_data.get('uebersprungen'),
                feedback=old_data.get('feedback')
            )
            db.add(setsong)

        # GigSet-Verknüpfung erneuern
        gigset = db.query(models.GigSet).filter_by(id_gig=db_gig.id, id_set=set_obj.id).first()
        if not gigset:
            gigset = models.GigSet(
                id_gig=db_gig.id,
                id_set=set_obj.id,
                position=set_pos
            )
            db.add(gigset)
        else:
            gigset.position = set_pos
        new_gigsets.append(gigset)

    db.commit()
    db.refresh(db_gig)
    return gig

@router.post("/")
def create_new_gig(
    gig: schemas.NewGig,
    jahr = Query(None, description="Das Jahr der Gigs"),
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user)
):
    logger.info(f"Creating new gig in database with name={gig.name}")
    if not check_editor(current):
        logger.error(f"Permission denied: User {current['user_name']} is not admin or editor")
        raise HTTPException(status_code=401, detail="User role does not allow to create a new gig!")

    gig_to_add = models.Gig(
        name=gig.name,
        datum=gig.datum,
        kind_of_gig=gig.kind_of_gig,
        organizer=gig.organizer,
        venue=gig.venue,
        doors=gig.doors,
        begin=gig.begin,
        end=gig.end,
        status=gig.status,
        publish=False,
    )
    db.add(gig_to_add)
    db.commit()

    query = db.query(models.Gig).order_by(models.Gig.datum.desc())
    if jahr is not None:
        query = query.filter(models.Gig.datum.startswith(str(jahr)))

    # Mattermost notification
    try:
        from backend.utils import mattermost
        message = f":mega: Es wurde soeben ein neuer Gig erstellt:\n\tName: **{gig.name}**\n\tDatum: **{gig.datum.strftime('%d.%m.%Y')}**"
        if gig.begin:
            message += f"\n\tBeginn: **{gig.begin.strftime('%H:%M Uhr')}**"
        if gig.end:
            message += f"\n\tEnde: **{gig.end.strftime('%H:%M Uhr')}**"
        if gig.venue:
            message += f"\n\tOrt: **{gig.venue}**"
        if gig.organizer:
            message += f"\n\tVeranstalter: **{gig.organizer}**"
        mattermost.send_mm_message(channel=MM_CHANNEL, text=message)
    except Exception as e:
        logger.error(f"Failed to send Mattermost message: {e}")

    return query.all()

@router.delete("/{gig_id}", response_model=List[schemas.GigOut])
def delete_gig(
    gig_id: int,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user)
):
    logger.info(f"Deleting gig in database with gig_id={gig_id}")
    if not check_editor(current):
        logger.error(f"Permission denied: User {current['user_name']} is not admin or editor")
        raise HTTPException(status_code=401, detail="User role does not allow to delete a gig!")

    gig_to_del = db.query(models.Gig).get(gig_id)
    if not gig_to_del:
        logger.error(f"Gig with id={gig_id} not found for deletion")
        raise HTTPException(status_code=404, detail="Gig not found")

    for gs in list(gig_to_del.sets):
        logger.info("Deleting Gigset")
        # DELETE ALL SETS
        db.delete(gs)
    # DELETE GIG
    db.delete(gig_to_del)
    db.commit()

    query = db.query(models.Gig).order_by(models.Gig.datum.desc())
    jahr = None
    if jahr is not None:
        query = query.filter(models.Gig.datum.startswith(str(jahr))) # pragma: no cover

    # Mattermost notification
    try:
        from backend.utils import mattermost
        message = f":mega: Der Gig **{gig_to_del.name}** am **{gig_to_del.datum.strftime('%d.%m.%Y')}** wurde abgesagt."
        mattermost.send_mm_message(channel=MM_CHANNEL, text=message)
    except Exception as e:
        logger.error(f"Failed to send Mattermost message: {e}")

    return query.all()


@router.get("/{gig_id}/setlist_available")
def is_setlist_available(
    gig_id: int,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user)
):
    logger.info(f"Checking if setlist is available for gig_id={gig_id}")
    gig = db.query(models.Gig).get(gig_id)
    if not gig:
        logger.error(f"Gig with id={gig_id} not found for setlist availability check")
        raise HTTPException(status_code=404, detail="Gig not found")

    set_available = len(gig.sets) > 0
    setsong_available = any(len(gs.set.songs) > 0 for gs in gig.sets)
    is_available = set_available and setsong_available
    logger.info(f"Setlist availability for gig_id={gig_id}: {is_available}")
    return {"setlist_available": is_available}

