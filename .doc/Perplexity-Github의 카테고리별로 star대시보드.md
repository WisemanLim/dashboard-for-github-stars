<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# Github의 카테고리별로 star수 top100, 금일, 금주, 금월 형태로 제공하는 대시보드를 만들어 줘

요청하신 **GitHub 카테고리별 Star Top 100 + 금일·금주·금월 트렌딩** 대시보드를 만들었습니다. 데이터 파일도 함께 포함해서, 정적 HTML만 열어도 동작하도록 구성했습니다.[^1_1][^1_2][^1_3]

## 구성 내용

이 대시보드는 GitHub Topics를 기준으로 주요 카테고리를 나누고, 각 카테고리마다 GitHub Search API의 `sort=stars` 결과를 이용해 누적 스타 상위 100개 저장소를 보여주도록 설계했습니다.[^1_4][^1_5][^1_1]
또한 금일·금주·금월 트렌딩은 GitHub Trending 페이지의 기간별 뷰를 기준으로 분리해서 탐색할 수 있게 만들었습니다.[^1_2][^1_3]

## 포함된 기능

- 좌측 사이드바에서 카테고리 선택
- 금일 / 금주 / 금월 트렌딩 전환
- 저장소명, 설명, 언어 기준 검색
- Stars, Forks, 언어 수 등 요약 통계
- 다크 모드 전환
- 원본 JSON 데이터 열기

GitHub Topics는 저장소를 주제별로 연결하는 분류 체계이므로, “카테고리별” 대시보드 요구에 가장 자연스럽게 대응할 수 있습니다.[^1_1][^1_4]

## 데이터 기준

카테고리 목록의 기반은 GitHub Topics 탐색 페이지이며, 대표 기술 토픽들을 선별해 대시보드에 넣었습니다.[^1_1]
카테고리별 Top 100은 GitHub Search API의 repository search를 이용하는 방식에 맞춰 구성했고, 트렌딩 기간 뷰는 GitHub Trending의 daily 및 monthly 페이지 구조를 기준으로 반영했습니다.[^1_5][^1_3][^1_2]

## 파일 안내

대시보드 HTML과 데이터 JSON을 함께 전달했습니다. HTML은 단일 정적 페이지이며, JSON에는 카테고리별 Top 100과 금일·금주·금월 트렌딩 스냅샷이 포함되어 있습니다.[^1_3][^1_2][^1_1]

다음 단계로는 GitHub Actions를 붙여 매일 자동 갱신되게 만들거나, 카테고리를 더 확장해서 AI, Bioinformatics, Cloud Native 같은 맞춤 분류로 재구성할 수 있습니다.
<span style="display:none">[^1_10][^1_11][^1_12][^1_13][^1_14][^1_15][^1_6][^1_7][^1_8][^1_9]</span>

<div align="center">⁂</div>

[^1_1]: https://github.com/topics

[^1_2]: https://github.com/trending

[^1_3]: https://github.com/trending?since=monthly

[^1_4]: https://github.blog/news-insights/product-news/introducing-topics/

[^1_5]: https://gist.github.com/jasonrudolph/6057563

[^1_6]: https://github.com/sindresorhus/awesome

[^1_7]: https://github.com/orgs/community/discussions/22473

[^1_8]: http://github.com/topics/topics

[^1_9]: https://wangchujiang.com/github-rank/trending-monthly.html

[^1_10]: https://github.com/github/explore

[^1_11]: https://github.com/topics/trending-weekly

[^1_12]: https://stackoverflow.com/questions/69796393/how-to-star-a-topic-on-github-with-api

[^1_13]: https://github.com/explore

[^1_14]: https://x.com/trending_repos

[^1_15]: https://docs.github.com/ko/rest/activity/starring


---

# 금일, 금주, 금월은 급격하게 star수가 증가한 repo를 의미합니다.

즉, top100과 인기가 급상승하는 repo를 보여줍니다.
그리고 해당 작업은 매일 오전 2시에 수집하여 제공하는 정적페이지입니다.

맞습니다. 이 대시보드에서 **Top 100**은 카테고리별 누적 스타 상위 저장소를 의미하고, **금일·금주·금월**은 해당 기간 동안 스타 수가 급격히 증가한, 즉 GitHub Trending 성격의 급상승 저장소를 의미하도록 해석하는 것이 맞습니다.[^2_1][^2_2]

## 의미 정리

정리하면 화면은 두 축으로 구성됩니다. 하나는 `topic` 기준의 누적 인기 저장소 Top 100이고, 다른 하나는 GitHub Trending의 기간 뷰를 이용한 급상승 저장소 목록입니다.[^2_2][^2_3][^2_1]
GitHub Trending 페이지 자체가 “today”, “this week”, “this month” 형태의 기간 필터를 제공하므로, 금일·금주·금월은 총 스타가 아니라 해당 기간의 상승세를 반영하는 해석이 타당합니다.[^2_4][^2_1][^2_2]

## 수집 방식

말씀하신 운영 방식에 맞게, 이 페이지는 **매일 오전 2시 수집 후 제공되는 정적 페이지**로 두는 것이 적절합니다. 정적 페이지 구조는 배포가 단순하고, 스냅샷 기준 시각을 명확히 남길 수 있으며, GitHub Trending처럼 시점 의존적인 데이터를 “일일 배치 결과”로 고정해서 보여주기 좋습니다.[^2_5][^2_2]
실제로 GitHub 트렌딩 관련 자동화 프로젝트들도 일간 또는 주간 단위 스케줄 실행 방식을 사용합니다.[^2_6][^2_5]

## 반영 방향

현재 전달한 산출물은 구조적으로 이미 이 요구에 맞습니다. 다만 문구와 운영 메타데이터를 더 명확히 해서, 화면에 다음이 드러나도록 다듬는 것이 좋습니다.[^2_1][^2_2]

- `Top 100`: 카테고리별 누적 스타 기준
- `금일/금주/금월`: 기간 내 스타 급상승 기준
- `수집 시각`: 매일 오전 2시 KST 스냅샷
- `정적 제공`: 배치 생성된 HTML + JSON 결과물


## 권장 운영 문구

페이지 상단 또는 푸터에 아래처럼 명시하는 것을 권장합니다. GitHub Trending은 시점 기반 목록이므로, 스냅샷 시각을 노출해야 데이터 해석이 쉬워집니다.[^2_2][^2_1]

- “카테고리별 Top 100은 누적 스타 기준입니다.”[^2_3][^2_7]
- “금일·금주·금월은 해당 기간 동안 스타가 급증한 저장소입니다.”[^2_1][^2_2]
- “데이터는 매일 오전 2시(KST)에 수집한 정적 스냅샷입니다.”[^2_5][^2_6]

원하시면 다음 답변에서 바로 **문구를 수정한 최종 HTML**, 그리고 **GitHub Actions 기준 오전 2시 KST 자동 수집 워크플로우 YAML**까지 함께 만들어 드리겠습니다.
<span style="display:none">[^2_10][^2_11][^2_12][^2_13][^2_14][^2_15][^2_16][^2_17][^2_8][^2_9]</span>

<div align="center">⁂</div>

[^2_1]: https://github.com/trending?since=monthly

[^2_2]: https://github.com/trending

[^2_3]: https://github.com/topics

[^2_4]: https://github.com/trending/javascript

[^2_5]: https://github.com/vitalets/github-trending-repos

[^2_6]: https://mshibanami.github.io/GitHubTrendingRSS/

[^2_7]: https://gist.github.com/jasonrudolph/6057563

[^2_8]: https://wangchujiang.com/github-rank/trending-monthly.html

[^2_9]: https://github.com/topics/trending-weekly

[^2_10]: https://trendshift.io

[^2_11]: https://ossinsight.io/blog/introducing-trending-page

[^2_12]: https://x.com/trending_repos

[^2_13]: https://codebutor.com/trending

[^2_14]: https://chromewebstore.google.com/detail/github-trending/gfhhbglclhdjchmfccaefcepjcmdkncl

[^2_15]: https://github.com/trending?spoken_language_code=zh

[^2_16]: https://github.com/explore

[^2_17]: https://www.kaggle.com/datasets/satoshiss/github-daily-trending-repos


---

# 구현된 정적페이지를 무료로 제공할 수 있는 서비스는. 인터넷을 통해 접속할 수 있도록 배포하고 싶어요.

무료로 정적 페이지를 배포하려면 **Cloudflare Pages, GitHub Pages, Netlify**가 가장 현실적인 선택지입니다. 지금처럼 HTML + JSON 기반의 대시보드라면 특히 **Cloudflare Pages**나 **GitHub Pages**가 잘 맞습니다.[^3_1][^3_2][^3_3]

## 추천 서비스

