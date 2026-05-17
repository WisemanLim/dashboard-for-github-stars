You are a senior open-source commercialization architect. Perform a comprehensive in-depth analysis of the target project to assess whether it is suitable for adoption as a commercial solution.

Arguments: $ARGUMENTS

**Argument Parsing Rules (must be processed before analysis begins):**

Parse the following options from `$ARGUMENTS`:

- `--review-result <filename>` — Output filename base. Defaults to `REVIEW-InDepth` if not provided.
  - Output: `.review/<filename>.md`
- `--pdf <true|false>` — Convert report to PDF after generating markdown. Defaults to `false`.
- All remaining arguments are treated as **analysis target paths** (space-separated). If no path is given, analyze the current working directory.

Parsing examples:

| Arguments | Target(s) | Output location |
|---|---|---|
| (none) | current dir | `.review/REVIEW-InDepth.md` |
| `/proj/A` | A | `A/.review/REVIEW-InDepth.md` |
| `/proj/A --review-result OSS-Check` | A | `A/.review/OSS-Check.md` |
| `/proj/A --pdf true` | A | `A/.review/REVIEW-InDepth.md` (+PDF) |

**All analysis results must be written in Korean, and if possible, in English as well.**

---

## Analysis Execution Guide

Follow the steps below **in order**. Read actual files before making any claims. If a file is absent, note it as absent rather than skipping it.

---

### Step 1. Project Structure Overview (always run first)

Start at the project root and map the entire structure before any other analysis.

```
1. Full directory tree (depth 3–4, including hidden files/dirs)
2. Top-level documentation files: README, LICENSE, NOTICE, SECURITY.md, CHANGELOG, etc.
3. Build/dependency manifests: package.json, go.mod, Cargo.toml, pom.xml, build.gradle,
   pyproject.toml, requirements.txt, composer.json, etc.
4. CI/CD configs: .github/workflows/, .gitlab-ci.yml, Jenkinsfile, Makefile
5. Container/deploy configs: Dockerfile, docker-compose.yml, k8s/, helm/, charts/
6. Configuration files: .env.example, config/, application.yml, settings.py, etc.
```

---

### Step 2. Software Stack and Architecture Analysis

```
- Language(s) and runtime versions
- Frameworks and major libraries
- Entry points (main, index, bootstrap files)
- Module/package boundaries and layer structure
- Data stores (DB, cache, message queue)
- Inter-service communication (REST, gRPC, MQ, events)
- Architectural patterns (MVC, Hexagonal, Clean, Event-driven, etc.)
```

---

### Step 3. License Audit (core of the analysis — read actual files)

```
1. Project's own license: read LICENSE file directly
2. Direct dependency licenses:
   - package.json → license field per package
   - go.mod → per-module license (via GitHub source)
   - requirements.txt / pyproject.toml → PyPI license metadata
   - pom.xml / build.gradle → Maven Central license
   - Cargo.toml → crates.io license
3. License classification per dependency:
   - Permissive    : MIT, Apache 2.0, BSD-2, BSD-3, ISC, Unlicense
   - Weak Copyleft : LGPL-2.1, LGPL-3.0, MPL-2.0, EUPL
   - Strong Copyleft: GPL-2.0, GPL-3.0
   - Network Copyleft (highest risk): AGPL-3.0
   - Commercial-incompatible: BUSL, Commons Clause, SSPLv1
4. Compatibility conflict detection:
   - GPL + Apache 2.0 mixing (GPL-2.0 + Apache 2.0 = incompatible)
   - AGPL presence (SaaS deployment triggers source disclosure obligation)
5. NOTICE, THIRD_PARTY_LICENSES files presence
```

Include a license risk classification table in the report.

---

### Step 4. Security and Vulnerability Analysis

```
1. SECURITY.md presence and content
2. Dependency vulnerability management:
   - Dependabot (.github/dependabot.yml)
   - Renovate (renovate.json)
   - Snyk (.snyk)
   - Other auto-update configs
3. Known risk pattern detection:
   - EOL dependency versions
   - Hardcoded secret patterns (.env committed, API key patterns)
   - Unsafe direct dependencies (check audit results if present)
4. Authentication/authorization implementation approach
5. Secret management method (Vault, AWS SSM, env vars, etc.)
6. SBOM presence (cyclonedx, SPDX files)
```

