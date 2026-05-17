# GitHub Stars Dashboard

GitHub 인기 저장소를 매일 오전 2시(KST) 자동 수집하여 GitHub Pages에 정적 대시보드로 배포합니다.

## 계정 구성 (A / B)

| 역할 | 설명 |
|------|------|
| **계정 A** (소스) | 이 저장소(스크립트·스케줄러·Claude 분석)를 소유하는 GitHub 계정. Linux 서버에서 실행됩니다. |
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
├── .claude/commands/          # Claude skill 파일
│   ├── analysis-source.md
│   ├── in-depth-review.md
│   └── create-guide4junior.md
├── scripts/
│   ├── collect_data.py        # GitHub API + Trending 수집
│   ├── compare_with_previous.py  # 신규 트렌딩 식별
│   ├── build_dashboard.py     # index.html 생성
│   ├── run_claude_analysis.sh # Claude 분석 실행
│   ├── run_daily.sh           # 일일 오케스트레이터 (Linux / macOS)
│   ├── run_daily.ps1          # 일일 오케스트레이터 (Windows)
│   ├── run_claude_analysis.ps1 # Claude 분석 실행 (Windows)
│   └── bootstrap_server.sh    # 서버 최초 초기화 (Linux)
├── templates/
│   ├── dashboard.html.j2      # 대시보드 템플릿
│   └── analysis.html.j2       # 분석 결과 템플릿
├── site/                      # GitHub Pages 배포 대상
│   ├── index.html             # 생성된 대시보드 (자동)
│   ├── assets/
│   │   ├── data.json          # 당일 수집 데이터 (자동)
│   │   └── previous_data.json # 전일 백업 (자동)
│   └── analysis/              # repo별 분석 HTML (자동)
├── deploy.sh                  # 인터랙티브 배포 설정 (Linux / macOS)
├── deploy.ps1                 # 인터랙티브 배포 설정 (Windows PowerShell)
├── requirements.txt
├── .env.example               # 환경 변수 템플릿 (git 포함)
└── .env                       # 실제 환경 변수 (git 제외, .env.example 복사 후 수정)
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

`deploy.sh`가 물어보는 항목:

| 항목 | 설명 |
|------|------|
| Source GitHub 계정 (A) | 스크립트·스케줄러 소스 코드를 소유하는 계정 |
| Deploy GitHub 계정 (B) | GitHub Pages 정적 파일을 push할 계정 (A와 동일 가능) |
| Deploy repo 이름 | 계정 B에서 Pages가 활성화된 repo명 |
| 스케줄 시각 | KST 기준 HH:MM (기본: 02:00) |
| Claude 모델 | 기본: `claude-sonnet-4-6` |
| GitHub 인증 | `gh auth login` (PAT 불필요 — 브라우저 또는 토큰 방식) |
| Claude 인증 | `claude login` OAuth 플로우 (API Key 입력 불필요) |

> **헤드리스 서버(Oracle Cloud 등)**: `gh auth login` 시 `--web` 플래그 없이 실행하면 토큰(PAT) 입력 방식도 선택 가능합니다.  
> `claude login` 실행 시 터미널에 URL이 표시됩니다 — 로컬 브라우저에서 열고 인증 후 토큰을 붙여넣으면 완료됩니다.

## GitHub Pages 설정

1. 저장소 → **Settings → Pages**
2. **Source**: `Deploy from a branch`
3. **Branch**: `main` / **Folder**: `/site`
4. 저장 → `https://ACCOUNT.github.io/REPO/` 접속 확인

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

## 일일 파이프라인

```
02:00 KST
  [1] git pull
  [2] data.json 백업
  [3] GitHub 데이터 수집 (API + Trending)
  [4] 전일 대비 신규 trending 식별
  [5] index.html 생성
  [6] Claude 분석 (상위 5개 repo)
       /analysis-source → REVIEW.md
       /in-depth-review → REVIEW-InDepth.md
       /create-guide4junior → GUIDE4Junior.md
       → site/analysis/{repo}.html
  [7] git commit & push → GitHub Pages 자동 반영
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

OS를 자동 감지하여 설치를 처리합니다.

| 플랫폼 | OS | 설치 스크립트 | 스케줄러 |
|--------|----|--------------|---------|
| Oracle Cloud Always Free (Ampere A1) | Oracle Linux 8/9 | `deploy.sh` | systemd timer |
| AWS Free Tier / EC2 | Amazon Linux 2023 (AL3) | `deploy.sh` | systemd timer |
| 범용 VPS | Ubuntu 22.04 LTS | `deploy.sh` | systemd timer |
| macOS | macOS 13+ | `deploy.sh` | launchd plist |
| Windows | Windows 10/11 | `deploy.ps1` | Task Scheduler |

> **권장 서버**: Oracle Cloud Always Free — Ampere A1 (1 OCPU / 6 GB RAM), 무료·무기한.  
> **macOS 주의**: 시스템 timezone을 Asia/Seoul로 설정해야 KST 기준 스케줄이 정확합니다.  
> **Windows 주의**: 시스템 timezone을 `(UTC+09:00) Seoul`로 설정하세요.

## 라이선스

MIT
