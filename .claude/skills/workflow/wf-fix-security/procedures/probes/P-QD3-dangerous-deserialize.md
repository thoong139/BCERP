# P-QD3-dangerous-deserialize — Dangerous Deserialization Detection

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD3-dangerous-deserialize |
| **Loai** | static |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Phat hien dangerous deserialization patterns: eval(), Function(), unserialize, pickle, yaml.load (unsafe), JSON.parse without try/catch, BinaryFormatter, ObjectInputStream. |
| **Cache** | NEVER (ADR-22 Rule 6 — security probes always re-scan) |
| **Migrates from** | (v5 legacy — removed in v6) phase4-deserialize-check.md |

## PRE-GATE

```
IF khong co source code (Glob src/**/* tra 0 results):
  SKIP probe, note "skipped_no_source_code"
IF chay tu wf-fix-bugs orchestrator: yeu cau --use-cache=false (always)
IF profile == standard: chi scan JS/TS eval + JSON.parse patterns
IF profile == deep: scan JS/TS + Python deserialization
IF profile == exhaustive: scan JS/TS + Python + Java/C# deserialization + security agent review
```

## SENSE

### B1: Delegate to bash script (inline grep)

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD3-security/raw/P-QD3-dangerous-deserialize.json"
mkdir -p "$(dirname "$RAW_OUT")"

# Detect project language
HAS_TS=$(find src/ -name "*.ts" -o -name "*.tsx" 2>/dev/null | head -1)
HAS_JS=$(find src/ -name "*.js" -o -name "*.jsx" 2>/dev/null | head -1)
HAS_PY=$(find src/ -name "*.py" 2>/dev/null | head -1)
HAS_JAVA=$(find src/ -name "*.java" 2>/dev/null | head -1)
HAS_CS=$(find src/ -name "*.cs" 2>/dev/null | head -1)
HAS_PHP=$(find src/ -name "*.php" 2>/dev/null | head -1)

