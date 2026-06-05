You are a senior developer tasked with creating comprehensive guides for a project. Your goal is to analyze the target project and produce two detailed guide documents for junior developers and implementers.

**Language requirement**: Every guide file must be written **bilingually** — each section contains the Korean version first, immediately followed by the English version. Use clear language markers (`**[한국어]**` and `**[English]**`) within every section body. Section headings themselves use the format `한국어 제목 / English Title`.

## Target Project

`$ARGUMENTS` may contain:

- **Options** (parsed before paths):
  - `-O` / `--overall` — Aggregate mode (multi-project only). Default `false`.
    - **Off (default)**: each project gets its **own** `.review/GUIDE4Junior.md` and `.review/GUIDE4ImpMethod.md`.
    - **On**: all per-project guides are written under the **first project's** `.review/GUIDE4Junior/` and `.review/GUIDE4ImpMethod/` directories (one subdir per project named by project basename), plus a top-level cross-project overview guide.
- **Positional arguments**: one or more analysis target paths (space-separated). If none, use the current working directory.

**Single vs. Multi-project mode:**

- **Single project** (one path or none): produce `.review/GUIDE4Junior.md` and `.review/GUIDE4ImpMethod.md` in that project. `--overall` is ignored.
- **Multi-project default** (≥2 paths, no `--overall`): produce both guide files **per project**, each saved in that project's own `.review/`. No cross-project overview.
- **Multi-project with `-O`/`--overall`**:
  - For each project: full guides at `<first-project>/.review/GUIDE4Junior/<project-basename>/GUIDE4Junior.md` and `<first-project>/.review/GUIDE4ImpMethod/<project-basename>/GUIDE4ImpMethod.md`.
  - Plus aggregate overview guides at `<first-project>/.review/GUIDE4Junior/GUIDE4Junior.md` and `<first-project>/.review/GUIDE4ImpMethod/GUIDE4ImpMethod.md`. The aggregate files contain: project list, shared setup prerequisites, per-project quick links, and a comparison/integration scenarios section (for ImpMethod).

Parsing examples:

| Arguments | Behavior |
|---|---|
| (none) | Single, current dir → `.review/GUIDE4Junior.md` + `.review/GUIDE4ImpMethod.md` |
| `/proj/A` | Single → `A/.review/GUIDE4Junior.md` + `A/.review/GUIDE4ImpMethod.md` |
| `/proj/A /proj/B` | Per-project → `A/.review/GUIDE4Junior.md` + `B/.review/GUIDE4Junior.md` (and ImpMethod likewise) |
| `/proj/A /proj/B -O` | Aggregate → `A/.review/GUIDE4Junior/{GUIDE4Junior.md, A/GUIDE4Junior.md, B/GUIDE4Junior.md}` (and ImpMethod likewise) |

---

## Step 1: Project Analysis

Before writing any guides, thoroughly analyze the project:

1. **Read key files**: `README.md`, `package.json` / `pom.xml` / `build.gradle` / `Cargo.toml` / `go.mod` / `pyproject.toml` / `requirements.txt` — whatever build/dependency manifests exist.
2. **Explore the source tree**: understand the top-level directory layout, main entry points, configuration files, test directories, CI/CD pipelines (`.github/`, `Jenkinsfile`, `Makefile`, `Dockerfile`, `docker-compose.yml`, etc.).
3. **Identify the tech stack**: language(s), frameworks, databases, external services, cloud providers.
4. **Identify build & run commands** from scripts, CI configs, or READMEs.
5. **Check for environment variables**: `.env.example`, `config/`, `application.yml`, etc.
6. **Search the web** if the tech stack is unfamiliar or if official setup instructions would help (e.g., specific framework version quirks, known pitfalls).

---

## Step 2: Create `GUIDE4Junior.md`

**Output path resolution** (use the mode rules from "Target Project"):

- Single or multi-project default: write to `<project>/.review/GUIDE4Junior.md` for each project.
- Multi-project with `--overall`: write to `<first-project>/.review/GUIDE4Junior/<project-basename>/GUIDE4Junior.md` per project, **plus** an aggregate `<first-project>/.review/GUIDE4Junior/GUIDE4Junior.md`. The aggregate file must follow the same template, but Sections 1, 4, and 9 should summarize across all projects (with per-project sub-bullets and links to the per-project files); other sections must list shared prerequisites/setup steps and explicitly call out project-specific differences.

Write every section **bilingually**: Korean first, then English, within the same section body. Use `**[한국어]**` and `**[English]**` labels to distinguish them.

The file must follow this exact template structure:

---