---

### Step 5. Community and Maintenance Maturity

```
1. Project activity:
   - Most recent commit date and commit frequency
   - Open issues/PR count, last release date
   - Number and distribution of contributors
2. Governance:
   - CONTRIBUTING.md presence
   - CODE_OF_CONDUCT.md presence
   - Branch strategy, PR review process
3. Corporate sponsorship:
   - Corporate-backed or foundation-led (README, GitHub Org, CNCF/ASF membership)
4. Release cadence:
   - CHANGELOG / RELEASES analysis
   - LTS version availability
   - SemVer compliance
5. Documentation quality:
   - API docs, operations guide, migration guide presence
```

---

### Step 6. Commercialization Architecture Fitness

```
1. Scalability:
   - Horizontal/vertical scaling support
   - Multi-tenancy support
   - Configuration injection approach (12-factor app compliance)
2. Production environment support:
   - Docker/Kubernetes readiness
   - Health check, readiness/liveness probe implementation
   - Structured logging, metrics exposure (Prometheus, etc.)
   - Distributed tracing support
3. Test system:
   - Unit / integration / e2e test presence
   - Coverage level
   - CI automation of tests
4. Plugin/extension architecture:
   - Core engine vs. business logic separability
   - Strong Copyleft module isolation feasibility
5. Dependency locking:
   - Lockfile presence (package-lock.json, go.sum, Cargo.lock, etc.)
   - Reproducible build guarantee
```

---

### Step 7. Legal, Contractual, and Compliance Risk Assessment

Evaluate against ISO 5230 / OpenChain standards.

```
1. OpenChain compliance stage status:
   [Identify] → [Source scan] → [Remediate] → [Review/approve] → [Register/notify/distribute]
2. NOTICE distribution method:
   - Included in installer?
   - In-product copyright/license menu?
3. Source disclosure method defined for Strong Copyleft usage?
4. Commercial distribution license violation risk:
   - AGPL SaaS commercialization risk
   - GPL propagation scope (consider linking method)
5. Trademark issues:
   - Commercial use restrictions on project name/logo
6. Patent risk:
   - Apache 2.0 includes patent grant (note explicitly)
   - MIT/BSD do not include patent grant (note explicitly)
```

---

### Step 8. Commercialization Risk Rating

Rate each dimension using a **5-level scale**. This scale applies to commercialization readiness only — it is separate from the license classification colors in Section 2.3 of the report.

- 🟢 **Safe**: Ready for commercialization as-is
- 🔵 **Review**: Conditional use — additional review required
- 🟡 **Caution**: Architecture adjustment needed
- 🟠 **Risk**: Legal/OSPO review mandatory
- 🔴 **Block**: Unsuitable for commercialization — replace

---

### Step 9. Report Generation

After completing analysis, save the report to `.review/<output-filename>.md` at the project root.

- Create `.review/` directory if it does not exist.
- Overwrite if the file already exists.
- Include `분석일 / Analysis Date: YYYY-MM-DD`, target path, and analyst (Claude) at the top.

---

## Report Structure

