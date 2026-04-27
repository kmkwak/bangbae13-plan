# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

방배 5구역 재건축 입주권 자금 계획용 단일 HTML 시뮬레이션. GitHub Pages로 호스팅하되, StatiCrypt 클라이언트 암호화로 비밀번호 게이트를 둠. **원본 평문 파일은 절대 commit하지 않음.**

- **Repo**: https://github.com/kmkwak/bangbae13-plan (public — 무료 GitHub Pages 사용에 필수)
- **Live URL**: https://kmkwak.github.io/bangbae13-plan/ (비밀번호: `<PASSWORD>` — 실제 값은 사용자의 비밀번호 매니저에 보관)

## 무엇을 commit 하고, 무엇을 commit 하지 않는가

`.gitignore` 가 평문 원본을 로컬 전용으로 묶어둠. 사용자의 명시적 지시 없이 이 규칙을 약화시키지 말 것.

- ✅ Commit 대상: `docs/index.html` (암호화본), `.staticrypt.json` (salt만 포함), `.gitignore`, `CLAUDE.md`
- ❌ Commit 금지: `simulation-v1.html`, `simulation-v2.html`, `simulation-v3.html`, `simulation.html`, `DESIGN.md`, `node_modules/` 하위 일체

암호화 빌드를 위해 `package.json` / `package-lock.json` 을 임시 생성하더라도 후처리에서 반드시 제거. `.gitignore` 에 이미 등록되어 있지만, git history에 평문 파일이 잘못 들어가지 않았는지 한 번씩 확인할 것.

## 빌드 및 배포 (재암호화 → push)

`simulation-v1.html` 이 작업 원본. 모든 수정은 여기에 들어가고, 배포 산출물은 `docs/index.html` 로 StatiCrypt가 생성.

작업 디렉토리에 `package.json` 이 없어서 `npx staticrypt …` 직접 실행은 실패함. 다음 패턴을 그대로 사용:

```bash
echo '{"name":"tmp","version":"0.0.0","private":true}' > package.json
npm install --no-save --silent staticrypt
./node_modules/.bin/staticrypt simulation-v1.html -p '<PASSWORD>' --short -o docs/index.html

# 현재 StatiCrypt 버전은 -o 를 정확히 지키지 않고 encrypted/simulation-v1.html 로 출력하므로
# 필요 시 수동 이동:
[ -f encrypted/simulation-v1.html ] && mv -f encrypted/simulation-v1.html docs/index.html && rmdir encrypted

rm -rf package.json package-lock.json node_modules
```

이후 commit + push:

```bash
git add docs/index.html
git commit -m "Update simulation"
git push
```

GitHub Pages 설정은 `main` branch / `/docs` 폴더. 최초 활성화는 repo Settings → Pages 에서 처리됨.

## `simulation-v1.html` 아키텍처

순수 vanilla HTML/CSS/JS, 단일 파일. Plotly.js 는 CDN 로드. 원본 자체에는 빌드 단계가 없고 StatiCrypt 래핑만 거침.

### 데이터 흐름

```
JANDO_AMT, JEONSE_RISE  (let, 사용자 조정 가능 파라미터)
        │
        ▼
recomputeParams()  ──► BALANCE_PAYMENT, ACQ_TAX, COMPLETION_NET,
                       JUNDO_PER_TRANCHE, JUNDO_INT_LOW/MID/HIGH
        │
        ▼
makeScenarios()    ──► [{ id:0, 자체 조달 }, { id:1, 중도금 60% 대출 }]
        │
        ▼
makeEvents(sc)     ──► 시간순 이벤트 리스트
        │
        ▼
runSimulation()    ──► { timeline, eventLog }  현금/주식 누적치 포함
        │
        ▼
render*(sid, sc, sim) ──► #status-{0,1}, #fg-{0,1}, #fn-{0,1},
                          #wf-{0,1}, #et-{0,1}, #asmp-{0,1} 에 DOM 주입
```

`rerender()` 가 진입점. 초기 로드 시점, 그리고 사용자가 입력 필드(`#input-jando`, `#input-jrise`) 값을 바꿀 때마다 호출됨. 두 시나리오를 모두 순회하며 모든 render 함수를 다시 실행 — diff 나 부분 업데이트 없음.

### 렌더 함수 매핑

각 함수는 시나리오 `sid` (0 또는 1) 별로 한 영역을 채움:

- `renderAssumptions` → `#asmp-{sid}`: 공통 가정 + 시나리오별 가정 (중도금 이자 표 포함)
- `renderStatus` → `#status-{sid}`: 4카드 그리드 (현재 자산 / 현재 부채 / 추가분담금 / 전세 상승 조달). 추가분담금 카드만 featured-card 변형 적용
- `renderWaterfall` → `#wf-{sid}`: Plotly waterfall 차트
- `renderEventTable` → `#et-{sid}`, 경고 메시지는 `#aa-{sid}` 에
- `renderFinalSummary` → `#fg-{sid}` (잔금 직전 패널) + `#fn-{sid}` (Step 0 + 처리 절차 step rows)

