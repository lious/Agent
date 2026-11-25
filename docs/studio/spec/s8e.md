## 8E · Character Asset Library：跨项目角色形象、Look与模型绑定

Project.Character继续是工程内角色；CharacterAsset/CharacterPack成为独立不可变版本资产。身份设计、服装状态、参考图片、声线意图和模型适配分开，避免“改全局发型”让十集旧工程悄悄换人。资产库复用是用户授权的内容复用，不是跨App共享会话、相册权限或人物识别数据库。

| 完整字段域（8G给展开Schema） | 约束与可编辑边界 |
| --- | --- |
| CharacterAsset | id/version/name/kind(fictional或realPerson)、description、Traits、Voice、defaultLookId、portraitRightsId、tags。Traits有用户声明/虚构设计的ageMin/ageMax/ageBasis、身高体型姿态、眼形眼色/鼻/口/下颌/眉/耳/肤色描述、发型发色、distinctiveFeatures、doNotDrift。未知值显式null；不从照片猜年龄、种族或真实身份，不默认做生物识别/人脸检索。年龄范围由用户填，min≤max；未成年/真实肖像风险由安全与权利门禁另管。 |
| VoiceProfile | description/languages/registerIntent/accentIntent/speedIntent/sampleHashes/cloningAllowed/voiceRightsId/providerSpeakerIdRef。描述声线不等于已克隆；cloningAllowed必须有独立voice权利且目标模型能力真实支持，YuE2/SA不能因此获得不存在的参考说话人接口。样本音频是敏感来源，独立上传同意；导出默认不带。 |
| LookVariant / ReferenceView | Look字段era、wardrobe、hairOverride、makeup、stateDescription、referenceIds、forbiddenChanges；参考组role=front/left/right/back/threeQuarter/fullBody/expression/wardrobeDetail，带lookId、blobHash、expression、source、rightsId。三视图不是模型自动保证；缺侧面可标缺，不合成后冒充真实采集。生成补图是新Artifact，需用户认可后归入pack，不覆写原图。 |
| ModelAdapterBinding | kind=referenceImages/lora/featureEmbedding，providerProfileId、baseModelFamily/baseModelFingerprint、encoderFingerprint/embeddingLayout、adapterBlobHash、referenceRoles、strategy、preprocessorHash、parameterHash、trainingRightsId。LoRA/embedding需完整底模/编码器/预处理指纹匹配，不跨Wan/其他图像模型通用；未知cloud alias指纹不能直接加载LoRA。参考图只是软一致性；训练、下载/分发适配器均另需权利和资源审批，本轮不下载/训练。 |
| PortraitRightsRecord | subjectKind/holderRef/allowedUses(referenceGeneration、training、voiceClone、exportOutput、redistributePack、upload)、allowedProviderIds、territories、expiresAt、revocationAuthorityRef、evidenceHash、status、existingOutputsPolicy。虚构角色同样要核参考图/第三方IP；真人不能只勾fictional绕过肖像权。verified是经审核的授权证据状态，不是确认该人真实身份或法律无风险。 |

```text
// packages/studio_asset_library/{character_repository,character_resolver,rights_gate}.dart
CharacterRepository.createDraft(namespace)->CharacterDraft
CharacterRepository.publish(draft,expectedHeadVersion,rightsDecision)->CharacterPackRef
CharacterRepository.forkVersion(assetId,pinnedVersion)->CharacterDraft
CharacterRepository.exportPack(ref,selectedResources,rightsDecision)->ArchiveReceipt
CharacterRepository.importPack(fileToken,targetNamespace,collisionPolicy)->ImportPreview
ProjectCharacterResolver.resolve(ProjectCharacterRef,scope,liveRights)->ResolvedCharacter
CharacterUpgradePlanner.plan(oldPin,newPin,localOverrides,lockedPaths)->CharacterUpgradeProposal
CharacterPromptInjector.compile(resolvedCharacter,shot,providerCapability)->CharacterBindingPlan
PortraitRightsGate.evaluate(characterRef,operation,provider,region,now)->RightsDecision
PortraitRevocationCoordinator.revoke(rightsId,expectedEpoch)->RevocationReport

ResolvedCharacter {assetId,pinnedVersion,packHash,lookId,effectiveTraitHash,
 effectiveAppearanceText,selectedReferenceRefs:EntityRef[],voicePlanRef:null|Hash,
 appliedBindingId:null|Id,rightsDecisionRef,dependencySelectors:DependencyRef[]}
CharacterBindingPlan {promptSections:string[],providerImageInputs:Reference[],
 adapterLoadRefs:Hash[],warnings:string[],bindingHash}
// 自动注入的是本镜需要的有效外观、服装、动作与禁漂移约束，不是整个人物百科。
// provider只有一个first-frame槽：人物参考与产品首帧冲突→REFERENCE_SLOT_CONFLICT，
// 用户选已授权合成首帧/换已验证多参考profile/仅文字软约束；不得偷偷丢一方。
// IDENTITY_SOFT_CONSTRAINT提示概率身份一致，未通过看片不能标像素锁定。

Project.extensions["studio.character-library.v1"] = {
 schemaVersion:"1.0.0", refs:ProjectCharacterRef[], portablePackHashes:Hash[]
}
// ProjectCharacterRef完整Schema含pinnedVersion、packHash、lookId、有限字段overrides。
// 对应Project.Character的name/constraints/appearanceRef materialize到本工程；
// reference blob显式attach成工程Asset后再写appearanceRef，不引用外部库的裸Asset ID。
// core Character.version是工程实体版本，不等同外部pinnedVersion。
// 容器不新增Project根表；既有封闭Character字段保持不变。
```