```markdown
# 오픈소스 상용화 심층 분석 보고서 / In-Depth Open Source Commercialization Review

> 분석일 / Analysis Date: YYYY-MM-DD  
> 대상 / Target: <project path>  
> 분석 / Analyst: Claude (Anthropic)

---

## 1. 프로젝트 개요 / Project Overview

### 1.1 목적 및 분류 / Purpose and Classification
- 해결하는 문제 / Problem solved
- 분류 / Classification: Library / Framework / Application / Platform / Tool

### 1.2 소프트웨어 스택 / Software Stack
| 구분 / Category | 내용 / Details |
|---|---|
| 언어/런타임 / Language & Runtime | |
| 프레임워크 / Framework | |
| 데이터 저장소 / Data Store | |
| 통신 방식 / Communication | |
| 배포 환경 / Deployment | |

### 1.3 아키텍처 구조 / Architecture
(Mermaid diagram or text description)

### 1.4 소스 트리 구조 / Source Tree
(Actual directory tree — observed facts only)

---

## 2. 라이선스 분석 / License Analysis

### 2.1 프로젝트 자체 라이선스 / Project License
(LICENSE file summary, license name, version, key obligations)

### 2.2 의존성 라이선스 목록 / Dependency License Inventory
| 패키지 / Package | 버전 / Version | 라이선스 / License | 분류 / Class | 위험도 / Risk |
|---|---|---|---|---|
| | | | | |

### 2.3 라이선스 위험도 분류표 / License Risk Classification
| 등급 / Level | 라이선스 / Licenses | 상용화 영향 / Commercialization Impact |
|---|---|---|
| 🟢 Permissive | MIT, Apache 2.0, BSD, ISC | 소스 비공개 허용 / Source closure allowed |
| 🟡 Weak Copyleft | LGPL, MPL | 동적 링크 시 제한적 / Limited for dynamic linking |
| 🟠 Strong Copyleft | GPL-2.0, GPL-3.0 | 전파 위험 / Propagation risk |
| 🔴 Network Copyleft | AGPL-3.0 | SaaS 배포 시 소스 공개 의무 / Source disclosure on SaaS |
| 🔴 Commercial-incompatible | BUSL, Commons Clause, SSPLv1 | 상용화 금지 / Commercialization prohibited |

### 2.4 라이선스 호환성 분석 / License Compatibility Analysis
(Conflict detection, GPL propagation scope, AGPL SaaS risk)

### 2.5 상용화 시 의무 이행 사항 / Compliance Obligations
- [ ] 저작권 고지 포함 방법 / Copyright notice inclusion method
- [ ] NOTICE/고지문 배포 위치 / NOTICE distribution location
- [ ] 소스 공개 의무 여부 및 방식 / Source disclosure obligation and method

---

## 3. 보안 분석 / Security Analysis

### 3.1 보안 정책 및 취약점 관리 체계 / Security Policy and Vulnerability Management
(SECURITY.md, Dependabot, Renovate, Snyk)

### 3.2 알려진 위험 요소 / Known Risk Factors
(EOL dependencies, hardcoded secrets, vulnerable versions)

### 3.3 보안 아키텍처 평가 / Security Architecture Assessment
(Auth/authz approach, secret management, SBOM)

---

## 4. 커뮤니티·유지보수 평가 / Community and Maintenance Assessment

### 4.1 프로젝트 활성도 / Project Activity
| 항목 / Item | 내용 / Details |
|---|---|
| 최근 커밋 / Latest commit | |
| 커밋 빈도 / Commit frequency | |
| 기여자 수 / Contributors | |
| 마지막 릴리스 / Last release | |
| 오픈 이슈 수 / Open issues | |

### 4.2 거버넌스 문서 / Governance Documents
(CONTRIBUTING, CODE_OF_CONDUCT, ADR presence)

### 4.3 기업 스폰서십 및 장기 지원 전망 / Corporate Sponsorship and Long-term Outlook
(CNCF/ASF membership, corporate backer, LTS availability)

---

## 5. 상용화 아키텍처 적합성 / Commercialization Architecture Fitness

### 5.1 확장성 및 운영 지원 / Scalability and Operations Support
(Multi-tenancy, containerization, health check, metrics, structured logging)

### 5.2 테스트 및 품질 체계 / Test and Quality System
(Test types, coverage, CI automation)

### 5.3 Strong Copyleft 모듈 분리 가능성 / Strong Copyleft Module Isolation
(Can the module be isolated without architecture overhaul?)

### 5.4 12-Factor App 준수도 / 12-Factor App Compliance
(Config injection, reproducible builds, stateless processes)

---

## 6. 법적·컴플라이언스 리스크 / Legal and Compliance Risk

### 6.1 ISO 5230/OpenChain 컴플라이언스 현황 / OpenChain Compliance Status
| 단계 / Stage | 상태 / Status | 비고 / Notes |
|---|---|---|
| 1. 오픈소스 식별 / Identify | | |
| 2. 소스 코드 검사 / Source scan | | |
| 3. 문제 해결·대체 / Remediate | | |
| 4. 검토·승인 / Review & approve | | |
| 5. 등록·고지·배포 / Register, notify, distribute | | |

### 6.2 상표권·특허 위험 / Trademark and Patent Risk
(Commercial use restrictions on name/logo, patent grant presence)

### 6.3 AGPL·GPL 전파 위험 시나리오 / AGPL/GPL Propagation Risk Scenarios
(Actual risk paths for SaaS distribution)

---

## 7. 종합 평가 / Overall Assessment

### 7.1 항목별 등급 / Dimension Ratings

| 평가 항목 / Dimension | 등급 / Rating | 근거 / Rationale |
|---|---|---|
| 라이선스 위험 / License risk | 🟢/🔵/🟡/🟠/🔴 | |
| 보안 체계 / Security system | | |
| 커뮤니티 건강도 / Community health | | |
| 운영 성숙도 / Operational maturity | | |
| 상용화 아키텍처 / Commercialization fit | | |
| 법적 컴플라이언스 / Legal compliance | | |

### 7.2 강점 / Strengths (3–5 items)
1.
2.
3.

### 7.3 위험·개선 필요 사항 / Risks and Improvement Areas (3–5 items)
1.
2.
3.

### 7.4 상용화 도입 권고 / Commercialization Recommendation

**종합 판정 / Overall Verdict**: 🟢 Safe / 🔵 Review / 🟡 Caution / 🟠 Risk / 🔴 Block

(Detailed rationale and preconditions)

---

## 8. 실무 상용화 체크리스트 / Practical Commercialization Checklist

| 항목 / Category | 체크 포인트 / Check Point | 판정 / Status |
|---|---|---|
| 라이선스 / License | - [ ] Permissive/Weak/Strong Copyleft 분류 확인 / Classification verified | |
| | - [ ] 소스 공개 의무 여부 확인 / Source disclosure obligation checked | |
| | - [ ] 라이선스 호환성 충돌 없음 / No compatibility conflicts | |
| 저작권·고지 / Copyright & Notice | - [ ] 저작권 문구 포함 / Copyright notice included | |
| | - [ ] 고지문 배포 위치 정의 / NOTICE distribution location defined | |
| 소스 공개 / Source Disclosure | - [ ] Strong Copyleft 사용 시 공개 범위·방식 정의 / Scope and method defined if applicable | |
| 보안 / Security | - [ ] CVE 모니터링 체계 수립 / CVE monitoring in place | |
| | - [ ] 중고위험 취약점 패치 계획 / High-risk CVE patch plan defined | |
| 커뮤니티 / Community | - [ ] 유지보수 활성도·커밋 주기 확인 / Maintenance activity confirmed | |
| | - [ ] 기업 스폰서/컨설팅 존재 확인 / Corporate sponsor or consulting available | |
| CI/CD | - [ ] 라이선스 검사 자동화 / License scan automated | |
| | - [ ] 오픈소스 BOM 자동 생성 / BOM auto-generation configured | |
| | - [ ] 위반 라이선스 빌드 차단 / Prohibited license build gate active | |
| 법적·계약 / Legal | - [ ] 고객 계약서에 라이선스 의무 명시 / Customer contract includes license obligations | |
| | - [ ] 외부 감사 대비 문서 구비 / Audit-ready docs prepared (NOTICE, BOM, report) | |

---

## 9. 권고 조치 사항 / Recommended Actions

### 즉시 조치 / Critical (immediate)
(License violations, security vulnerabilities requiring immediate response)

### 단기 조치 / High (within 30 days)
(Architecture adjustments, vulnerable dependency replacements)

### 중기 조치 / Medium (within 90 days)
(CI/CD integration, BOM generation automation)

### 장기 권고 / Low (quarterly review)
(Community contribution, periodic compliance audits)
```

---

**PDF conversion (default: disabled):**

After saving the markdown, convert to PDF only if `--pdf true` was specified.
Use the following priority order — stop at first working tool:

1. `pandoc <input.md> -o <output.pdf>`
2. `md-to-pdf <input.md>`
3. `grip <input.md> --export <output.pdf>`
4. If none available, print warning and skip PDF conversion.

---

**Execution rules:**

1. Always run Step 1 first. Never skip the structure overview.
2. Record only observed facts. Mark absent files as "확인 불가 — 파일 부재 / Not found — file absent."
3. For projects with 100+ dependencies, prioritize Copyleft-class licenses; summarize the rest.
4. Create `.review/` directory if it does not exist.
5. After saving the report, output the file path and a one-paragraph summary of the commercialization verdict.
