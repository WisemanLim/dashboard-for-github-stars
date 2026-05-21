# GitHub Stars Dashboard

GitHub 인기 저장소를 매일 오전 2시(KST) 자동 수집하여 GitHub Pages에 정적 대시보드로 배포합니다.

## 계정 구성 (A / B)

| 역할 | 설명 |
|------|------|
| **계정 A** (소스) | 이 저장소(스크립트·스케줄러·Claude 분석)를 소유하는 GitHub 계정. 로컬 PC 또는 Linux 서버에서 실행됩니다. |
| **계정 B** (배포) | GitHub Pages가 활성화된 저장소를 소유하는 계정. 생성된 정적 파일(`site/`)이 여기로 push됩니다. 계정 A와 동일해도 무방합니다. |

## 기능

| 기능 | 설명 |
|------|------|
| **Top 100** | 카테고리별 누적 스타 기준 상위 100개 저장소 |
| **인기상승** | Daily / Weekly / Monthly 급상승 저장소 (GitHub Trending) |
| **자동 분석** | 신규 트렌딩 상위 5개 repo를 Claude로 심층 분석 |
| **분석 팝업** | 분석 결과를 모달 팝업으로 연결 |
| **정적 배포** | GitHub Pages 자동 배포 (서버 비용 없음) |

## 구조

```
.
├── .claude/commands/             # Claude skill 파일
│   ├── analysis-source.md
│   ├── in-depth-review.md
│   └── create-guide4junior.md
├── scripts/
│   ├── collect_data.py           # GitHub API + Trending 수집
│   ├── compare_with_previous.py  # 신규 트렌딩 식별
│   ├── build_dashboard.py        # index.html 생성
│   ├── run_claude_analysis.sh    # Claude 분석 실행 (Linux / macOS)
│   ├── run_claude_analysis.ps1   # Claude 분석 실행 (Windows)
│   ├── run_daily.sh              # 일일 오케스트레이터 (Linux / macOS)
│   ├── run_daily.ps1             # 일일 오케스트레이터 (Windows)
│   └── bootstrap_server.sh      # 서버 최초 초기화 (Linux)
├── templates/
│   ├── dashboard.html.j2         # 대시보드 템플릿
│   └── analysis.html.j2          # 분석 결과 템플릿
├── site/                         # GitHub Pages 배포 대상
│   ├── index.html                # 생성된 대시보드 (자동)
│   ├── assets/
│   │   ├── data.json             # 당일 수집 데이터 (자동)
│   │   ├── previous_data.json    # 전일 백업 (자동)
│   │   └── new_trending.json     # 신규 트렌딩 목록 (자동)
│   └── analysis/                 # repo별 분석 HTML (자동)
├── deploy.sh                     # 인터랙티브 배포 설정 (Linux / macOS)
├── deploy.ps1                    # 인터랙티브 배포 설정 (Windows PowerShell)
├── test.sh                       # deploy.sh 스모크 테스트 (macOS)
├── requirements.txt
├── .env.example                  # 환경 변수 템플릿 (git 포함)
└── .env                          # 실제 환경 변수 (git 제외, .env.example 복사 후 수정)
```

## 빠른 시작

### Linux / macOS

```bash
# 1. 저장소 클론 (계정 A)
git clone https://github.com/WisemanLim/dashboard-for-github-stars.git
cd dashboard-for-github-stars

# 2. 배포 설정 (대화형 — 계정/시간 입력, gh/claude 인증 포함)
bash deploy.sh
```

### Windows (PowerShell)

```powershell
# 1. 저장소 클론 (계정 A)
git clone https://github.com/WisemanLim/dashboard-for-github-stars.git
cd dashboard-for-github-stars

# 2. 실행 정책 허용 (최초 1회)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# 3. 배포 설정 (대화형)
.\deploy.ps1
```

`deploy.sh` / `deploy.ps1`이 물어보는 항목:

| 항목 | 설명 |
|------|------|
| Source GitHub 계정 (A) | 스크립트·스케줄러 소스 코드를 소유하는 계정 |
| Deploy GitHub 계정 (B) | GitHub Pages 정적 파일을 push할 계정 (A와 동일 가능) |
| Deploy repo 이름 | 계정 B에서 Pages가 활성화된 repo명 (없으면 자동 생성) |
| 스케줄 시각 | KST 기준 HH:MM (기본: 02:00) |
| 스케줄러 | macOS: launchd / cron / skip, Linux: systemd / cron / skip |
| Claude 모델 | 기본: `claude-sonnet-4-6` |
| GitHub 인증 | `gh auth login` (PAT 불필요 — 브라우저 또는 토큰 방식) |
| Claude 인증 | `claude login` OAuth 플로우 (이미 로그인된 경우 skip 선택 가능) |

> **재실행 시**: `.env`가 이미 존재하면 기존 값이 각 항목의 기본값으로 표시됩니다. Enter만 누르면 기존 설정 유지, 새 값을 입력하면 덮어씁니다.

