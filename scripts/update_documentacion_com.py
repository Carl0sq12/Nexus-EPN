"""Edit the already-open Word document via COM (GetActiveObject)."""
import sys
import win32com.client

TARGET = "Nexus_Campus_Documentacion"


def get_word():
    try:
        return win32com.client.GetActiveObject("Word.Application")
    except Exception as e:
        print("No hay Word activo:", e)
        sys.exit(1)


def find_doc(word):
    preferred = None
    fallback = None
    for i in range(1, word.Documents.Count + 1):
        doc = word.Documents.Item(i)
        name = doc.Name
        print("DOC:", name)
        if TARGET.lower() not in name.lower():
            continue
        if "actualizada" in name.lower():
            fallback = doc
        else:
            preferred = doc
    return preferred or fallback


def replace_all(doc, old, new):
    rng = doc.Content
    f = rng.Find
    f.ClearFormatting()
    f.Replacement.ClearFormatting()
    # Execute with named args via late binding can be flaky; use classic pattern
    found = f.Execute(
        old,
        False,  # MatchCase
        False,  # MatchWholeWord
        False,  # MatchWildcards
        False,  # MatchSoundsLike
        False,  # MatchAllWordForms
        True,   # Forward
        1,      # Wrap = wdFindContinue
        False,  # Format
        new,    # ReplaceWith
        2,      # Replace = wdReplaceAll
    )
    return bool(found)


def replace_paragraph_containing(doc, marker, new_text):
    """Find marker and replace its whole paragraph text (keep para mark)."""
    rng = doc.Content
    f = rng.Find
    f.ClearFormatting()
    ok = f.Execute(
        marker,
        False, False, False, False, False,
        True, 1, False, "", 0,  # Find only
    )
    if not ok:
        print("NOT FOUND para:", marker[:50])
        return False
    # Expand to paragraph
    para_rng = rng.Paragraphs(1).Range
    # Exclude trailing paragraph mark
    para_rng.MoveEnd(1, -1)  # wdCharacter = 1
    para_rng.Text = new_text
    print("OK para:", marker[:50])
    return True


def ensure_trip_locations(doc):
    for t in range(1, doc.Tables.Count + 1):
        table = doc.Tables.Item(t)
        try:
            header = table.Cell(1, 1).Range.Text
            header = header.replace("\r", "").replace("\x07", "").strip().lower()
        except Exception:
            continue
        if not header.startswith("colecci"):
            continue
        for r in range(1, table.Rows.Count + 1):
            cell = table.Cell(r, 1).Range.Text
            cell = cell.replace("\r", "").replace("\x07", "").strip()
            if "trip_locations" in cell:
                print("trip_locations already in table")
                return
        row = table.Rows.Add()
        # Setting Range.Text on cells adds junk; use simpler assignment
        row.Cells(1).Range.Text = "trip_locations"
        row.Cells(2).Range.Text = (
            "Ubicacion en vivo del conductor durante la navegacion del viaje "
            "(seguimiento GPS para pasajeros)."
        )
        print("Added trip_locations row")
        return
    print("WARN: tabla de colecciones no encontrada")


def append_capabilities(doc):
    marker = "Esta organización permite separar las responsabilidades"
    extra = (
        " Entre las capacidades implementadas en la versión 1.2.13 destacan: "
        "separación entre Solicitudes (cupos) y Notificaciones (chat, fin de viaje, SOS); "
        "solicitud de cupo con parada obligatoria sobre la ruta del conductor; "
        "navegación en tiempo real con recorte de la polilínea recorrida; "
        "finalización automática al llegar al destino; calificación al llegar a la parada "
        "del pasajero; aprobación de vehículo del conductor; y autenticación biométrica "
        "para desbloquear una sesión existente."
    )
    rng = doc.Content
    f = rng.Find
    ok = f.Execute(
        marker,
        False, False, False, False, False,
        True, 1, False, "", 0,
    )
    if not ok:
        print("NOT FOUND capabilities anchor")
        return
    # Check if already appended nearby
    check = doc.Content.Text
    if "1.2.13 destacan" in check:
        print("Capabilities already present")
        return
    para_rng = rng.Paragraphs(1).Range
    para_rng.MoveEnd(1, -1)
    current = para_rng.Text
    para_rng.Text = current + extra
    print("Appended capabilities")


