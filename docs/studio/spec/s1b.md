## 1B · 模型商业矩阵、精确范围与原文证据

E/C/B/U是许可事实：原则允许/附条件/当前许可不涵盖/证据不全，不是planner启禁状态。C/H/D与T/Q/R/A/O逐操作独立。以下所有商业许可缺口按1C默认允许执行并显示风险，不改表内事实、不伪造授权；缺模型文件/真实hash完整性/ABI能力仍可独立阻断。不是已交付ModelPack。许可证据核查日期2026-11-24（Asia/Shanghai）。

| 精确版本/范围 | C / H / D | T / Q / R | A / O | 条件与本产品结论 |
| --- | --- | --- | --- | --- |
| Wan2.2 TI2V-5B、I2V-A14B、T2V-A14B官方 | E / E / C | C / C / C | C / E | 各官方模型卡Apache-2.0；D/T/Q/R须NOTICE/修改/第三方权利核验。自有GPU许可优先候选，不代表手机性能已验证。不把Wan2.6 API许可倒推其他权重，也不替换现有Wan2.6适配器。 |
| LTX-2.5 dev/distilled；LTX-2.x Community | C / C / C | C / C / C | C / C | 代码与权重分开。聚合年营收达到US$10m需额外商业许可；低于门槛仍有竞争条款。创作Studio可能直接竞争，本产品许可事实保留needsReview/竞争风险，执行默认allow_with_warning，不因该缺口过滤托管/分发；这不代表已获适用授权或可通过商店审核。 |
| FLUX.1-dev；NC License v1.1.1 | B / B / B | B / B / B | C / C | 当前NC权重授予不支持本产品商业运行/改造/分发；另获明确商业许可可逐项重评。§2(d)输出可商业使用不等于商业运行权重获准；合法获授权API输出独立核验。量化不绕过。 |
| Illustrious-xl-early-release-v0 / v0.1 | U / U / U | U / U / U | C / C | 官方研究定位、fair-public-ai/README/TERM_OF_USE须整体闭合；已见闭源微调/合并模型变现限制。许可链未闭合保留unknown，执行默认allow_with_warning；不是宣称已获授权，也不是宣称所有Illustrious输出禁商用。派生版本逐个核验。 |
| Tencent HunyuanVideo-1.5 | C / C / C | C / C / C | C / C | Tencent Community非Apache通用权重许可；Territory排除EU/UK/韩国，发布时MAU>100m另授权；再分发通知、AUP、服务身份披露须核验。个人低营收不解除地域等义务，不能据此承诺全球C端发行。 |
| SkyReels-V1，未选定具体权重 | U / U / U | U / U / U | C / U | 仓库自有部分Apache不覆盖所有Hunyuan派生限制；权重与上游链未冻结，不能按系列名启用。 |
| SkyReels-V2-T2V-14B-720P官方 | C / C / C | C / C / C | C / C | Skywork Community非系列统一Apache；商业/安全审核备案及完整条款须按目标地域/用途闭合，具体权重依赖未冻结。本轮不扩展承诺其他V2/V3。 |
| ACE-Step 1.5 official base/sft/turbo | E / E / C | C / C / C | C / E | 代码/权重MIT、卡明确商业输出；商业自托管音乐默认候选不变。变体能力不同，官方自托管API不等于可购买公共SaaS。输入音乐/声线授权另检。 |
| Stable Audio Open Small 341M | C / C / C | C / C / C | C / C | Community适用于individual或entity；商业登记、聚合营收、完整协议/NOTICE/Powered by及AUP；本App保守<US$1m，临界与未知review，超限需企业授权。最终用户例外不解除发行方义务。 |
| YuE2-3B + YuE2-Vae | C / B / B | U / C / B | C / C | 权重CC-BY-NC4.0+2026-09-16个人创作者附加许可；代码Apache-2.0。个人本人创作/接客户/卖输出可适用例外；面向用户的商业App托管与商业权重再分发授权不从此推导；缺凭证保留restricted/missing事实，执行默认allow_with_warning。Q仅个人创作所需转换逐项核验；训练/派生不凭想象放开。 |
| Kokoro-82M v1.0 / CosyVoice2-0.5B / OpenVoiceV2 | E / E / C | C / C / C | C / E | 依次Apache-2.0/Apache-2.0/MIT；voice rights及依赖/字典/phonemizer单查。Kokoro权重Apache不覆盖eSpeak GPL；GPL可商用但闭源App分发需履约/合规前端。CosyVoice3不自动继承2的证据。 |
| F5-TTS预训练，含F5TTS_v1_Base | B / B / B | B / B / B | C / C | 代码MIT而预训练CC-BY-NC；商业需另授权或合法自训并验全链。OpenVoice可商用不使串接F5预训练变成可商用。 |
| Qwen3-1.7B / Whisper base / SAM2.1 tiny / BiRefNet official | E / E / C | C / C / C | C / E | 依次Apache-2.0/MIT/Apache-2.0/MIT；第三方转换包另验。许可E不证明qwen_image_edit_2511_q6p iPhone离线已跑，也不证明所有语义提示/追踪模式支持。 |
| Demucs htdemucs / RNNoise / DeepFilterNet / Real-ESRGAN_x4plus | E / E / C | C / C / C | C / E | 沿8O/8R/8T代码+权重范围与依赖：MIT、BSD-3、MIT/Apache、BSD-3。UVR/BS-RoFormer第三方权重、SCUNet、ncnn各查，不继承工具仓许可。 |
| LaMa big checkpoint / 未核实声库或转换包 | U / U / U | U / U / U | C / U | 代码Apache不自动证明选中LaMa checkpoint范围；Piper当前GPL-3与每个voice分别核验，未选声库unknown；本地不等于非商业。 |
| ProPainter / E2FGVI官方 / AnimeGANv2受限配置 | B / B / B | B / B / B | C / C | 按8O已核实非商业/受限许可；可凭另授商业许可按范围重评。逐帧LaMa不能冒充已实现时序补全。API授权事实另评，缺许可默认风险放行；供应商真实拒绝/鉴权失败或接口能力不存在仍不可执行。 |

