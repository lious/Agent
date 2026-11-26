# 第一种官方标记侧车 `studio.markers.sidecar` v1

这是用户授权、由啾啾书面指定的**新准入**，不是原 104 份 `docs/studio` 规格快照里已有的枚举。本文是独立 addendum，**不回写、不改写**原规格快照（包括 `docs/studio/spec`、work-items 与 SHA256SUMS）。原规格仍把 Marker 写成核心工程文档的 `markers[]` 字段；s7 导出选项仍只有 `captions:burnIn|sidecarSrt`。本文件不把该侧车写进原 s7 枚举，也不把它做成 MP4 mux 选项。

文中曾误写「喵喵」，已更正为「啾啾」（U+557E）；这只是笔误修正，不是新授权。

本批只落地这一种官方标记侧车的导入/导出往返与不支持项告警 / 整文件拒绝政策。不宣称完整标记矩阵，不打开 WebVTT chapters / CSV / FCPXML，不宣称与它们兼容，不打开源字幕区间裁切、MP4/预览烧录、确定性 shaping 或任意 ASS 效果往返无损，也不改 I-005 逆操作主路径或核心工程 Schema。I-005 与 I-010 仍为部分完成。

## 格式合同

- 格式名称：`studio.markers.sidecar`
- 文件：UTF-8 JSON，**无 BOM**
- 推荐扩展名：`.studio-markers.json`
- 媒体类型：`application/json`

信封字段（仅此三项；`additionalProperties` 视为不支持）：

- `format`：固定为 `"studio.markers.sidecar"`
- `formatVersion`：本批写出 `"1.0.0"`。导入接受同一主版本的 `1.y.z`（仍不得有未知字段）；主版本不是 `1`、或不是 `major.minor.patch` 十进制形式，整文件拒绝。
- `markers`：数组，可空

`markers[]` 每一项严格按现有工程 Schema 的 Marker 对象往返，不得改核心工程 Schema，也不得改成浮点秒。`time` 仍是序列时间轴位置，与现有 `TimelineMarker` 一致。官方字段：

- `id`, `sequenceId`, `label`（0–1024，不含 NUL）
- `colorRGBA`：4 个 0–1 的数
- `anchor.kind`：只允许 `absolute` | `clipLocal`
- `anchor.clipId`：`absolute` 必须为 `null`；`clipLocal` 必须是已有镜头 Id
- `time`, `duration`：沿用现有有理数 Time JSON（`{n, d}`），不是浮点秒
- `ripple`：boolean

Marker 对象、`anchor` 与 Time 对象均 `additionalProperties` 为 false。

## 政策

- 导出必须写出选定范围（默认当前工程全部 markers）里的每一条标记，禁止静默丢弃。选定 id 在工程中不存在则拒绝，不得写出缺条的子集冒充完整选定范围。
- 导入必须恢复全部合法官方字段。缺 required 字段、非法值、重复 id、`format` 不是 `studio.markers.sidecar`、`formatVersion` 主版本不认识，整文件拒绝，不得部分导入。
- 未知额外字段：列出不支持项告警 `MARKER_SIDECAR_UNSUPPORTED`（含 JSON 路径），并拒绝该文件；禁止剥掉未知字段后当成完整成功。
- `clipLocal` 的 `clipId` 在目标工程中不存在，或不再覆盖该标记区间：拒绝，禁止悄悄改成 `absolute`。
- 目标工程没有对应 `sequenceId`：拒绝。
- 标记文字不得烧进预览或 MP4。不要改 s7 的 `captions:burnIn|sidecarSrt`。

建议错码（不改变已有错码含义）：

- `MARKER_SIDECAR_INVALID`：信封非法、BOM、错误 `format`、无法识别的主版本、选定 id 缺失等
- `MARKER_SIDECAR_UNSUPPORTED`：出现未知额外字段（同时列出告警并拒绝）
- `MARKER_INVALID`：标记官方字段缺失或非法（含超长 / 含 NUL 的 label、非法 `colorRGBA`）
- `DUPLICATE_ID`：重复标记 id
- `ANCHOR_INVALID`：`absolute` 带了 clipId，或 `clipLocal` 缺少 clipId
- `MARKER_ANCHOR_NOT_IMPLEMENTED`：`anchor.kind` 不是 `absolute` / `clipLocal`
- `PARENT_MISMATCH`：目标工程没有对应 `sequenceId`
- `ANCHOR_OUT_OF_RANGE`：`clipLocal` 宿主不存在或不再覆盖标记区间
- `TIME_ENCODING`：`time` / `duration` 不是官方有理数 Time JSON（包括浮点秒）

既有 JSON 严格读取错码（`JSON_SYNTAX` / `JSON_UTF8` / `JSON_DUPLICATE_KEY` / `DOCUMENT_LIMIT`）含义不变。
