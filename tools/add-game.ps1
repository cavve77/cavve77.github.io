param(
    [string]$SourceFolder,
    [string]$GameTitle,
    [string]$Slug,
    [string]$Description = '',
    [string]$Controls = '',
    [switch]$NoPublish,
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$siteRoot = Split-Path -Parent $PSScriptRoot
$expectedRemote = 'https://github.com/cavve77/cavve77.github.io.git'

function Invoke-SiteGit {
    param([string[]]$GitArgs)
    $result = & git -C $siteRoot @GitArgs 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($result -join "`n") }
    return $result
}

try {
    if ($CheckOnly) {
        $catalog = Get-Content -LiteralPath (Join-Path $siteRoot 'data\games.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($null -eq $catalog.games) { throw '游戏目录缺少 games 字段。' }
        foreach ($game in $catalog.games) {
            if (-not $game.id -or -not $game.title) { throw '游戏条目缺少 id 或 title。' }
            if ($game.web -and -not ($game.web -match '^https?://')) {
                $entry = Join-Path $siteRoot $game.web
                if (-not (Test-Path -LiteralPath $entry -PathType Leaf)) { throw "游戏入口不存在：$($game.web)" }
            }
        }
        Write-Host "目录检查通过，共 $(@($catalog.games).Count) 款游戏。" -ForegroundColor Green
        exit 0
    }

    if (-not $SourceFolder -or -not $GameTitle) {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        [System.Windows.Forms.Application]::EnableVisualStyles()
        $form = New-Object System.Windows.Forms.Form
        $form.Text = '添加网页游戏 · CAVVE PLAY'
        $form.ClientSize = New-Object System.Drawing.Size(580, 380)
        $form.StartPosition = 'CenterScreen'
        $form.FormBorderStyle = 'FixedDialog'
        $form.MaximizeBox = $false
        $form.Font = New-Object System.Drawing.Font('DengXian', 10)
        function Add-Field {
            param([string]$Label, [int]$Y, [string]$Value)
            $caption = New-Object System.Windows.Forms.Label
            $caption.Text = $Label
            $caption.SetBounds(22, $Y + 5, 112, 24)
            $box = New-Object System.Windows.Forms.TextBox
            $box.SetBounds(135, $Y, 420, 28)
            $box.Text = $Value
            $form.Controls.Add($caption)
            $form.Controls.Add($box)
            return $box
        }
        $folderBox = Add-Field '网页导出文件夹' 23 $SourceFolder
        $folderBox.Width = 320
        $choose = New-Object System.Windows.Forms.Button
        $choose.Text = '选择…'
        $choose.SetBounds(465, 22, 90, 29)
        $choose.Add_Click({
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.Description = '选择包含 index.html 的游戏网页导出文件夹'
            if ($dialog.ShowDialog() -eq 'OK') { $folderBox.Text = $dialog.SelectedPath }
            $dialog.Dispose()
        })
        $form.Controls.Add($choose)
        $titleBox = Add-Field '游戏名称' 70 $GameTitle
        $defaultSlug = if ($Slug) { $Slug } else { 'game-' + (Get-Date -Format 'yyyyMMdd-HHmmss') }
        $slugBox = Add-Field '目录名（英文）' 117 $defaultSlug
        $descriptionBox = Add-Field '简短介绍' 164 $Description
        $controlsBox = Add-Field '操作说明' 211 $Controls
        $note = New-Object System.Windows.Forms.Label
        $note.Text = "只选择游戏的网页导出文件夹。`n点击发布后，导出文件与以上信息将公开到你的试玩站。"
        $note.SetBounds(22, 259, 533, 50)
        $form.Controls.Add($note)
        $publish = New-Object System.Windows.Forms.Button
        $publish.Text = '添加并发布'
        $publish.SetBounds(345, 324, 128, 32)
        $publish.DialogResult = 'OK'
        $cancel = New-Object System.Windows.Forms.Button
        $cancel.Text = '取消'
        $cancel.SetBounds(484, 324, 71, 32)
        $cancel.DialogResult = 'Cancel'
        $form.Controls.Add($publish)
        $form.Controls.Add($cancel)
        $form.AcceptButton = $publish
        $form.CancelButton = $cancel
        if ($form.ShowDialog() -ne 'OK') { $form.Dispose(); exit 0 }
        $SourceFolder = $folderBox.Text.Trim()
        $GameTitle = $titleBox.Text.Trim()
        $Slug = $slugBox.Text.Trim()
        $Description = $descriptionBox.Text.Trim()
        $Controls = $controlsBox.Text.Trim()
        $form.Dispose()
    }

    if (-not $GameTitle) { throw '请填写游戏名称。' }
    if (-not $Slug) { $Slug = 'game-' + (Get-Date -Format 'yyyyMMdd-HHmmss') }
    if ($Slug -notmatch '^[a-z0-9][a-z0-9-]{0,63}$') { throw '目录名只能使用小写英文字母、数字和连字符，最多 64 个字符。' }
    $source = (Resolve-Path -LiteralPath $SourceFolder).Path
    if (-not (Test-Path -LiteralPath (Join-Path $source 'index.html') -PathType Leaf)) { throw '请选择包含 index.html 的网页导出文件夹。' }
    $rootItem = Get-Item -LiteralPath $source
    if ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw '请选择普通文件夹，不使用文件夹链接。' }
    $sourceItems = @(Get-ChildItem -LiteralPath $source -Recurse -Force)
    if ($sourceItems | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw '导出文件夹中包含文件链接，请移除链接后重试。' }
    $forbidden = @('.git', '.godot', 'node_modules', '.env', 'project.godot', 'project.config.json', 'project.private.config.json')
    if ($sourceItems | Where-Object { $_.Name -in $forbidden -or $_.Name -like '.env.*' -or $_.Extension -in @('.blend', '.blend1', '.gd', '.cs', '.ts', '.pem', '.key', '.keystore') }) { throw '选择的文件夹包含源工程、缓存或密钥文件。请重新选择纯网页导出文件夹。' }
    $files = @($sourceItems | Where-Object { -not $_.PSIsContainer })
    if ($files | Where-Object { $_.Length -ge 100MB }) { throw '有单个文件达到 100 MB，无法直接上传 GitHub。请压缩导出体积或使用其他资源托管。' }
    $existingSize = (Get-ChildItem -LiteralPath (Join-Path $siteRoot 'games') -File -Recurse | Measure-Object Length -Sum).Sum
    $incomingSize = ($files | Measure-Object Length -Sum).Sum
    if (($existingSize + $incomingSize) -ge 950MB) { throw '游戏文件总量接近 Pages 的 1 GB 上限，请改用外部资源或下载链接。' }
    $target = Join-Path (Join-Path $siteRoot 'games') $Slug
    if (Test-Path -LiteralPath $target) { throw '这个目录已经存在。请填写新的目录名，以保留旧版本。' }

    if (-not $NoPublish) {
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw '未找到 Git。请安装 Git for Windows 后重试。' }
        if (-not (Test-Path -LiteralPath (Join-Path $siteRoot '.git'))) { throw '请在本机提供的完整仓库内运行此工具；从网页下载的 ZIP 不含 Git 信息。' }
        $remote = (Invoke-SiteGit -GitArgs @('remote', 'get-url', 'origin') | Out-String).Trim()
        if ($remote -notin @($expectedRemote, 'git@github.com:cavve77/cavve77.github.io.git')) { throw '仓库地址不匹配，停止发布。' }
        $branch = (Invoke-SiteGit -GitArgs @('branch', '--show-current') | Out-String).Trim()
        if ($branch -ne 'main') { throw '请切换到 main 分支后发布。' }
        if (Invoke-SiteGit -GitArgs @('status', '--porcelain')) { throw '仓库还有未发布的修改。请先保存或提交这些修改，再添加游戏。' }
        Write-Host '同步最新目录…'
        Invoke-SiteGit -GitArgs @('pull', '--ff-only', 'origin', 'main') | Out-Host
    }

    $catalogPath = Join-Path $siteRoot 'data\games.json'
    $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (@($catalog.games | Where-Object { $_.id -eq $Slug }).Count -gt 0 -or (Test-Path -LiteralPath $target)) { throw '这个游戏目录名已经被使用，请选择新的目录名。' }
    Copy-Item -LiteralPath $source -Destination $target -Recurse
    $game = [ordered]@{
        id = $Slug
        title = $GameTitle
        description = $Description
        version = '试玩版'
        updated = Get-Date -Format 'yyyy-MM-dd'
        tags = @('试玩')
        controls = $Controls
        web = "games/$Slug/index.html"
        downloads = @()
    }
    $catalog.games = @($game) + @($catalog.games)
    $json = ($catalog | ConvertTo-Json -Depth 12) + "`n"
    [IO.File]::WriteAllText($catalogPath, $json, (New-Object System.Text.UTF8Encoding($false)))

    if ($NoPublish) { Write-Host "本地已添加：$GameTitle" -ForegroundColor Green; exit 0 }
    Invoke-SiteGit -GitArgs @('add', '--', "games/$Slug", 'data/games.json') | Out-Host
    Invoke-SiteGit -GitArgs @('commit', '-m', "Add playable game: $Slug") | Out-Host
    Invoke-SiteGit -GitArgs @('push', 'origin', 'main') | Out-Host
    Write-Host "已发布：$GameTitle。等待 Pages 自动部署后，打开 https://cavve77.github.io/" -ForegroundColor Green
    Start-Process 'https://cavve77.github.io/'
    Read-Host '按回车关闭'
} catch {
    Write-Host "未完成：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host '若已生成本地提交但推送失败，请在仓库中运行 git push origin main 重试；游戏文件不会被删除。'
    exit 1
}
