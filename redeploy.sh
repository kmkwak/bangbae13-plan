#!/usr/bin/env bash
#
# redeploy.sh — simulation-v1.html 재암호화 + GitHub Pages 배포
#
# 최초 1회: macOS Keychain 에 비밀번호 저장
#   security add-generic-password -a "$USER" -s bangbae13-plan -w '<password>'
#
# 이후: ./redeploy.sh
#
# (macOS 전용. Linux 전환 시 `security` 호출부를 secret-tool/pass 등으로 교체)

set -euo pipefail

cd "$(dirname "$0")"

# ── 1. 사전 점검 ──────────────────────────────────────────
if [ ! -f simulation-v1.html ]; then
  echo "✗ simulation-v1.html 이(가) $(pwd) 에 없습니다." >&2
  exit 1
fi

if ! PASSWORD=$(security find-generic-password -a "$USER" -s bangbae13-plan -w 2>/dev/null); then
  echo "✗ Keychain 에 비밀번호가 없습니다. 최초 1회 등록:" >&2
  echo '   security add-generic-password -a "$USER" -s bangbae13-plan -w '"'"'<password>'"'"'' >&2
  exit 1
fi

# ── 2. 원본 해시 비교 (StatiCrypt IV 가 매번 랜덤이라 ciphertext diff 는 의미 없음) ──
SRC_HASH=$(shasum -a 256 simulation-v1.html | awk '{print $1}')
LAST_HASH=$(cat .deploy-state 2>/dev/null || echo "")
if [ "$SRC_HASH" = "$LAST_HASH" ]; then
  echo "= simulation-v1.html 변경 없음. 배포 생략."
  exit 0
fi

# ── 3. StatiCrypt 임시 환경 ──────────────────────────────
echo '{"name":"tmp","version":"0.0.0","private":true}' > package.json
trap 'rm -rf package.json package-lock.json node_modules encrypted' EXIT

echo "→ staticrypt 설치 (silent)"
npm install --no-save --silent staticrypt

# ── 4. 암호화 ────────────────────────────────────────────
echo "→ simulation-v1.html 암호화 → docs/index.html"
./node_modules/.bin/staticrypt simulation-v1.html \
    -p "$PASSWORD" --short -o docs/index.html >/dev/null 2>&1 || true

# StatiCrypt 의 -o 가 무시되고 encrypted/ 로 떨어지는 케이스 보정
if [ -f encrypted/simulation-v1.html ]; then
  mv -f encrypted/simulation-v1.html docs/index.html
fi

# ── 5. 커밋 + push ───────────────────────────────────────
echo "→ git commit + push"
git add docs/index.html
git commit -m "Update simulation"
git push

# ── 6. 배포 성공 시 원본 해시 기록 (다음 실행에서 변경 감지용) ──
echo "$SRC_HASH" > .deploy-state

cat <<'EOF'

✓ 배포 트리거됨. Pages 빌드 ~1-2 분.
  https://kmkwak.github.io/bangbae13-plan/

  강제 새로고침: Cmd + Shift + R
EOF
