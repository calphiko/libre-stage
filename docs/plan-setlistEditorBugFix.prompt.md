# Plan: Setlist-Editor – Bug „Zweites Set erscheint erst nach Refresh"

## Problembeschreibung

Wenn man zwei Sets hintereinander hinzufügt (über „+ Set"), wird das zweite Set erst nach
einem Browser-Refresh korrekt angezeigt und der Editor funktioniert danach nicht mehr sauber
(DnD kaputt, Songs lassen sich nicht mehr verschieben).

---

## Ursachenanalyse

### Root Cause: `gigset_id` ist `undefined` nach dem ersten Set-Hinzufügen

Das `{#each}`-Template in `SetList.svelte` (Z. 181) nutzt `gigset_id` als reaktiven Key:

```svelte
{#each setlist.sets as set, setIdx (set.gigset_id)}
```

Der Ablauf beim Hinzufügen eines Sets:

1. Ein neues Set-Objekt wird **lokal** erstellt – ohne `gigset_id` (ist `undefined`).
2. Die Funktion `addSetAtEnd()` / `insertSetBefore()` ruft `updateSetlist(setlist)` auf –
   **aber ohne `await`** und **ohne das Ergebnis zurückzuschreiben**.
3. Der API-Call gibt die Setliste mit echten `gigset_id`s zurück – diese werden **verworfen**.
4. Im DOM existiert nun ein Set mit `key = undefined`. Svelte kann es nicht eindeutig
   identifizieren.
5. Klickt man auf „+ Set" ein zweites Mal, kollidieren zwei Sets mit `key = undefined` →
   Svelte-Reaktivität bricht, DnD-Zustand ist inkonsistent.

### Weiteres Problem in `+page.svelte`

Die exportierte `updateSetlist`-Funktion in `+page.svelte` (Z. 104–107) ist broken:

```js
export async function updateSetlist(data) {
    console.log("Data für API-Call:", data);
    updateGigSetlist(null, data);  // ← falsche Argumente, kein await, kein return
}
```

Diese Funktion wird nicht verwendet (SetList.svelte hat eine eigene `updateSetlist`),
ist aber irreführend und fehleranfällig.

---

## Betroffene Dateien

| Datei | Problem |
|---|---|
| `src/routes/setlist_editor/SetList.svelte` | `insertSetBefore`, `addSetAtEnd`, `removeSet` – kein `await`, Ergebnis wird nicht zurückgeschrieben |
| `src/routes/setlist_editor/+page.svelte` | `updateSetlist` – falsche Argumente, kein `await`, kein `return` |

---

## Fix-Schritte

### ✅ Schritt 1 – `SetList.svelte`: `insertSetBefore` async machen

```js
// VORHER
function insertSetBefore(idx) {
    const newSet = { songs: [], pause: '00:10:00' };
    setlist.sets.splice(idx, 0, newSet);
    setlist = { ...setlist };
    updateSetlist(setlist);          // fire-and-forget, Ergebnis verworfen
}

// NACHHER
async function insertSetBefore(idx) {
    const newSet = { songs: [], pause: '00:10:00' };
    setlist.sets.splice(idx, 0, newSet);
    setlist = { ...setlist };
    const updated = await updateSetlist(setlist);
    if (updated) setlist = updated;  // echte gigset_id zurückschreiben
}
```

### ✅ Schritt 2 – `SetList.svelte`: `addSetAtEnd` async machen

```js
// VORHER
function addSetAtEnd() {
    const newSet = { songs: [], pause: '00:10:00', setlist_name: '', set_name: '' };
    setlist.sets.push(newSet);
    setlist = { ...setlist };
    updateSetlist(setlist);

// NACHHER
async function addSetAtEnd() {
    const newSet = { songs: [], pause: '00:10:00', setlist_name: '', set_name: '' };
    setlist.sets.push(newSet);
    setlist = { ...setlist };
    const updated = await updateSetlist(setlist);
    if (updated) setlist = updated;
}
```

### ✅ Schritt 3 – `SetList.svelte`: `removeSet` async machen

```js
// VORHER
function removeSet(setIdx) {
    setlist.sets.splice(setIdx, 1);
    setlist = { ...setlist };
    updateSetlist(setlist);

// NACHHER
async function removeSet(setIdx) {
    setlist.sets.splice(setIdx, 1);
    setlist = { ...setlist };
    const updated = await updateSetlist(setlist);
    if (updated) setlist = updated;
}
```

### ✅ Schritt 4 – `+page.svelte`: Kaputte `updateSetlist`-Funktion entfernen

Die exportierte `updateSetlist`-Funktion (Z. 104–107) wird nicht verwendet und hat falsche
Argumente. Sie sollte entfernt werden:

```js
// ENTFERNEN:
export async function updateSetlist(data) {
    console.log("Data für API-Call:", data);
    updateGigSetlist(null, data);
}
```

---

## Warum das reicht

- Nach `addSetAtEnd()` enthält `setlist` jetzt die Server-Antwort mit echten `gigset_id`s.
- Der `{#each ... (set.gigset_id)}`-Key ist immer eindeutig.
- Das zweite Set bekommt sofort seine eigene ID → kein Konflikt, kein Refresh nötig.
- DnD (`svelte-dnd-action`) arbeitet weiterhin mit `setsong_id` als Key – das ist
  unberührt und bleibt korrekt.

## ✅ Eigentlicher Root Cause: Backend gibt Input-Objekt statt DB-Entität zurück

Die Frontend-Fixes (Schritte 1–4 + `$bindable`) waren notwendig, aber nicht ausreichend.
Der wahre Bug lag im **Backend**:

**`backend/routers/gigs.py`, Zeile 756:**
```python
# VORHER – gibt das Pydantic INPUT-Objekt zurück (ohne echte gigset_id/set_id)
db.commit()
db.refresh(db_gig)
return gig            # ← gig = Input-Schema, NICHT die DB-Entität!

# NACHHER – gibt die aktualisierte DB-Entität mit echten IDs zurück
db.commit()
db.refresh(db_gig)
return db_gig.to_dict()  # ← enthält echte gigset_id, set_id, setsong_id
```

**Warum das der eigentliche Root Cause war:**
- `to_dict()` serialisiert `gigset.id` als `gigset_id` und `gigset.set.id` als `set_id`
- Das Input-Objekt (`gig`) enthält für neue Sets `gigset_id=None` und `set_id=None`
- Selbst mit `$bindable` + `await` erhielt das Frontend nie echte IDs zurück
- Der `{#each ... (set.gigset_id)}`-Key war bei neuen Sets immer `undefined/null`


1. ✅ **`handleSongsFinalize`** (Z. 51–56) schreibt das `updateSetlist`-Ergebnis ebenfalls
   nicht zurück – ggf. gleicher Fix nötig. → **Umgesetzt.**
2. ✅ **Race Condition:** Wenn der User schnell zwei Sets klickt, könnten zwei API-Calls
   parallel laufen. Die Buttons könnten während `isUpdating === true` disabled werden,
   um das zu verhindern (`disabled={isUpdating}` an den „+ Set"-Buttons). → **Umgesetzt.**