> **헤드리스 서버(Oracle Cloud 등)**: `gh auth login` 시 토큰(PAT) 입력 방식도 선택 가능합니다.  
> **Deploy repo 자동 생성**: `gh repo view`로 존재를 확인하고, 없으면 `gh repo create`로 public repo를 자동 생성합니다.  
> **최초 push**: deploy repo에 `main` 브랜치가 없으면 `git push -u origin main`으로 초기 push를 자동 수행합니다.

## 스모크 테스트 (macOS)

`test.sh`는 현재 `.env` 값을 그대로 사용하여 `deploy.sh`를 비대화형으로 실행합니다.  
스케줄러 설정 및 최초 실행은 skip하고, 설정·인증·패키지 설치 단계만 검증합니다.

```bash
bash test.sh
# 로그: logs/test_YYYYMMDD_HHmmss.log
```

사전 조건 (hard — 미설치 시 테스트 중단):

| 항목 | 확인 방법 |
|------|----------|
| git | `git --version` |
| python3 | `python3 --version` |
| node | `node --version` |
| claude CLI | `claude --version` |
| Homebrew | `brew --version` (macOS only) |

사전 조건 (soft — deploy.sh가 처리):

| 항목 | 동작 |
|------|------|
| gh CLI | 미설치 시 `brew install gh` 자동 실행 |
| gh 인증 | 미인증 시 `gh auth login` 실행 (대화형) |

## GitHub Pages 설정

> `run_daily.sh`는 `site/` 내용물을 Deploy repo **루트**에 직접 배포합니다.  
> GitHub Pages는 루트(`/`)를 서빙 폴더로 지정해야 합니다.

1. Deploy repo(계정 B) → **Settings → Pages**
2. **Source**: `Deploy from a branch`
3. **Branch**: `main` / **Folder**: `/` (root)
4. 저장 → `https://ACCOUNT_B.github.io/REPO/` 접속 확인

## 수동 실행

```bash
# Linux / macOS
cp .env.example .env   # 최초 1회
source .env
bash scripts/run_daily.sh
```

```powershell
# Windows
Copy-Item .env.example .env   # 최초 1회
.\scripts\run_daily.ps1
```

## git remote 구성

| remote | URL | 용도 |
|--------|-----|------|
| `origin` | `https://github.com/SOURCE_ACCOUNT/dashboard-for-github-stars` | 스크립트 업데이트 pull |
| `deploy` | `https://github.com/DEPLOY_ACCOUNT/DEPLOY_REPO` | 생성된 `site/` push |

소스 코드는 Source repo에만 존재합니다. Deploy repo에는 **생성된 정적 파일만** 배포됩니다.

## 일일 파이프라인

```
02:00 KST
  [1] git pull origin main  (소스 스크립트 업데이트, 실패 시 skip)
  [2] data.json 백업
  [3] GitHub 데이터 수집 (API + Trending)
  [4] 전일 대비 신규 trending 식별 → new_trending.json
  [5] index.html 생성
  [6] Claude 분석 (상위 5개 repo)
       /analysis-source     → .review/REVIEW.md
       /in-depth-review     → .review/REVIEW-InDepth.md
       /create-guide4junior → .review/GUIDE4Junior.md
       → site/analysis/{repo}.html
  [7] Deploy repo clone → site/ 내용 복사 → commit → push
       https://DEPLOY_ACCOUNT.github.io/DEPLOY_REPO/
```

## 환경 변수 (.env)

`.env.example`을 복사하여 시작합니다:

```bash
cp .env.example .env
# 필요시 .env 편집
```

```bash
# .env.example 기본값
CLAUDE_MODEL=claude-sonnet-4-6
SOURCE_ACCOUNT=your-github-account-A
DEPLOY_ACCOUNT=your-github-account-B
DEPLOY_REPO=your-pages-repo-name
SCHEDULE_TIME=02:00
GIT_USER_NAME=dashboard-bot
GIT_USER_EMAIL=dashboard-bot@users.noreply.github.com
```

> GitHub 인증은 `gh auth login` 세션으로, Claude 인증은 `claude login` OAuth 세션으로 관리됩니다.  
> `.env`에 토큰을 저장하지 않습니다. `.env.example`은 git에 포함됩니다.

## 지원 플랫폼

OS를 자동 감지하여 설치 및 스케줄러를 처리합니다.

| 플랫폼 | OS | 설치 스크립트 | 스케줄러 |
|--------|----|--------------|---------|
| Oracle Cloud Always Free (Ampere A1) | Oracle Linux 8/9 | `deploy.sh` | systemd timer / cron |
| AWS Free Tier / EC2 | Amazon Linux 2023 | `deploy.sh` | systemd timer / cron |
| 범용 VPS | Ubuntu 22.04 LTS | `deploy.sh` | systemd timer / cron |
| macOS | macOS 13+ | `deploy.sh` | launchd / cron |
| Windows | Windows 10/11 | `deploy.ps1` | Task Scheduler |

> **권장 서버**: Oracle Cloud Always Free — Ampere A1 (1 OCPU / 6 GB RAM), 무료·무기한.  
> **macOS 주의**: 시스템 timezone을 Asia/Seoul로 설정해야 KST 기준 스케줄이 정확합니다.  
> **Windows 주의**: 시스템 timezone을 `(UTC+09:00) Seoul`로 설정하세요.

## 라이선스

MIT
