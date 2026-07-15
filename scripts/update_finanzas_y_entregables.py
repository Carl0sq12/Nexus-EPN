"""Correct financial tables/narrative in open Word + note pitch/README/video."""
import sys

import win32com.client

# Corrected model:
# - Fare matches app: 0.80 + 0.45/km, min 1.00 → 3km = 2.15
# - Commission 10% projected = 0.215 / trip (not charged in app yet)
# - Trips/month = active_users * 8 / 3  (each trip involves ~3 participants)
# - Fixed opex = 162/month (100 marketing + 45 infra + 17 ops)

ROWS_VIAJES = [
    # mes, viajes, comision, ing_com, convenio, total
    ("1-2", "320", "$0.215", "$69", "$0", "$69"),
    ("3", "960", "$0.215", "$206", "$0", "$206"),
    ("6", "2 880", "$0.215", "$619", "$500", "$1 119"),
    ("9", "4 480", "$0.215", "$963", "$500", "$1 463"),
    ("12", "5 600", "$0.215", "$1 204", "$500", "$1 704"),
]

ROWS_UTIL = [
    ("1-2", "69", "162", "-93"),
    ("3", "206", "162", "44"),
    ("6", "1 119", "162", "957"),
    ("9", "1 463", "162", "1 301"),
    ("12", "1 704", "162", "1 542"),
]

COST_ROWS = [
    ("Publicidad en redes sociales (Instagram, Facebook, TikTok)", "$100"),
    ("Infraestructura Appwrite / cloud (plan proyectado)", "$45"),
    ("Herramientas, dominio y operación menor", "$17"),
    ("Total mensual (costos fijos proyectados)", "$162"),
]


def get_doc():
    word = win32com.client.GetActiveObject("Word.Application")
    preferred = None
    fallback = None
    for i in range(1, word.Documents.Count + 1):
        d = word.Documents.Item(i)
        name = d.Name.lower()
        print("DOC:", d.Name)
        if "nexus_campus_documentacion" not in name:
            continue
        if "actualizada" in name or "backup" in name:
            fallback = d
        else:
            preferred = d
    doc = preferred or fallback
    if doc is None:
        raise SystemExit("Documento Nexus no abierto")
    return word, doc


def set_cell(cell, text):
    cell.Range.Text = text


def find_table_by_header(doc, first_cell_contains):
    needle = first_cell_contains.lower()
    for t in range(1, doc.Tables.Count + 1):
        table = doc.Tables.Item(t)
        try:
            h = table.Cell(1, 1).Range.Text
            h = h.replace("\r", "").replace("\x07", "").strip().lower()
        except Exception:
            continue
        if needle in h:
            return table
    return None


def replace_paragraph_containing(doc, marker, new_text):
    rng = doc.Content
    f = rng.Find
    ok = f.Execute(
        marker,
        False,
        False,
        False,
        False,
        False,
        True,
        1,
        False,
        "",
        0,
    )
    if not ok:
        print("NOT FOUND:", marker[:70])
        return False
    para_rng = rng.Paragraphs(1).Range
    para_rng.MoveEnd(1, -1)
    para_rng.Text = new_text
    print("OK:", marker[:70])
    return True


def replace_all(doc, old, new):
    rng = doc.Content
    f = rng.Find
    return bool(
        f.Execute(
            old,
            False,
            False,
            False,
            False,
            False,
            True,
            1,
            False,
            new,
            2,
        )
    )


def update_cost_table(doc):
    table = find_table_by_header(doc, "actividad")
    if table is None:
        print("WARN: cost table not found")
        return
    # Rebuild data rows: keep header, delete extras, add 4 rows
    while table.Rows.Count > 1:
        table.Rows(2).Delete()
    for actividad, costo in COST_ROWS:
        row = table.Rows.Add()
        set_cell(row.Cells(1), actividad)
        set_cell(row.Cells(2), costo)
    print("Updated cost table -> $162")


def update_income_table(doc):
    table = find_table_by_header(doc, "mes")
    # Prefer the one with Viajes mensuales in header row col2
    found = None
    for t in range(1, doc.Tables.Count + 1):
        table = doc.Tables.Item(t)
        try:
            c2 = table.Cell(1, 2).Range.Text.replace("\r", "").replace("\x07", "")
        except Exception:
            continue
        if "viaje" in c2.lower():
            found = table
            break
    if found is None:
        print("WARN: income table not found")
        return
    while found.Rows.Count > 1:
        found.Rows(2).Delete()
    for row_data in ROWS_VIAJES:
        row = found.Rows.Add()
        for i, val in enumerate(row_data, 1):
            set_cell(row.Cells(i), val)
    print("Updated income/trips table")


def update_util_table(doc):
    found = None
    for t in range(1, doc.Tables.Count + 1):
        table = doc.Tables.Item(t)
        try:
            c2 = table.Cell(1, 2).Range.Text.replace("\r", "").replace("\x07", "")
            c3 = table.Cell(1, 3).Range.Text.replace("\r", "").replace("\x07", "")
        except Exception:
            continue
        if "ingreso" in c2.lower() and "costo" in c3.lower():
            found = table
            break
    if found is None:
        print("WARN: utilidad table not found")
        return
    while found.Rows.Count > 1:
        found.Rows(2).Delete()
    for row_data in ROWS_UTIL:
        row = found.Rows.Add()
        for i, val in enumerate(row_data, 1):
            set_cell(row.Cells(i), val)
    print("Updated utilidad table")


