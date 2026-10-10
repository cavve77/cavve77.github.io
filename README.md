# CAVVE PLAY · 个人游戏试玩站

网站：**https://cavve77.github.io/**

这是用于存放游戏网页试玩和下载入口的个人 GitHub Pages 网站。首次发布没有添加任何真实游戏，目录为空。

## 添加网页游戏（Windows）

1. 找到游戏的 **网页导出文件夹**，里面必须有 `index.html` 和它配套的资源文件。
2. 在本机完整仓库内双击 **添加网页游戏.cmd**。
3. 选择导出文件夹，填入游戏名称、介绍和操作说明。默认目录名会自动生成，也可以使用小写英文名称。
4. 点击 **添加并发布**。如果 Git 弹出登录窗口，请登录 `cavve77`。
5. 推送完成后，GitHub Pages 自动部署。页面更新通常需要几分钟。

工具会将网页导出文件复制到 `games/<目录名>/`，更新 `data/games.json`，并推送至 `main`。目录名不能重复，已有版本不会被覆盖。它会拒绝常见源工程、密钥和缓存文件，以及达到 100 MB 的文件。

从 GitHub 的 **Download ZIP** 下载的副本没有 `.git`，不能直接推送。当前本机交付目录已经初始化为完整仓库。换电脑时先安装 Git for Windows，再克隆：

```sh
git clone https://github.com/cavve77/cavve77.github.io.git
```

如果推送失败但已有本地提交，可在仓库中运行 `git push origin main` 重新推送。

## 手动添加或更新目录

首页从 `data/games.json` 读取游戏信息。每个条目至少有游戏名称和一个有效试玩 / 下载入口。例子如下，**示例不是已发布游戏**：

```json
{
  "games": [
    {
      "id": "my-game-v1",
      "title": "我的游戏",
      "description": "一句话介绍玩法。",
      "version": "v0.1.0",
      "updated": "2026-10-10",
      "tags": ["解谜", "原型"],
      "cover": "assets/my-game-cover.png",
      "controls": "WASD 移动，空格跳跃",
      "web": "games/my-game-v1/index.html",
      "downloads": [
        {
          "platform": "Windows",
          "url": "https://github.com/cavve77/cavve77.github.io/releases/download/v0.1.0/my-game.zip"
        }
      ]
    }
  ]
}
```

- `cover`、`controls`、`tags`、`version` 可省略。
- 只有安装包的游戏可省略 `web`，提供 `downloads` 即可。
- `web` 可以使用本仓库内的相对路径，或外部 HTTPS 网页试玩链接。
- Windows ZIP / EXE、Android APK 等下载包建议上传到 [GitHub Releases](https://github.com/cavve77/cavve77.github.io/releases)，然后把真实下载链接填入 `downloads`。
- 用新目录名存放大版本，便于保留历史试玩。

## 网页导出要求

GitHub Pages 托管静态网页，不运行游戏服务器。联机服务需单独部署。网页导出应使用相对资源路径；不要只上传 HTML 而遗漏 WASM、PCK、音频或贴图。

Godot 网页导出建议使用单线程模式，因为多线程网页游戏通常需要额外的跨源隔离配置，而 Pages 无法直接设置自定义响应头。需要多线程时，请先验证专用隔离方案再发布。

Unity 网页构建不要依赖服务器自动返回 `.gz` / `.br` 压缩响应头；选择无压缩导出或正确启用 Decompression Fallback，并用真实浏览器验证。

此网站公开可访问。游戏导出文件、网页脚本和目录信息也会公开；不要把未授权素材、凭据或私有源工程放进仓库。

## Pages 配置

仓库 **Settings → Pages**：

- Source：**Deploy from a branch**
- Branch：**main**
- Folder：**/ (root)**
- 使用默认域名：**cavve77.github.io**

`.nojekyll` 让静态资源按原样发布。每次推送 `main` 后自动重新部署，无需其他构建依赖。

## 本地预览

```sh
python -m http.server 8765 --bind 127.0.0.1
```

打开 `http://127.0.0.1:8765/`。不要直接双击 `index.html`，浏览器通常会阻止从 `file://` 读取目录 JSON。

## 平台限制与参考

- [Pages 限制](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits)：发布站点最大 1 GB，带宽软限制 100 GB / 月。
- [GitHub 大文件限制](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github)：常规 Git 不接受超过 100 MiB 的单个文件。
- [Godot Web 导出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)。
- [Unity Web 压缩部署说明](https://docs.unity3d.com/Manual/webgl-deploying.html)。

## 内容与授权

仓库公开不代表游戏、素材或源代码已授予开源使用许可。各游戏的使用范围由作者另行说明。
