"""Tests cho stack_detector — Phase B wf-fix-bugs Coverage Improvement v8."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from stack_detection import stack_detector as sd


def _write(p: Path, content: str = "{}") -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content, encoding="utf-8")


class TestEmptyDir:
    def test_empty_returns_unknown(self, tmp_path: Path):
        result = sd.detect_stack(tmp_path)
        assert result.primary_stack == "unknown"
        assert result.confidence == "low"
        assert result.secondary_stacks == []
        assert result.frameworks == []

    def test_nonexistent_dir(self, tmp_path: Path):
        result = sd.detect_stack(tmp_path / "nonexistent")
        assert result.primary_stack == "unknown"


class TestTypescriptReact:
    def test_pure_react_ts(self, tmp_path: Path):
        _write(tmp_path / "package.json", json.dumps({
            "dependencies": {"react": "^18.0.0", "typescript": "^5.0.0"},
        }))
        _write(tmp_path / "tsconfig.json", "{}")
        _write(tmp_path / "src/App.tsx", "// REQ-ID: REQ-001\nexport const App = () => null;")
        _write(tmp_path / "src/index.ts", "// entry")
        result = sd.detect_stack(tmp_path)
        assert result.primary_stack == "typescript-react"
        assert "react" in result.frameworks

    def test_nextjs_ts(self, tmp_path: Path):
        _write(tmp_path / "package.json", json.dumps({
            "dependencies": {"next": "^14.0.0", "react": "^18.0.0", "typescript": "^5.0.0"},
        }))
        _write(tmp_path / "tsconfig.json", "{}")
        _write(tmp_path / "src/app/page.tsx", "export default function Page() { return null; }")
        result = sd.detect_stack(tmp_path)
        assert result.primary_stack == "typescript-nextjs"
        assert "nextjs" in result.frameworks
        assert "react" in result.frameworks

    def test_react_js_no_ts(self, tmp_path: Path):
        _write(tmp_path / "package.json", json.dumps({
            "dependencies": {"react": "^18.0.0"},
        }))
        _write(tmp_path / "src/App.jsx", "export const App = () => null;")
        result = sd.detect_stack(tmp_path)
        assert result.primary_stack == "javascript-react"

    def test_marketing_specific_frameworks(self, tmp_path: Path):
        _write(tmp_path / "package.json", json.dumps({
            "dependencies": {
                "next": "^14.0.0",
                "react": "^18.0.0",
                "typescript": "^5.0.0",
                "@tanstack/react-query": "^5.0.0",
                "next-intl": "^3.0.0",
                "zod": "^3.0.0",
                "react-hook-form": "^7.0.0",
            },
        }))
        _write(tmp_path / "tsconfig.json", "{}")
        result = sd.detect_stack(tmp_path)
        assert result.primary_stack == "typescript-nextjs"
        assert "tanstack-query" in result.frameworks
        assert "next-intl" in result.frameworks
        assert "zod" in result.frameworks


class TestVue:
    def test_vue3(self, tmp_path: Path):
        _write(tmp_path / "package.json", json.dumps({
            "dependencies": {"vue": "^3.0.0"},
        }))
        _write(tmp_path / "src/App.vue", "<template></template>")
        result = sd.detect_stack(tmp_path)
        assert result.primary_stack == "vue"
        assert "vue" in result.frameworks

    def test_nuxt(self, tmp_path: Path):
        _write(tmp_path / "package.json", json.dumps({
            "dependencies": {"nuxt": "^3.0.0", "vue": "^3.0.0"},
        }))
        result = sd.detect_stack(tmp_path)
        assert result.primary_stack == "vue"
        assert "nuxt" in result.frameworks


class TestCSharp:
    def test_dotnet_csproj(self, tmp_path: Path):
        _write(tmp_path / "MyApp/MyApp.csproj", """