| 操作/状态 | 事务、依赖与异常 |
| --- | --- |
| 资产库屏幕→新建/编辑/发布 | draft本地可反复改；publish校验引用闭包/权利/必要图、生成packHash→CAS更新library head。版本体只增不改，draft→published→deprecated；revoked属live AccessRecord，不改历史blob内容。失败RIGHTS_REQUIRED/RESOURCE_MISSING/BINDING_MISMATCH/HEAD_CONFLICT无半发布。改名是新版本或库显示别名，不篡改旧content hash。 |
| 项目@角色引用 | 输入@仅检索当前授权库，选择asset/version/look后生成ProjectCharacterRef，并显示锁定版本。会话存ref与选择器，不把整包图自动上传。镜头Compiler提取当前角色+Look约束；DP按实际参考覆盖检查正侧面/服装/主体一致，低置信给unknown或人工审片，不用embedding相似度替代法律身份。 |
| 全局升级与局部换装 | 默认pin不跟latest。库v2改发型不影响仍pin v1的项目；用户点升级才比较traits/look/binding/rights差异，逐项目/逐镜选择。局部overrides只允许wardrobe/era/stateDescription/hairStyle，身份五官或权利不可通过任意JSON Patch覆盖。升级时局部换装三方比较保留/冲突，不覆盖手剪/字幕。依赖绑定selectors，发型变化只失效用到该角色外观的prompt/候选判断，不使无人物产品镜头/OCR全重算。 |
| 撤销/过期 | 新生成/训练/参考上传在dispatch前都查live authority/epoch；pin只冻结内容，不冻结许可。收到撤销立即deny、清派生语义缓存/RAG/旧摘要可用引用、失效未提交计划；在跑任务请求取消、晚到隔离。已有成片按existingOutputsPolicy分别retainAllowed/blockUse/reviewRequired，不擅自删用户文件。离线设备不能获即时全网撤销：真人新云生成要求新鲜在线权利检查，离线lease过期阻断；已知撤销不能被恢复旧pack绕过。 |
| 跨集/跨项目/跨App | 共享底层CharacterRepository与格式，不共享授权默认值。P1跨App显式.export/.import；用户开启共享库后仅内容CAS与已授予libraryId可共用，各App各自namespace/grant/session/审批。引入时重建本地ID映射、校验pack hash与body schema，不继承源App审批。导出需redistributePack且逐选参考图/voice/adapter；默认模型/LoRA只存指纹引用，缺件不自动下载。 |
| 归档与GC | 角色包manifest列所有相对路径/hash/bytes/role/rights，固化Schema版本与签名声明；采用既有路径防穿越/大小限制/atomic写包协议。Project pins、导出pin和候选任务pin均为GC roots，删除库head不删被旧项目引用v1。只有零引用且不在保留/撤销清理计划内可回收；撤销先阻访问，物理GC可重试。 |

合成例：角色“岚”v1（短发、蓝外套）被第1集pin1和第2集pin1复用；第2集只override衣服为绿。库发布v2长发后，两集画面不变。用户仅升级第2集→new packHash，保绿衣override、仅其人物镜头PromptDraft stale；手工trim/字幕锁仍保留。真人授权随后撤销→所有已知引用这一rightsId的新生成阻断，v1也不例外；无人物镜头和独立产品音效不无谓失效，关联voice授权是否撤销按它自己的记录检查。
