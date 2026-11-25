## 1C · 许可事实不变，项目默认风险放行

| 对象 | 唯一执行合同 |
| --- | --- |
| 作用域 | 用户指定本项目商业模型及组件（含推理运行库、编解码/字体组件）的许可缺失、待核实、缺额外商用授权、非商业/地域/竞争/营收/登记/再分发限制，默认allow_with_warning。许可facts保持原样，继续执行不代表取得许可或免责。既有MIT/Apache等允许路径仍正常allow。 |
| 不覆盖 | 支付/预算/上传审批、供应商真实拒绝/鉴权、系统权限、用户数据与素材权利、肖像/声音/监护同意、模型签名/hash完整性、安全、Schema结构、能力/ABI不支持、资源不足与手动锁仍按原合同wait/block。不绕过工具或平台检查，不把HTTP403改叫许可warning后重试。 |
| Planner/发布 | licenseGap不参与catalog隐藏、候选剔除、下载/compile/submit/render/export/归档硬阻断；保留capability/资源/隐私/预算筛选。缺商业授权不会自动改用另一模型。允许生成/构建/打包，但不自动取得服务访问或商店审核通过；真实支付/上传/发布行动仍需各自授权。本次只改设计，无下载/部署/调用授权。 |
| UI | 同时显示“许可：受限/缺证据”和“本项目：允许执行（有许可风险，非已获授权）”。可展开条款/缺口/归因/证据，不要求逐次上传凭证或额外风险勾选才能继续。按钮仅因非许可硬门禁置灰，明确列独立原因；默认不是隐性needsReview排队。 |
| 审计/依赖 | 事实评估、策略版本、执行决定、warnings、非许可门禁、job/plan/revision分别记事件；不回写grantRef/verified。仅商业许可资料变化刷新warning/审计，不取消运行job、不丢候选、不触发付费重试；肖像/声音/隐私撤销仍即时失效/阻断。晚到/账单继续原流程。 |
| 审批/多App | 本项目可信策略默认allow_with_warning；缺旧策略记录时迁移显式填该值，不因缺许可资料退回block。仅许可策略/事实hash变更可出PolicyRebaseReceipt复用同费用/素材/输入/provider/prompt/revision/writeScope的原批准，原签名不改；任何实际范围变化仍重新审批。跨App不带密钥/预算批准，执行用目标App支持的同合同策略；未实现策略的旧App标不支持，不能伪称当前App已执行。 |
| 归档/资产 | 用户明确选择收集的模型/组件字节，不再仅因商业许可缺口排除；附未授权/受限事实、NOTICE和风险清单，禁止标“合法自包含”。默认referencesOnly仍是体积/可移植设计，不是许可禁用。缺字节、hash不符、危险路径、隐私或素材同意缺失仍阻断相应收集；用户源素材/肖像/voice不因本策略获共享权。 |

```text
// harness/license_fact_assessor.dart + project_execution_policy.dart
facts = LicenseComplianceGate.assessFacts(ctx); // 每个组件/操作真实事实，不签发不存在的grant
nonLicenseGates = runExistingBudgetPrivacyConsentIntegrityCapabilityResourceGates();
assessment = ProjectExecutionPolicy.evaluate(facts, nonLicenseGates);
// 任一非许可gate.state=deny→block；否则任一pending→wait（含资源等待/待同意）；
// 其他gate全通过：存在许可缺口→allow_with_warning；无许可缺口→allow。
// 旧LicenseDecision.block不能直接喂Run.failed：先按注册reason.category拆分。
// COMMERCIAL_LICENSE_REQUIRED / LICENSE_EVIDENCE_MISSING / YUE_COMMERCIAL_LICENSE_REQUIRED
// 映射许可warning；MODEL_ABI_UNVERIFIED / VOICE_RIGHTS_REVOKED / HTTP403等仍独立hard。
// provider因许可拒绝的事实仍providerRefusal，不绕其鉴权/另接口/另一账号。
// Unknown非许可失败不得按名字猜为licenseGap；保留原因并正确分类。
// licenseFactsVersion独立于privacy/portrait/voice/sourceConsentEpoch；仅商业许可变化不提升后者。
// 旧混合rightsEpoch必须按reason分类迁移，不能让商业许可warning通过旧epoch路径重新阻断。
// ModelPack旧License schema不变：commercialStatus=unknown/restricted如实填，grantRef=null；
// 证据缺失时evidenceUrl可指向本地MissingEvidenceRecord的urn:studio:missing-license:<id>，
// 该记录明确status=missing且无外部授权，不伪造官方许可证URL；licenseId可显式unknown。
// 无效文件/hash、坏签名、未知算子仍独立拒绝；不可用placeholder绕结构/完整性验证。
// audit events: license.facts_assessed → license.policy_applied → job.dispatch_decided。
// payload: policyRef/hash, factArtifactRef/hash, assessmentRef, planId, jobId|null,
// projectRevision, operation, warningCodes, independentGateRefs, timestamp；append-only。
// 本地许可缺口不额外弹审批；费用/上传/发布等原审批不可被policy替代。
// SQLite additive：复用artifact CAS + event/outbox存储，新增artifact kind
// studio.license-execution.v1；不改Project2.0闭合根/旧六块Schema/旧License商用事实enum。
// policy/facts/assessment可随“制作依据”导出；凭据/私密合同、已删除正文不导出。
// Legacy block混合license+capability时，许可转warning、capability保block，不能整条翻allow。
// 策略是文档设计；不表示已运行、已安装模型、获第三方许可或通过任何工具审批。
```