def main():
    print("Conectando a Word...")
    word = get_word()
    word.Visible = True
    print("Docs abiertos:", word.Documents.Count)
    doc = find_doc(word)
    if doc is None:
        print("ERROR: documento no abierto")
        sys.exit(1)
    print("Editando:", doc.FullName)

    # Full-paragraph replacements
    replace_paragraph_containing(
        doc,
        "Finalmente, el documento incluye el material audiovisual",
        "Finalmente, el documento puede complementarse con material audiovisual del proyecto "
        "(video promocional y pitch deck) cuando dicho material se incorpore como anexo a la "
        "sustentación. La versión actual de la aplicación móvil documentada corresponde a "
        "Nexus Campus 1.2.13.",
    )
    replace_paragraph_containing(
        doc,
        "Comisión mínima por viaje:",
        "Comisión mínima por viaje (proyección de negocio): porcentaje proyectado sobre cada "
        "viaje compartido para cubrir costos operativos. En la versión actual del prototipo "
        "esta comisión no se cobra automáticamente dentro de la aplicación; el precio por "
        "asiento se calcula y negocia en la app, pero no existe pasarela de pagos ni retención "
        "automática de comisión.",
    )
    replace_paragraph_containing(
        doc,
        "Para efectos de la proyección financiera, se asumió una distancia promedio de 3 km",
        "Para efectos de la proyección financiera, se asumió una distancia promedio de 3 km "
        "por viaje, obteniendo una tarifa promedio de $2.15. Asimismo, el plan de negocio "
        "proyecta una comisión del 10 % sobre el valor de cada viaje (equivalente a $0.215 "
        "por viaje en el escenario promedio). Esta comisión forma parte del modelo financiero "
        "proyectado y no está implementada como cobro automático en el código de la aplicación "
        "en su versión actual (1.2.13).",
    )
    replace_paragraph_containing(
        doc,
        "Tiendas de aplicaciones (Google Play / App Store):",
        "Tiendas de aplicaciones (Google Play / App Store): canal de distribución proyectado "
        "para el lanzamiento oficial. En la fase actual de prototipo académico la distribución "
        "se realiza principalmente mediante instalable Android (APK).",
    )
    replace_paragraph_containing(
        doc,
        "Adicionalmente, el proyecto utiliza dos buckets de almacenamiento",
        "Adicionalmente, el proyecto utiliza almacenamiento de archivos en Appwrite. El bucket "
        "avatars almacena fotografías de perfil de los usuarios. Las imágenes de vehículos y "
        "licencia se gestionan también sobre Appwrite; en el plan gratuito, cuando solo se "
        "dispone de un bucket, se reutiliza avatars con rutas del tipo vehicles/{id}.jpg. "
        "El tamaño máximo configurado es de 10 MB por archivo.",
    )
    replace_paragraph_containing(
        doc,
        "descritas en la sección 6.2.4",
        "descritas en la sección 2.4 (Manual de Despliegue), de acuerdo con lo solicitado en la "
        "guía de la actividad.",
    )
    replace_paragraph_containing(
        doc,
        "Los ingresos de Nexus Campus provienen de dos fuentes: la comisión cobrada",
        "Los ingresos proyectados de Nexus Campus provienen de dos fuentes: la comisión "
        "estimada por cada viaje realizado (modelo financiero, no cobrada aún en la app) "
        "y los convenios institucionales con universidades. El número de viajes mensuales "
        "se estima multiplicando los usuarios activos por un promedio de 8 viajes al mes "
        "(2 viajes por semana × 4 semanas), y el ingreso por comisión se obtiene "
        "multiplicando los viajes mensuales por la comisión proyectada de $0.215 por viaje. "
        "A partir del mes 6 se incorpora un convenio institucional fijo de $500 mensuales "
        "con una universidad.",
    )

    # Substring replace-all
    pairs = [
        (
            "compuesta por nueve colecciones principales",
            "compuesta por diez colecciones principales",
        ),
        (
            "equivalente funcional a un backend as a service tipo Supabase",
            "como Backend as a Service (BaaS)",
        ),
        (
            "Suscripción WebSocket a las colecciones trips y notifications",
            "Suscripción WebSocket a colecciones como trips, notifications y trip_locations",
        ),
        ("sección 6.2.4", "sección 2.4"),
    ]
    for old, new in pairs:
        ok = replace_all(doc, old, new)
        print(f"sub '{old[:40]}' -> {ok}")

    append_capabilities(doc)
    ensure_trip_locations(doc)

    doc.Save()
    print("GUARDADO:", doc.FullName)

    text = doc.Content.Text
    for c in [
        "trip_locations",
        "diez colecciones",
        "1.2.13",
        "APK",
        "sección 2.4",
        "vehicles/{id}.jpg",
        "no cobrada aún en la app",
    ]:
        print(("OK" if c in text else "MISSING"), "-", c)


if __name__ == "__main__":
    main()
