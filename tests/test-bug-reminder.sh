# The Stop hook nudges a bug fix that changed code but no tests toward a regression test, once.
. "$(dirname "$0")/helpers.sh"
p="$scratch/bug"; new_repo "$p"; cd "$p" || exit 1
stub_verify bin/verify; mkdir -p .shipinetics/.cache docs/worksheets src tests
printf 'tests/*\n' >.shipinetics/test-paths; printf '.shipinetics/.cache/\n' >.gitignore
echo a >src/cart.js; git add -A; git commit -qm init
touch .shipinetics/.cache/session-s1
printf '# Cart total is wrong\n> Status: in progress | Type: bug | Task: T-1\n' >docs/worksheets/w.md
echo docs/worksheets/w.md >.shipinetics/.cache/current-worksheet
echo b >src/cart.js; printf 'src/cart.js\ndocs/worksheets/w.md\n' >.shipinetics/.cache/touched-s1

stop_hook "$p"; has "bug fix without a test change: reminded" "$OUT" "regression test first"
stop_hook "$p"; hasnt "only once per session" "$OUT" "regression test first"
rm .shipinetics/.cache/bugreminded-s1
echo 'tests/cart.test.js' >>.shipinetics/.cache/touched-s1
stop_hook "$p"; hasnt "a test changed too: no reminder" "$OUT" "regression test first"
printf 'src/cart.js\n' >.shipinetics/.cache/touched-s1
printf '# Add a coupon field\n> Status: in progress | Type: feature\n' >docs/worksheets/w.md
stop_hook "$p"; hasnt "a feature: no reminder" "$OUT" "regression test first"
printf '# Fix crash on empty cart (Sentry CART-12)\n> Status: in progress\n' >docs/worksheets/w.md
stop_hook "$p"; has "a title naming a fix counts" "$OUT" "regression test first"
done_testing