if [ -z "$HAS_TS$HAS_JS$HAS_PY$HAS_JAVA$HAS_CS$HAS_PHP" ]; then
  cat > "$RAW_OUT" <<EOF
{"\$schema":"lane-signals-v1","lane":"wf-fix-security","dimension":"QD3",
 "probe_id":"P-QD3-dangerous-deserialize","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"no_source_files"}
EOF
  exit 0
fi

# --- JS/TS: eval and dynamic execution ---
grep -rnE '(eval\s*\(|new\s+Function\s*\(|setTimeout\s*\(.*["'"'"']|setInterval\s*\(.*["'"'"'])' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.|\.spec\.|__mocks__|fixtures)' \
  | grep -vE '(//|/\*).*(eval|Function)' \
  | head -30 > "$RAW_OUT.eval_dynamic"

# --- JS/TS: JSON.parse without try/catch ---
grep -rnE 'JSON\.parse\s*\(' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.|catch|try\s*\{)' \
  | head -30 > "$RAW_OUT.json_parse_unsafe"

# --- JS/TS: innerHTML/dangerouslySetInnerHTML with user data ---
grep -rnE '(\.innerHTML\s*=|dangerouslySetInnerHTML|v-html|insertAdjacentHTML)' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' \
  | head -30 > "$RAW_OUT.innerHTML_userdata"

# --- Python: pickle/cPickle ---
if [ -n "$HAS_PY" ] && [ "$PROFILE" != "standard" ]; then
  grep -rnE '(pickle\.loads|pickle\.load|cPickle\.loads|cPickle\.load|pickle\.Unpickler)' \
    --include="*.py" src/ 2>/dev/null \
    | grep -vE '(node_modules|\.test\.|__pycache__)' \
    | head -20 > "$RAW_OUT.pickle"

  # Python: yaml.load without Loader
  grep -rnE 'yaml\.load\s*\(' --include="*.py" src/ 2>/dev/null \
    | grep -vE '(Loader|SafeLoader|yaml\.safe_load|node_modules|\.test\.)' \
    | head -20 > "$RAW_OUT.python_yaml_load"

  # Python: marshal/joblib/cloudpickle
  grep -rnE '(marshal\.loads|marshal\.load|joblib\.load|cloudpickle\.loads|dill\.loads)' \
    --include="*.py" src/ 2>/dev/null \
    | grep -vE '(node_modules|\.test\.)' \
    | head -20 > "$RAW_OUT.python_other_serial"
fi

# --- Java: ObjectInputStream (deep/exhaustive only) ---
if [ -n "$HAS_JAVA" ] && [ "$PROFILE" != "standard" ]; then
  grep -rnE '(ObjectInputStream|readObject|readResolve|readExternal|Serializable.*readObject)' \
    --include="*.java" src/ 2>/dev/null \
    | grep -vE '(node_modules|\.test\.)' \
    | head -20 > "$RAW_OUT.java_deserialize"
fi

# --- C#: BinaryFormatter (deep/exhaustive only) ---
if [ -n "$HAS_CS" ] && [ "$PROFILE" != "standard" ]; then
  grep -rnE '(BinaryFormatter|LosFormatter|NetDataContractSerializer|ObjectStateFormatter|SoapFormatter)' \
    --include="*.cs" src/ 2>/dev/null \
    | grep -vE '(node_modules|\.test\.)' \
    | head -20 > "$RAW_OUT.csharp_deserialize"

  grep -rnE '(JavaScriptSerializer|XmlSerializer|DataContractSerializer|DataContractJsonSerializer)' \
    --include="*.cs" src/ 2>/dev/null \
    | grep -vE '(node_modules|\.test\.)' \
    | head -10 > "$RAW_OUT.csharp_serializer"
fi


### B2: KHONG check scan cache

ADR-22 Rule 6 -- security probes ALWAYS re-scan.

## THINK

Phan tich deserialization patterns theo language:

1. **JS/TS:** `eval()` va `new Function()` = CRITICAL (arbitrary code execution). `JSON.parse` khong try/catch = HIGH (crash/unhandled exception info leak).

2. **Python:** `pickle.loads` = CRITICAL (arbitrary code execution during unpickling). `yaml.load` khong `SafeLoader` = CRITICAL (YAML deserialization RCE). `marshal.loads` = HIGH.

3. **Java:** `ObjectInputStream.readObject()` = CRITICAL (gadget chain RCE). Common libraries (Jackson, XStream) dang version cu cung co CVE.

4. **C#:** `BinaryFormatter.Deserialize()` = CRITICAL (known RCE via gadget chains). `JavaScriptSerializer` = HIGH.

**CDG flags:** `cdg_flags: ["CDG-SECURITY-LIVE"]` cho eval/Function/pickle/ObjectInputStream/BinaryFormatter.

**MITRE ATT&CK mapping:**
- eval/Function() -> T1059.007 (Command and Scripting Interpreter: JavaScript)
- pickle.loads -> T1059.006 (Command and Scripting Interpreter: Python)
- ObjectInputStream -> T1203 (Exploitation for Client Execution)
- BinaryFormatter -> T1203 (Exploitation for Client Execution)
- JSON.parse no try/catch -> T1499 (Endpoint Denial of Service)

## ACT

Grep results duoc aggregate thanh signals theo schema `signal-v2`:
- `signal_id` format: `DESER-{language}-{pattern}-{file_hash8}`
- `dimension_id: "QD3"`, `domain: "security"`
- `cdg_flags`: ["CDG-SECURITY-LIVE"] cho CRITICAL patterns
- `evidence[].description` chua truncated snippet (100 chars max)
- `remediation.suggested_action`: specific to each language/pattern:
  - JS: "Replace eval with safe alternatives, add try/catch to JSON.parse"
  - Python: "Use yaml.safe_load instead of yaml.load, avoid pickle with untrusted data"
  - Java: "Use look-ahead ObjectInputFilter, avoid ObjectInputStream with untrusted sources"
  - C#: "Use DataContractSerializer instead of BinaryFormatter, add serialization binder"
- `remediation.suggested_agent`: "security"

## VERIFY

1. Moi CRITICAL signal co `cdg_flags` chua "CDG-SECURITY-LIVE"
2. Moi signal co `dimension_id == "QD3"` va `domain == "security"`
3. Moi signal co `target.file_path` va `target.line_range`
4. KHONG co scan cache calls (ADR-22 Rule 6 audit)
5. Signal language tag matches actual project language
6. Standard profile khong co Java/C# signals

## Severity Rules

| Pattern | Language | Severity | CDG | MITRE ATT&CK |
|---------|----------|----------|-----|--------------|
| eval() / new Function() | JS/TS | CRITICAL | CDG-SECURITY-LIVE | T1059.007 |
| JSON.parse without try/catch | JS/TS | HIGH | -- | T1499 |
| innerHTML/dangerouslySetInnerHTML | JS/TS | HIGH | -- | T1059.007 |
| pickle.loads / cPickle | Python | CRITICAL | CDG-SECURITY-LIVE | T1059.006 |
| yaml.load (no Loader) | Python | CRITICAL | CDG-SECURITY-LIVE | T1059.006 |
| marshal/joblib/cloudpickle | Python | HIGH | -- | T1059.006 |
| ObjectInputStream.readObject | Java | CRITICAL | CDG-SECURITY-LIVE | T1203 |
| BinaryFormatter.Deserialize | C# | CRITICAL | CDG-SECURITY-LIVE | T1203 |
| JavaScriptSerializer | C# | HIGH | -- | T1203 |
| unserialize() | PHP | CRITICAL | CDG-SECURITY-LIVE | T1059 |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| No source code | Skip probe, `skip_reason: "no_source_dir"` |
| Project language khong co trong danh sach (Ruby, Rust, Swift...) | Chi scan JS/TS patterns (universal), note "limited_language_support" |
| eval pattern match la trong comment/test | Bash script tu filter (grep -v test, spec, mock) |
| False positive rate cao | Agent re-classify, giam severity cho low-confidence |