| 서비스 | 장점 | 주의점 | 추천도 |
| :-- | :-- | :-- | :-- |
| **Cloudflare Pages** | 무료 플랜에서 무제한 대역폭, 월 500 builds, 프로젝트당 최대 100개 커스텀 도메인을 제공해 공개 대시보드 운영에 유리합니다.[^3_4][^3_5] | Free 플랜은 사이트당 파일 수가 20,000개 제한입니다.[^3_3] | 가장 추천 |
| **GitHub Pages** | GitHub 저장소와 바로 연결되고, `github.io` 도메인과 커스텀 도메인, HTTPS 적용을 지원합니다.[^3_2][^3_6] | 정적 사이트 전용에 가깝고, 대시보드 미리보기나 배포 UI는 비교적 단순합니다.[^3_2] | 매우 추천 |
| **Netlify** | 정적 사이트 배포가 쉽고 UI가 편하며 배포 미리보기 같은 기능이 좋습니다.[^3_1] | 무료 플랜 제약은 Cloudflare Pages보다 보수적으로 느껴질 수 있습니다.[^3_1] | 보조 선택 |
| **Vercel** | 프론트엔드 배포 경험이 좋고 자동 배포가 편합니다.[^3_1] | 정적 스냅샷 대시보드만 운영할 때는 Cloudflare Pages 대비 이점이 크지 않을 수 있습니다.[^3_1] | 가능 |
| **Surge / Render 등** | 간단 배포는 가능합니다.[^3_7][^3_8] | 장기 운영성과 생태계 측면에서는 위 3개보다 덜 선호됩니다.[^3_7][^3_8] | 예비용 |

## 가장 적합한 선택

당신의 요구사항은 “매일 오전 2시에 수집된 정적 결과물을 인터넷으로 공개”하는 형태이므로, **Cloudflare Pages**가 가장 잘 맞습니다. 무료 플랜에서 무제한 대역폭을 제공하므로 공개 링크가 많이 열려도 부담이 적고, 정적 HTML/JSON 배포에 최적화되어 있습니다.[^3_4][^3_5]
반대로 GitHub 저장소 중심으로 아주 단순하게 운영하고 싶다면 **GitHub Pages**도 충분히 좋습니다. GitHub Pages는 커스텀 도메인과 HTTPS 강제를 공식 지원합니다.[^3_6][^3_2]

## 배포 방식

현재 산출물은 정적 HTML과 JSON 파일이므로, 저장소에 다음처럼 넣으면 됩니다.[^3_2][^3_1]

- `github-category-stars-dashboard.html`
- `assets/data.json`

다만 대부분의 정적 호스팅은 기본 진입 파일로 `index.html`을 기대하므로, 배포 시에는 파일명을 `index.html`로 바꾸는 편이 가장 편합니다. GitHub Pages와 Cloudflare Pages 모두 정적 파일 기반 배포에 적합합니다.[^3_1][^3_2]

## 도메인과 HTTPS

공개 서비스로 운영할 생각이면 커스텀 도메인을 붙이는 것이 좋습니다. GitHub Pages는 커스텀 도메인 설정과 HTTPS 적용을 지원하고, 올바른 DNS가 잡히면 인증서도 자동으로 처리합니다.[^3_6][^3_2]
특히 GitHub Pages는 `github.io` 도메인에서 기본 HTTPS를 제공하고, 커스텀 도메인에서도 HTTPS 강제를 설정할 수 있습니다.[^3_2]

## 제 권장안

가장 실용적인 조합은 아래 둘 중 하나입니다.[^3_4][^3_1][^3_2]

- **1안: Cloudflare Pages + GitHub Actions 수집 배치**
매일 오전 2시에 GitHub Actions가 데이터를 수집해 저장소에 반영하고, Cloudflare Pages가 자동 배포하는 방식입니다.[^3_5][^3_4]
- **2안: GitHub Pages + GitHub Actions**
가장 단순한 구조입니다. 코드, 데이터 수집, 배포를 전부 GitHub 안에서 끝낼 수 있습니다.[^3_6][^3_2]

제 기준에서는 **외부 공개 대시보드**면 Cloudflare Pages, **운영 단순성**이면 GitHub Pages를 추천합니다.[^3_1][^3_4][^3_2]

원하시면 다음 단계에서 바로

1. **Cloudflare Pages 배포용 구조로 파일명 정리**,
2. **GitHub Actions 오전 2시 KST 자동 수집 워크플로우**,
3. **커스텀 도메인 연결 방법**
까지 한 번에 정리해드리겠습니다.
<span style="display:none">[^3_10][^3_11][^3_12][^3_13][^3_14][^3_15][^3_16][^3_17][^3_9]</span>

<div align="center">⁂</div>

[^3_1]: https://jp-my-blog.vercel.app/blog/github-pages-vs-netlify-cloudflare-pages-and-vercel-the-only-free-static-site-host-comparison-that-matters

[^3_2]: https://github.com/topics

[^3_3]: https://github.com/sindresorhus/awesome

[^3_4]: https://agentdeals.dev/vendor/cloudflare-pages

[^3_5]: https://www.oreateai.com/blog/cloudflare-pages-pricing-2025-unpacking-the-free-plans-limits/c971beb3590767270a7adb31e97eb0d7

[^3_6]: https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site

[^3_7]: https://htmlpub.com/blog/static-site-hosting-comparison-2026

[^3_8]: https://snapdeploy.dev/blog/deploy-website-free-2026-complete-guide

[^3_9]: https://appwrite.io/blog/post/best-free-static-website-hosting

[^3_10]: https://github.com/iSoumyaDey/Awesome-Web-Hosting-2026

[^3_11]: https://htmlpub.com/blog/how-to-host-static-website-free

[^3_12]: https://docs.github.com/en/pages/getting-started-with-github-pages/securing-your-github-pages-site-with-https

[^3_13]: https://developers.cloudflare.com/changelog/2026-01-23-pages-file-limit-increase/

[^3_14]: https://dev.to/vinishbhaskar/9-best-free-static-website-hosting-7ki

[^3_15]: https://docs.github.com/ko/pages/getting-started-with-github-pages/securing-your-github-pages-site-with-https

[^3_16]: https://uideck.com/blog/free-static-website-hosting-platforms

[^3_17]: https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site


---

# 2안으로 운영할 수 있는 가이드를 상세하게 알려주세요. 회원가입 부터 소스 자동화 등등을 포함하고 매일 자동화 수집 및 대시보드 생성, 배포까지 단계를 모두 포함합니다.

좋습니다. 2안인 **GitHub Pages + GitHub Actions**로 운영하면, 저장소 하나에서 데이터 수집·정적 대시보드 생성·배포까지 모두 자동화할 수 있습니다. GitHub Pages는 저장소의 브랜치/폴더 또는 GitHub Actions 워크플로우로 정적 사이트를 배포할 수 있고, 정적 파일의 진입점은 `index.html`이어야 합니다.[^4_1][^4_2]

## 전체 구조

이 방식의 핵심은 `main` 브랜치에 수집 스크립트와 대시보드 템플릿을 두고, GitHub Actions가 매일 정해진 시각에 실행되어 정적 산출물을 만든 뒤 GitHub Pages로 배포하는 것입니다. GitHub는 Pages 배포를 위해 **GitHub Actions** 기반 워크플로우를 공식 지원하며, 일반적인 흐름은 checkout → build → `upload-pages-artifact` → `deploy-pages`입니다.[^4_2]
또한 GitHub Pages는 공개 저장소에 대해 무료로 사용할 수 있고, 변경 사항 반영에는 보통 몇 분이 걸릴 수 있습니다.[^4_1]

## 1. 회원가입과 저장소 생성

