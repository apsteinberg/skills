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

## Markdown around code cells

Every code cell in the marimo notebook must have markdown that explains it:

- **Before** the code cell: add a markdown cell that states what the code is about to do (intent, question, or step).
- **After** the code cell: add a markdown cell that explains the results (what the output or plot shows, what it means for the analysis).

This keeps the notebook readable and documents intent and interpretation alongside the code.

## Lab notebook integration

Even when using a marimo notebook, maintain the analysis's `lab_notebook.md`. The lab notebook should reference what was done in the notebook and capture key findings and interpretation. The marimo notebook contains the executable code; the lab notebook provides the narrative and decision record.
