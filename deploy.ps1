# deploy.ps1
# git add -> auto commit message via claude CLI -> git commit -> git push

$ErrorActionPreference = 'Stop'

# 1. no changes -> exit
$status = git status --porcelain
if (-not $status) {
    Write-Host "No changes. Exiting." -ForegroundColor Yellow
    exit 0
}

# 2. stage all
Write-Host "Staging changes..." -ForegroundColor Cyan
git add -A
if ($LASTEXITCODE -ne 0) { throw "git add failed" }

# 3. get staged diff
$diff = git diff --cached
if (-not $diff) {
    Write-Host "No staged changes. Exiting." -ForegroundColor Yellow
    exit 0
}

# 4. generate Japanese commit message via claude CLI
Write-Host "Generating commit message..." -ForegroundColor Cyan

$prompt = @'
以下の git diff の内容を読み、変更内容を簡潔にまとめた日本語のコミットメッセージを1行だけ出力してください。

ルール:
- 50文字程度で簡潔に
- 日本語で
- 前置きや説明、引用符、コードブロックは一切付けない
- 「〜を追加」「〜を修正」「〜を更新」「〜をリファクタリング」のような動詞で終わる形式
- 出力はコミットメッセージ本文のみ

git diff:
'@

$inputText = $prompt + "`n" + $diff

# call claude CLI in print mode
$message = $inputText | claude -p 2>$null
if ($LASTEXITCODE -ne 0 -or -not $message) {
    throw "Failed to generate commit message. Is the claude CLI available?"
}

# clean up: trim whitespace and stray quotes, take first line only
$message = $message.Trim()
$message = $message -replace '^[\s"''`]+', ''
$message = $message -replace '[\s"''`]+$', ''
$message = ($message -split "`r?`n")[0].Trim()

if (-not $message) {
    throw "Generated commit message is empty."
}

Write-Host "Message: $message" -ForegroundColor Green

# 5. commit
Write-Host "Committing..." -ForegroundColor Cyan
git commit -m $message
if ($LASTEXITCODE -ne 0) { throw "git commit failed" }

# 6. push
Write-Host "Pushing..." -ForegroundColor Cyan
git push
if ($LASTEXITCODE -ne 0) { throw "git push failed" }

Write-Host "Deploy complete!" -ForegroundColor Green

