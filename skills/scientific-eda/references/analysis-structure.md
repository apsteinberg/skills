# Analysis folder structure

Each analysis is one folder under `analyses/` (or project-agreed base).

**Naming convention:**

- On creation, use a single date: **`[YYMMDD]_[optional_ID]_descriptive-slug`**, e.g. `260315_SV-APS-052_somatic_sv_exploration` or `260315_protein_binding_eda`.
- The date is the **creation date** and never changes, even when work resumes on a later day. Do not rename folders on resume.
- The optional ID follows the format **`PROJ-INITIALS-NNN`**: a 1–4 letter uppercase project code, analyst initials (default `APS`), and a page number. Example: `SV-APS-052`, `BIND-APS-003`.

**Canonical layout:**

```text
analyses/
  260315_SV-APS-052_somatic_sv_exploration/
    lab_notebook.md          # co-authored; goals, methods, results, conclusions
    plots/                   # WebP figures only
    scripts/                 # disposable scripts; uv run
    sv_haplotypes.py         # marimo notebook (at root)
    sv_cn_changepoint.Rmd    # Rmarkdown notebook (at root)
```

- **lab_notebook.md** – Co-authored lab notebook for this analysis. The user writes goals, background, and interpretation; the agent drafts methods and results entries. See [lab-notebook.md](lab-notebook.md) for the full convention.
- **plots/** – All figures from this analysis; save as `.webp` (matplotlib: `format="webp"`).
- **scripts/** – Disposable Python scripts; run with `uv run script.py` using the project environment. Add PEP723 inline metadata only when a script needs dependencies outside the project environment.
- **Notebooks** – Marimo (`.py`) and Rmarkdown (`.Rmd`) notebooks live at the analysis folder root, not inside `scripts/`. Notebooks are the primary analytical artifacts; scripts are supporting/throwaway.
