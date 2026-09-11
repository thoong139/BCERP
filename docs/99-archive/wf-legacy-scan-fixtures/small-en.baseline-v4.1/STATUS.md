# Baseline Status: small-en v4.1

**Status:** ⬜ EMPTY — pending user run `/wf-legacy-scan` v4.1 trên `../small-en/` sau khi fixture có content.

## Expected Files (when populated)

- [ ] `project-context.md`
- [ ] `project-profile.json`
- [ ] `assessment-report.json`
- [ ] `ledger.json`
- [ ] `inventory/` (screens, api-endpoints, source-files, dependency-graph, doc-files, external-docs, doc-classified, ui-manifest)
- [ ] `classified/` (batch files)
- [ ] `extracted/` (module files)
- [ ] `doc-quality-map.json`
- [ ] `impl-status-snapshot.json`
- [ ] `module-code-mapping.json`

## How To Populate

```bash
cd fixtures/small-en       # populated content required
/wf-legacy-scan .
cp -r .mc-data/work/legacy-scan/* ../small-en.baseline-v4.1/
rm -rf .mc-data
```

See parent `../README.md` for full workflow.