render 함수들은 inline style 비중이 매우 높음. 대부분의 스타일이 CSS 클래스가 아닌 template literal 로 직접 구성됨. `:root` 디자인 토큰은 여전히 유효하지만, 디자인 언어 변경 시 inline 값까지 동시에 갱신해야 함.

### 두 시나리오 토글

`sc.id` 는 전 코드에서 0 또는 1. UI 의 `<div id="sc-0">` / `<div id="sc-1">` 가 `switchTab(idx)` 의 `.active` 클래스 토글로 전환됨. 탭 활성화 시 자식들에 CSS `nth-child` 기반 stagger fade-up 애니메이션이 자동 트리거.

기본 활성 탭은 `sc-1` (중도금 60% 대출).

## 디자인 시스템

현재 적용 스타일은 Minimalist Modern — Electric Blue 그라데이션 (`#0052FF` → `#4D7CFF`) 단일 accent, dual-font (Calistoga 디스플레이, Inter UI/본문, JetBrains Mono 모노스페이스 라벨), 차분한 slate 팔레트. 토큰은 `<style>` 의 `:root { --primary, --accent-2, --foreground, --muted-foreground, --canvas, --canvas-warm, --border, --pos, --neg, --warn, --loan, ... }` 에 정의됨.

`DESIGN.md` (gitignored) 는 사용자가 활성 디자인 시스템 스펙을 제공하는 파일. 사용자는 이 디자인을 여러 번 갈아끼웠음. 새로운 `DESIGN.md` 를 적용할 때:

1. `:root` CSS 토큰 교체
2. JS render 함수의 inline hex 색상 일괄 치환 (`Bash grep -oE '#[0-9a-fA-F]{3,6}'` 으로 열거)
3. border-radius 스케일, 폰트 스택, 간격 리듬 조정
4. Plotly 차트 색상 (`renderWaterfall`) 갱신

### 한글 폰트 처리

Calistoga / Inter / JetBrains Mono 는 한글 글리프를 지원하지 않음 → 한글은 fallback 으로 떨어짐. 안정적 렌더링을 위해 `Pretendard` 를 jsdelivr CDN 으로 웹폰트 로드 중이며, 이게 빠지면 사용자/기기마다 시스템 폰트(Apple SD Gothic Neo / 맑은 고딕 등)로 들쭉날쭉해짐. 폰트 스택 변경 시 한글 fallback (Pretendard → Noto Sans KR) 을 반드시 유지할 것.

inline 스타일의 `letter-spacing: 0.12em`, `text-transform: uppercase` 같은 속성은 한글에 효과가 없거나 부자연스러우므로, 한글 라벨에서는 의도적으로 제거해야 함 (이미 한 차례 정리된 상태).

## 도메인 빠른 참조

고정 상수 (불변):

- `JEONSE_DEPOSIT_OURS = 1.5` (우리 전세보증금)
- `JEONSE_REPAY = 5.0` (농협 전세자금대출 — 완공 시 자동 상환)
- `INIT_STOCKS = 6.0`, `INIT_CASH = 0`
- `TOTAL_DEBT = 10.7` (현재 부채 합계 — `DEBTS` 리스트로 고정)
- `JUNDO_LOAN_MONTHS = [42,36,30,24,18,12]` (각 회차의 완공까지 잔여 월수)

파생 값 (`recomputeParams()` 에서 재계산):

- `BALANCE_PAYMENT = JANDO_AMT * 0.30` (잔금)
- `ACQ_TAX = JANDO_AMT * 0.033` (취득세 + 지방교육세, 농어촌특별세 면제 — 59㎡)
- `JUNDO_PER_TRANCHE = JANDO_AMT * 0.10` (계약금 / 중도금 회차당)
- `JUNDO_INT_MID` ≈ 4.5% 단리 기준 중도금 이자 추정치 (sc1 에만 적용)
- `COMPLETION_NET = JEONSE_DEPOSIT_OURS + JEONSE_RISE - BALANCE_PAYMENT - ACQ_TAX`

완공 시점 running balance (`renderFinalSummary`):

```
rb0 = fStocks                      (Step 00 시작 — 완공 직전 유동자산)
rb1 = rb0 + 5                      (Step 01 전세 회수 + 농협 상환)
rb2 = rb1 - BALANCE_PAYMENT        (Step 02 잔금)
rb3 = rb2 - ACQ_TAX                (Step 03 취득세)
rb4 = rb3 - JUNDO_INT_MID  [sc1]   (Step 04 중도금 이자)
caseB_liq = rb4 - JANDO_AMT*0.6    (Step 05 자체 상환 분기)
```
