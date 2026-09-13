// Append CQG1 traceability appendix to api-contract.md
const fs = require('fs');
const FILE = 'E:/BC-Working/.mc-data/docs/phase3-architecture/technical-specs/api-contract.md';
const rows = JSON.parse(fs.readFileSync('E:/BC-Working/.mc-data/work/wf-design/sessions/20260913-053848-f4d7/validation/cqg1-map2.txt','utf8').replace(/\n/g,''));
function shorten(s){
  return s.replace(/^SYS-BCERP-WEB §/,'WEB §').replace(/^SYS-CORE-BACKEND §/,'CORE §')
    .replace(/^SYS-INTEGRATION-GW §/,'GW §').replace(/^SYS-PORTAL-WEB §/,'PORTAL §')
    .replace(/^SYS-MOBILE-INTERNAL §/,'MBI §').replace(/^SYS-MOBILE-PORTAL §/,'MPO §')
    .replace(/\s*\(MOD-[A-Z0-9, -]+\)\s*$/,'').replace(/\s*— FEAT-[A-Z0-9/ ,-]+$/,'');
}
let md = `
### 9. FEAT Traceability — cross-system variants (bổ sung Cross-Validation 2026-09-13)

> Phase 2 sinh FEAT-ID per-system (FEAT-CORE-* / FEAT-ERP-* / FEAT-GW-* / FEAT-MBI-* / FEAT-PORTAL-* / FEAT-MPO-*)
> với số thứ tự đồng bộ trong cùng module. Thiết kế Phase 3 **tập trung nghiệp vụ vào một touchpoint chính**
> (business services tại SYS-BCERP-WEB — COMP-ERP-001…007; identity/RBAC/datahub tại COMP-CORE-*; adapter tại GW;
> BFF read/action tại MBI/MPO/PORTAL), nên endpoint chỉ gắn nhãn FEAT của system sở hữu touchpoint.
> Bảng dưới map **70 FEAT variant chưa xuất hiện trực tiếp** trong hợp đồng này → touchpoint thi công thật
> (xác định bằng FEAT cùng số hiệu trong cùng module). Không endpoint nào bị bỏ sót capability — đây là chú giải traceability, không phải endpoint mới.

| FEAT variant | Cùng capability với | Touchpoint thi công | API IDs chính |
|--------------|---------------------|---------------------|----------------|
`;
for (const r of rows) {
  const secs = r.secs.slice(0,2).map(shorten).join(' + ');
  const apis = r.apis.slice(0,4).join(', ') + (r.apis.length>4 ? ` (+${r.apis.length-4})` : '');
  md += '| `' + r.id + '` | ' + r.sibs.map(s=>'`'+s+'`').join(', ') + ' | ' + secs + ' | ' + apis + ' |\n';
}
fs.appendFileSync(FILE, md);
console.log('appended', rows.length, 'rows');
