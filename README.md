# PopClip Plugins Collection

A collection of custom PopClip extensions to enhance text selection workflows on macOS.

[中文说明](#中文说明) | [English](#english)

---

## English

### 📦 Plugins Included

#### 1. **Open Gemini** 🤖
Send selected text directly to Google Gemini AI with a single click.

- **Features:**
  - Opens Gemini in your default browser
  - Pre-fills the prompt with your selected text
  - Configurable Gemini base URL
  - Supports URL encoding for special characters
  
- **Configuration:**
  - `Gemini Base URL`: Customize the Gemini URL (default: `https://gemini.google.com/app`)

#### 2. **Send to Claude** 💬
Quickly send selected text to Claude AI assistant.

- **Features:**
  - Opens Claude in your browser
  - Automatically pastes selected text
  - Configurable delay for page loading
  
- **Configuration:**
  - `Delay Time`: Adjust the delay in seconds before pasting (default: `2.5`)

#### 3. **Fancy Text** ✨
Transform regular text into fancy Unicode mathematical alphanumeric symbols.

- **Features:**
  - Multiple fancy text styles
  - Instant text replacement
  - Preserves spaces and punctuation
  
- **Available Styles:**
  - Sans-serif Bold Italic (𝘼𝘽𝘾)
  - Bold Script (𝓐𝓑𝓒)
  - Script (𝒜ℬ𝒞)
  - Sans-serif Bold (𝗔𝗕𝗖)
  - Bold (𝐀𝐁𝐂)
  - Italic (𝐴𝐵𝐶)
  - Bold Italic (𝑨𝑩𝑪)
  - Double-struck (𝔸𝔹ℂ)
  - Monospace (𝙰𝙱𝙲)

#### 4. **Snipaste Float** 📌
Float the selected content on the desktop using the Snipaste CLI. Auto-classifies the selection.

- **Features:**
  - Plain text → floating text pin
  - Rich text (HTML) → rendered HTML pin
  - Local image path → image pin
  - Image URL → downloaded and pinned as image
  - Mermaid source (lines starting with `flowchart`, `graph`, `sequenceDiagram`, etc.) → rendered PNG pin

- **Detection priority:** Mermaid → HTML → local image file → image URL → plain text (fallback)

- **Configuration:** None
- **Dependencies:** [Snipaste](https://www.snipaste.com/) installed at `/Applications/Snipaste.app`. Optional: [`mmdc`](https://github.com/mermaid-js/mermaid-cli) (`@mermaid-js/mermaid-cli`) on `PATH` for Mermaid rendering — without it, Mermaid selections silently fall back to plain-text float.

### 🚀 Installation

1. **Install PopClip** (if not already installed):
   - Download from [PopClip website](https://pilotmoon.com/popclip/)
   - Or install via Homebrew: `brew install --cask popclip`

2. **Install Plugins:**
   - Double-click any `.popclipext` folder
   - Or drag the folder to the PopClip icon in the menu bar
   - PopClip will automatically install the extension

### 📁 Project Structure

```
popclip-plugins/
├── OpenGemini.popclipext/
│   ├── Config.popclipext          # Plugin configuration
│   ├── gemini-icon.svg             # Plugin icon
│   └── open-gemini.sh              # Shell script
├── SendToClaude.popclipext/
│   ├── Config.popclipext
│   ├── claude-color.svg
│   └── send-to-claude.sh
├── fancy-text.popclipext/
│   ├── Config.popclipext
│   ├── fancy-a.svg
│   └── fancy-text.js               # JavaScript implementation
├── SnipasteFloat.popclipext/
│   ├── Config.popclipext
│   ├── snipaste-icon.svg
│   └── snipaste-float.js
└── README.md
```

### 🛠️ Development

Each plugin follows the PopClip extension format:

- **Config.popclipext**: YAML configuration file defining plugin metadata and options
- **Icon file**: SVG icon displayed in PopClip menu
- **Script file**: Shell script (`.sh`) or JavaScript (`.js`) containing the plugin logic

#### Creating Your Own Plugin

1. Create a new folder with `.popclipext` extension
2. Add a `Config.popclipext` file with plugin metadata
3. Add an icon file (SVG recommended)
4. Add your script file (shell or JavaScript)
5. Test by double-clicking the folder

For more details, see the [PopClip Extensions Documentation](https://github.com/pilotmoon/PopClip-Extensions).

### 📝 Requirements

- macOS 10.13 or later
- PopClip app
- For OpenGemini and SendToClaude: Python 3 or Perl (for URL encoding)
- For Snipaste Float: Snipaste app installed at `/Applications/Snipaste.app`

### 📄 License

MIT License - Feel free to use and modify these plugins.

---

## 中文说明

### 📦 包含的插件

#### 1. **Open Gemini** 🤖
一键将选中的文本发送到 Google Gemini AI。

- **功能特性:**
  - 在默认浏览器中打开 Gemini
  - 自动填充选中的文本作为提示词
  - 可配置的 Gemini 基础 URL
  - 支持特殊字符的 URL 编码
  
- **配置选项:**
  - `Gemini Base URL`: 自定义 Gemini URL(默认: `https://gemini.google.com/app`)

#### 2. **Send to Claude** 💬
快速将选中的文本发送到 Claude AI 助手。

- **功能特性:**
  - 在浏览器中打开 Claude
  - 自动粘贴选中的文本
  - 可配置的页面加载延迟
  
- **配置选项:**
  - `Delay Time`: 调整粘贴前的延迟秒数(默认: `2.5`)

#### 3. **Fancy Text** ✨
将普通文本转换为花式 Unicode 数学字母数字符号。

- **功能特性:**
  - 多种花式文本样式
  - 即时文本替换
  - 保留空格和标点符号
  
- **可用样式:**
  - 无衬线粗斜体 (𝘼𝘽𝘾)
  - 粗体手写体 (𝓐𝓑𝓒)
  - 手写体 (𝒜ℬ𝒞)
  - 无衬线粗体 (𝗔𝗕𝗖)
  - 粗体 (𝐀𝐁𝐂)
  - 斜体 (𝐴𝐵𝐶)
  - 粗斜体 (𝑨𝑩𝑪)
  - 双线体 (𝔸𝔹ℂ)
  - 等宽字体 (𝙰𝙱𝙲)

#### 4. **Snipaste Float** 📌
使用 Snipaste CLI 将选中内容悬浮在桌面上。自动识别内容类型。

- **功能特性:**
  - 纯文本 → 文字悬浮贴图
  - 富文本（HTML）→ HTML 渲染贴图
  - 本地图片路径 → 图片贴图
  - 图片 URL → 下载后作为图片贴图
  - Mermaid 源码（以 `flowchart`、`graph`、`sequenceDiagram` 等开头）→ 渲染为 PNG 后悬浮

- **识别优先级:** Mermaid → HTML → 本地图片文件 → 图片 URL → 纯文本（兜底）

- **配置选项:** 无
- **依赖:** [Snipaste](https://www.snipaste.com/) 安装在 `/Applications/Snipaste.app`。可选：[`mmdc`](https://github.com/mermaid-js/mermaid-cli)（`@mermaid-js/mermaid-cli`）在 `PATH` 上 — 缺失时 Mermaid 选区会静默回退为纯文本悬浮。

### 🚀 安装方法

1. **安装 PopClip**(如果尚未安装):
   - 从 [PopClip 官网](https://pilotmoon.com/popclip/)下载
   - 或通过 Homebrew 安装: `brew install --cask popclip`

2. **安装插件:**
   - 双击任意 `.popclipext` 文件夹
   - 或将文件夹拖到菜单栏中的 PopClip 图标
   - PopClip 会自动安装扩展

### 📁 项目结构

```
popclip-plugins/
├── OpenGemini.popclipext/
│   ├── Config.popclipext          # 插件配置
│   ├── gemini-icon.svg             # 插件图标
│   └── open-gemini.sh              # Shell 脚本
├── SendToClaude.popclipext/
│   ├── Config.popclipext
│   ├── claude-color.svg
│   └── send-to-claude.sh
├── fancy-text.popclipext/
│   ├── Config.popclipext
│   ├── fancy-a.svg
│   └── fancy-text.js               # JavaScript 实现
├── SnipasteFloat.popclipext/
│   ├── Config.popclipext
│   ├── snipaste-icon.svg
│   └── snipaste-float.js
└── README.md
```

### 🛠️ 开发说明

每个插件都遵循 PopClip 扩展格式:

- **Config.popclipext**: YAML 配置文件,定义插件元数据和选项
- **图标文件**: 在 PopClip 菜单中显示的 SVG 图标
- **脚本文件**: 包含插件逻辑的 Shell 脚本(`.sh`)或 JavaScript(`.js`)

#### 创建自己的插件

1. 创建一个带 `.popclipext` 扩展名的新文件夹
2. 添加包含插件元数据的 `Config.popclipext` 文件
3. 添加图标文件(推荐使用 SVG)
4. 添加脚本文件(Shell 或 JavaScript)
5. 双击文件夹进行测试

更多详情请参阅 [PopClip 扩展文档](https://github.com/pilotmoon/PopClip-Extensions)。

### 📝 系统要求

- macOS 10.13 或更高版本
- PopClip 应用
- OpenGemini 和 SendToClaude 需要: Python 3 或 Perl(用于 URL 编码)
- Snipaste Float 需要: Snipaste 应用安装在 `/Applications/Snipaste.app`

### 📄 许可证

MIT 许可证 - 欢迎自由使用和修改这些插件。

---

## 🤝 Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest new features
- Submit pull requests
- Create new plugins

## 📮 Support

If you encounter any issues or have questions, please open an issue on GitHub.

---

**Enjoy your enhanced text selection workflow! 🎉**