def main():
    word, doc = get_doc()
    print("Editando:", doc.FullName)

    # Cost list paragraphs under estructura de costos (optional list items)
    # Narrative replacements
    replace_paragraph_containing(
        doc,
        "Asimismo, se estimó que, del total de usuarios registrados, aproximadamente el 60 %",
        "Asimismo, se estimó que, del total de usuarios registrados, aproximadamente el 60 % "
        "utilizará la aplicación de manera activa cada mes. Con base en este supuesto, se calculó "
        "la cantidad de usuarios activos mensuales mediante: Usuarios activos = Usuarios "
        "registrados × 0,60.",
    )

    replace_paragraph_containing(
        doc,
        "Para efectos de la proyección financiera, se asumió una distancia promedio de 3 km",
        "Para efectos de la proyección financiera, se asumió una distancia promedio de 3 km "
        "por viaje, obteniendo una tarifa promedio de $2.15 (coherente con la fórmula "
        "implementada en la app: $0.80 + $0.45/km, mínimo $1.00). El plan de negocio proyecta "
        "una comisión del 10 % sobre el valor de cada viaje ($0.215 en el escenario promedio). "
        "Esta comisión es del modelo financiero y no se cobra automáticamente en la versión "
        "actual (1.2.13). Los viajes mensuales se estiman como: Viajes = Usuarios activos × 8 "
        "/ 3, porque cada viaje involucra en promedio un conductor y dos pasajeros; así se "
        "evita contar tres veces el mismo viaje cuando varios usuarios activos participan.",
    )

    replace_paragraph_containing(
        doc,
        "Este valor resulta sostenible al compararlo con los ingresos que genera un usuario activo",
        "Este valor resulta sostenible al compararlo con el aporte económico de un usuario activo. "
        "Si cada usuario participa en promedio en 8 viajes al mes y cada viaje involucra ~3 "
        "participantes, el aporte mensual por usuario vía comisión es aproximadamente "
        "(8/3) × $0.215 ≈ $0.57. En 6 meses el LTV aproximado es ~$3.4, superior al CAC de "
        "$0.34. El MRR proyectado en el mes 12 (comisión + convenio) alcanza ~$1.704.",
    )

    replace_paragraph_containing(
        doc,
        "Los ingresos proyectados de Nexus Campus provienen de dos fuentes: la comisión",
        "Los ingresos proyectados de Nexus Campus provienen de dos fuentes: la comisión "
        "estimada por cada viaje realizado (modelo financiero, no cobrada aún en la app) "
        "y los convenios institucionales con universidades. El número de viajes mensuales "
        "se estima con Viajes = Usuarios activos × 8 / 3. El ingreso por comisión es "
        "Viajes × $0.215. A partir del mes 6 se incorpora un convenio institucional fijo "
        "de $500 mensuales.",
    )

    replace_paragraph_containing(
        doc,
        "El análisis muestra que Nexus Campus logra cubrir sus costos operativos desde los primeros meses",
        "Con costos fijos proyectados de $162 mensuales (marketing $100 + infraestructura $45 + "
        "operación $17), el punto de equilibrio se alcanza cerca de 753 viajes/mes "
        "(≈ 94 usuarios activos). En la proyección corregida, el primer bimestre aún presenta "
        "pérdida operativa ($-93), el mes 3 alcanza utilidad positiva (~$44) y desde el mes 6, "
        "con el convenio institucional, la utilidad se fortalece de forma consistente.",
    )

    # Intro audiovisual + entregables
    replace_paragraph_containing(
        doc,
        "Finalmente, el documento puede complementarse con material audiovisual",
        "Los entregables audiovisuales del examen se complementan así: el pitch deck está "
        "en docs/Nexus_Campus_Pitch_Deck.pptx del repositorio; el video promocional se "
        "anexa mediante el enlace oficial del equipo (actualizar aquí cuando esté disponible). "
        "El README del repositorio describe instalación, configuración y ejecución. "
        "La versión documentada de la app es Nexus Campus 1.2.13.",
    )
    # If previous wording still present
    replace_paragraph_containing(
        doc,
        "Finalmente, el documento incluye el material audiovisual",
        "Los entregables audiovisuales del examen se complementan así: el pitch deck está "
        "en docs/Nexus_Campus_Pitch_Deck.pptx del repositorio; el video promocional se "
        "anexa mediante el enlace oficial del equipo (actualizar aquí cuando esté disponible). "
        "El README del repositorio describe instalación, configuración y ejecución. "
        "La versión documentada de la app es Nexus Campus 1.2.13.",
    )

    # Fix leftover marketing-only $100 if listed as unique total
    replace_all(
        doc,
        "se estableció un presupuesto mensual fijo de $100, destinado a la ejecución de campañas",
        "se estableció un presupuesto de adquisición de $100 mensuales dentro de una estructura "
        "de costos fijos de $162 (marketing $100, infraestructura proyectada $45 y operación $17), "
        "destinado a campañas",
    )

    update_cost_table(doc)
    update_income_table(doc)
    update_util_table(doc)

    doc.Save()
    print("GUARDADO:", doc.FullName)

    text = doc.Content.Text
    for c in ["$1 119", "$162", "8 / 3", "Pitch_Deck", "0.57", "753"]:
        print(("OK" if c in text else "MISSING"), c)


if __name__ == "__main__":
    main()
