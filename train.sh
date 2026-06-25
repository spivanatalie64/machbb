#!/bin/bash
# train.sh — Train a model on yourself
# Collects your writing, code, and conversations to create a dataset
# for fine-tuning a language model.
set -e

echo "━━ AI Training Data Collector ━━"
echo ""

# ── Config ──────────────────────────────────────────────────────────
OUTPUT_DIR="${1:-./training-data}"
mkdir -p "$OUTPUT_DIR"

# ── Collect git history ─────────────────────────────────────────────
collect_git() {
    local dir="$1"
    local label="$2"
    cd "$dir"
    echo "→ Collecting git history: $label"

    # Commit messages
    git log --all --format="%H%n%an%n%ae%n%ai%n%s%n%b%n---END---" > "$OUTPUT_DIR/git-commits-$label.txt" 2>/dev/null

    # Diff of last 100 commits (training on coding style)
    git log -p --max-count=100 > "$OUTPUT_DIR/git-diffs-$label.txt" 2>/dev/null

    # Your authored lines (who you are as a coder)
    git log --all --format="%an <%ae>" | sort -u > "$OUTPUT_DIR/git-authors-$label.txt" 2>/dev/null

    echo "   ✓ $label: $(wc -l < "$OUTPUT_DIR/git-commits-$label.txt") lines"
}

# ── Collect opencode/session data ───────────────────────────────────
collect_opencode() {
    echo "→ Collecting opencode sessions..."
    local src="$HOME/.local/share/opencode"
    if [ -d "$src" ]; then
        find "$src" -name "*.json" -o -name "*.md" -o -name "*.txt" 2>/dev/null \
            -exec cp {} "$OUTPUT_DIR/opencode-" \; 2>/dev/null || true
        echo "   ✓ Copied opencode sessions"
    else
        echo "   - No opencode data found"
    fi
}

# ── Collect writing ─────────────────────────────────────────────────
collect_writing() {
    echo "→ Collecting writing samples..."
    # Markdown files you've written
    find . -name "*.md" -not -path "*/node_modules/*" -not -path "*/.git/*" \
        -exec cat {} + > "$OUTPUT_DIR/writing-markdown.txt" 2>/dev/null
    echo "   ✓ Markdown: $(wc -l < "$OUTPUT_DIR/writing-markdown.txt") lines"
}

# ── Collect shell history ───────────────────────────────────────────
collect_shell() {
    echo "→ Collecting shell history..."
    if [ -f "$HOME/.bash_history" ]; then
        cp "$HOME/.bash_history" "$OUTPUT_DIR/shell-history.txt"
        echo "   ✓ Shell: $(wc -l < "$OUTPUT_DIR/shell-history.txt") commands"
    fi
    if [ -f "$HOME/.zsh_history" ]; then
        cp "$HOME/.zsh_history" "$OUTPUT_DIR/shell-zsh-history.txt"
    fi
}

# ── Generate training format ────────────────────────────────────────
generate_dataset() {
    echo "→ Generating training dataset..."
    local dataset="$OUTPUT_DIR/training.jsonl"

    # Convert collected text into JSONL format (conversation pairs)
    for f in "$OUTPUT_DIR"/*.txt; do
        [ -f "$f" ] || continue
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            printf '{"text": %s}\n' "$(echo "$line" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')" \
                >> "$dataset" 2>/dev/null || true
        done < "$f"
    done

    echo "   ✓ Dataset: $(wc -l < "$dataset") samples"
}

# ── Summary ─────────────────────────────────────────────────────────
summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Training data collected in: $OUTPUT_DIR"
    echo ""
    ls -lh "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.jsonl 2>/dev/null
    echo ""
    echo "Next steps:"
    echo "  1. Review the data in $OUTPUT_DIR"
    echo "  2. Use with your preferred fine-tuning platform:"
    echo "     - Unsloth (local): https://github.com/unslothai/unsloth"
    echo "     - LlamaFactory: https://github.com/hiyouga/LLaMA-Factory"
    echo "     - OpenAI fine-tuning API"
    echo "  3. Or use the data directly with axolotl"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ── Main ────────────────────────────────────────────────────────────
for dir in . .. /storage/Projects/*/ 2>/dev/null; do
    [ -d "$dir/.git" ] && collect_git "$dir" "$(basename "$dir")"
done

collect_opencode
collect_writing
collect_shell
generate_dataset
summary