<Project Sdk="Microsoft.NET.Sdk.Web">
  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.App" />
    <PackageReference Include="MediatR" />
    <PackageReference Include="Microsoft.EntityFrameworkCore" />
    <PackageReference Include="FluentValidation" />
  </ItemGroup>
</Project>
""")
        _write(tmp_path / "MyApp/Program.cs", "// entry")
        _write(tmp_path / "MyApp/Endpoints.cs", "// endpoints")
        result = sd.detect_stack(tmp_path)
        assert result.primary_stack == "csharp-dotnet"
        assert "aspnetcore" in result.frameworks
        assert "mediatr" in result.frameworks
        assert "ef-core" in result.frameworks
        assert "fluentvalidation" in result.frameworks


class TestPython:
    def test_fastapi(self, tmp_path: Path):
        _write(tmp_path / "requirements.txt", "fastapi==0.100.0\npydantic==2.0\nsqlalchemy==2.0")
        _write(tmp_path / "main.py", "from fastapi import FastAPI")
        result = sd.detect_stack(tmp_path)
        assert result.primary_stack == "python-fastapi"
        assert "fastapi" in result.frameworks
        assert "pydantic" in result.frameworks
        assert "sqlalchemy" in result.frameworks

    def test_django(self, tmp_path: Path):
        _write(tmp_path / "requirements.txt", "Django==4.2\ncelery==5.3")
        _write(tmp_path / "manage.py", "")
        result = sd.detect_stack(tmp_path)
        assert result.primary_stack == "python-django"
        assert "django" in result.frameworks
        assert "celery" in result.frameworks

    def test_pyproject_toml(self, tmp_path: Path):
        _write(tmp_path / "pyproject.toml", '[tool.poetry.dependencies]\nfastapi = "^0.100"\npydantic = "^2.0"')
        _write(tmp_path / "app/main.py", "")
        result = sd.detect_stack(tmp_path)
        assert result.primary_stack == "python-fastapi"


class TestGo:
    def test_gin(self, tmp_path: Path):
        _write(tmp_path / "go.mod", """module example.com/app

require (
    github.com/gin-gonic/gin v1.9.0
    gorm.io/gorm v1.25.0
)
""")
        _write(tmp_path / "main.go", "")
        result = sd.detect_stack(tmp_path)
        assert result.primary_stack == "go"
        assert "gin" in result.frameworks
        assert "gorm" in result.frameworks


class TestJava:
    def test_spring_boot(self, tmp_path: Path):
        _write(tmp_path / "pom.xml", """<project>
  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
      <groupId>org.hibernate</groupId>
    </dependency>
  </dependencies>
</project>""")
        _write(tmp_path / "src/main/java/Main.java", "")
        result = sd.detect_stack(tmp_path)
        assert result.primary_stack == "java-spring"
        assert "hibernate" in result.frameworks


class TestRust:
    def test_axum(self, tmp_path: Path):
        _write(tmp_path / "Cargo.toml", """[package]
