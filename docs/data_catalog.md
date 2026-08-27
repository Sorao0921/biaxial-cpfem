# Research data catalog

`database/analysis.db` is the searchable catalog for the pipeline's research data.
It stores file metadata and case relationships; it does not copy or modify the
large simulation outputs.

## Case key

Each analysis case is identified by:

```text
rho × seed × texture × sd × state
```

The Theme 1 readiness view checks whether a case has all three core artifacts:

- `surface_height`: edge-dropped coordinates are preferred over raw coordinates.
- `orientation_metrics`: the grain-level file containing GOS and grain rotation.
- `accumulated_shear_strain`: ID-enriched data are preferred over raw data.

`training_ready` additionally checks for the initial-orientation file and the
seed-specific spatial model.

## Refresh the catalog

Run from the repository root:

```bash
python -m src.data_catalog.catalog --database database/analysis.db scan --root .
```

The scan is incremental. Unchanged files reuse the stored CSV header and sampled
fingerprint. Deleted files are removed from the catalog after a successful scan.

## Inspect readiness

```bash
python -m src.data_catalog.catalog --database database/analysis.db report
```

The most useful SQL view is:

```sql
SELECT *
FROM v_theme1_case_readiness
WHERE training_ready = 1;
```

## Export the GPU-training manifest

```bash
python -m src.data_catalog.catalog \
  --database database/analysis.db \
  export database/theme1_ready_manifest.csv
```

The export contains exactly one preferred file for each of the three roles and
each training-ready case. Use `--all-cases` to include incomplete cases for data
quality review.

## Database tables and views

- `scan_runs`: scan history and error counts.
- `artifacts`: file paths, classifications, case fields, CSV headers, size,
  modification time, and sampled SHA-256 fingerprint.
- `cases`: normalized case keys.
- `case_artifacts`: many-to-many links between cases and artifact roles.
- `v_theme1_case_readiness`: completeness flags for Theme 1.
- `v_preferred_theme1_artifacts`: lowest-priority-number artifact candidates.

Large arrays remain in `outputs/`, while the catalog provides paths for local or
external-GPU data loaders. This separation keeps the database small and avoids
duplicating tens of gigabytes of simulation data.
