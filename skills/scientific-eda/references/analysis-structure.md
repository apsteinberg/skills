# Analysis folder structure

Each analysis is one folder under `analyses/` (or project-agreed base).

**Naming convention:**

- On creation, use a single date: **`[YYMMDD]_[optional_ID]_descriptive-slug`**, e.g. `260120_APS052_somatic_sv_exploration`.
- When work resumes on a later day, the folder name gains a second date showing the original start date: **`[YYMMDD_last]-[YYMMDD_start]_...`**, e.g. `260315-260120_APS052_somatic_sv_exploration`. This keeps active analyses sorted to the top of the directory while preserving when the analysis started.
- When resuming work, the agent should **suggest** this rename but **not do it automatically**. The user decides whether to rename.

**Canonical layout:**

```text
analyses/
  260315-260120_APS052_somatic_sv_exploration/
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