```markdown
# 프로젝트 주니어 개발자 가이드 / Junior Developer Guide

> 이 문서는 한국어와 영어로 작성되었습니다.  
> This document is written in both Korean and English.

---

## 1. 프로젝트 개요 / Project Overview

**[한국어]**
- 프로젝트 목적 및 핵심 기능 요약 (2~5문장)
- 주요 기술 스택: 언어, 프레임워크, 데이터베이스, 주요 라이브러리

**[English]**
- Summary of the project's purpose and core features (2–5 sentences)
- Key tech stack: language(s), framework(s), database(s), major libraries

---

## 2. 개발 환경 요구사항 / Prerequisites

**[한국어]**
- 필수 도구 목록 (버전 포함): Node.js, JDK, Python, Go, Docker 등
- 권장 IDE 및 플러그인/익스텐션
- OS별 주의사항 (있을 경우)

**[English]**
- Required tools with versions: Node.js, JDK, Python, Go, Docker, etc.
- Recommended IDE and plugins/extensions
- OS-specific notes (if any)

---

## 3. 개발 환경 구성 (단계별) / Environment Setup (Step-by-Step)

**[한국어]**
1. 저장소 클론
2. 의존성 설치
3. 환경 변수 설정 (.env 예시 포함)
4. 데이터베이스 또는 외부 서비스 초기화 (해당 시)
5. 검증: 설치가 올바른지 확인하는 명령어

**[English]**
1. Clone the repository
2. Install dependencies
3. Configure environment variables (include .env example)
4. Initialize database or external services (if applicable)
5. Verify: commands to confirm the setup is correct

---

## 4. 소스 구조 설명 / Source Structure

**[한국어]**
```tree
(실제 디렉토리 트리 삽입)
```
- 각 주요 디렉토리/파일의 역할 설명
- 핵심 모듈 간 의존 관계 (간단한 다이어그램 또는 설명)

**[English]**
```tree
(same directory tree)
```
- Role of each major directory/file
- Dependency relationships between core modules (diagram or description)

---

## 5. 로컬 빌드 방법 / Local Build

**[한국어]**
- 빌드 명령어 (개발/프로덕션 구분)
- 빌드 결과물 위치 및 의미
- 자주 발생하는 빌드 오류와 해결 방법

**[English]**
- Build commands (development vs. production)
- Build output location and meaning
- Common build errors and how to fix them

---

## 6. 로컬 실행 방법 / Running Locally

**[한국어]**
- 실행 명령어 (개발 모드 / 프로덕션 모드)
- 접속 URL 또는 포트 정보
- Docker / docker-compose를 사용하는 경우 해당 명령어
- 실행 확인 방법 (health check, 로그 확인 등)

**[English]**
- Run commands (dev mode / production mode)
- Access URL or port information
- Docker / docker-compose commands (if applicable)
- How to verify the app is running (health check, log inspection, etc.)

---

## 7. 테스트 실행 / Running Tests

**[한국어]**
- 단위 테스트 / 통합 테스트 실행 명령어
- 테스트 커버리지 확인 방법
- 테스트 데이터 또는 픽스처 설정 방법 (해당 시)

**[English]**
- Unit test / integration test commands
- How to check test coverage
- Test data or fixture setup (if applicable)

---

## 8. 코드 기여 가이드라인 / Contribution Guidelines

**[한국어]**
- 브랜치 전략
- 커밋 메시지 컨벤션
- PR/코드 리뷰 절차
- 코딩 스타일 / 린트 규칙

**[English]**
- Branching strategy
- Commit message conventions
- PR / code review process
- Coding style and lint rules

---

## 9. 자주 묻는 질문 / FAQ

**[한국어]**
- 환경 구성 중 자주 겪는 문제와 해결책 (최소 3가지)

**[English]**
- Common setup issues and solutions (at least 3)
```

---

Fill every section with **concrete, specific information** derived from the actual project. Do not leave placeholder text. If a section is not applicable (e.g., no tests exist), state that clearly in **both languages** with a brief explanation.

---

## Step 3: Create `GUIDE4ImpMethod.md`

**Output path resolution** (use the mode rules from "Target Project"):

- Single or multi-project default: write to `<project>/.review/GUIDE4ImpMethod.md` for each project.
- Multi-project with `--overall`: write to `<first-project>/.review/GUIDE4ImpMethod/<project-basename>/GUIDE4ImpMethod.md` per project, **plus** an aggregate `<first-project>/.review/GUIDE4ImpMethod/GUIDE4ImpMethod.md`. The aggregate file follows the same template but must include a cross-project integration/composition scenarios subsection in Section 3 and a comparative pros/cons table in Section 8.