```text
// LICENSE_EXECUTION_SCHEMA_DATA_BEGIN
{"$schema":"https://json-schema.org/draft/2020-12/schema","$id":"urn:studio:license-execution:1.0.0","type":"object","additionalProperties":false,"required":["policy","assessment"],"properties":{"policy":{"$ref":"#/$defs/Policy"},"assessment":{"$ref":"#/$defs/Assessment"}},"$defs":{
"Id":{"type":"string","minLength":1,"maxLength":512},"Hash":{"type":"string","pattern":"^[a-f0-9]{64}$"},"U64":{"type":"string","pattern":"^(0|[1-9][0-9]*)$"},
"Policy":{"type":"object","additionalProperties":false,"required":["schemaVersion","id","projectId","version","mode","scope","authorizedBy"],"properties":{"schemaVersion":{"const":"1.0.0"},"id":{"$ref":"#/$defs/Id"},"projectId":{"$ref":"#/$defs/Id"},"version":{"$ref":"#/$defs/U64"},"mode":{"const":"allow_with_warning"},"scope":{"const":"commercialModelComponentLicense"},"authorizedBy":{"const":"pt69u"}}},
"Fact":{"type":"object","additionalProperties":false,"required":["id","componentId","operation","status","reasonCode","evidenceRefs","grantRef"],"properties":{"id":{"$ref":"#/$defs/Id"},"componentId":{"$ref":"#/$defs/Id"},"operation":{"enum":["C","H","D","T","Q","R","A","O"]},"status":{"enum":["allowed","conditional","restricted","unknown","missing","expired","revoked"]},"reasonCode":{"$ref":"#/$defs/Id"},"evidenceRefs":{"type":"array","items":{"$ref":"#/$defs/Id"},"uniqueItems":true},"grantRef":{"anyOf":[{"$ref":"#/$defs/Id"},{"type":"null"}]}}},
"Gate":{"type":"object","additionalProperties":false,"required":["id","category","state","reasonCode"],"properties":{"id":{"$ref":"#/$defs/Id"},"category":{"enum":["budgetApproval","uploadApproval","privacy","portraitConsent","voiceConsent","userAssetRights","authentication","providerRefusal","systemPermission","integrity","capability","resource","schemaValidation","security","manualLock"]},"state":{"enum":["pass","pending","deny"]},"reasonCode":{"$ref":"#/$defs/Id"}}},
"Assessment":{"type":"object","additionalProperties":false,"required":["id","policyRef","policyHash","projectRevision","facts","gates","decision","warningFactIds"],"properties":{"id":{"$ref":"#/$defs/Id"},"policyRef":{"$ref":"#/$defs/Id"},"policyHash":{"$ref":"#/$defs/Hash"},"projectRevision":{"$ref":"#/$defs/U64"},"facts":{"type":"array","items":{"$ref":"#/$defs/Fact"}},"gates":{"type":"array","items":{"$ref":"#/$defs/Gate"}},"decision":{"enum":["allow","allow_with_warning","wait","block"]},"warningFactIds":{"type":"array","items":{"$ref":"#/$defs/Id"},"uniqueItems":true}}}
}}
// LICENSE_EXECUTION_SCHEMA_DATA_END
```

Schema无隐式default；迁移器/构造器显式填mode。nullable仅grantRef；缺证据使用空数组和unknown/missing，不伪造链接。语义验证另查policyRef/hash/project一致、U64范围、ID唯一、warningFactIds恰对应所有非allowed事实以及按typed gates重算decision；JSON Schema不会证明授权真伪或自动完成这些关系。本轮测试和三轮审查归档 `[box-local audit path]`，不把设计oracle当真实运行或商业合法性证明。
