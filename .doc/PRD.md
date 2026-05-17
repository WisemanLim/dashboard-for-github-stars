# PRD: GitHub Stars Dashboard

## 1. 개요

GitHub 인기 저장소 현황을 매일 자동 수집하여 정적 대시보드로 제공하는 시스템.  
수집 → 분석 → 정적 파일 생성 → GitHub Pages 배포까지 완전 자동화.

---

## 2. 목표

| 목표 | 설명 |
|------|------|
| 자동 수집 | 매일 오전 2시(KST) GitHub 데이터 수집 |
| 대시보드 | Top 100 + 인기상승(일/주/월) 정적 페이지 |
| 자동 분석 | 인기상승 상위 5개 repo 심층 분석 |
| 배포 | GitHub Pages 정적 사이트 자동 배포 |
| 운영 자동화 | 리눅스 서버 기반 완전 무인 운영 |

---

## 3. 기능 요구사항

### 3.1 데이터 수집

- **수집 주기**: 매일 오전 2시 KST (systemd timer)
- **수집 대상**:
  - Top 100: GitHub Search API `sort=stars` 기준 카테고리별 누적 스타 상위 100개
  - 인기상승 Daily: GitHub Trending (today) 급상승 repo
  - 인기상승 Weekly: GitHub Trending (this week) 급상승 repo
  - 인기상승 Monthly: GitHub Trending (this month) 급상승 repo
- **수집 결과**: `data.json` (수집 시각 KST 포함), `previous_data.json` (전일 백업)

### 3.2 대시보드 (메인 페이지)

- **파일**: `site/index.html` (정적)
- **구성**:
  - Top 100 탭: 카테고리별 누적 스타 기준 순위
  - 인기상승 탭: Daily / Weekly / Monthly 전환
  - 검색: 저장소명, 설명, 언어 필터
  - 통계 요약: Stars, Forks, 언어 분포
  - 다크모드 지원
  - 푸터: 수집 시각 표시 ("Generated at 02:00 KST snapshot")
- **데이터**: `site/assets/data.json` fetch 방식 (브라우저 직접 로드)

### 3.3 자동 분석 (AI 분석 파이프라인)

- **대상**: 인기상승 repo 중 상위 5개
- **조건**: 전일 대비 신규 진입 repo 우선
- **사용 Skills** (Claude Code CLI):
  - `/analysis-source` - 소스코드 구조 분석
  - `/in-depth-review` - 심층 코드 리뷰
  - `/create-guide4junior` - 주니어 개발자용 가이드 생성
- **출력**: repo별 독립 정적 HTML 파일 (`site/analysis/{repo-name}.html`)

### 3.4 분석 결과 연동 (팝업)

- 대시보드의 인기상승 목록에서 분석된 repo에 "분석 보기" 링크 표시
- 링크 클릭 시 팝업(모달) 형태로 분석 결과 표시
- 팝업 내용: analysis-source 결과 + in-depth-review 요약 + junior guide 링크
- **파일 구조**: 대시보드(`index.html`)와 분석 결과(`analysis/*.html`) 완전 분리

### 3.5 정적 파일 독립 관리 원칙

```
site/
├── index.html              # 메인 대시보드
├── assets/
│   ├── data.json           # 당일 수집 데이터
│   └── previous_data.json  # 전일 백업
└── analysis/
    ├── {repo-name-1}.html  # 분석 결과 (repo별 독립 파일)
    ├── {repo-name-2}.html
    └── ...
```

- 대시보드와 분석 결과 파일은 각각 독립적으로 생성/관리
- 매일 새로운 분석 파일 생성 (날짜별 누적 또는 덮어쓰기)

---

## 4. 배포 아키텍처

### 4.1 구성 요소

```
[Oracle Cloud Free Server]          [GitHub]
  systemd timer (02:00 KST)   →   Source repo (main branch)
  Python 수집 스크립트          →   GitHub Pages (site/ 폴더)
  Claude Code CLI (분석)        →   공개 대시보드 URL
  Shell 오케스트레이터
```

### 4.2 GitHub 저장소 구조

```
github-stars-dashboard/          # 소스 관리 계정 repo
├── .github/
│   └── workflows/
│       └── pages.yml            # (선택) GitHub Actions 배포
├── .claude/
│   └── commands/
│       ├── analysis-source.md   # /analysis-source skill
│       ├── in-depth-review.md   # /in-depth-review skill
│       └── create-guide4junior.md  # /create-guide4junior skill
├── scripts/
│   ├── bootstrap_server.sh      # 서버 최초 초기화
│   ├── run_daily.sh             # 일일 실행 오케스트레이터
│   ├── collect_data.py          # GitHub 데이터 수집
│   ├── build_dashboard.py       # index.html 생성
│   ├── compare_with_previous.py # 전일 대비 비교
│   └── run_claude_analysis.sh   # Claude skills 실행
├── templates/
│   ├── dashboard.html.j2        # 대시보드 템플릿
│   └── analysis.html.j2         # 분석 결과 템플릿
├── site/                        # 배포 대상 (GitHub Pages source)
│   ├── index.html
│   ├── assets/
│   └── analysis/
├── requirements.txt
└── README.md
```

### 4.3 배포 계정 분리

| 역할 | 계정 | 용도 |
|------|------|------|
| 소스 관리 | `{source-account}` | 스크립트/코드 관리 repo |
| 페이지 배포 | `{deploy-account}` | GitHub Pages 공개 repo |

- 소스 repo와 배포 repo 분리 운영 가능 (또는 동일 계정 사용 가능)
- GitHub Pages: `https://{deploy-account}.github.io/{repo-name}/`

### 4.4 GitHub Pages 설정