1. [GitHub](https://github.com/)에서 계정을 생성합니다.
2. 새 저장소를 만듭니다. 공개 배포를 위해서는 GitHub Free 기준으로 저장소를 `Public`으로 두는 것이 안전합니다.[^4_1]
3. 저장소 이름은 일반 프로젝트 사이트라면 자유롭게 정할 수 있습니다. 사용자 사이트가 아니라 프로젝트 사이트라면 꼭 `<user>.github.io` 형식일 필요는 없습니다.[^4_1]
4. 저장소 생성 시 `README`를 함께 생성합니다.[^4_1]

실제로 GitHub Pages는 새 저장소 또는 기존 저장소 어디서든 만들 수 있으며, 프로젝트 파일 전부가 사이트와 직접 관련되지 않아도 됩니다. 이 경우 배포 소스를 브랜치/폴더 또는 GitHub Actions로 지정하면 됩니다.[^4_2][^4_1]

## 2. Pages 배포 방식 선택

이 프로젝트는 단순 정적 파일 복사보다 “수집 → 가공 → HTML 생성”의 빌드 과정이 있으므로, **Deploy from a branch**보다 **GitHub Actions** 방식이 더 적합합니다. GitHub Docs도 Jekyll 이외의 커스텀 빌드가 필요하면 GitHub Actions 워크플로우를 권장합니다.[^4_2]
설정 경로는 저장소의 **Settings → Pages → Build and deployment → Source → GitHub Actions**입니다.[^4_2]

## 3. 권장 저장소 구조

아래처럼 구성하면 관리가 편합니다.

```text
repo/
├─ .github/
│  └─ workflows/
│     └─ pages.yml
├─ scripts/
│  ├─ collect.py
│  └─ build_dashboard.py
├─ templates/
│  └─ dashboard.html
├─ output/
│  ├─ index.html
│  └─ assets/
│     └─ data.json
├─ requirements.txt
└─ README.md
```

여기서 `output/index.html`은 최종 배포 산출물이고, GitHub Pages는 배포 아티팩트 최상위에 `index.html`이 있어야 정상적으로 사이트 진입점을 인식합니다.[^4_2][^4_1]

## 4. 동작 흐름

매일 오전 2시에 GitHub Actions가 실행되면 다음 순서로 처리됩니다.

- GitHub Trending 및 GitHub Search API 기반 데이터 수집
- 카테고리별 Top 100 JSON 생성
- 금일·금주·금월 급상승 저장소 JSON 생성
- 정적 HTML 대시보드 생성
- `output/` 폴더를 Pages artifact로 업로드
- GitHub Pages에 자동 배포

이 흐름은 GitHub가 제시하는 custom workflow 패턴과 동일합니다. 즉, 리포지토리 checkout 후 산출물을 만들고 `actions/upload-pages-artifact`로 업로드한 뒤 `actions/deploy-pages`로 배포합니다.[^4_2]

## 5. 자동 실행 시각 설정

GitHub Actions의 schedule은 전통적으로 UTC 기준으로 동작하므로, 한국 시간 오전 2시에 맞추려면 UTC로 변환해야 합니다. 한국 표준시 KST는 UTC+9이므로, **오전 2시 KST = 전날 17:00 UTC**입니다.[^4_3][^4_4]
다만 2026년 3월 GitHub Changelog에 따르면, 이제 스케줄에서 IANA timezone을 지정할 수 있습니다. 즉 `timezone: "Asia/Seoul"`을 함께 써서 로컬 시간 기준 실행이 가능해졌습니다.[^4_5]

권장 예시는 아래와 같습니다.

```yaml
name: Build and Deploy GitHub Dashboard

on:
  workflow_dispatch:
  schedule:
    - cron: "0 2 * * *"
      timezone: "Asia/Seoul"
```

이 방식은 사람이 읽기 쉽고 유지보수가 편합니다.[^4_5]
만약 구버전 방식으로 유지한다면 다음처럼 UTC cron으로도 가능합니다.[^4_4][^4_3]

```yaml
on:
  workflow_dispatch:
  schedule:
    - cron: "0 17 * * *"
```


## 6. GitHub Actions 워크플로우 예시

아래는 Python으로 수집·생성 후 Pages로 배포하는 전체 예시입니다.

```yaml
name: Build and Deploy GitHub Dashboard

on:
  workflow_dispatch:
  schedule:
    - cron: "0 2 * * *"
      timezone: "Asia/Seoul"

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Pages
        uses: actions/configure-pages@v5

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install dependencies
        run: |
          pip install -r requirements.txt

      - name: Collect data
        run: |
          python scripts/collect.py

      - name: Build dashboard
        run: |
          python scripts/build_dashboard.py

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: ./output

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build

    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

GitHub Docs가 안내하는 custom Pages workflow의 핵심 액션은 `upload-pages-artifact`와 `deploy-pages`이며, 배포 환경은 `github-pages`를 사용합니다.[^4_2]
또한 Pages는 branch 배포뿐 아니라 Actions 배포도 공식적으로 지원하므로, 이 구조는 표준적인 운영 방식입니다.[^4_2]

## 7. 수집 스크립트 설계

`collect.py`는 다음 역할을 담당하면 됩니다.

- GitHub Search API로 카테고리별 `sort=stars` Top 100 수집
- GitHub Trending 일/주/월 페이지 파싱
- 결과를 `output/assets/data.json`으로 저장
- 수집 시각을 KST 기준 문자열로 포함

예를 들어 JSON 구조는 아래처럼 두는 것이 좋습니다.

```json
{
  "generated_at": "2026-05-17 02:00:12 KST",
  "source": {
    "top100": "GitHub Search API",
    "trending": "GitHub Trending"
  },
  "categories": [
    {
      "slug": "python",
      "label": "Python",
      "top100": []
    }
  ],
  "trending": {
    "daily": [],
    "weekly": [],
    "monthly": []
  }
}
```

이렇게 두면 화면에서 “이 데이터는 매일 오전 2시 배치로 생성된 정적 스냅샷”이라는 점을 명확히 표시할 수 있습니다.[^4_6][^4_7]

## 8. 대시보드 생성 스크립트 설계

`build_dashboard.py`는 `data.json`을 읽어 `output/index.html`을 생성하면 됩니다. GitHub Pages는 진입 파일로 `index.html`을 찾으므로, 기존 파일명을 그대로 쓰기보다 최종 산출물은 `index.html`로 저장하는 편이 낫습니다.[^4_1]
정적 HTML 안에서 `./assets/data.json`을 fetch하도록 구성하면 브라우저에서 바로 읽을 수 있습니다. GitHub Pages는 정적 파일 호스팅이므로 HTML, JSON, CSS, JS 같은 정적 리소스를 그대로 서비스합니다.[^4_1]

## 9. 최초 배포 절차

초기 설정은 아래 순서가 가장 안정적입니다.

1. 저장소 생성
2. `main` 브랜치에 코드 업로드
3. **Settings → Pages → Source = GitHub Actions** 설정[^4_2]
4. `.github/workflows/pages.yml` 추가
5. `git push origin main`
6. **Actions** 탭에서 첫 실행 확인
7. **Settings → Pages → Visit site**로 사이트 확인[^4_1]

GitHub Docs에 따르면 published site 링크는 저장소의 **Settings → Pages**에서 확인할 수 있습니다.[^4_1]

## 10. 수동 실행도 함께 두기

운영 중에는 스케줄만으로 충분하지 않습니다. 장애 대응이나 급한 갱신이 필요할 때를 위해 `workflow_dispatch`를 포함해야 합니다. 그러면 GitHub Actions 탭에서 버튼으로 즉시 다시 수집·재배포가 가능합니다.[^4_2]
이것은 데이터 소스 일시 오류, HTML 템플릿 수정, 특정 카테고리 추가 후 즉시 반영 같은 상황에서 매우 유용합니다.

## 11. 커스텀 도메인 연결

기본 주소는 보통 `https://<username>.github.io/<repository>/` 형태입니다.[^4_1]
직접 도메인을 붙이고 싶다면 **Settings → Pages → Custom domain**에서 설정할 수 있고, GitHub Pages는 올바르게 구성된 커스텀 도메인에 대해 HTTPS 및 HTTPS enforcement를 지원합니다.[^4_8][^4_9]

중요한 점은 다음입니다.

- DNS가 올바르게 설정되면 GitHub가 인증서 발급 절차를 자동으로 진행합니다.[^4_8]
- Pages 설정에서 **Enforce HTTPS**를 켤 수 있습니다.[^4_10][^4_8]
- 혼합 콘텐츠를 피하려면 사이트 내부 리소스도 모두 HTTPS여야 합니다.[^4_8]


## 12. 운영 시 주의사항

GitHub Pages 사이트는 인터넷에 공개되므로, 저장소가 private여도 사이트는 외부에 노출될 수 있습니다. 민감한 토큰, 로그, 디버그 파일, 실수로 남긴 raw 응답은 절대 배포 아티팩트에 넣으면 안 됩니다.[^4_1][^4_2]
또한 branch 기반 Pages에서는 `GITHUB_TOKEN`으로 푸시한 커밋이 Pages 빌드를 트리거하지 않는다는 제약이 있지만, 우리는 artifact 기반 Actions 배포를 쓰므로 이 문제를 우회할 수 있습니다.[^4_2]

## 13. 추천 운영 전략

실무적으로는 다음 전략이 가장 안정적입니다.

- `main`: 수집 코드와 템플릿 관리
- Pages 배포: GitHub Actions artifact 기반
- 스케줄: 매일 02:00 Asia/Seoul
- 수동 재실행: `workflow_dispatch`
- `output/`는 항상 빌드 결과물만 포함
- 푸터에 “Generated at 02:00 KST snapshot” 표시

이 방식은 코드와 배포를 모두 GitHub 안에서 끝내므로 단순하고, 배포 대상이 정적 페이지라 유지비도 없습니다.[^4_1][^4_2]

## 14. 다음에 바로 해드릴 수 있는 것

다음 단계로 바로 실사용 가능한 형태로 드릴 수 있습니다.

- `pages.yml` 완성본
- `collect.py` / `build_dashboard.py` 분리 버전
- `requirements.txt`
- GitHub Pages 배포용 최종 디렉터리 구조
- README 운영 가이드

원하시면 다음 답변에서 **그대로 저장소에 넣어 실행할 수 있는 전체 소스 세트**를 파일 형태로 만들어 드리겠습니다.[^4_2][^4_1]
<span style="display:none">[^4_11][^4_12][^4_13][^4_14][^4_15][^4_16][^4_17][^4_18][^4_19]</span>

<div align="center">⁂</div>

[^4_1]: https://github.com/topics

[^4_2]: https://github.blog/news-insights/product-news/introducing-topics/

[^4_3]: https://jackharner.com/blog/github-actions-cron/

[^4_4]: https://jasonet.co/posts/scheduled-actions/

[^4_5]: https://github.blog/changelog/2026-03-19-github-actions-late-march-2026-updates/

[^4_6]: https://github.com/trending

[^4_7]: https://github.com/trending?since=monthly

[^4_8]: https://docs.github.com/en/pages/getting-started-with-github-pages/securing-your-github-pages-site-with-https

[^4_9]: https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/about-custom-domains-and-github-pages

[^4_10]: https://docs.github.com/ko/pages/getting-started-with-github-pages/securing-your-github-pages-site-with-https

[^4_11]: https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site

[^4_12]: https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site

[^4_13]: https://github.com/marketplace/actions/deploy-to-github-pages

[^4_14]: https://github.com/actions/deploy-pages

[^4_15]: https://github.com/peaceiris/actions-gh-pages

[^4_16]: https://dev.to/jajera/setting-up-github-pages-with-github-actions-2o72

[^4_17]: https://github.com/go-gitea/gitea/issues/31657

[^4_18]: https://github.com/marketplace/actions/github-pages-action

[^4_19]: https://docs.github.com/articles/creating-project-pages-manually


---

# 배포를 리눅스 서버에 하고자 합니다. 최저 사양으로 무료로 이용할 수 있는 IaaS를 조사 및 비교, 추천해 주세요.

무료로 리눅스 서버를 **IaaS 형태로 오래 운영**하려면 사실상 **Oracle Cloud Always Free**가 가장 유력합니다. AWS, Azure, GCP도 무료 혜택은 있지만 상당수가 기간제 크레딧 또는 제한된 VM 사양이어서, “매일 자동 수집 + 정적 대시보드 배포”를 장기 무상 운영하려는 목적에는 Oracle이 가장 적합합니다.[^5_1][^5_2][^5_3][^5_4]

## 추천 결론

당신의 요구사항은 “리눅스 서버 1대, 가능한 최저 사양, 무료, 장기 운영, 인터넷 공개”이므로 우선순위는 **지속 가능한 무료 여부**입니다. 이 기준에서 Oracle Cloud는 Always Free로 AMD VM 2개와 Ampere A1 리소스를 제공하고, Ampere는 최대 4 OCPU와 24GB 메모리를 무료 한도 안에서 사용할 수 있어 다른 후보보다 훨씬 여유가 있습니다.[^5_5][^5_3][^5_1]
반면 GCP의 e2-micro는 월별 Always Free이지만 1GB 메모리의 매우 작은 인스턴스이고, Azure VM 무료는 12개월 성격이 강하며, AWS도 현재는 크레딧/평가판 중심으로 바뀌어 장기 고정 무료 IaaS로 보기 어렵습니다.[^5_6][^5_7][^5_2][^5_4]

## 후보 비교

| 서비스 | 무료 형태 | 리눅스 VM 관점 | 한계 | 적합도 |
| :-- | :-- | :-- | :-- | :-- |
| **Oracle Cloud Always Free** | 상시 무료 | AMD VM 2개, Ampere A1는 월 3,000 OCPU 시간과 18,000 GB-시간, 최대 4 OCPU/24GB 메모리 사용 가능.[^5_5][^5_1][^5_3] | 계정 생성과 자원 확보가 다소 까다롭고, 지역/용량 가용성 이슈가 있을 수 있습니다.[^5_8][^5_9] | 최고 |
| **Google Cloud Free Tier** | 상시 무료 + 초기 크레딧 | Compute Engine `e2-micro`가 특정 리전에서 월별 무료이며, 표준 영구 디스크 30GB도 무료 범위가 있습니다.[^5_4][^5_10] | 1GB RAM급이라 여유가 거의 없고, 지역 제한이 있습니다.[^5_10][^5_4] | 차선 |
| **Azure Free Account** | 12개월 무료 + 일부 상시 무료 | B1S, B2pts v2, B2ats v2 계열 VM을 월 750시간 무료로 사용할 수 있습니다.[^5_2] | “영구 무료 VM”이 아니라 free account 기반 제한이므로 장기 무상 운영엔 불리합니다.[^5_2][^5_11] | 제한적 |
| **AWS Free Tier / Lightsail trial** | 크레딧·평가판 중심 | Lightsail은 90일 무료 평가판이고, AWS Free Tier도 현재는 최대 6개월과 크레딧 중심입니다.[^5_6][^5_7][^5_12] | 장기 상시 무료 IaaS라고 보기 어렵습니다.[^5_6][^5_7] | 낮음 |
| **Fly.io / Railway / Render** | 대부분 PaaS 성격 | 배포는 쉽습니다.[^5_13][^5_14][^5_15] | 엄밀한 IaaS가 아니고, 실질적인 장기 무료 VM으로 보기 어렵습니다.[^5_14][^5_16] | 이번 요구와는 덜 맞음 |

## 최저 사양 기준 해석

정적 대시보드 수집/배포 용도라면 CPU와 메모리 요구량은 매우 낮습니다. 실제로 Python 수집 스크립트, cron, nginx 정적 서빙 정도면 1 vCPU / 1GB RAM 급도 동작 가능하므로, GCP의 `e2-micro`도 이론상 운영은 가능합니다.[^5_10][^5_4]
하지만 GitHub 데이터 수집, HTML 생성, 향후 reverse proxy, SSL, 로그, 모니터링까지 고려하면 너무 작은 인스턴스는 운영 피로가 높아집니다. 그래서 “최저 사양”을 원하더라도 **무료 범위 내에서 조금 더 여유로운 Oracle Ampere 1 OCPU + 6GB 정도**가 오히려 실전 운영에 유리합니다.[^5_8][^5_3][^5_1]

## 서비스별 평가

**Oracle Cloud Always Free**는 무료 리눅스 서버를 가장 오래, 가장 넉넉하게 운영할 수 있다는 점이 강점입니다. Oracle 공식 페이지는 AMD 컴퓨트 VM 2개와 Arm 기반 Ampere 리소스를 Always Free로 제공한다고 안내하고 있습니다.[^5_5][^5_1]
특히 Ampere A1는 무료 한도 안에서 총 4 OCPU와 24GB 메모리를 배분할 수 있어, 1대 서버로 크게 잡거나 여러 대로 나눠 쓰는 것도 가능합니다.[^5_3][^5_8]

**Google Cloud Free Tier**는 두 번째 후보입니다. 공식 문서상 Compute Engine의 eligible `e2-micro`는 매월 무료 한도 내 사용이 가능하지만, 지역 제약과 매우 작은 메모리 때문에 정적 페이지 배포 외 확장성이 제한됩니다.[^5_4]
저사양 단일 노드 실험용으로는 좋지만, 운영 안정성 면에서는 Oracle보다 불리합니다.[^5_10][^5_4]

**Azure**는 무료 계정에서 일부 VM을 750시간 제공하지만, 영구 무료 서버라고 보기는 어렵습니다. 무료 계정 모델은 보통 12개월 범주로 이해해야 하므로 “계속 무료”라는 목적에는 맞지 않습니다.[^5_2][^5_11]

**AWS**는 현재 Free Tier와 Lightsail 모두 “상시 무료 VM”보다는 크레딧/체험 구조에 가깝습니다. 그래서 장기 무상 운영 목적에는 적합하지 않습니다.[^5_7][^5_12][^5_6]

## 최종 추천

가장 추천하는 선택은 **Oracle Cloud Always Free의 Ampere A1 VM**입니다. 무료 한도 자체가 넉넉하고, 정적 대시보드 수집 서버 용도로는 과분할 정도의 메모리를 확보할 수 있기 때문입니다.[^5_1][^5_3]
보수적인 대안은 **Google Cloud e2-micro**입니다. 다만 무료 유지 조건과 리소스 여유를 함께 보면 Oracle이 확실히 우세합니다.[^5_4][^5_10]

## 권장 사양

당신의 용도에는 아래처럼 시작하면 충분합니다.

- **1순위: Oracle Cloud Ampere A1**
    - 1 OCPU
    - 6GB RAM
    - Ubuntu 22.04 또는 24.04
    - 50GB 부트 볼륨
이 정도면 cron 수집, Python 스크립트, nginx 정적 서빙, certbot 또는 Caddy 운용까지 충분합니다.[^5_8][^5_1]
- **2순위: GCP e2-micro**
    - e2-micro
    - 1GB RAM
    - Standard persistent disk 30GB
단, 메모리가 작아 Python 수집과 웹 서버를 함께 돌릴 때 여유가 적습니다.[^5_10][^5_4]


## 실무 관점 조언

무료 IaaS를 고를 때는 단순히 “생성 가능”보다 **장기 운영 가능성**과 **리소스 여유**를 봐야 합니다. 정적 대시보드는 가볍지만, SSH, 방화벽, 인증서, 로그, 패키지 업데이트, cron 실패 대응까지 포함하면 너무 작은 VM은 오히려 관리 비용이 커집니다.[^5_4][^5_10]
그래서 이번 케이스에서는 “최저 사양”을 문자 그대로 최소치로 맞추기보다, **무료 범위 안에서 가장 안정적인 최소 운영 사양**을 선택하는 것이 맞고, 그 점에서 Oracle Ampere가 가장 합리적입니다.[^5_3][^5_1]

원하시면 다음 단계로 바로 **Oracle Cloud Always Free 기준 가입부터 Ubuntu 생성, nginx 설치, cron/systemd timer 설정, GitHub 데이터 수집 스크립트 배치, HTTPS 공개 배포**까지 운영 절차를 상세 가이드로 이어서 정리해드리겠습니다.
<span style="display:none">[^5_17][^5_18][^5_19][^5_20][^5_21][^5_22][^5_23][^5_24][^5_25][^5_26][^5_27][^5_28][^5_29][^5_30]</span>

<div align="center">⁂</div>

[^5_1]: https://www.oracle.com/cloud/free/

[^5_2]: https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/create-free-services

[^5_3]: https://docs.oracle.com/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm

[^5_4]: https://docs.cloud.google.com/free/docs/free-cloud-features

[^5_5]: https://www.oracle.com/kr/cloud/free/

[^5_6]: https://aws.amazon.com/free/compute/lightsail/

[^5_7]: https://aws.amazon.com/free/

[^5_8]: https://gist.github.com/rssnyder/51e3cfedd730e7dd5f4a816143b25dbd

[^5_9]: https://www.reddit.com/r/selfhosted/comments/1ma6jbt/does_oracle_cloud_free_tier_have_any_gotchas_or/

[^5_10]: https://dev.to/jeaniscoding/how-to-host-your-side-projects-for-0-the-ultimate-gcp-free-tier-guide-3p07

[^5_11]: https://learn.microsoft.com/en-us/answers/questions/3876423/about-the-free-trial-period-of-microsoft-azure

[^5_12]: https://aws.amazon.com/ko/free/compute/lightsail/

[^5_13]: https://encore.dev/articles/render-vs-railway

[^5_14]: https://render.com/articles/platforms-with-a-real-free-tier-for-developers-in-2026

[^5_15]: https://techsy.io/en/blog/railway-vs-render-vs-fly-io

[^5_16]: https://gautamkhorana.com/cloud-hosting/compare/railway-vs-fly-io/

[^5_17]: https://www.back4app.com/heroku-alternatives-ko

[^5_18]: https://www.buildmvpfast.com/blog/best-cloud-services-mvp-hosting-2026

[^5_19]: https://browser.geekbench.com/v5/cpu/17430046

[^5_20]: https://www.youtube.com/watch?v=BUxyD-IXP1s

[^5_21]: https://www.deployhq.com/blog/heroku-alternatives-render-railway-fly-deployhq-vps

[^5_22]: https://gist.github.com/rssnyder/51e3cfedd730e7dd5f4a816143b25dbd?permalink_comment_id=5546378

[^5_23]: https://www.reddit.com/r/devops/comments/1s28v4z/vps_vs_paas_cost_comparison/

[^5_24]: https://www.reddit.com/r/oracle/comments/qfwo9q/oracle_cloud_is_canonicalubuntu1804202109220/

[^5_25]: https://url.kr/webzine/view.php?slug=오라클-클라우드-평생무료-서버-만들기-인스턴스-생성-완벽-가이드2026년-최신

[^5_26]: https://hoing.io/archives/24489

[^5_27]: https://fullmetalbrackets.com/blog/oci-free-tier-breakdown

[^5_28]: https://aaroni.tistory.com/entry/2024-GCPGoogle-Cloud-Platform-VM-무료가상머신-설정법

[^5_29]: https://www.51sec.org/2025/08/04/create-a-free-tier-windows-virtual-machine-in-azure/

[^5_30]: https://cloud.google.com/free


---

# 다음과 같은 단계로 운영할 수 있도록 스크립트 및 코드를 보여주세요.

1. 새로운 깃헙 계정을 생성합니다. 이를 위한 구글 계정도 생성합니다.
2. 대시보드를 매일 오전에 생성하고 커밋할 수 있는 오라클 무료 서버 설정 및 소스 pull 등을 진행하는 쉘스크렙트가 필요합니다.
3. 2항에서 매일 갱신되는 대시보드 코드가 필요합니다.
4. 3항까지 완료할 수 있는 단계적 코드가 필요하며 아래와 같은 플로우로 자동화합니다.
4.1. 매일 오전 2시에 대시보드 정적 페이지 생성
4.2. 정적페이지 깃헙에 푸시
4.3. 깃헙에서 제공하는 정적페이지 대시보드 http접속

추가로 .claude를 연결하고 command를 연결하고 해당 command를 실행할 수 있는 스크립트를 생성합니다.
예를 들어, analyze.md, claude.md 파일로 구성하고 대시보드 완료 후 전일 대시보드와 비교하여 새롭게 인기star에 오른 소스에 대해서 analyze.md를 실행하고 그 결과를 대시보드에 정적페이지 result.md를 링크를 추가합니다.

가능합니다. 다만 먼저 짚고 가면, **구글 계정 생성이나 GitHub 계정 생성 자체를 자동화하는 스크립트는 제공할 수 없습니다**. 이런 가입 자동화는 서비스 약관, 보안, 본인확인 절차와 충돌할 수 있어서 수동으로 진행해야 합니다.[^6_1][^6_2]
대신 그 이후 단계인 **Oracle 무료 서버 초기 설정, 저장소 pull, 매일 오전 2시 대시보드 생성, GitHub push, GitHub Pages 공개, `.claude` 명령 연결, 전일 대비 신규 급상승 분석 및 result 링크 생성**까지는 운영 가능한 형태로 상세하게 설계해드릴 수 있습니다.[^6_3][^6_4][^6_5][^6_1]

## 1. 계정 준비

Google 계정은 [Google 계정 생성 페이지](https://accounts.google.com/signup)에서 직접 만들어야 하고, GitHub 계정은 [GitHub 가입 페이지](https://github.com/signup) 또는 **Continue with Google**로 생성할 수 있습니다.[^6_2][^6_1]
GitHub는 가입 후 이메일 검증이 필요하며, 기본 작업 수행을 위해 검증된 이메일이 필요하므로 반드시 완료해야 합니다. 또한 GitHub는 2FA 설정을 강하게 권장합니다.[^6_6][^6_1]

수동으로 해야 할 체크리스트는 아래와 같습니다.

- Google 계정 생성
- GitHub 계정 생성
- 이메일 인증 완료
- 2FA 활성화
- 새 public repository 생성
- GitHub Pages 활성화 준비


## 2. 전체 아키텍처

운영 플로우는 다음처럼 잡는 것이 가장 단순합니다.

1. Oracle Cloud Always Free Ubuntu 서버 1대 생성.[^6_7][^6_5]
2. 서버에서 프로젝트 저장소를 clone.
3. 매일 오전 2시에 systemd timer 또는 cron으로 배치 실행.
4. Python 스크립트가 GitHub 데이터 수집, 정적 대시보드 생성, 전일 대비 비교 수행.
5. Claude Code CLI가 `.claude/commands/analyze.md`를 이용해 신규 급상승 저장소 분석 문서 생성.
6. 결과물 `index.html`, `assets/data.json`, `result.md`를 GitHub에 commit/push.
7. GitHub Pages가 저장소 최신 커밋을 정적 사이트로 공개.[^6_4][^6_8][^6_9]

이렇게 하면 Oracle 서버는 “수집/생성 엔진”, GitHub는 “소스 저장소 + 정적 호스팅”, GitHub Pages는 “공개 대시보드 엔드포인트” 역할을 맡습니다.[^6_8][^6_9]

## 3. 저장소 구조

아래 구조를 권장합니다.

```text
github-trending-dashboard/
├── .claude/
│   ├── CLAUDE.md
│   └── commands/
│       ├── analyze.md
│       └── claude.md
├── scripts/
│   ├── bootstrap_server.sh
│   ├── run_daily.sh
│   ├── collect_data.py
│   ├── build_dashboard.py
│   ├── compare_with_previous.py
│   └── run_claude_analysis.sh
├── site/
│   ├── index.html
│   ├── result.md
│   └── assets/
│       ├── data.json
│       ├── previous_data.json
│       └── analysis.json
├── requirements.txt
├── README.md
└── .gitignore
```

GitHub Pages에 바로 연결하려면 배포 브랜치 또는 루트/`docs` 구조를 사용할 수 있지만, 가장 쉬운 방법은 `main` 브랜치의 `site/` 또는 `docs/`를 publishing source로 잡는 것입니다.[^6_9]
혹은 리포지토리 루트에 `index.html`을 두어도 되지만, 산출물과 소스를 분리하는 편이 유지보수에 좋습니다.[^6_8][^6_9]

## 4. GitHub Pages 준비

GitHub Pages는 저장소에서 정적 사이트를 게시할 수 있고, publishing source를 branch/folder로 설정할 수 있습니다.[^6_9][^6_8]
이번 구조에서는 **Settings → Pages → Build and deployment → Deploy from a branch → Branch: main / Folder: /site** 또는 `/docs` 같은 방식이 간단합니다.[^6_9]

중요 포인트는 다음입니다.

- `site/index.html`이 있어야 합니다.[^6_8]
- push 후 Pages 반영까지 수 분 걸릴 수 있습니다.[^6_8]
- public repository가 가장 간단합니다.[^6_8]


## 5. 서버 초기 설정 스크립트

아래 스크립트는 Oracle Ubuntu 서버에서 필요한 패키지 설치, Python 환경 구성, Git clone, SSH key, systemd service/timer 배치까지 수행하는 예시입니다.

### `scripts/bootstrap_server.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_USER="${APP_USER:-ubuntu}"
APP_HOME="/home/${APP_USER}"
APP_DIR="${APP_HOME}/github-trending-dashboard"
REPO_URL="${REPO_URL:-git@github.com:YOUR_GITHUB_USERNAME/YOUR_REPO.git}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
TZ_REGION="${TZ_REGION:-Asia/Seoul}"

sudo timedatectl set-timezone "${TZ_REGION}"

sudo apt-get update
sudo apt-get install -y \
  git curl wget unzip jq \
  build-essential \
  python3 python3-venv python3-pip \
  nginx

if ! id -u "${APP_USER}" >/dev/null 2>&1; then
  sudo useradd -m -s /bin/bash "${APP_USER}"
fi

sudo mkdir -p "${APP_DIR}"
sudo chown -R "${APP_USER}:${APP_USER}" "${APP_HOME}"

if [ ! -d "${APP_HOME}/.ssh" ]; then
  sudo -u "${APP_USER}" mkdir -p "${APP_HOME}/.ssh"
  sudo chmod 700 "${APP_HOME}/.ssh"
fi

if [ ! -f "${APP_HOME}/.ssh/id_ed25519" ]; then
  sudo -u "${APP_USER}" ssh-keygen -t ed25519 -N "" -f "${APP_HOME}/.ssh/id_ed25519"
  echo "==== GitHub Deploy Key Public Key ===="
  sudo cat "${APP_HOME}/.ssh/id_ed25519.pub"
  echo "==== 위 공개키를 GitHub 저장소 Deploy Key 또는 계정 SSH Key에 등록하세요. ===="
fi

sudo -u "${APP_USER}" bash -c "ssh-keyscan github.com >> ${APP_HOME}/.ssh/known_hosts"

if [ ! -d "${APP_DIR}/.git" ]; then
  sudo -u "${APP_USER}" git clone "${REPO_URL}" "${APP_DIR}"
else
  sudo -u "${APP_USER}" git -C "${APP_DIR}" pull --rebase
fi

sudo -u "${APP_USER}" ${PYTHON_BIN} -m venv "${APP_DIR}/.venv"
sudo -u "${APP_USER}" bash -c "source ${APP_DIR}/.venv/bin/activate && pip install --upgrade pip && pip install -r ${APP_DIR}/requirements.txt"

sudo tee /etc/systemd/system/github-dashboard.service >/dev/null <<EOF
[Unit]
Description=GitHub Trending Dashboard Daily Builder
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=${APP_USER}
WorkingDirectory=${APP_DIR}
Environment=HOME=${APP_HOME}
Environment=PATH=${APP_DIR}/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=${APP_DIR}/scripts/run_daily.sh
EOF

sudo tee /etc/systemd/system/github-dashboard.timer >/dev/null <<EOF
[Unit]
Description=Run GitHub Dashboard Daily at 02:00 KST

[Timer]
OnCalendar=*-*-* 02:00:00 Asia/Seoul
Persistent=true
Unit=github-dashboard.service

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable github-dashboard.timer
sudo systemctl start github-dashboard.timer

echo "Bootstrap complete."
echo "Manual run: sudo systemctl start github-dashboard.service"
echo "Timer check: systemctl list-timers --all | grep github-dashboard"
```

이 스크립트는 Ubuntu 인스턴스 위에서 Apache/PHP 같은 웹 서비스 설치 튜토리얼과 유사한 기본 패키지 준비 흐름을 따르되, 이번 목적에 맞게 Python/Git/systemd 중심으로 구성한 것입니다.[^6_7]
Oracle 무료 서버는 Ubuntu 인스턴스를 생성해 SSH 접속 후 이런 초기화 절차를 수행하는 것이 일반적입니다.[^6_5][^6_7]

## 6. 일일 실행 오케스트레이션

### `scripts/run_daily.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[^6_0]}")/.." && pwd)"
cd "${ROOT_DIR}"