name = "app"
[dependencies]
axum = "0.7"
""")
        _write(tmp_path / "src/main.rs", "")
        result = sd.detect_stack(tmp_path)
        assert result.primary_stack == "rust"
        assert "axum" in result.frameworks


class TestMonorepo:
    def test_csharp_and_react(self, tmp_path: Path):
        # C# backend with many .cs files
        _write(tmp_path / "backend/Api.csproj", '<Project Sdk="Microsoft.NET.Sdk.Web"></Project>')
        for i in range(20):
            _write(tmp_path / f"backend/Service{i}.cs", "// stub")
        # TS frontend with fewer files
        _write(tmp_path / "frontend/package.json", json.dumps({
            "dependencies": {"react": "^18.0.0", "typescript": "^5.0.0"},
        }))
        _write(tmp_path / "frontend/tsconfig.json", "{}")
        for i in range(5):
            _write(tmp_path / f"frontend/src/Comp{i}.tsx", "// stub")

        result = sd.detect_stack(tmp_path)
        # C# has more files → primary
        assert result.primary_stack == "csharp-dotnet"
        # TS should appear as secondary
        assert "typescript-react" in result.secondary_stacks


class TestConfidence:
    def test_high_confidence_with_many_files(self, tmp_path: Path):
        _write(tmp_path / "package.json", json.dumps({
            "dependencies": {"react": "^18.0.0", "typescript": "^5.0.0"},
        }))
        _write(tmp_path / "tsconfig.json", "{}")
        for i in range(60):
            _write(tmp_path / f"src/comp{i}.tsx", "// stub")
        result = sd.detect_stack(tmp_path)
        assert result.confidence == "high"

    def test_medium_confidence(self, tmp_path: Path):
        _write(tmp_path / "package.json", json.dumps({
            "dependencies": {"react": "^18.0.0", "typescript": "^5.0.0"},
        }))
        _write(tmp_path / "tsconfig.json", "{}")
        for i in range(15):
            _write(tmp_path / f"src/comp{i}.tsx", "// stub")
        result = sd.detect_stack(tmp_path)
        assert result.confidence == "medium"

    def test_low_confidence_few_files(self, tmp_path: Path):
        _write(tmp_path / "package.json", json.dumps({
            "dependencies": {"react": "^18.0.0", "typescript": "^5.0.0"},
        }))
        _write(tmp_path / "tsconfig.json", "{}")
        for i in range(3):
            _write(tmp_path / f"src/comp{i}.tsx", "// stub")
        result = sd.detect_stack(tmp_path)
        assert result.confidence == "low"


class TestSchema:
    def test_schema_present(self, tmp_path: Path):
        _write(tmp_path / "package.json", json.dumps({"dependencies": {"react": "*"}}))
        result = sd.detect_stack(tmp_path)
        assert result.schema == "stack-info-v1"

    def test_to_dict_serializable(self, tmp_path: Path):
        _write(tmp_path / "package.json", json.dumps({"dependencies": {"react": "*"}}))
        result = sd.detect_stack(tmp_path)
        d = result.to_dict()
        # Must be JSON-serializable
        json.dumps(d)
        assert "primary_stack" in d
        assert "evidence" in d


class TestExclusions:
    def test_skips_node_modules(self, tmp_path: Path):
        _write(tmp_path / "package.json", json.dumps({"dependencies": {"react": "*", "typescript": "*"}}))
        _write(tmp_path / "tsconfig.json", "{}")
        # Create files in skip dirs (should not count)
        for i in range(100):
            _write(tmp_path / f"node_modules/some-pkg/file{i}.ts", "// noise")
            _write(tmp_path / f"dist/build{i}.tsx", "// build noise")
        # Create few real source files
        for i in range(5):
            _write(tmp_path / f"src/Comp{i}.tsx", "// real")
        result = sd.detect_stack(tmp_path)
        ev = result.evidence.get("typescript-react")
        assert ev is not None
        # Counted only real source files
        assert ev.file_count == 5


class TestCorruptedConfigs:
    def test_invalid_package_json(self, tmp_path: Path):
        _write(tmp_path / "package.json", "{not valid json")
        result = sd.detect_stack(tmp_path)
        # Should not crash, returns unknown
        assert result.primary_stack == "unknown"


class TestCLI:
    def test_cli_writes_output(self, tmp_path: Path):
        _write(tmp_path / "package.json", json.dumps({"dependencies": {"react": "*", "typescript": "*"}}))
        _write(tmp_path / "tsconfig.json", "{}")
        rc = sd.main(["--target", str(tmp_path)])
        assert rc == 0
        out = tmp_path / "stack-info.json"
        assert out.exists()
        data = json.loads(out.read_text(encoding="utf-8"))
        assert data["schema"] == "stack-info-v1"
        assert data["primary_stack"] == "typescript-react"

    def test_cli_missing_target(self):
        rc = sd.main(["--target", "/nonexistent/12345"])
        assert rc == 2
