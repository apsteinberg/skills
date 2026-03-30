# Obsidian lab notebook conventions

This reference documents the entry format and conventions used in the Obsidian lab notebook vault.

## Vault structure

```
msk_lab_notebook/
├── Experiments/              # Notebook entries (one .md per analysis)
│   ├── Sarcoma project/      # Subdirectory for project grouping
│   ├── A673/                 # Subdirectory for project grouping
│   └── *.md                  # Individual experiment entries
├── attachments/              # Images and other files
├── scripts/                  # Utility scripts
└── AGENTS.md                 # Agent conventions
```

## Entry format

Each experiment entry follows this structure:

```markdown
**Created:** YYYY-MM-DD

Goal(s):

- Primary question or objective

Background:

- Scientific rationale
- Hypotheses
- Relevant prior work and references to other notebook entries

Code/Data Storage:

- Links to research compendia, pipelines, data paths
- Numbered list of repos, output paths, reference files

Methods:

1. First method step
2. (YYYY-MM-DD) Timestamped method entry with details
   1. Sub-steps indented as nested list

Results:

Description of findings with embedded images.

![](../attachments/filename.png)

Conclusions:

- Key takeaways
```

## Notebook ID system

Entries are identified by a notebook ID that appears in the filename:

| Pattern | Meaning | Example |
|---|---|---|
| `APS-NNN` | Analyst page (Asher P. Steinberg) | APS046, APS054 |
| `SAR-APS-NNN` | Sarcoma project specific | SAR-APS-056 |
| `A673-APS-NNN` | A673 project specific | A673-APS-056 |

The same ID appears in research compendium analysis folder names:
- `analyses/260321_SAR-APS-056_sample_swaps/` maps to `SAR-APS-056 atlas sample swap checks.md`
- `analyses/260325_A673-APS-056_ONT_vs_ILL/` maps to `A673-APS-056 - A673 ONT vs ILL comparison.md`

To find the matching Obsidian entry, search `Experiments/` for files containing the notebook ID (e.g., `APS046`, `SAR-APS-056`).

## Mapping research compendia to Obsidian entries

Each research compendium repo may contain multiple analyses. The mapping is:

1. **Research compendium** (GitHub repo) contains `analyses/` folders
2. Each **analysis folder** follows the naming convention `YYMMDD_[ID]_descriptive-slug/`
3. Each analysis folder may contain a `lab_notebook.md` with Methods, Results, etc.
4. The **notebook ID** in the folder name (e.g., `SAR-APS-056`) maps to an Obsidian entry

Key research compendia:
- `shahcompbio/SarcAtlas` — Sarcoma Atlas analyses (SAR-APS-*, APS04x, APS05x)
- `shahcompbio/A673` — A673 Ewing sarcoma analyses (A673-APS-*)

Supporting repos (pipelines, tools):
- `shahcompbio/nanogenome` — ONT genomics Nextflow pipeline
- `shahcompbio/minda` — SV decomposition and annotation
- `shahcompbio/proteomegenerator3` — Proteogenomics pipeline
- `shahcompbio/shahlab_apps` — Isabl pipeline apps
- `shahcompbio/somalierswap` — Sample swap detection pipeline

## Attachment conventions

- Images saved to `attachments/` at the vault root
- Referenced in entries with: `![](../attachments/filename.png)`
- For images from subdirectories: `![](../../attachments/filename.png)`
- Prefer descriptive filenames: `260318_msk_kids_tsne.png`, not `plot1.png`
- When fetching from GitHub, use `gh api` to get download URL and `curl` to save

## Editing rules

- **Append only**: never overwrite or modify existing user text
- **Continue numbering**: when appending to Methods, continue the numbered list from the last item
- **Timestamp new entries**: prefix with `(YYYY-MM-DD)` for date context
- **Preserve heading style**: some entries use `#` headings, others use bold text — match what's there
- **Link between entries**: use Obsidian wiki-links `[display text](relative/path.md)` or standard markdown links
- **Section names vary slightly**: "Goal" vs "Goals", "Goal:" vs "# Goal" — match the existing entry's style
