"""Fast in-place finance fix on currently open Word docs via COM."""
import win32com.client

ROWS_VIAJES = [
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


def cell_text(cell):
    return cell.Range.Text.replace("\r", "").replace("\x07", "").strip()


def set_cell(cell, text):
    # Keep end-of-cell markers intact by replacing content carefully
    rng = cell.Range
    rng.MoveEnd(1, -1)  # exclude cell mark
    rng.Text = text


def overwrite_table(table, data_rows, ncols):
    # Ensure enough rows
    while table.Rows.Count < len(data_rows) + 1:
        table.Rows.Add()
    # Delete extras from bottom
    while table.Rows.Count > len(data_rows) + 1:
        table.Rows(table.Rows.Count).Delete()
    for r_i, values in enumerate(data_rows, start=2):
        for c_i in range(1, ncols + 1):
            set_cell(table.Cell(r_i, c_i), values[c_i - 1])


def replace_once(doc, marker, new_text):
    find = doc.Content.Find
    find.ClearFormatting()
    ok = find.Execute(FindText=marker, Forward=True, Wrap=1)
    if not ok:
        print("  miss:", marker[:60])
        return
    para = find.Parent.Paragraphs(1).Range
    para.MoveEnd(1, -1)
    para.Text = new_text
    print("  hit:", marker[:60])


def update_doc(doc):
    print("Edit:", doc.Name)
    for t in range(1, doc.Tables.Count + 1):
        table = doc.Tables.Item(t)
        h0 = cell_text(table.Cell(1, 1)).lower()
        h1 = cell_text(table.Cell(1, 2)).lower() if table.Columns.Count > 1 else ""
        h2 = cell_text(table.Cell(1, 3)).lower() if table.Columns.Count > 2 else ""
        if h0.startswith("actividad") and "costo" in h1:
            overwrite_table(table, COST_ROWS, 2)
            print("  costs table")
        elif h0 == "mes" and "viaje" in h1:
            overwrite_table(table, ROWS_VIAJES, 6)
            print("  trips table")
        elif h0 == "mes" and "ingreso" in h1 and "costo" in h2:
            overwrite_table(table, ROWS_UTIL, 4)
            print("  utilidad table")

    replace_once(
        doc,
        "Para efectos de la proyección financiera, se asumió una distancia promedio de 3 km",
        "Para efectos de la proyección financiera, se asumió una distancia promedio de 3 km "
        "por viaje, obteniendo una tarifa promedio de $2.15 (coherente con la app: $0.80 + "
        "$0.45/km, mínimo $1.00). Comisión proyectada 10% = $0.215/viaje (no cobrada aún en "
        "la app 1.2.13). Viajes mensuales = Usuarios activos × 8 / 3 (evita triple conteo: "
        "1 conductor + ~2 pasajeros por viaje).",
    )
    replace_once(
        doc,
        "Los ingresos proyectados de Nexus Campus provienen de dos fuentes: la comisión",
        "Los ingresos proyectados provienen de comisión por viaje (no cobrada aún en la app) "
        "y convenios institucionales. Viajes = Usuarios activos × 8 / 3; ingreso por comisión "
        "= Viajes × $0.215. Desde el mes 6: convenio institucional de $500 mensuales.",
    )
    replace_once(
        doc,
        "Este valor resulta sostenible al compararlo con los ingresos que genera un usuario activo",
        "El aporte mensual por usuario vía comisión es ≈ (8/3)×$0.215 ≈ $0.57. LTV 6 meses ≈ "
        "$3.4 > CAC $0.34. MRR mes 12 (comisión + convenio) ≈ $1.704.",
    )
    replace_once(
        doc,
        "El análisis muestra que Nexus Campus logra cubrir sus costos operativos desde los primeros meses",
        "Costos fijos proyectados: $162/mes (marketing $100 + infra $45 + operación $17). "
        "Punto de equilibrio ≈ 753 viajes/mes (~94 activos). Meses 1-2: pérdida $-93; mes 3: "
        "utilidad ~$44; desde mes 6, con convenio, la utilidad se fortalece.",
    )
    replace_once(
        doc,
        "Finalmente, el documento puede complementarse con material audiovisual",
        "Entregables: pitch deck en docs/Nexus_Campus_Pitch_Deck.pptx; video promocional "
        "(PENDIENTE: pegar link); README del repo con instalación/configuración/ejecución. "
        "Versión app documentada: 1.2.13.",
    )
    replace_once(
        doc,
        "Los entregables audiovisuales del examen se complementan así",
        "Entregables: pitch deck en docs/Nexus_Campus_Pitch_Deck.pptx; video promocional "
        "(PENDIENTE: pegar link); README del repo con instalación/configuración/ejecución. "
        "Versión app documentada: 1.2.13.",
    )

    doc.Save()
    print("  SAVED")


def main():
    word = win32com.client.GetActiveObject("Word.Application")
    for i in range(1, word.Documents.Count + 1):
        d = word.Documents.Item(i)
        if "nexus_campus_documentacion" in d.Name.lower():
            update_doc(d)


if __name__ == "__main__":
    main()