source .venv/bin/activate

mkdir -p site/assets logs tmp

echo "[1/6] pull latest source"
git pull --rebase origin main

echo "[2/6] backup previous data"
if [ -f site/assets/data.json ]; then
  cp site/assets/data.json site/assets/previous_data.json
fi

echo "[3/6] collect latest github data"
python scripts/collect_data.py

echo "[4/6] compare with previous dashboard"
python scripts/compare_with_previous.py

echo "[5/6] build static dashboard"
python scripts/build_dashboard.py

echo "[6/6] run claude analysis"
bash scripts/run_claude_analysis.sh || true

git add site index.html .claude scripts README.md || true
git add -A

if ! git diff --cached --quiet; then
  git config user.name "dashboard-bot"
  git config user.email "dashboard-bot@users.noreply.github.com"
  git commit -m "chore: daily dashboard update $(date '+%Y-%m-%d %H:%M:%S %Z')"
  git push origin main
else
  echo "No changes detected."
fi
```

이 스크립트가 핵심입니다. 오전 2시에 실행되어 이전 데이터 백업, 최신 수집, 비교, HTML 생성, Claude 분석, GitHub push까지 한 번에 처리합니다.

## 7. Python 의존성

### `requirements.txt`

```txt
requests==2.32.3
jinja2==3.1.4
python-dateutil==2.9.0.post0
pytz==2025.2
beautifulsoup4==4.12.3
lxml==5.3.0
markdown==3.7
```


## 8. GitHub 데이터 수집 코드

### `scripts/collect_data.py`

```python
#!/usr/bin/env python3
import json
import time
from pathlib import Path
from datetime import datetime
import pytz
import requests
from bs4 import BeautifulSoup

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "site" / "assets"
OUT.mkdir(parents=True, exist_ok=True)

