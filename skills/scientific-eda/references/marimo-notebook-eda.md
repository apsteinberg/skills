# EDA in a Marimo notebook

When exploratory data analysis under this skill is done in a **marimo notebook** (rather than with scripts in `scripts/`), the notebook lives at the **analysis folder root** and the same workflow applies (context first, one step, lab notebook, ask why).

## Notebook placement

Marimo notebooks (`.py` files) are primary analytical artifacts and live at the root of the analysis folder, not inside `scripts/`. For example:

```text
analyses/260315-260120_APS052_somatic_sv_exploration/
  lab_notebook.md
  plots/
  scripts/
  sv_haplotypes.py          # marimo notebook
```

## Cell ordering convention

Marimo notebooks follow a consistent cell ordering at the top of the notebook:

1. **First cell: all package imports.** Every `import` statement goes here. When a new dependency is needed later, add it to this cell rather than importing inline elsewhere.
2. **Second cell (after the analysis goal markdown): paths and variables.** Define all file paths, directory locations, and key configuration variables in one place. This makes it easy to adapt the notebook to different data without hunting through cells. **All plot output paths must be defined here** so they are visible and easily editable at the top of the notebook.

This mirrors the convention used in Rmarkdown notebooks (packages block, then paths block) and keeps the notebook's dependencies and data sources immediately visible at the top.

## Code visibility: never hide code by default

Code cells must show their code. **Do not hide code** — an EDA notebook is a transparent record of exactly what was run, and collapsing the code defeats that purpose. When creating cells programmatically (e.g. via the marimo-pair `code_mode` API), `create_cell` defaults to `hide_code=True`; this convention overrides that default. Always create cells with `hide_code=False`, and if any cell ends up hidden, set it back to visible with `edit_cell(cell_id, hide_code=False)`.

The only acceptable exception is purely presentational markdown cells, and even those may be left visible — when in doubt, show the code.

## Variable reassignment

Marimo does **not** allow variable reassignment across cells. The correct way to handle this is to **wrap logic in functions** within the cell. Do **not** use underscore-prefixed variables (e.g., `_df`) to work around this restriction — that is an anti-pattern. Instead:

```python
# GOOD: wrap in a function
@app.cell
def _(raw_df):
    def filter_data(df):
        df = df[df["quality"] > 30]
        df = df.drop_duplicates(subset=["sample_id"])
        return df

    filtered_df = filter_data(raw_df)
    return (filtered_df,)

# BAD: underscore prefix hack
@app.cell
def _(raw_df):
    _df = raw_df[raw_df["quality"] > 30]
    _df = _df.drop_duplicates(subset=["sample_id"])
    filtered_df = _df
    return (filtered_df,)
```

## Plots: save WebP artifact + emit `mo.image` for inline display

Every plot in a marimo notebook must:

1. **Save a WebP artifact** to the analysis `plots/` directory at **dpi ≥ 300** (publication resolution).
2. **Emit a self-contained `mo.image(png_bytes)`** as the cell output so it renders inline **and survives HTML export**.

**Do not just return the matplotlib `fig` object.** It renders in the live app but marimo's HTML export (`auto_download=["html"]` / `marimo export html`) **drops** the auto-rendered figure — the user opens the exported HTML and the images are missing. Instead, render the figure to in-memory PNG bytes and return `mo.image(...)`, which bakes the image into the HTML as base64.

Use two DPIs on purpose: **300** for the saved WebP artifact (publication), and a lighter **~120 view-dpi** for the inline PNG so the exported HTML does not balloon to hundreds of MB.

The plot output path must be defined in the **paths cell at the top** of the notebook (cell 2), not inline in the plotting cell.

```python
# In the imports cell (cell 1): import io, marimo as mo, matplotlib.pyplot as plt

# A shared render() helper (define once, return it for downstream plot cells):
@app.cell
def _(io, mo, plt):
    def render(fig, webp_path, save_dpi=300, view_dpi=120):
        fig.savefig(webp_path, format="webp", dpi=save_dpi, bbox_inches="tight")
        buf = io.BytesIO()
        fig.savefig(buf, format="png", dpi=view_dpi, bbox_inches="tight")
        plt.close(fig)
        return mo.image(buf.getvalue())
    return (render,)

# In the plotting cell — bare render(...) call is the cell's last expression:
@app.cell
def _(plt, render, sv_burden_plot_path, data):
    def make_plot():
        fig, ax = plt.subplots(figsize=(10, 6))
        # ... plotting code ...
        return render(fig, sv_burden_plot_path)
    make_plot()  # displayed inline AND embedded in exported HTML
    return
```

**Verify** after building: `uv run marimo export html nb.py -o /tmp/x.html`, then `grep -c 'data:image/png;base64' /tmp/x.html` should equal the number of figures.

## SVG exports: set `svg.fonttype = "none"` for Illustrator editing

If a notebook also exports an editable `.svg` (e.g. for hand-tweaking in Illustrator), set `matplotlib.rcParams["svg.fonttype"] = "none"` once in the imports cell, right after `matplotlib.style.use("default")`. Matplotlib's default (`"path"`) converts every text glyph into a `<path>` outline — no font-size property survives, so text is uneditable in Illustrator. `"none"` keeps text as real `<text>` elements with a `font-size`/`font-family` style, editable via Illustrator's Character panel (rendering then depends on the editing machine having a matching font, which is fine for local editing).

```python
# In the imports cell (cell 1), alongside matplotlib.style.use("default"):
matplotlib.rcParams["svg.fonttype"] = "none"
```

This is a one-time rcParam set — no per-plot changes needed. After changing it, re-run the notebook (`uv run marimo export html nb.py -o ...`) to regenerate existing `.svg` files with editable text.

## Markdown around code cells

Every code cell in the marimo notebook must have markdown that explains it:

- **Before** the code cell: add a markdown cell that states what the code is about to do (intent, question, or step).
- **After** the code cell: add a markdown cell that explains the results (what the output or plot shows, what it means for the analysis).

This keeps the notebook readable and documents intent and interpretation alongside the code.

## Lab notebook integration

Even when using a marimo notebook, maintain the analysis's `lab_notebook.md`. The lab notebook should reference what was done in the notebook and capture key findings and interpretation. The marimo notebook contains the executable code; the lab notebook provides the narrative and decision record.
