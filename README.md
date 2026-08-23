<div align="center">
    <img width="200" height="200" src="assets/images/logo/logo.png">
    <h1>PiliPlus (Inky-Moon 专属定制版)</h1>
    <p>使用 Flutter 开发的 BiliBili 第三方客户端 —— 深度定制与低版本兼容分支</p>
</div>

<br/>

## 🌟 关于此分支 (About This Fork)

这是 PiliPlus 的深度定制分支，在保留了上游所有强大功能（如直播、番剧、动态、高级弹幕等）的基础上，主要致力于**修复低版本安卓系统的致命崩溃**以及**增强个性化自定义体验**。

相比于原版，此分支的核心特色包括：

- 🚀 **Android 6 (API 23) 完美兼容**
  原版依赖的 Flutter 3.47 引擎在编译 Release 包时，会因为 R8 优化丢失 API 版本保护，导致在 Android 7 以下的老旧设备上打开即闪退（报 `NoSuchMethodError`）。此分支在 GitHub Actions 编译流水线中引入了硬核的 **Javassist 字节码热修复**，精准剔除 `flutter_embedding_release.jar` 中的不兼容调用，**无需降级 Flutter 版本**即可在老设备上流畅运行现代框架！
  
- 🔤 **彻底解决弹幕字体发飘 (支持加载外部 TTF/OTF)**
  完全脱离外部库限制，重构了底层的 `canvas_danmaku` 渲染引擎。现已支持在播放器弹幕设置中，**直接选取并动态加载手机本地的 `.ttf` 或 `.otf` 字体文件**。彻底解决原版 Flutter 在部分安卓系统上弹幕字形发飘、骨架太瘦、甚至强制 Fallback 到日文汉字字库的通病，让弹幕渲染完全受你掌控。

- 📦 **内置固定签名，无损覆盖升级**
  原版使用 GitHub Actions 云端打包时，由于每次运行环境重置，会导致生成的 APK 签名频繁随机变动。每次更新都需要痛苦地卸载重装（丢失所有应用缓存和偏好配置）。此分支内置了静态 Fallback Keystore 配置，现在所有的云端构建产物均具有唯一稳定的签名，**可直接点击覆盖安装，数据无缝保留**。

<br/>

## 📸 界面预览

<div align="center">
<img src="assets/screenshots/510shots_so.png" width="32%" alt="home" />
<img src="assets/screenshots/174shots_so.png" width="32%" alt="home" />
<img src="assets/screenshots/850shots_so.png" width="32%" alt="home" />
<br/>
<img src="assets/screenshots/main_screen.png" width="96%" alt="home" />
</div>

<br/>

## 🛠️ 下载与安装

- 每次向 `main` 分支提交代码后，GitHub Actions 会自动编译构建最新的安装包。
- 请前往本仓库的 Actions 页面，下载最近一次成功构建里的 `app-release.apk`。
- 本版本已自带固定签名，后续更新均可直接覆盖安装，免去卸载烦恼。

<br/>

## 🤝 鸣谢与声明

本项目（PiliPlus）仅用于个人兴趣、学习和测试，不提供任何破解内容。所用 API 皆从官方网站及公开网络收集。

感谢上游生态的卓越贡献：
- 感谢原项目开源作者：[guozhigq/pilipala](https://github.com/guozhigq/pilipala)
- 感谢二次开发作者：[orz12/PiliPalaX](https://github.com/orz12/PiliPalaX)
- 感谢直接上游代码来源：[bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)
- 感谢提供大量 API 参考：[bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)

*感谢开源精神让这一切成为可能！*