| 原文证据 | 适用边界与官方链接 |
| --- | --- |
| Wan：license: apache-2.0 | https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B ；https://huggingface.co/Wan-AI/Wan2.2-I2V-A14B ；https://huggingface.co/Wan-AI/Wan2.2-T2V-A14B ；不覆盖任意第三方merge。 |
| LTX §2.1；Attachment A item20 | “directly competes with Licensor’s commercial products or services” / “without obtaining a separate commercial license”；https://raw.githubusercontent.com/Lightricks/LTX-2/main/LICENSE-2_x （2026-08-11，amended 2026-11-11）；https://huggingface.co/Lightricks/LTX-2.5 。本App竞争归类待审，不把<10m当无条件商用。 |
| FLUX §2(a)(b)(d) | “non-commercial purposes only”；“You may use Outputs for any purpose (including for commercial purposes)”与运行限制分读；https://huggingface.co/black-forest-labs/FLUX.1-dev/blob/main/LICENSE.md 。不是API订购合同。 |
| Illustrious官方证据范围 | https://huggingface.co/OnomaAIResearch/Illustrious-xl-early-release-v0 ；https://huggingface.co/OnomaAIResearch/Illustrious-xl-early-release-v0/blob/main/TERM_OF_USE 。统一许可证据不全保unknown，不用排行榜补许可。 |
| Hunyuan与SkyReels | https://huggingface.co/tencent/HunyuanVideo-1.5/blob/main/LICENSE ；https://raw.githubusercontent.com/SkyworkAI/SkyReels-V1/main/LICENSE.txt ；https://huggingface.co/Skywork/SkyReels-V2-T2V-14B-720P/blob/main/LICENSE 。型号/上游/地区是授权输入。 |
| YuE2个人附加许可 | “personal users, content creators and musicians acting in an individual capacity”；“does not extend to commercial redistribution or sale of model weights”；https://raw.githubusercontent.com/multimodal-art-projection/YuE/main/MODEL_LICENSE 。不抹掉个人商业输出权，也不推导托管运营权。 |
| ACE / Stability | https://huggingface.co/ACE-Step/Ace-Step1.5 ；https://github.com/ace-step/ACE-Step-1.5 ；https://huggingface.co/stabilityai/stable-audio-open-small/blob/main/LICENSE 。Stability明确“any individual person or entity”、商业产品/service/API、登记与营收。 |
| 声音许可 | https://huggingface.co/hexgrad/Kokoro-82M ；https://huggingface.co/FunAudioLLM/CosyVoice2-0.5B ；https://huggingface.co/myshell-ai/OpenVoiceV2 （“Free for commercial use”）；https://raw.githubusercontent.com/SWivid/F5-TTS/main/README.md （code MIT / pre-trained CC-BY-NC）；https://github.com/OHF-Voice/piper1-gpl 。模型与参考人声许可分开。 |
| 本地模型补证 | https://huggingface.co/Qwen/Qwen3-1.7B ；https://github.com/openai/whisper#license ；https://github.com/facebookresearch/sam2#license ；https://huggingface.co/ZhengPeng7/BiRefNet 。其余具体证据完整保留8O—8U/13—14，不以此表删减。 |

这是许可事实记录与项目执行策略，不是法律意见。构建完整性仍固定sourceRevision、文件SHA256与依赖SBOM；许可条款/主体/地域/有效期缺口记风险清单，不再因未审定商业许可禁止项目执行/打包。带风险产物不能标“已获授权/已通过商店审核”。API条款/竞争归类/商业报价未核实不编造；不购买、不代联系，真实服务拒绝与商店决定不受本策略控制。
