You are an expert open-source software analyst. Perform a comprehensive and structured analysis of the target repository or codebase.

Arguments: $ARGUMENTS

**Argument Parsing Rules (must be processed before analysis begins):**

Parse the following options from `$ARGUMENTS`:

- `--review-result <filename>` — Specifies the output filename for the report. Defaults to `REVIEW.md` if not provided.
  - Example: `--review-result GUIDE4Junior.md` → saves to `.review/GUIDE4Junior.md`
- `--pdf <true|false>` — Whether to convert the report to PDF after generating the markdown. Defaults to `false`.
  - `--pdf true`: generate `.md` then convert to `.pdf` with the same base name in `.review/`
  - `--pdf false` (default): generate `.md` only, skip PDF conversion
- All remaining arguments after removing the above options are treated as **analysis target paths** (space-separated). If no path is given, analyze the current working directory.

**Single vs. Multi-project mode:**

- **Single project** (one path or no path): perform a standard analysis of that project.
- **Multi-project** (two or more paths): perform an individual analysis of each project, then produce a **综합 비교 분석 (Comprehensive Comparative Analysis)** section at the end.
  - The output file is saved under the **first project's** `.review/` directory.
  - The report includes a per-project summary table followed by a cross-project comparison.

Parsing examples:

| Arguments                                | Target(s)   | Output location              |
| ---------------------------------------- | ----------- | ---------------------------- |
| `/proj/A /proj/B`                        | A, B        | `A/.review/REVIEW.md` only   |
| `/proj/A /proj/B --review-result CMP.md` | A, B        | `A/.review/CMP.md`           |
| `/proj/A /proj/B --pdf true`             | A, B        | `A/.review/REVIEW.md` (+PDF) |
| `/proj/A`                                | A           | `A/.review/REVIEW.md` only   |
| `/proj/A --pdf true`                     | A           | `A/.review/REVIEW.md` (+PDF) |
| (no arguments)                           | current dir | `.review/REVIEW.md`          |

**All analysis results must be written in Korean, and if possible, in English as well.**

---

## Analysis Execution Guide

Follow the steps below in order. For each step, actively inspect actual files and output your findings.

When analyzing multiple projects, repeat Steps 1–7 for **each project** before proceeding to Step 8.

---

### Step 1. Purpose and Scope Definition

- Read the README and top-level documentation.
- Identify what problem the project solves and who the target users are.
- Clarify whether it is a library, framework, application, platform, or tool.

---

### Step 2. Repository Structure Analysis

Inspect the top-level directory structure and answer the following:

- What are the major directories and their roles? (`src`, `tests`, `docs`, `deploy`, `charts`, `infra`, etc.)
- Is code and operational assets separated?
- Is it a monorepo or multi-repo?
- Is the structure function-oriented, layer-oriented, or domain-oriented?

---

### Step 3. Software Stack Identification

Identify the tech stack from build/dependency files:

- Language and version (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `.tool-versions`, `.nvmrc`, etc.)
- Build tools and package managers
- Frameworks and major libraries
- Runtime environment
- Data storage (DB, cache, message queue)
- Deployment platform (Docker, Kubernetes, Helm, Serverless, etc.)

---

### Step 4. Architecture Analysis

Analyze the code structure to identify the following:

- Entry points (main file, CLI entrypoint, server bootstrap)
- Module/package boundaries and dependency graph
- Layer separation (presentation, business logic, data access)
- Domain or service boundaries
- Architectural patterns (Clean Architecture, Hexagonal, MVC, Event-driven, etc.)
- State management approach
- Inter-component communication method (REST, gRPC, message queue, event, etc.)

---

### Step 5. Quality and Test System

- Test structure and type (unit, integration, e2e)
- Test coverage tools and current coverage level
- CI/CD workflow (`.github/workflows`, `.gitlab-ci.yml`, `Jenkinsfile`, etc.)
- Lint, formatting, static analysis tools
- Release cycle and versioning strategy

---

### Step 6. Security and Supply Chain

- Security policy (`SECURITY.md`)
- Dependency vulnerability management (`dependabot`, `renovate`, `snyk`, etc.)
- SBOM presence and artifact signing
- License identification and compatibility review (primary license + major dependency licenses)
- Secret management method

---

### Step 7. Documentation and Operational Maturity

- README quality (quick start, API docs, examples)
- CONTRIBUTING, CODE_OF_CONDUCT, ADR presence
- Issue/PR template and label system
- Release notes and changelog management
- Community activity (number of contributors, recent commit frequency, response time)

---

### Step 8. Final Report

When analysis is complete, save the results to `.review/<output-filename>` at the **first project's root**.

- Use the filename determined during argument parsing (default: `REVIEW.md`).
- Create the `.review/` directory if it does not exist.
- Overwrite the file if it already exists.
- Include the analysis date (`분석일: YYYY-MM-DD`) and the list of analyzed target paths at the top of the file.

#### 8-A. Single-project report

Output a structured report in the following table format:

| 항목     | 확인 내용 | 평가 |
| -------- | --------- | ---- |
| 목적     |           |      |
| 구조     |           |      |
| 스택     |           |      |
| 진입점   |           |      |
| 아키텍처 |           |      |
| 데이터   |           |      |
| 배포     |           |      |
| 테스트   |           |      |
| 보안     |           |      |
| 성숙도   |           |      |

After the table, provide:

1. **강점** — 3~5 notable architectural or operational strengths
2. **위험/개선 필요 사항** — 3~5 risks or areas for improvement
3. **도입 권고** — Summary judgment for technology adoption, architectural benchmarking, security review, contribution readiness, or operational maturity evaluation

#### 8-B. Multi-project report (two or more projects)

First, output a **per-project summary table** for each project (same format as 8-A).

Then append a **종합 비교 분석 (Comprehensive Comparative Analysis)** section with the following structure:

**① 프로젝트별 요약 비교표**

| 항목     | 프로젝트 A | 프로젝트 B | …   |
| -------- | ---------- | ---------- | --- |
| 목적     |            |            |     |
| 스택     |            |            |     |
| 아키텍처 |            |            |     |
| 테스트   |            |            |     |
| 보안     |            |            |     |
| 성숙도   |            |            |     |

**② 공통점** — Shared patterns, technologies, or practices across all projects

**③ 차이점** — Key differences in design philosophy, stack choices, or operational maturity

**④ 상호 참조 권고** — What each project could learn from the others

**⑤ 종합 도입 권고** — Overall recommendation when considering all projects together (e.g., which to adopt, combine, or avoid)

---

**PDF conversion (default: disabled):**

After saving the markdown file, convert it to PDF only if `--pdf true` was specified.
Use the following priority order to find a conversion tool — stop at the first one that works:

1. `pandoc <input.md> -o <output.pdf>` — preferred if pandoc is installed
2. `md-to-pdf <input.md>` — if md-to-pdf (npm) is available
3. `grip <input.md> --export <output.pdf>` — if grip is available
4. If none of the above tools are available, print a warning and skip PDF conversion:
   > "PDF 변환 도구를 찾을 수 없습니다. `.review/<filename>.md` 파일만 생성되었습니다. pandoc, md-to-pdf, grip 중 하나를 설치하면 PDF 변환이 가능합니다."

The PDF output path is `.review/<same-base-name>.pdf` (e.g., `REVIEW.md` → `REVIEW.pdf`).

---

Be thorough but concise. Read actual files before making claims. If a file or directory is missing, note it as absent rather than skipping it. Prioritize observed evidence over assumptions.
