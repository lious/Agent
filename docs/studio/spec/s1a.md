## 1A · 个人商业用途：逐操作而非个人标签授权

| 合同 | 当前有效规则 |
| --- | --- |
| 适用主体 | 本产品开发者是个人商业经营者。为客户制作收费内容、App内购、广告变现、订阅、付费API、内部商业生产均须评估；免费获客也不能自动视为非商业。用户本人创作权利与运营方权利分别评估。 |
| 状态 | enabled/conditional/blocked/unknown仅表示授权事实评估：原则许可/附条件/当前授予不涵盖/证据不全。它们不是执行开关；后三者及missing/expired/revoked在本项目执行层默认allow_with_warning。已知非商用、地域、营收、竞争限制如实展示，不伪造grant。能力/安全/隐私/预算等独立门禁仍生效。 |
| 操作 | C商业生产成片；H商业托管/API代跑权重；D随App分发权重；T训练LoRA/适配器；Q量化/格式转换；R分发派生权重；A调用获授权第三方API并集成C端；O输出商用。C允许不推出H/D，A不推出自托管，O不反向授权违规运行权重。 |
| 共同义务 | 代码、权重、VAE、tokenizer、phonemizer、声库、训练数据和参考素材逐项SBOM/权利核验；保许可证/NOTICE/修改说明/归因/AUP。量化、LoRA、合并、改名不洗掉上游条件。输出不保证独占/可版权/不侵权；模型名称不替代文件hash。 |
| 分发/API | D/R需核验App商店条款、链接/源代码义务与权重再分发是否相容；用户主动下载不自动免除发行方责任。A须验证具体vendor/offer/model/revision/地区/输出/转售与嵌入C端权限，不因有API就推断获得自托管权利；本轮没有接入/调用服务。 |
| 多App/归档 | 可信AppProfile商业角色不可被LLM/外部Skill/“个人模式”降级；授权按App/租户隔离。工程仅存许可ID、条款hash、公开义务与可分发清单，不带密钥/合同私密正文。未选择收集或物理缺失的权重列引用/缺失清单；商业再分发许可缺口按1C仅提示，不剔除用户选定收集的字节。跨App按目标主体/地区/操作重检。 |

```text
// contracts/commercial_use_v1.dart；harness/license_compliance_gate.dart
CommercialUseContext {
 schemaVersion:"1.0.0", licenseeId:Id, legalType:individual|soleProprietor|company|institution,
 operatorRole:contentCreator|appPublisher|serviceOperator, commercial:true,
 servesThirdPartyInference:bool, operation:C|H|D|T|Q|R|A|O,
 // true=允许第三方触发/消费所托管权重的推理；不是指个人替客户制作成片。
 // 个人接商业客户制作输出可适用creator许可；开放App代跑推理仍属H。
 deployment:phoneLocal|ownGpu|ownedServer|thirdPartyApi,
 modelPin:{profileId,sourceRevision,weightHashes:Hash[],codeRevision,termsHashes:Hash[]},
 territories:ISORegion[], aggregateRevenueUSD:null|DecimalString,
 competesWithLicensor:null|bool, noticeProofRefs:Id[], rightsRefs:Id[],
 registrationProofRef:null|Id, scopedGrantRefs:Id[], apiOfferProofRef:null|Id,
 evaluatedAt:Timestamp, policyVersion:SemVer, rightsEpoch:UInt64String
}
// 全字段required；仅显式null可空；additionalProperties:false；Id非空、金额>=0。
// 地域不能为空；营收按许可证affiliate范围聚合；未知不能当0；competes未知不能当false。
// 经营角色由可信配置签发，不允许请求自己选个人豁免。旧8D ctx只是适配层，不能单独allow。
LicenseComplianceGate.assessFacts(legacyCtx, ctx):LicenseDecision
  resolveAvailableTermsAndComponents(ctx.modelPin); // 许可资料缺失归missing/unknown，不抛执行阻断
  evaluateEachOperationAndRegion(ctx); validateAvailableGrantScopes(ctx);
  return existingFactDecision(allow|block|needsReview,termsHashes,obligations,contextHash);
// 此block/needsReview只说明许可事实；没有资料不捏造许可、verified或grantRef。
ProjectExecutionPolicy.evaluate(facts,typedNonLicenseGates):LicenseExecutionAssessment // 1C
// 商业许可资料/登记/额外授权/NOTICE/地域/竞品等缺口→warnings，默认allow_with_warning。
// 输入素材权利、肖像/声音同意、隐私/系统权限、费用/上传、完整性/能力/资源等仍独立检查。
// LICENSE_OPERATION_UNVERIFIED / LICENSE_SCOPE_MISMATCH / LICENSE_COMPETITION_REVIEW /
// LICENSE_REGION_RESTRICTED / LICENSE_REVENUE_REVIEW / LICENSE_OBLIGATION_MISSING仅许可warning codes。
// 复用8D证据记录；下载/submit/发行/归档/输出均记录事实+执行决定，不能把warning当供应商鉴权。
// 仅商业许可事实/政策变更可签PolicyRebaseReceipt关联同范围原批准，不改原批准hash；
// 实际费用/输入/provider/prompt/上传/隐私/肖像声音/revision/writeScope变化仍按原合同重批。
// 旧context缺许可字段由可信适配器显式归unknown；不以缺证据另名硬阻断。
// SQLite additive：policy/shotPlan作为版本化CAS artifact，复用现有artifact/job引用。
// Project2.0.0闭合根Schema不变；使用既有扩展/工件引用合同，旧端未知时只读呈现。
// 不向additionalProperties:false对象塞新字段；授权私密证明不进入可移植工程包。
```
