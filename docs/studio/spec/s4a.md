## 4A · 私人图形资产与可编辑模板：补足跨项目复用

角色库不能代替一般图形素材库。图片/贴纸/边框/背景/图标复用GraphicAsset；用户作品仍是完整ImageDocument，不把Studio缩成贴纸产品。新图形库与模板是独立graphics-library/1.0.0文档，Project/Command/Manifest 2.0不增根字段。下列持久字段全部required、对象闭合、可空显式null；ID/Hash/U64/Namespace/Rights/Layer沿现有类型，所有引用与许可另作语义验证。

```text
GraphicAsset {schemaVersion:"1.0.0",id,version:U64,namespace,name:Text256,
 kind:sticker|background|frame|texture|illustration,
 sourceAssetRef:EntityRef,sourceGeometryHash:Hash,maskArtifactHash:Hash|null,
 editableDocumentRef:EntityRef|null,previewBlobHash:Hash,thumbnailBlobHash:Hash,
 width:uint[1..32768],height:uint[1..32768],colorPolicyRef:Id,alpha:none|straight,
 tags:Text128[0..128],rightsId:Id,dependencyBlobHashes:Hash[0..10000]}
TemplatePack {schemaVersion:"1.0.0",id,version:SemVer,namespace,name:Text256,
 canvas:{width:uint[2..8192],height:uint[2..8192]},imageDocumentHash:Hash,
 slots:TemplateSlot[1..128],graphicPins:GraphicPin[0..256],fontRefs:Id[0..128],
 rightsIds:Id[1..256],dependencyBlobHashes:Hash[0..10000]}
GraphicPin {id,version:U64,hash:Hash}
TemplateSlot {id,layerId,kind:image|graphic|text,required:bool,
 allowedMime:Text128[0..16],fit:contain|cover|none,safeRect:[number,number,number,number],
 defaultText:Text4096|null,defaultGraphicPin:GraphicPin|null,editablePaths:JsonPointer[1..64]}
TemplateInstance {schemaVersion:"1.0.0",id,namespace,templatePin:{id,version:SemVer,hash:Hash},
 projectId,imageDocumentId,imageDocumentVersion:U64,
 bindings:{slotId,assetRef:EntityRef|null,text:Text4096|null,graphicPin:GraphicPin|null}[],
 generatedLayerIds:Id[],manualPaths:JsonPointer[],overrideHash:Hash}
// slot.kind恰好选择一种binding；required槽未填只可草稿，交付阻断。
// 所有version/pin必须>=1；name trim后1..256字符；Text128标签非空、casefold去重。
// bindings/generatedLayerIds/slots分别唯一且一一对应；manualPaths只能指现存可编辑字段。
// modules/graphics/graphic_repository.dart、template_service.dart、template_validator.dart
// 负责这些语义校验，store/graphics_library.sql不改变任何2.0 Project schema。
// 4B小洞Telea/NS的输入mask/ROI/颜色/撤销沿8P ImageInpaintPipeline，不新增同名假AI算子。
// safeRect位于模板画布内；layerId存在且类型相符；每slot/binding ID唯一。
// imageDocumentHash是冻结的完整可解析图像文档依赖，不执行包内代码/远程模板。
GraphicRepository.publish(draft,expectedHead,rightsEpoch)->GraphicPin
GraphicRepository.search(namespace,tags,text,cursor)->Page<GraphicPin>
GraphicRepository.renameOrRefine(pin,changes,expectedHead)->NewPin
TemplateService.instantiate(packPin,bindings,targetProject,R)->PreviewProposal
TemplateService.rebind(instanceId,slotId,newValue,R)->PreviewProposal
TemplateService.upgrade(instanceId,newPackPin,threeWayBase,R)->ConflictDiff
GraphicRetention.planDelete(id,version,scope)->ReferenceImpact
// 发布新版本不改变旧项目pin；重命名不用文件名作ID；删除head不删被引用版本。
// 生成的PNG只是衍生预览/导出，编辑源保留source+mask或ImageDocument。
// instantiate派生稳定新Layer IDs，明确槽→Layer映射；替图只改槽允许字段，
// 保留独立文字/装饰/人工transform；升级三方比较base/local/new，冲突逐项确认。
// 全部accept编译为既有attachArtifacts+setImageDocument的batch，一次Undo。

```

| 工作流/存储 | 规则与验收 |
| --- | --- |
| 库界面 | 创建/改名/标签/分类/搜索/再次修边/导出/移入回收站；名称空/超长拒绝，标签去重；FTS先namespace/ACL过滤。真人素材沿PortraitRights，普通素材沿Rights；选用不代表可公开再分发。 |
| 模板示例 | 原创photo-card、paper-collage、brand-card三族可作首批设计样例，不是必须先完成贴纸产品。尺寸自由受画布合同约束；1:1、4:5、9:16仅快捷预设。所有文字独立Layer；不从热点网站复制纹理、IP角色或音乐。 |
| 工程与共享 | 扩展studio.graphics-library.v1存所用pack/pin/instance的manifestHash；ReferenceWalker枚举源/Mask/字体/模板闭包，允许再分发才嵌入。未知模板元数据不影响已物化图层渲染，但禁升级/重绑；旧App另存提示可能丢规划，保原包。 |
| 错误 | GRAPHIC_IN_USE列项目/历史pin；SLOT_TYPE/RIGHTS_REQUIRED/MISSING_FONT/TEMPLATE_VERSION_CONFLICT/LOCKED_FIELD拒绝整批。不修改相册原件；清理缓存不删图形库；导出JPEG先说明底色，PNG按straight alpha写出并保ICC。 |
| 断言 | 同Graphic@1在P/Q引用；发布@2后P/Q仍@1；仅Q明确升级。替照片后文字内容、Layer ID、装饰与手改transform不变；删除库head后P仍可打开；无授权素材不能打入共享模板。均为待生产实现的验收合同。 |

```text
-- additive graphics-library/1，私有库而非可移植Project新增表。
INSERT INTO workspace_features VALUES('graphics_library','1.0.0','graphics-library/1');
CREATE TABLE graphic_versions(ns TEXT NOT NULL,kind TEXT NOT NULL CHECK(kind IN ('graphic','template')),
 id TEXT NOT NULL,version TEXT NOT NULL,body_hash TEXT NOT NULL,
 PRIMARY KEY(ns,kind,id,version));
CREATE TRIGGER graphic_version_no_update BEFORE UPDATE ON graphic_versions
 BEGIN SELECT RAISE(ABORT,'IMMUTABLE_GRAPHIC_VERSION'); END;
CREATE TRIGGER graphic_version_no_replace BEFORE INSERT ON graphic_versions
 WHEN EXISTS(SELECT 1 FROM graphic_versions WHERE ns=NEW.ns AND kind=NEW.kind AND id=NEW.id AND version=NEW.version)
 BEGIN SELECT RAISE(ABORT,'IMMUTABLE_GRAPHIC_VERSION'); END;
CREATE TABLE graphic_heads(ns TEXT NOT NULL,kind TEXT NOT NULL,id TEXT NOT NULL,version TEXT NOT NULL,
 PRIMARY KEY(ns,kind,id),FOREIGN KEY(ns,kind,id,version) REFERENCES graphic_versions(ns,kind,id,version));
-- project pins沿blob_edges/扩展清单，不另存可变模板内容。移除版本必须先证明无pin/历史可达引用，
-- 删除元数据仅RetentionService；普通Agent无SQL入口。数字版本比较不按TEXT字典序。

```