- **Source**: `main` branch → `/site` 폴더
- **URL**: `https://{deploy-account}.github.io/{repo-name}/`
- **HTTPS**: 자동 적용

---

## 5. 자동화 파이프라인 (일일 실행 흐름)

```
02:00 KST
  │
  ├─ [1] git pull (최신 소스 동기화)
  ├─ [2] previous_data.json 백업
  ├─ [3] collect_data.py (GitHub API + Trending 수집)
  ├─ [4] compare_with_previous.py (전일 대비 신규 repo 식별)
  ├─ [5] build_dashboard.py (index.html 생성)
  ├─ [6] run_claude_analysis.sh (상위 5개 repo 분석)
  │     ├─ /analysis-source
  │     ├─ /in-depth-review
  │     └─ /create-guide4junior
  │     → site/analysis/{repo}.html 생성
  └─ [7] git commit & push → GitHub Pages 자동 반영
```

---

## 6. 배포 쉘스크립트 (deploy.sh)

### 6.1 실행 방식

```bash
bash deploy.sh
```

### 6.2 사용자 입력 항목

스크립트 실행 시 대화형으로 입력 받음:

| 항목 | 설명 | 예시 |
|------|------|------|
| 소스 관리 GitHub 계정 | 코드 관리 계정명 | `myaccount` |
| 배포 GitHub 계정 | Pages 배포 계정명 | `myaccount` (동일 가능) |
| 배포 repo 이름 | Pages가 활성화된 repo | `github-stars-dashboard` |
| 스케줄러 실행 시각 | cron 시간 (KST) | `02:00` |
| GitHub Personal Access Token | push 권한용 PAT | `ghp_xxx...` |
| Claude API Key | Claude Code CLI 인증 | `sk-ant-xxx...` |
| Claude 모델 | 분석에 사용할 모델 | `claude-sonnet-4-6` |

### 6.3 스크립트 수행 단계

```
deploy.sh 실행
  ├─ [입력] 계정 정보, 스케줄, Claude 연결 정보
  ├─ [검증] 필수 패키지 확인 (git, python3, curl)
  ├─ [설치] Claude Code CLI 설치 및 인증 구성
  ├─ [구성] .claude/commands/ 에 skills 배포
  ├─ [구성] Git remote 설정 (source/deploy 계정)
  ├─ [구성] systemd timer 생성 (입력받은 시각 기준)
  ├─ [구성] GitHub PAT를 git credential에 등록
  └─ [확인] 수동 1회 실행 옵션 제공
```

---

## 7. Claude Skills 배포 요구사항

### 7.1 Skills 위치

```
.claude/commands/
├── analysis-source.md      # /analysis-source
├── in-depth-review.md      # /in-depth-review
└── create-guide4junior.md  # /create-guide4junior
```

### 7.2 서버 실행 방식

```bash
# 각 skill을 Claude Code CLI로 비대화형 실행
claude --print /analysis-source --target {repo_url} > site/analysis/{repo}.md
```

- `--print` 플래그로 비대화형(non-interactive) 실행
- 출력 결과를 정적 HTML로 변환하여 `site/analysis/` 에 저장
- Claude API Key는 환경변수 `ANTHROPIC_API_KEY`로 주입

---

## 8. 기술 스택

| 영역 | 기술 |
|------|------|
| 서버 | Oracle Cloud Always Free (Ubuntu 22.04+, Ampere A1, 1 OCPU / 6GB RAM) |
| 스케줄러 | systemd timer (KST 기준) |
| 데이터 수집 | Python 3.12+, GitHub Search API, GitHub Trending 파싱 |
| 대시보드 생성 | Python (Jinja2 템플릿 → 정적 HTML) |
| AI 분석 | Claude Code CLI + `/analysis-source`, `/in-depth-review`, `/create-guide4junior` |
| 정적 배포 | GitHub Pages (main branch / site/ 폴더) |
| 인증 | GitHub PAT (push), Anthropic API Key (Claude) |

---

## 9. 비기능 요구사항

| 항목 | 요구사항 |
|------|---------|
| 무료 운영 | Oracle Cloud Always Free + GitHub Pages Free |
| 정적 파일 | 모든 산출물은 서버 없이 브라우저에서 직접 열람 가능 |
| 독립성 | 대시보드와 분석 결과 파일 간 독립 생성/관리 |
| 내결함성 | Claude 분석 실패 시 나머지 파이프라인 계속 실행 |
| 수동 실행 | `systemctl start github-dashboard.service` 로 즉시 재실행 가능 |
| 투명성 | 대시보드 푸터에 수집 시각 KST 명시 |

---

## 10. 제약사항 및 결정사항

| 항목 | 결정 |
|------|------|
| 계정 생성 | 수동 진행 (GitHub/Google 약관상 자동화 불가) |
| GitHub API Rate Limit | PAT 사용으로 시간당 5,000 요청 확보 |
| Trending 수집 | GitHub Trending 페이지 HTML 파싱 (공식 API 미제공) |
| 분석 대상 | 인기상승 top 5 고정 (Claude API 비용 제어) |
| 배포 방식 | GitHub Pages branch 배포 (Actions 불필요, 단순 push) |
| Skills 실행 | Claude Code CLI `--print` 비대화형 모드 |

---

## 11. 마일스톤

| 단계 | 내용 |
|------|------|
| M1 | 저장소 구조 및 Python 수집 스크립트 |
| M2 | 정적 대시보드 HTML 생성 (Top 100 + 인기상승) |
| M3 | Claude Skills 연동 + 분석 결과 팝업 |
| M4 | `deploy.sh` 작성 + systemd timer 구성 |
| M5 | GitHub Pages 배포 검증 + 자동화 end-to-end 테스트 |
