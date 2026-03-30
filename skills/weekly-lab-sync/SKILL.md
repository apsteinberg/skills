---
name: weekly-lab-sync
description: Sync GitHub activity into an Obsidian lab notebook. Discovers repos with recent commits (including non-default branches), reads research compendium lab_notebook.md files, and updates matching Obsidian experiment entries. Use when summarizing weekly work, syncing lab notebooks, or asking "what did I do this week?"
license: MIT
---

# Weekly lab notebook sync

This skill syncs your recent GitHub activity across all repos into your Obsidian lab notebook. It auto-discovers repos you've committed to, reads research compendium `lab_notebook.md` files, and proposes updates to matching Obsidian experiment entries.

## Usage

Invoke when you want to summarize recent work and sync findings into your Obsidian notebook. Works best at the end of a week or before a meeting.

```
/weekly-lab-sync
```

The skill defaults to the last 7 days. The user can specify a different range:

```
/weekly-lab-sync 2026-03-17 2026-03-24
```

## Requirements

- `gh` CLI authenticated (`gh auth login`)
- An Obsidian vault with experiment entries (see [obsidian-conventions.md](references/obsidian-conventions.md))
- Research compendium repos with `analyses/` folders containing `lab_notebook.md` files

## What It Does

1. Discovers all repos with recent commits by the authenticated user.
2. Fetches commit details, including non-default branches.
3. Reads `lab_notebook.md` files from research compendium analysis folders.
4. Presents a structured summary of activity organized by repo.
5. Maps analyses to Obsidian experiment entries by notebook ID.
6. Proposes updates to Obsidian entries and applies them after user approval.

## How It Works

### Phase 1: Auto-discover repos and gather commits

1. Get the authenticated GitHub username:
   ```bash
   gh api user --jq '.login'
   ```

2. Search for commits on default branches across all repos:
   ```bash
   gh api search/commits \
     --method GET \
     -f q="author:USERNAME committer-date:>START_DATE" \
     -f sort=committer-date -f order=desc -f per_page=100 \
     --jq '.items[] | "\(.repository.full_name) | \(.commit.committer.date) | \(.commit.message | split("\n")[0])"'
   ```

3. For each discovered repo, check non-default branches for additional commits. Common branches to check: `dev`, `develop`. List branches with:
   ```bash
   gh api repos/OWNER/REPO/branches --jq '.[].name' | grep -v main
   ```
   Then for each non-default branch:
   ```bash
   gh api repos/OWNER/REPO/commits \
     --method GET -f sha=BRANCH -f since=START_DATE \
     -f per_page=50 \
     --jq '.[] | "\(.sha[:7]) | \(.commit.committer.date) | \(.commit.message | split("\n")[0])"'
   ```

4. For repos that look like research compendia (have an `analyses/` directory), search for `lab_notebook.md` files in recently changed analysis folders. Fetch their content via:
   ```bash
   gh api repos/OWNER/REPO/contents/analyses/FOLDER/lab_notebook.md \
     --jq '.content' | base64 -d
   ```

### Phase 2: Summarize activity

Present a structured summary to the user organized by repo:
- Repo name, number of commits, branch(es)
- Key changes (group related commits)
- Findings from any `lab_notebook.md` files (Methods, Results sections)
- Flag any plots in analysis `plots/` directories

### Phase 3: Map to Obsidian entries

Identify which Obsidian experiment entries correspond to each analysis:
- Match by notebook ID tag (e.g., APS046, SAR-APS-056, A673-APS-056)
- Search for entries in the `Experiments/` directory of the vault
- Present the mapping as a table: source lab notebook -> Obsidian file -> proposed action
- Identify entries that are already up-to-date vs. those needing updates
- **Get explicit user approval before proceeding to edits**

### Phase 4: Update Obsidian entries

For each approved update:
1. Read the current Obsidian entry to understand existing content
2. Determine what new information to append (Methods, Results, Code/Data Storage)
3. **Append only** — never overwrite or modify existing user text
4. For plots: download from the repo via `gh api` and save to the vault's `attachments/` directory, then embed with Obsidian image syntax
5. Use the date format `(YYYY-MM-DD)` for timestamped entries
6. Use numbered list items continuing from the last existing item

See [obsidian-conventions.md](references/obsidian-conventions.md) for the full entry format.

## Guardrails

1. **Summary before edits** — Always present the full summary and mapping before modifying any files.
2. **User approval required** — Do not edit Obsidian entries without explicit confirmation.
3. **Append only** — Never overwrite or delete existing text in entries.
4. **One entry at a time** — If the user prefers, update entries one at a time with review between each.
5. **Preserve formatting** — Match the existing style of the entry (heading levels, list styles, link formats).
6. **Fetch plots explicitly** — Only download and embed plots that the user confirms they want included.
