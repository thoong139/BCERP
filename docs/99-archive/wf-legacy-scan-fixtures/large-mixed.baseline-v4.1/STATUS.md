# Baseline Status: large-mixed v4.1

**Status:** ⬜ EMPTY — pending user run `/wf-legacy-scan` v4.1 trên `../large-mixed/` sau khi fixture có content.

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
cd fixtures/large-mixed       # populated content required
/wf-legacy-scan .
cp -r .mc-data/work/legacy-scan/* ../large-mixed.baseline-v4.1/
rm -rf .mc-data
```

See parent `../README.md` for full workflow.