**Use web search** to supplement best practices for this specific tech stack and how the project's patterns are used in real-world scenarios.

Write every section **bilingually**: Korean first, then English, within the same section body.

The file must follow this exact template structure:

---

```markdown
# 실전 프로젝트 활용 가이드 / Implementation Method Guide

> 이 문서는 한국어와 영어로 작성되었습니다.  
> This document is written in both Korean and English.

---

## 1. 이 저장소의 활용 목적 / Purpose of This Repository

**[한국어]**
- 라이브러리 / 프레임워크 / 보일러플레이트 / 레퍼런스 구현 등 분류
- 실전에서 어떤 문제를 해결하기 위해 사용하는지

**[English]**
- Classification: library / framework / boilerplate / reference implementation
- What real-world problems this repository solves

---

## 2. 아키텍처 이해 / Architecture Overview

**[한국어]**
- 전체 아키텍처 다이어그램 (Mermaid 형식)
- 핵심 컴포넌트와 그 역할
- 데이터 흐름 설명

**[English]**
- Overall architecture diagram (Mermaid format)
- Core components and their roles
- Data flow description

```mermaid
(insert actual Mermaid diagram here)
```

---

## 3. 실전 프로젝트 적용 시나리오 / Real-World Scenarios

**[한국어]**
- 시나리오 1: [구체적인 사용 사례 — 단계별 설명]
- 시나리오 2: [구체적인 사용 사례 — 단계별 설명]
- (기술 스택에 따라 추가)

**[English]**
- Scenario 1: [specific use case — step-by-step]
- Scenario 2: [specific use case — step-by-step]
- (add more based on tech stack)

---

## 4. 확장 및 커스터마이징 / Extension & Customization

**[한국어]**
- 설정 변경 포인트 (환경 변수, 설정 파일)
- 기능 추가 시 수정해야 할 주요 파일/모듈
- 플러그인 / 미들웨어 / 훅 구조 (해당 시)

**[English]**
- Configuration touch points (env vars, config files)
- Key files/modules to modify when adding features
- Plugin / middleware / hook architecture (if applicable)

---

## 5. 운영 환경 배포 / Production Deployment

**[한국어]**
- 프로덕션 빌드 및 배포 절차
- 환경별 설정 분리 방법
- CI/CD 파이프라인 연동 방법
- 컨테이너화 (Docker/Kubernetes) 가이드 (해당 시)

**[English]**
- Production build and deployment steps
- Environment-specific configuration separation
- CI/CD pipeline integration
- Containerization guide (Docker/Kubernetes, if applicable)

---

## 6. 성능 및 확장성 고려사항 / Performance & Scalability

**[한국어]**
- 알려진 성능 병목 지점
- 수평/수직 확장 전략
- 캐싱 전략 (해당 시)
- 모니터링 및 로깅 설정

**[English]**
- Known performance bottlenecks
- Horizontal / vertical scaling strategies
- Caching strategy (if applicable)
- Monitoring and logging configuration

---

## 7. 보안 체크리스트 / Security Checklist

**[한국어]**
- 환경 변수 및 시크릿 관리
- 인증/인가 구현 포인트
- 의존성 취약점 점검 방법
- 알려진 보안 고려사항

**[English]**
- Environment variable and secret management
- Authentication / authorization implementation points
- Dependency vulnerability scanning
- Known security considerations

---

## 8. 관련 참고 자료 / References

**[한국어]**
- 공식 문서 링크
- 관련 블로그 포스트 / 튜토리얼
- 커뮤니티 리소스
- 유사 프로젝트 비교 (장단점)

**[English]**
- Official documentation links
- Related blog posts / tutorials
- Community resources
- Comparison with similar projects (pros and cons)
```

---

For sections where the project does not provide direct evidence, use web search to find best practices for the identified tech stack and annotate with:
> 참고: 공식 문서 기반 권장 사항 / Note: Recommended based on official documentation

---

## Step 4: Final Check

After creating the files:

1. Verify all expected files exist at the paths dictated by the resolved mode:
   - Single / multi-default: `<project>/.review/GUIDE4Junior.md` and `<project>/.review/GUIDE4ImpMethod.md` for each project.
   - Multi + `--overall`: aggregate files at `<first-project>/.review/GUIDE4Junior/GUIDE4Junior.md` and `<first-project>/.review/GUIDE4ImpMethod/GUIDE4ImpMethod.md`, plus per-project files under each `<project-basename>/` subdir.
2. Confirm `.review/` and any aggregate subdirs were created if they didn't exist.
3. Report a brief summary (Korean + English) of what was written: list each generated file path, highlight any sections where you relied on web search, and call out any sections skipped due to not being applicable.