KST = pytz.timezone("Asia/Seoul")
NOW = datetime.now(KST).strftime("%Y-%m-%d %H:%M:%S %Z")

TOPICS = [
    ("python", "Python"),
    ("javascript", "JavaScript"),
    ("typescript", "TypeScript"),
    ("java", "Java"),
    ("go", "Go"),
    ("rust", "Rust"),
    ("kubernetes", "Kubernetes"),
    ("docker", "Docker"),
    ("machine-learning", "Machine Learning"),
    ("llm", "LLM"),
]

HEADERS = {
    "User-Agent": "github-dashboard-bot/1.0",
    "Accept": "application/vnd.github+json",
}

def github_search_top100(topic: str):
    url = "https://api.github.com/search/repositories"
    params = {
        "q": f"topic:{topic} archived:false mirror:false",
        "sort": "stars",
        "order": "desc",
        "per_page": 100,
        "page": 1,
    }
    r = requests.get(url, headers=HEADERS, params=params, timeout=30)
    r.raise_for_status()
    data = r.json()
    items = []
    for idx, repo in enumerate(data.get("items", []), start=1):
        items.append({
            "rank": idx,
            "full_name": repo["full_name"],
            "url": repo["html_url"],
            "stars": repo["stargazers_count"],
            "forks": repo["forks_count"],
            "language": repo.get("language") or "",
            "description": repo.get("description") or "",
        })
    return {
        "topic": topic,
        "count": data.get("total_count", 0),
        "items": items,
    }

