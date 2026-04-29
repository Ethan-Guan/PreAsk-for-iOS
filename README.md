# PreAsk

一款极简风格的 AI 终端聊天应用，支持多 Agent 切换，具备思考链展示和 TTS 语音输出能力。

## 功能特性

- **多 Agent 支持** — 内置多个 AI 模型（MiMo、豆包等），可自定义添加新的 Agent，配置不同的 API 端点、模型和系统提示
- **思考链展示** — 支持模型推理过程的可视化，点击即可展开查看 AI 的思考路径
- **TTS 语音输出** — 内置文字转语音功能，AI 回复可自动朗读
- **图片理解** — 支持发送图片进行多模态对话
- **会话管理** — 多会话支持，历史记录本地持久化存储
- **网络监测** — 实时检测网络连接状态，无网络时给出提示
- **开机动画** — 复古终端风格的启动序列动画
- **深色主题** — 黑白红配色的极简终端美学

## 技术栈

- SwiftUI + Combine + Network
- 纯原生实现，无第三方依赖

## 环境要求

- iOS 17.0+
- Xcode 15.0+

## 快速开始

1. 克隆项目
   ```bash
   git clone https://github.com/Ethan-Guan/PreAsk-for-iOS.git
   ```

2. 用 Xcode 打开 `PreAsk.xcodeproj`

3. 在 App 内「设置」中配置你的 API Key

4. 运行到模拟器或真机

## 自定义 Agent

在 Agent 列表页面点击「+」添加新 Agent，填写：

| 字段 | 说明 |
|------|------|
| Name | Agent 显示名称 |
| Base URL | OpenAI 兼容的 API 端点 |
| API Key | 你的 API 密钥 |
| Model | 模型标识符 |
| System Prompt | AI 的角色设定 |

## 许可证

本项目使用 [AGPL-3.0 License](LICENSE)。

字体 [Aber Mono](https://github.com/oliverdunk/Aber-Mono) 遵循 SIL Open Font License。