def parse_trending(period: str):
    url = "https://github.com/trending"
    params = {}
    if period != "daily":
        params["since"] = period
    r = requests.get(url, headers={"User-Agent": HEADERS["User-Agent"]}, params=params, timeout=30)
    r.raise_for_status()
    soup = BeautifulSoup(r.text, "lxml")
    repos = []

    for idx, article in enumerate(soup.select("article.Box-row"), start=1):
        h2 = article.select_one("h2 a")
        if not h2:
            continue
        href = h2.get("href", "").strip("/")
        if "/" not in href:
            continue

        full_name = href
        desc = article.select_one("p")
        lang = article.select_one('[itemprop=\"programmingLanguage\"]')

        text = article.get_text(" ", strip=True)
        period_label = {
            "daily": "stars today",
            "weekly": "stars this week",
            "monthly": "stars this month",
        }[period]

        delta = 0
        import re
        m = re.search(r"([0-9,]+)\s+stars?\s+" + re.escape(period_label), text)
        if m:
            delta = int(m.group(1).replace(",", ""))

        stars_total = 0
        links = article.select("a.Link--muted")
        for a in links:
            txt = a.get_text(" ", strip=True).replace(",", "")
            if txt.isdigit():
                stars_total = int(txt)
                break

        repos.append({
            "rank": idx,
            "full_name": full_name,
            "url": f"https://github.com/{full_name}",
            "description": desc.get_text(" ", strip=True) if desc else "",
            "language": lang.get_text(strip=True) if lang else "",
            "period_stars": delta,
            "stars": stars_total,
        })
    return repos

def main():
    categories = []
    for slug, label in TOPICS:
        item = github_search_top100(slug)
        item["label"] = label
        categories.append(item)
        time.sleep(0.5)

    trending = {
        "daily": parse_trending("daily"),
        "weekly": parse_trending("weekly"),
        "monthly": parse_trending("monthly"),
    }

    payload = {
        "generated_at": NOW,
        "generated_by": "Oracle Cloud daily scheduler",
        "categories": categories,
        "trending": trending,
    }

    (OUT / "data.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

if __name__ == "__main__":
    main()
```

GitHub Trending은 공식 API보다 웹 페이지 기반 접근이 일반적이므로 HTML 파싱 방식이 현실적입니다. 또한 GitHub Search API는 누적 스타 Top 100 생성에 적합합니다.[^6_10][^6_11][^6_12]

## 9. 전일 대비 신규 급상승 비교

### `scripts/compare_with_previous.py`

```python
#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "site" / "assets"

current_file = ASSETS / "data.json"
previous_file = ASSETS / "previous_data.json"
analysis_file = ASSETS / "analysis.json"

current = json.loads(current_file.read_text(encoding="utf-8"))

if previous_file.exists():
    previous = json.loads(previous_file.read_text(encoding="utf-8"))
else:
    previous = {"trending": {"daily": [], "weekly": [], "monthly": []}}

def names(items):
    return {item["full_name"] for item in items}

result = {
    "generated_at": current["generated_at"],
    "new_trending": {}
}

for period in ["daily", "weekly", "monthly"]:
    prev_names = names(previous.get("trending", {}).get(period, []))
    cur_items = current.get("trending", {}).get(period, [])
    new_items = [item for item in cur_items if item["full_name"] not in prev_names]
    result["new_trending"][period] = new_items

analysis_file.write_text(
    json.dumps(result, ensure_ascii=False, indent=2),
    encoding="utf-8"
)
```

이 코드는 전일 스냅샷 대비 오늘 새롭게 급상승 목록에 들어온 저장소를 계산합니다. 이 결과를 Claude 분석 입력으로 넘기면 됩니다.

## 10. Claude Code 연결

커스텀 명령은 `.claude/commands/` 아래의 Markdown 파일로 정의할 수 있습니다. 프로젝트 수준 커맨드는 버전 관리에 포함되므로 팀 공유에도 مناسب합니다.[^6_13][^6_3]

### `.claude/CLAUDE.md`

```md
# CLAUDE.md

이 저장소는 GitHub 카테고리별 누적 스타 Top100과 금일/금주/금월 급상승 저장소를
정적 페이지로 생성하는 프로젝트다.

주요 원칙:
- site/index.html 은 최종 공개 페이지다.
- site/result.md 는 전일 대비 신규 급상승 저장소 분석 리포트다.
- site/assets/data.json 은 최신 수집 데이터다.
- site/assets/previous_data.json 은 전일 데이터다.
- site/assets/analysis.json 은 신규 급상승 비교 결과다.

분석 시 유의사항:
- 신규 급상승 저장소는 daily, weekly, monthly로 구분한다.
- 과도한 추정은 피하고, 저장소 설명과 공개 정보 중심으로 요약한다.
- 결과는 한국어로 작성한다.
```


### `.claude/commands/analyze.md`

```md
---
description: 전일 대비 신규 급상승 저장소를 분석하여 site/result.md를 생성합니다.
allowed-tools: Read,Write,Edit,Bash(python:*),Bash(cat:*),Bash(jq:*)
argument-hint: [optional-period]
---

다음 파일을 읽고 신규 급상승 저장소를 분석합니다.

입력 파일:
- @site/assets/data.json
- @site/assets/analysis.json
- @.claude/CLAUDE.md

목표:
1. daily, weekly, monthly 별 신규 진입 저장소를 파악합니다.
2. 각 저장소의 full_name, description, language, period_stars를 요약합니다.
3. 왜 주목받는지 설명하되, 근거 없는 추정은 하지 않습니다.
4. 결과를 한국어 Markdown 보고서로 @site/result.md 에 저장합니다.
5. 보고서 첫머리에 생성 시각과 분석 기준(전일 대비 신규 급상승)을 적습니다.

출력 형식:
- 제목
- 생성 시각
- Daily 신규 급상승
- Weekly 신규 급상승
- Monthly 신규 급상승
- 관찰 포인트
```


### `.claude/commands/claude.md`

```md
---
description: 분석 보고서 생성 전체 흐름을 실행하기 위한 프로젝트 명령 설명
allowed-tools: Read,Bash(ls:*),Bash(cat:*),Bash(python:*)
---

이 프로젝트의 Claude 분석 절차는 다음과 같습니다.

1. @site/assets/analysis.json 확인
2. @site/assets/data.json 확인
3. /analyze 실행
4. 생성된 @site/result.md 검토
5. 대시보드 HTML에서 result.md 링크가 노출되는지 확인
```


## 11. Claude 실행 스크립트

Claude Code CLI 설치 자체는 사용 중인 환경에 따라 달라지므로, 여기서는 이미 설치되어 있다고 가정합니다. 커스텀 slash command는 `.claude/commands/`에 위치시킬 수 있습니다.[^6_3][^6_13]

### `scripts/run_claude_analysis.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[^6_0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! command -v claude >/dev/null 2>&1; then
  echo "claude CLI not found. skip analysis."
  exit 0
fi

if [ ! -f site/assets/analysis.json ]; then
  echo "analysis.json not found. skip analysis."
  exit 0
fi

claude "/analyze"
```

주의할 점은, 실제 Claude CLI의 비대화형 실행 방식은 설치 버전과 환경에 따라 차이가 있을 수 있습니다. 다만 커스텀 slash command가 `.claude/commands/`에 위치하는 구조는 공개 자료에서 확인됩니다.[^6_13][^6_3]

## 12. 대시보드 생성 코드

### `scripts/build_dashboard.py`

```python
#!/usr/bin/env python3
import json
from pathlib import Path
from markdown import markdown

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "site"
ASSETS = SITE / "assets"

data = json.loads((ASSETS / "data.json").read_text(encoding="utf-8"))
analysis = {}
analysis_path = ASSETS / "analysis.json"
if analysis_path.exists():
    analysis = json.loads(analysis_path.read_text(encoding="utf-8"))

result_md = SITE / "result.md"
result_html = ""
if result_md.exists():
    result_html = markdown(result_md.read_text(encoding="utf-8"))

def stat_card(title, value, desc):
    return f"""
    <div class="card">
      <div class="label">{title}</div>
      <div class="value">{value}</div>
      <div class="desc">{desc}</div>
    </div>
    """

def repo_row(repo, metric_label="stars"):
    metric = repo.get("period_stars", repo.get("stars", 0))
    return f"""
    <tr>
      <td>{repo.get('rank','')}</td>
      <td><a href="{repo['url']}" target="_blank" rel="noopener noreferrer">{repo['full_name']}</a></td>
      <td>{repo.get('description','')}</td>
      <td>{repo.get('language','')}</td>
      <td>{metric}</td>
    </tr>
    """

top_topic = data["categories"][^6_0]
daily = data["trending"]["daily"][:20]
weekly = data["trending"]["weekly"][:20]
monthly = data["trending"]["monthly"][:20]

html = f"""<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>GitHub Trending Dashboard</title>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 0; background: #f7f6f2; color: #222; }}
    .wrap {{ max-width: 1280px; margin: 0 auto; padding: 24px; }}
    h1,h2 {{ margin-top: 0; }}
    .grid {{ display: grid; grid-template-columns: repeat(4,1fr); gap: 16px; }}
    .card {{ background: #fff; border: 1px solid #ddd; border-radius: 12px; padding: 16px; }}
    .label {{ font-size: 12px; color: #666; text-transform: uppercase; }}
    .value {{ font-size: 28px; font-weight: bold; margin-top: 8px; }}
    .desc {{ font-size: 14px; color: #666; margin-top: 8px; }}
    table {{ width: 100%; border-collapse: collapse; background: #fff; }}
    th,td {{ border-bottom: 1px solid #eee; padding: 10px; text-align: left; vertical-align: top; }}
    th {{ background: #fafafa; }}
    a {{ color: #006494; text-decoration: none; }}
    .section {{ margin-top: 32px; }}
    .panel {{ background: #fff; border: 1px solid #ddd; border-radius: 12px; padding: 16px; }}
    @media (max-width: 900px) {{ .grid {{ grid-template-columns: 1fr 1fr; }} }}
    @media (max-width: 600px) {{ .grid {{ grid-template-columns: 1fr; }} }}
  </style>
</head>
<body>
<div class="wrap">
  <h1>GitHub 카테고리별 Top100 + 급상승 대시보드</h1>
  <p>생성 시각: {data['generated_at']}</p>
  <p>매일 오전 2시에 Oracle 서버에서 정적 페이지를 생성하고 GitHub에 푸시합니다.</p>
  <p><a href="./result.md" target="_blank" rel="noopener noreferrer">전일 대비 신규 급상승 분석 보고서 보기</a></p>

  <div class="grid">
    {stat_card("카테고리 수", len(data["categories"]), "수집 대상 토픽")}
    {stat_card("금일 급상승", len(data["trending"]["daily"]), "오늘 스타 급증 저장소")}
    {stat_card("금주 급상승", len(data["trending"]["weekly"]), "이번 주 스타 급증 저장소")}
    {stat_card("금월 급상승", len(data["trending"]["monthly"]), "이번 달 스타 급증 저장소")}
  </div>

  <div class="section">
    <h2>{top_topic['label']} Top 100</h2>
    <div class="panel">
      <table>
        <thead><tr><th>#</th><th>Repository</th><th>Description</th><th>Language</th><th>Stars</th></tr></thead>
        <tbody>
          {''.join(repo_row(r, 'stars') for r in top_topic['items'][:30])}
        </tbody>
      </table>
    </div>
  </div>

  <div class="section">
    <h2>금일 급상승</h2>
    <div class="panel">
      <table>
        <thead><tr><th>#</th><th>Repository</th><th>Description</th><th>Language</th><th>Today</th></tr></thead>
        <tbody>{''.join(repo_row(r, 'today') for r in daily)}</tbody>
      </table>
    </div>
  </div>

  <div class="section">
    <h2>금주 급상승</h2>
    <div class="panel">
      <table>
        <thead><tr><th>#</th><th>Repository</th><th>Description</th><th>Language</th><th>This Week</th></tr></thead>
        <tbody>{''.join(repo_row(r, 'week') for r in weekly)}</tbody>
      </table>
    </div>
  </div>

  <div class="section">
    <h2>금월 급상승</h2>
    <div class="panel">
      <table>
        <thead><tr><th>#</th><th>Repository</th><th>Description</th><th>Language</th><th>This Month</th></tr></thead>
        <tbody>{''.join(repo_row(r, 'month') for r in monthly)}</tbody>
      </table>
    </div>
  </div>

  <div class="section">
    <h2>최근 분석 결과</h2>
    <div class="panel">
      {result_html if result_html else '<p>아직 분석 보고서가 생성되지 않았습니다.</p>'}
    </div>
  </div>
</div>
</body>
</html>
"""

(SITE / "index.html").write_text(html, encoding="utf-8")
```

이 스크립트는 `result.md` 링크를 노출하고, 동시에 Markdown 내용을 HTML로 렌더링해서 대시보드 안에서도 보여줍니다.

## 13. Oracle 서버에서 실제 실행 순서

아래처럼 진행하면 됩니다.

1. Oracle Cloud Free Tier 가입 후 Ubuntu 인스턴스 생성.[^6_5][^6_7]
2. SSH 접속.
3. 저장소를 로컬에서 미리 만들어 push해 둠.
4. 서버에서 `bootstrap_server.sh` 실행.
5. 출력된 SSH 공개키를 GitHub Deploy Key로 등록.
6. `sudo systemctl start github-dashboard.service`로 수동 1회 테스트.
7. 정상 동작 확인 후 타이머 자동 실행 대기.

예시:

```bash
git clone git@github.com:YOUR_GITHUB_USERNAME/YOUR_REPO.git
cd YOUR_REPO
chmod +x scripts/*.sh
bash scripts/bootstrap_server.sh
sudo systemctl start github-dashboard.service
journalctl -u github-dashboard.service -n 200 --no-pager
```


## 14. GitHub Pages 공개 경로

GitHub Pages는 project site로 배포하면 일반적으로 다음 형식으로 공개됩니다.[^6_4][^6_8]

```text
https://<github-username>.github.io/<repository-name>/
```

만약 `site/` 폴더를 publishing source로 설정했다면, 그 안의 `index.html`이 메인 페이지가 됩니다.[^6_9]

## 15. 한계와 보완점

몇 가지는 현실적으로 보완이 필요합니다.

- GitHub/Google 계정 생성은 수동입니다.[^6_1][^6_2]
- GitHub API rate limit을 안정적으로 늘리려면 Personal Access Token을 `GITHUB_TOKEN` 환경변수로 두는 것이 좋습니다.
- Claude CLI의 비대화형 실행 형태는 설치 버전별 차이가 있으므로, `/analyze` 호출 부분은 실제 환경에서 한 번 검증해야 합니다.[^6_3]
- GitHub Trending HTML 구조가 바뀌면 파서 수정이 필요합니다.[^6_11][^6_10]


## 16. 실제 운영용으로 권장하는 추가 파일

아래 파일도 함께 두는 것이 좋습니다.

### `.gitignore`

```gitignore
.venv/
__pycache__/
logs/
tmp/
*.pyc
```


### `README.md` 핵심 항목

- Oracle 서버 초기 설정 방법
- GitHub Pages 설정
- systemd timer 확인 방법
- 수동 재실행 방법
- Claude 분석 결과 확인 방법

원하시면 다음 단계에서 제가 이 전체 구성을 **실제로 바로 커밋 가능한 프로젝트 파일 세트**로 만들어서, `index.html`, `scripts/*.py`, `scripts/*.sh`, `.claude/*`, `README.md`까지 한 번에 내려받을 수 있게 패키징해드리겠습니다.[^6_3][^6_9]
<span style="display:none">[^6_14][^6_15][^6_16][^6_17][^6_18][^6_19][^6_20]</span>

<div align="center">⁂</div>

[^6_1]: https://docs.github.com/en/get-started/start-your-journey/creating-an-account-on-github

[^6_2]: https://github.com/signup

[^6_3]: https://prg.sh/notes/Claude-Code-Slash-Commands

[^6_4]: https://docs.github.com/articles/creating-project-pages-manually

[^6_5]: https://www.oracle.com/kr/cloud/free/

[^6_6]: https://github.com/github/docs/blob/main/content/get-started/start-your-journey/creating-an-account-on-github.md

[^6_7]: https://docs.oracle.com/en-us/iaas/Content/developer/apache-on-ubuntu/01oci-ubuntu-apache-summary.htm

[^6_8]: https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site

[^6_9]: https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site

[^6_10]: https://github.com/trending

[^6_11]: https://github.com/trending?since=monthly

[^6_12]: https://gist.github.com/jasonrudolph/6057563

[^6_13]: https://github.com/artemgetmann/claude-slash-commands

[^6_14]: https://docs.github.com/en/get-started/onboarding/getting-started-with-your-github-account

[^6_15]: https://docs.github.com/ko/enterprise-cloud@latest/get-started/onboarding/getting-started-with-your-github-account

[^6_16]: https://gist.github.com/frazei/1a068671db9de53a5a05833e6c8e6fc1

[^6_17]: https://www.reddit.com/r/ClaudeAI/comments/1lf4b9i/can_claude_code_execute_slash_commands_from/

[^6_18]: https://github.com/login

[^6_19]: https://github.com/orgs/community/discussions/169207

[^6_20]: https://oneuptime.com/blog/post/2026-02-08-how-to-set-up-docker-on-an-oracle-cloud-free-tier-instance/view

