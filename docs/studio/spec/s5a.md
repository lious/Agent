## 5A · Schema语义、命令结果与归档闭合

本节及完整2.0.0 Schema是持久化合同的唯一精确定义；前文的类写法/操作签名是语义说明，按本合同补足新增字段。Clip没有speed字段，速度只存在TimeMap；Caption存在根captions表，caption Track.items必须为空；所有数组即使空也显式输出。新增字段不靠JSON Schema的default自动补齐。

| 阶段/Owner | 输入→输出；失败与可编辑性 |
| --- | --- |
| P0 StrictJsonReader | 限制文本快照32MiB、递归深度64、单字符串按schema再收紧，拒绝重复key、NaN/Infinity、无效UTF8、非JSON类型。压缩包总上限按设备剩余空间/用户确认另算，不把32MiB文本上限当媒体包上限。路径用分段校验，拒绝绝对路径、空段、点/点点、反斜线、编码后穿越与symlink。 |
| P1 StructuralValidator | 先识别manifest版本→选择本地固定schema→Draft202012+format断言验证。required是必须出现，nullable必须明确null；default仅文档/表单注解，不修改实例。全闭合object；只有namespaced extensions、供应商parameters开放为受限JSON数据，绝不执行脚本。未知核心字段不先删掉再验证。 |
| P2 DocumentValidator | 纯函数建立ID索引/源版本索引、范围索引与DAG，执行下面业务规则，返回ValidationIssue{phase,code,path,entityIds,severity,repairOptions}。结构正确≠引用正确，schema不能证明轨道不相交、hash真实或权限有效。 |
| P3 ResourceResolver | 检查Blob文件hash/size/实际mime、字体hash、外链权限、frozen source定义文件；区分缺资源和坏文档。缺媒体仍可只读结构/编辑不依赖该源的项，最终交付须解决或显式代理导出；坏hash隔离。 |
| P4 Capability/Policy | requiredFeatures、effect/plugin版本、模型/provider配置、宿主AppProfile能力取交集；未知必需能力默认只读原样保留。上传/付费/删除批准始终重新检查，旧文档字段不能授权。P0—P4全部执行并分类后才能进入Workspace；结构/引用破坏性错误拒绝编辑，资源缺失可进入明确受限编辑状态，能力未知则只读。不是要求所有资源均存在才能改一个无关字幕。 |

| 跨字段/引用规则（非JSON Schema自动完成） | 确定性规则与错误 |
| --- | --- |
| ID与版本 | 同一namespace内当前实体ID全局唯一；Blob以hash唯一，ModelRef以profileId唯一。rootSequenceId必须解析。Clip source按(kind,id,version)解析，绝不自动latest；当前表只有当前版本，旧版本只能从retainedSources解析。Effect.owner/Track.parent/双向group成员必须一致；外键失联报REF_NOT_FOUND/PARENT_MISMATCH。speakerId是项目内分组标签而非缺失的speaker实体外键。 |
| 冻结版本/嵌套 | retainedSources.definitionBlobHash指向完整2.0 ProjectDocument快照，不是丢了效果/字体的孤立Sequence对象；装载并校验其全部定义后取指定(kind,id,version)，dependencyBlobHashes为闭包pin。沿source图验证无环、深度≤8；hash不符隔离，缺定义为SOURCE_VERSION_MISSING，只读不追随新版本。 |
| 时间/区间 | Time.n及所有U64编码值转换BigInt后限定有符号I64可存范围；U64在本合同是非负I64子域，不是数据库unsigned64。Time要gcd=1且零为0/1；timeBase/pixelAspect/rate>0。Clip/Gap/Caption/SourceRange duration>0；Sequence/点marker duration可0；offset允许负。视频边界落帧格，音频独立边界落sample格；拒绝静默二次量化。 |
| 同轨/总长/映射 | 每轨items按start排序、同轨不相交、ID/parent正确；内部缺口需显式Gap，尾Gap只在用户显式保留时存在，caption轨不补Gap。Sequence.duration=max所有A/V item与本序列caption end)，空序列为0。TimeMap线性rate×timelineDuration=sourceDuration；分段首尾一致且u/v严格递增，source在available范围；静态图/图片文档使用合成静态域。 |
| 转场/音频/关键帧 | Transition两侧邻接、cut匹配、p/q≥0且和>0、窗口不重叠、handles充分或显式freeze。bus路由DAG仅master到设备。keyframe.param必须是该effect的可动画数字参数，维度/范围符合参数schema，同param/localTime唯一；关键帧落owner局部域。颜色RGBA、crop左右上下、字体style owner还需语义校验。 |
| 故事板/候选/溯源 | Script.sceneIds、Scene.shotIds与各自parent双向一致，order唯一；独立Shot.sceneId允许null。candidateIds与outputAssetRefs等长且按索引一一对应；Clip.candidateId须属于其provenance，assetRef须对应。已知promptText时promptHash=SHA256(JCS({negative:negativePrompt,text:promptText}))；历史未知时promptText=null并提示不可复现，不伪造正文。 |
| 资源引用与非外键 | rights/font/effect/blob/source refs必须能解析或进入明确missing资源状态；ModelRef.profileId/provider/jobId/consentId/externalLocator是外部目录或本机审计标识，不假装在项目表中有对应完整对象。无目录只显示失效，不从ID取凭据、不自动重启job。所有EntityRef按使用位置限定kind，精确解析id/version；media类旧版本通过retainedSources，Character/Brief/Script/Scene/Shot等非media引用首版只允许当前定义，更新时必须同一预览事务重写其依赖引用，锁定依赖则拒绝，不把找不到旧版本当latest。Font.licenseRef=null或embedAllowed=false保持许可事实，用户选定收集时按1C允许并附风险提示；defaultFontRef为空且有文本时提示MISSING_FONT，不用系统默认字体偷偷通过最终导出。 |
| 扩展/安全 | 未知vendor effect可结构保留，但不能通过parameters任意字段取得执行能力；其feature必须列requiredFeatures。扩展JSON禁止运行代码，禁止本机路径/secret进入归档；插件只能来自宿主已安装受信注册表。快照hash用RFC8785 JCS；文本不擅自Unicode normalize，负零写0。实际资源内容hash始终按原始bytes。 |

版本归属必须可编码：schema中自带version的Sequence/Clip/Asset/Effect/Transition/Caption/ImageDocument/Brief/Character/Script/Scene/Shot才进入entity_versions；EntityRef、Source、RetainedSource中的version是引用而不是新实体。Track/Gap由所在Sequence版本负责，Layer由ImageDocument负责，Keyframe由Effect负责，Stream由Asset负责；根级AudioBus/Marker/Rights/LinkGroup/SelectionGroup/Font/GenerationRecord等无独立version的对象，用projectId+Project.revision作为readSet所有者，fieldPaths精确指向其根表项。不得给Gap虚构version=1塞入逆补丁。readSet.entityId只能是有版本实体或projectId；不允许无版本对象ID伪装版本时钟。changedEntities同样只记这些版本所有者，具体新增/删除Gap由before/after快照还原。

domain/revision_planner.dart::RevisionPlanner.plan在提交前计算定义闭包：一个命令对同一被改实体只分配一个新版本，Sequence内Track/Gap/Clip改动同时提升Sequence版本；Effect/Caption/Font/Bus等影响某序列渲染的改动也提升该序列定义版本。definitionContentHash不是整份Project快照hash，而是实体canonical数据加实际渲染依赖的已解析版本/无版本依赖canonical hash（排序；排除parent反向边和无关项目标题）。同(id,version)异定义hash拒绝IMMUTABLE_VERSION_CONFLICT。Nest/ImageDocument源引用是冻结的，不自动追随；修改仍被引用的旧定义前先写完整retainedSources快照及Blob pin，旧source继续指向旧版，只有upgradeNest/显式换源才跟随新版。因此保存的完整快照可带无关字段，而定义一致性不被无关标题改动误判。

Effect owner允许audioBus，AudioBus.effectIds中的效果必须反向指向该bus；否则master limiter在schema内无法表达。Clip/ImageLayer效果由effectIds连接，Caption样式由styleEffectId连接；Track/Sequence效果从根effects按owner过滤。P1使用固定EffectRegistry stage顺序（mask/crop→transform→color→opacity；音频gain→pan→limiter），同owner同type最多一个，effectIds须匹配该顺序，setEffect只更新现有槽或插入注册槽，重复槽报EFFECT_SLOT_CONFLICT；不暗示已支持任意效果链拖排。未知vendor插件没有受信stage合同就只读。effect/owner/反向引用都在业务校验，JSON Schema不会检查这些关系。

构造默认值：新对象由EntityFactory显式填充；enabled=true，locked/muted/solo=false，syncLock=true，targeted=false，空集合=[]，可空关系=null，原生参数按schema.default（如opacity=1、gainDb=0）写出。没有default的必填字段必须由调用方给出；不能猜source、rights、codec、revision或用户批准。打开缺字段的2.0文件直接报SCHEMA_REQUIRED，不按新建默认值修复；只有版本化迁移函数可补旧版本字段并产生报告。

跨端数值：Dart/JS用BigInt处理I64字符串，C ABI传int64_t与uint32 denominator；Swift Int64/Kotlin Long/Windows int64从十进制严格parse，任何JS Number中转失败。GPU不接收I64时间，只接当前frame已算好的Float32参数。关键帧先以有理数算α=(t-t0)/(t1-t0)，最后一次转Float64做v0+(v1-v0)α，逐分量插值，不逐帧累加；hold在[t0,t1)取v0，恰好t1取v1。布尔/字符串/枚举参数不允许伪装线性插值。CPU参考保Float64，GPU降Float32仅渲染，不能回写文档；golden容差与编码误差分开记录。

统一CommandResult及内部InversePatch（InversePatch在本schema.$defs中；不属于LLM可提交Operation）。每个改变文档内容的成功命令只增一次Project.revision，同事务保存receipt/result/event；失败无revision。disposition=applied要求revision=previousRevision+1且inversePatchRef非null。相同内容set或同hash的locator修复返回noDocumentChange：revision=previousRevision、beforeImageRef=afterImageRef、inversePatchRef=null、invalidatedRanges=[]、eventSeq仍为文档流原尾；只登记幂等receipt/资源修复审计，不伪造commands/revisions行。跨字段等式由结果业务校验检查，不冒称schema能比较两个字段。输入命令的newFileToken等是运行期能力，归档不导出可执行命令body。

```text
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "disposition",
    "commandId",
    "previousRevision",
    "revision",
    "eventSeq",
    "beforeImageRef",
    "afterImageRef",
    "inversePatchRef",
    "invalidatedRanges",
    "warnings"
  ],
  "properties": {
    "disposition": {
      "enum": [
        "applied",
        "noDocumentChange"
      ]
    },
    "commandId": {
      "$ref": "#/$defs/Id"
    },
    "previousRevision": {
      "$ref": "#/$defs/U64"
    },
    "revision": {
      "$ref": "#/$defs/U64"
    },
    "eventSeq": {
      "$ref": "#/$defs/U64"
    },
    "beforeImageRef": {
      "$ref": "#/$defs/Hash"
    },
    "afterImageRef": {
      "$ref": "#/$defs/Hash"
    },
    "inversePatchRef": {
      "anyOf": [
        {
          "$ref": "#/$defs/Hash"
        },
        {
          "type": "null"
        }
      ]
    },
    "invalidatedRanges": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "sequenceId",
          "range"
        ],
        "properties": {
          "sequenceId": {
            "$ref": "#/$defs/Id"
          },
          "range": {
            "$ref": "#/$defs/Range"
          }
        }
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "warnings": {
      "type": "array",
      "items": {
        "type": "string",
        "minLength": 0,
        "maxLength": 1024
      },
      "minItems": 0,
      "maxItems": 100000
    }
  },
  "allOf": [
    {
      "if": {
        "properties": {
          "disposition": {
            "const": "applied"
          }
        }
      },
      "then": {
        "properties": {
          "inversePatchRef": {
            "$ref": "#/$defs/Hash"
          }
        }
      },
      "else": {
        "properties": {
          "inversePatchRef": {
            "type": "null"
          },
          "invalidatedRanges": {
            "maxItems": 0
          }
        }
      }
    }
  ],
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "urn:studio:command-result:2.0.0",
  "$defs": {
    "Id": {
      "type": "string",
      "pattern": "^[A-Za-z0-9][A-Za-z0-9._:@-]{0,127}$"
    },
    "Text": {
      "type": "string",
      "minLength": 0,
      "maxLength": 4096
    },
    "I64": {
      "type": "string",
      "pattern": "^(0|-[1-9][0-9]{0,18}|[1-9][0-9]{0,18})$"
    },
    "U64": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,18})$"
    },
    "Hash": {
      "type": "string",
      "pattern": "^sha256:[0-9a-f]{64}$"
    },
    "Time": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "n",
        "d"
      ],
      "properties": {
        "n": {
          "$ref": "#/$defs/I64"
        },
        "d": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000000000
        }
      }
    },
    "Range": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "start",
        "duration"
      ],
      "properties": {
        "start": {
          "$ref": "#/$defs/Time"
        },
        "duration": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "Rate": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "n",
        "d"
      ],
      "properties": {
        "n": {
          "type": "integer",
          "minimum": 1,
          "maximum": 240000
        },
        "d": {
          "type": "integer",
          "minimum": 1,
          "maximum": 100000
        }
      }
    },
    "Timestamp": {
      "type": "string",
      "format": "date-time",
      "pattern": "Z$"
    },
    "Version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "Namespace": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "appId",
        "tenantId",
        "workspaceId"
      ],
      "properties": {
        "appId": {
          "$ref": "#/$defs/Id"
        },
        "tenantId": {
          "$ref": "#/$defs/Id"
        },
        "workspaceId": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Extensions": {
      "type": "object",
      "propertyNames": {
        "pattern": "^[a-z][a-z0-9_.-]{1,127}$"
      },
      "additionalProperties": true,
      "maxProperties": 64
    },
    "EntityRef": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "Source": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "kind",
        "id",
        "version",
        "streamId"
      ],
      "properties": {
        "kind": {
          "enum": [
            "asset",
            "sequence",
            "imageDocument"
          ]
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "streamId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Color": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "primaries",
        "transfer",
        "matrix",
        "range",
        "bitDepth",
        "alpha"
      ],
      "properties": {
        "primaries": {
          "type": "string",
          "minLength": 1,
          "maxLength": 64
        },
        "transfer": {
          "type": "string",
          "minLength": 1,
          "maxLength": 64
        },
        "matrix": {
          "type": "string",
          "minLength": 1,
          "maxLength": 64
        },
        "range": {
          "enum": [
            "full",
            "limited",
            "unspecified"
          ]
        },
        "bitDepth": {
          "type": "integer",
          "minimum": 1,
          "maximum": 32
        },
        "alpha": {
          "enum": [
            "none",
            "straight",
            "premultiplied"
          ]
        }
      }
    },
    "Stream": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "type",
        "codec",
        "profile",
        "width",
        "height",
        "pixelFormat",
        "timeBase",
        "startPTS",
        "duration",
        "nominalFrameRate",
        "variableFrameRate",
        "rotationDeg",
        "color",
        "sampleRate",
        "channels",
        "channelLayout"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "type": {
          "enum": [
            "video",
            "audio",
            "image"
          ]
        },
        "codec": {
          "type": "string",
          "minLength": 1,
          "maxLength": 128
        },
        "profile": {
          "anyOf": [
            {
              "type": "string",
              "minLength": 0,
              "maxLength": 128
            },
            {
              "type": "null"
            }
          ]
        },
        "width": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            {
              "type": "null"
            }
          ]
        },
        "height": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            {
              "type": "null"
            }
          ]
        },
        "pixelFormat": {
          "anyOf": [
            {
              "type": "string",
              "minLength": 0,
              "maxLength": 64
            },
            {
              "type": "null"
            }
          ]
        },
        "timeBase": {
          "$ref": "#/$defs/Time"
        },
        "startPTS": {
          "$ref": "#/$defs/I64"
        },
        "duration": {
          "$ref": "#/$defs/Time"
        },
        "nominalFrameRate": {
          "anyOf": [
            {
              "$ref": "#/$defs/Rate"
            },
            {
              "type": "null"
            }
          ]
        },
        "variableFrameRate": {
          "type": "boolean"
        },
        "rotationDeg": {
          "enum": [
            0,
            90,
            180,
            270
          ]
        },
        "color": {
          "anyOf": [
            {
              "$ref": "#/$defs/Color"
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleRate": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 8000,
              "maximum": 384000
            },
            {
              "type": "null"
            }
          ]
        },
        "channels": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 64
            },
            {
              "type": "null"
            }
          ]
        },
        "channelLayout": {
          "anyOf": [
            {
              "type": "string",
              "minLength": 0,
              "maxLength": 128
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Proxy": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "blobHash",
        "pipelineHash",
        "sourceVersion",
        "ptsMapBlobHash",
        "width",
        "height",
        "frameRate",
        "colorPolicy"
      ],
      "properties": {
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "pipelineHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceVersion": {
          "$ref": "#/$defs/U64"
        },
        "ptsMapBlobHash": {
          "$ref": "#/$defs/Hash"
        },
        "width": {
          "type": "integer",
          "minimum": 2,
          "maximum": 8192
        },
        "height": {
          "type": "integer",
          "minimum": 2,
          "maximum": 8192
        },
        "frameRate": {
          "$ref": "#/$defs/Rate"
        },
        "colorPolicy": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Asset": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "name",
        "kind",
        "originalBlobHash",
        "externalLocator",
        "streams",
        "proxyRefs",
        "rightsId",
        "contentFingerprint",
        "status"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "name": {
          "type": "string",
          "minLength": 1,
          "maxLength": 256
        },
        "kind": {
          "enum": [
            "video",
            "audio",
            "image",
            "mask",
            "model3d"
          ]
        },
        "originalBlobHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "externalLocator": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "streams": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Stream"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "proxyRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Proxy"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "rightsId": {
          "$ref": "#/$defs/Id"
        },
        "contentFingerprint": {
          "$ref": "#/$defs/Hash"
        },
        "status": {
          "enum": [
            "ready",
            "missing",
            "quarantined"
          ]
        }
      }
    },
    "Blob": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "hash",
        "bytes",
        "mime",
        "packagePath",
        "role"
      ],
      "properties": {
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "bytes": {
          "$ref": "#/$defs/U64"
        },
        "mime": {
          "type": "string",
          "minLength": 1,
          "maxLength": 128
        },
        "packagePath": {
          "type": "string",
          "pattern": "^(assets|originals|fonts|proxies|renders|thumbnails|snapshots|extensions)/[A-Za-z0-9_./-]+$"
        },
        "role": {
          "enum": [
            "original",
            "generated",
            "proxy",
            "render",
            "mask",
            "font",
            "thumbnail",
            "snapshot",
            "evidence",
            "ptsMap"
          ]
        }
      }
    },
    "TimeMap": {
      "oneOf": [
        {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "rate"
          ],
          "properties": {
            "kind": {
              "const": "linear"
            },
            "rate": {
              "$ref": "#/$defs/Time"
            }
          }
        },
        {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "knots",
            "interpolation"
          ],
          "properties": {
            "kind": {
              "const": "piecewise"
            },
            "knots": {
              "type": "array",
              "items": {
                "type": "object",
                "additionalProperties": false,
                "required": [
                  "u",
                  "v"
                ],
                "properties": {
                  "u": {
                    "$ref": "#/$defs/Time"
                  },
                  "v": {
                    "$ref": "#/$defs/Time"
                  }
                }
              },
              "minItems": 2,
              "maxItems": 2048
            },
            "interpolation": {
              "const": "linear"
            }
          }
        }
      ]
    },
    "Clip": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "trackId",
        "name",
        "source",
        "timelineRange",
        "sourceRange",
        "timeMap",
        "enabled",
        "lockedFields",
        "linkGroupId",
        "selectionGroupId",
        "effectIds",
        "shotId",
        "candidateId",
        "provenanceId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "trackId": {
          "$ref": "#/$defs/Id"
        },
        "name": {
          "type": "string",
          "minLength": 0,
          "maxLength": 256
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "timelineRange": {
          "$ref": "#/$defs/Range"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "timeMap": {
          "$ref": "#/$defs/TimeMap"
        },
        "enabled": {
          "type": "boolean",
          "default": true
        },
        "lockedFields": {
          "type": "array",
          "items": {
            "type": "string",
            "minLength": 1,
            "maxLength": 256
          },
          "minItems": 0,
          "maxItems": 256
        },
        "linkGroupId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "selectionGroupId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "effectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 256
        },
        "shotId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "candidateId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "provenanceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Gap": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "trackId",
        "timelineRange"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "trackId": {
          "$ref": "#/$defs/Id"
        },
        "timelineRange": {
          "$ref": "#/$defs/Range"
        }
      }
    },
    "Item": {
      "oneOf": [
        {
          "$ref": "#/$defs/Clip"
        },
        {
          "$ref": "#/$defs/Gap"
        }
      ]
    },
    "Track": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "sequenceId",
        "name",
        "kind",
        "order",
        "locked",
        "muted",
        "solo",
        "syncLock",
        "targeted",
        "busId",
        "items"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "sequenceId": {
          "$ref": "#/$defs/Id"
        },
        "name": {
          "type": "string",
          "minLength": 0,
          "maxLength": 256
        },
        "kind": {
          "enum": [
            "video",
            "audio",
            "caption"
          ]
        },
        "order": {
          "type": "integer",
          "minimum": 0,
          "maximum": 2147483647
        },
        "locked": {
          "type": "boolean",
          "default": false
        },
        "muted": {
          "type": "boolean",
          "default": false
        },
        "solo": {
          "type": "boolean",
          "default": false
        },
        "syncLock": {
          "type": "boolean",
          "default": true
        },
        "targeted": {
          "type": "boolean",
          "default": false
        },
        "busId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "items": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Item"
          },
          "minItems": 0,
          "maxItems": 100000
        }
      }
    },
    "Sequence": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "name",
        "version",
        "canvas",
        "frameRate",
        "sampleRate",
        "workingColor",
        "outputColor",
        "backgroundRGBA",
        "duration",
        "tracks",
        "markerIds",
        "masterBusId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "name": {
          "type": "string",
          "minLength": 0,
          "maxLength": 256
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "canvas": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "width",
            "height",
            "pixelAspect"
          ],
          "properties": {
            "width": {
              "type": "integer",
              "minimum": 2,
              "maximum": 8192,
              "multipleOf": 2
            },
            "height": {
              "type": "integer",
              "minimum": 2,
              "maximum": 8192,
              "multipleOf": 2
            },
            "pixelAspect": {
              "$ref": "#/$defs/Time"
            }
          }
        },
        "frameRate": {
          "$ref": "#/$defs/Rate"
        },
        "sampleRate": {
          "const": 48000
        },
        "workingColor": {
          "const": "linear-rec709"
        },
        "outputColor": {
          "const": "rec709"
        },
        "backgroundRGBA": {
          "type": "array",
          "items": {
            "type": "number",
            "minimum": 0,
            "maximum": 1
          },
          "minItems": 4,
          "maxItems": 4
        },
        "duration": {
          "$ref": "#/$defs/Time"
        },
        "tracks": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Track"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "markerIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "masterBusId": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Keyframe": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "param",
        "localTime",
        "value",
        "interpolation",
        "easing"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "param": {
          "type": "string",
          "minLength": 1,
          "maxLength": 128
        },
        "localTime": {
          "$ref": "#/$defs/Time"
        },
        "value": {
          "oneOf": [
            {
              "type": "number",
              "minimum": -1000000000000,
              "maximum": 1000000000000
            },
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 2,
              "maxItems": 2
            },
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 3,
              "maxItems": 3
            },
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 4,
              "maxItems": 4
            },
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            }
          ]
        },
        "interpolation": {
          "enum": [
            "hold",
            "linear"
          ]
        },
        "easing": {
          "type": "null"
        }
      }
    },
    "TransformParams": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "translateX",
        "translateY",
        "scaleX",
        "scaleY",
        "rotationDeg",
        "anchorX",
        "anchorY"
      ],
      "properties": {
        "translateX": {
          "type": "number",
          "minimum": -1000000000000,
          "maximum": 1000000000000,
          "default": 0
        },
        "translateY": {
          "type": "number",
          "minimum": -1000000000000,
          "maximum": 1000000000000,
          "default": 0
        },
        "scaleX": {
          "type": "number",
          "minimum": 0,
          "maximum": 100,
          "default": 1,
          "exclusiveMinimum": 0
        },
        "scaleY": {
          "type": "number",
          "minimum": 0,
          "maximum": 100,
          "default": 1,
          "exclusiveMinimum": 0
        },
        "rotationDeg": {
          "type": "number",
          "minimum": -360000,
          "maximum": 360000,
          "default": 0
        },
        "anchorX": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "default": 0.5
        },
        "anchorY": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "default": 0.5
        }
      }
    },
    "CropParams": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "left",
        "top",
        "right",
        "bottom"
      ],
      "properties": {
        "left": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "default": 0
        },
        "top": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "default": 0
        },
        "right": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "default": 1
        },
        "bottom": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "default": 1
        }
      }
    },
    "TextParams": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "fontRef",
        "fontSizePx",
        "fillRGBA",
        "strokePx",
        "shadow",
        "lineHeight",
        "letterSpacing",
        "alignment",
        "layoutRect"
      ],
      "properties": {
        "fontRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "fontSizePx": {
          "type": "number",
          "minimum": 6,
          "maximum": 1024,
          "default": 48
        },
        "fillRGBA": {
          "type": "array",
          "items": {
            "type": "number",
            "minimum": 0,
            "maximum": 1
          },
          "minItems": 4,
          "maxItems": 4
        },
        "strokePx": {
          "type": "number",
          "minimum": 0,
          "maximum": 32,
          "default": 0
        },
        "shadow": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "offsetX",
            "offsetY",
            "blurPx",
            "rgba"
          ],
          "properties": {
            "offsetX": {
              "type": "number",
              "minimum": -1024,
              "maximum": 1024
            },
            "offsetY": {
              "type": "number",
              "minimum": -1024,
              "maximum": 1024
            },
            "blurPx": {
              "type": "number",
              "minimum": 0,
              "maximum": 128
            },
            "rgba": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": 0,
                "maximum": 1
              },
              "minItems": 4,
              "maxItems": 4
            }
          }
        },
        "lineHeight": {
          "type": "number",
          "minimum": 0.5,
          "maximum": 4,
          "default": 1.2
        },
        "letterSpacing": {
          "type": "number",
          "minimum": -100,
          "maximum": 100,
          "default": 0
        },
        "alignment": {
          "enum": [
            "left",
            "center",
            "right",
            "justify"
          ]
        },
        "layoutRect": {
          "type": "array",
          "items": {
            "type": "number",
            "minimum": -1000000000000,
            "maximum": 1000000000000
          },
          "minItems": 4,
          "maxItems": 4
        }
      }
    },
    "Effect": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "owner",
        "pluginVersion",
        "enabled",
        "keyframes",
        "extensions",
        "type",
        "parameters"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "owner": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "id"
          ],
          "properties": {
            "kind": {
              "enum": [
                "clip",
                "track",
                "sequence",
                "caption",
                "imageLayer",
                "audioBus"
              ]
            },
            "id": {
              "$ref": "#/$defs/Id"
            }
          }
        },
        "pluginVersion": {
          "$ref": "#/$defs/Version"
        },
        "enabled": {
          "type": "boolean"
        },
        "keyframes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Keyframe"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "extensions": {
          "$ref": "#/$defs/Extensions"
        },
        "type": {
          "type": "string",
          "minLength": 1,
          "maxLength": 256
        },
        "parameters": {
          "type": "object"
        }
      },
      "oneOf": [
        {
          "properties": {
            "type": {
              "const": "transform2d"
            },
            "parameters": {
              "$ref": "#/$defs/TransformParams"
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "crop"
            },
            "parameters": {
              "$ref": "#/$defs/CropParams"
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "opacity"
            },
            "parameters": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "value"
              ],
              "properties": {
                "value": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 1,
                  "default": 1
                }
              }
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "colorBasic"
            },
            "parameters": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "exposureStops",
                "contrast",
                "saturation"
              ],
              "properties": {
                "exposureStops": {
                  "type": "number",
                  "minimum": -8,
                  "maximum": 8,
                  "default": 0
                },
                "contrast": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 2,
                  "default": 1
                },
                "saturation": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 2,
                  "default": 1
                }
              }
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "mask"
            },
            "parameters": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "blobHash",
                "transform",
                "invert"
              ],
              "properties": {
                "blobHash": {
                  "$ref": "#/$defs/Hash"
                },
                "transform": {
                  "type": "array",
                  "items": {
                    "type": "number",
                    "minimum": -1000000000000,
                    "maximum": 1000000000000
                  },
                  "minItems": 6,
                  "maxItems": 6
                },
                "invert": {
                  "type": "boolean",
                  "default": false
                }
              }
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "gain"
            },
            "parameters": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "gainDb"
              ],
              "properties": {
                "gainDb": {
                  "type": "number",
                  "minimum": -96,
                  "maximum": 12,
                  "default": 0
                }
              }
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "pan"
            },
            "parameters": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "value",
                "mode"
              ],
              "properties": {
                "value": {
                  "type": "number",
                  "minimum": -1,
                  "maximum": 1,
                  "default": 0
                },
                "mode": {
                  "enum": [
                    "monoEqualPower",
                    "stereoBalance"
                  ]
                }
              }
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "limiter"
            },
            "parameters": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "ceilingDb",
                "lookaheadMs",
                "releaseMs"
              ],
              "properties": {
                "ceilingDb": {
                  "type": "number",
                  "minimum": -24,
                  "maximum": 0,
                  "default": -1
                },
                "lookaheadMs": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 20,
                  "default": 5
                },
                "releaseMs": {
                  "type": "number",
                  "minimum": 1,
                  "maximum": 2000,
                  "default": 100
                }
              }
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "textStyle"
            },
            "parameters": {
              "$ref": "#/$defs/TextParams"
            }
          }
        },
        {
          "properties": {
            "type": {
              "type": "string",
              "pattern": "^[a-z][a-z0-9_.-]+/[A-Za-z0-9_.-]+$"
            },
            "parameters": {
              "type": "object",
              "maxProperties": 256
            }
          }
        }
      ]
    },
    "Transition": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "sequenceId",
        "trackId",
        "leftClipId",
        "rightClipId",
        "cut",
        "before",
        "after",
        "kind",
        "curve",
        "missingHandlePolicy",
        "enabled"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "sequenceId": {
          "$ref": "#/$defs/Id"
        },
        "trackId": {
          "$ref": "#/$defs/Id"
        },
        "leftClipId": {
          "$ref": "#/$defs/Id"
        },
        "rightClipId": {
          "$ref": "#/$defs/Id"
        },
        "cut": {
          "$ref": "#/$defs/Time"
        },
        "before": {
          "$ref": "#/$defs/Time"
        },
        "after": {
          "$ref": "#/$defs/Time"
        },
        "kind": {
          "enum": [
            "dissolve",
            "audioEqualPower"
          ]
        },
        "curve": {
          "const": "linear"
        },
        "missingHandlePolicy": {
          "enum": [
            "reject",
            "freeze"
          ]
        },
        "enabled": {
          "type": "boolean"
        }
      }
    },
    "Anchor": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "kind",
        "clipId",
        "range"
      ],
      "properties": {
        "kind": {
          "enum": [
            "absolute",
            "clipLocal",
            "source"
          ]
        },
        "clipId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "range": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Caption": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "trackId",
        "timelineRange",
        "text",
        "language",
        "styleEffectId",
        "anchor",
        "manualFields",
        "words",
        "speakerId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "trackId": {
          "$ref": "#/$defs/Id"
        },
        "timelineRange": {
          "$ref": "#/$defs/Range"
        },
        "text": {
          "type": "string",
          "minLength": 0,
          "maxLength": 4096
        },
        "language": {
          "type": "string",
          "pattern": "^[A-Za-z]{2,8}(-[A-Za-z0-9]{1,8})*$"
        },
        "styleEffectId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "anchor": {
          "$ref": "#/$defs/Anchor"
        },
        "manualFields": {
          "type": "array",
          "items": {
            "enum": [
              "text",
              "timing",
              "style",
              "speaker"
            ]
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "words": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "text",
              "sourceRange",
              "confidence"
            ],
            "properties": {
              "text": {
                "type": "string",
                "minLength": 0,
                "maxLength": 128
              },
              "sourceRange": {
                "$ref": "#/$defs/Range"
              },
              "confidence": {
                "type": "number",
                "minimum": 0,
                "maximum": 1
              }
            }
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "speakerId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "AudioBus": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "name",
        "inputBusIds",
        "gainDb",
        "pan",
        "effectIds",
        "muted",
        "solo",
        "outputBusId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "name": {
          "type": "string",
          "minLength": 0,
          "maxLength": 256
        },
        "inputBusIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "gainDb": {
          "type": "number",
          "minimum": -96,
          "maximum": 12,
          "default": 0
        },
        "pan": {
          "type": "number",
          "minimum": -1,
          "maximum": 1,
          "default": 0
        },
        "effectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 256
        },
        "muted": {
          "type": "boolean"
        },
        "solo": {
          "type": "boolean"
        },
        "outputBusId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Marker": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "sequenceId",
        "label",
        "colorRGBA",
        "anchor",
        "time",
        "duration",
        "ripple"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "sequenceId": {
          "$ref": "#/$defs/Id"
        },
        "label": {
          "type": "string",
          "minLength": 0,
          "maxLength": 1024
        },
        "colorRGBA": {
          "type": "array",
          "items": {
            "type": "number",
            "minimum": 0,
            "maximum": 1
          },
          "minItems": 4,
          "maxItems": 4
        },
        "anchor": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "clipId"
          ],
          "properties": {
            "kind": {
              "enum": [
                "absolute",
                "clipLocal"
              ]
            },
            "clipId": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Id"
                },
                {
                  "type": "null"
                }
              ]
            }
          }
        },
        "time": {
          "$ref": "#/$defs/Time"
        },
        "duration": {
          "$ref": "#/$defs/Time"
        },
        "ripple": {
          "type": "boolean"
        }
      }
    },
    "Rights": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "kind",
        "assetIds",
        "holder",
        "statement",
        "evidenceBlobHash",
        "providerTermsRef",
        "allowedUses",
        "territories",
        "expiresAt",
        "consentId",
        "verified"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "userAttestation",
            "license",
            "providerTerms"
          ]
        },
        "assetIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "holder": {
          "type": "string",
          "minLength": 0,
          "maxLength": 1024
        },
        "statement": {
          "type": "string",
          "minLength": 0,
          "maxLength": 16384
        },
        "evidenceBlobHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "providerTermsRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "allowedUses": {
          "type": "array",
          "items": {
            "enum": [
              "edit",
              "export",
              "upload",
              "redistribute"
            ]
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "territories": {
          "type": "array",
          "items": {
            "type": "string",
            "minLength": 0,
            "maxLength": 64
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "expiresAt": {
          "anyOf": [
            {
              "$ref": "#/$defs/Timestamp"
            },
            {
              "type": "null"
            }
          ]
        },
        "consentId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified": {
          "type": "boolean"
        }
      }
    },
    "LinkGroup": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "anchorClipId",
        "members",
        "syncPolicy"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "anchorClipId": {
          "$ref": "#/$defs/Id"
        },
        "members": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "clipId",
              "offset"
            ],
            "properties": {
              "clipId": {
                "$ref": "#/$defs/Id"
              },
              "offset": {
                "$ref": "#/$defs/Time"
              }
            }
          },
          "minItems": 2,
          "maxItems": 100000
        },
        "syncPolicy": {
          "enum": [
            "preserve",
            "allowOutOfSync"
          ]
        }
      }
    },
    "SelectionGroup": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "memberClipIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "memberClipIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 100000
        }
      }
    },
    "Layer": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "parentId",
        "kind",
        "sourceRef",
        "text",
        "transform",
        "opacity",
        "blendMode",
        "maskRef",
        "effectIds",
        "locked",
        "visible"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "parentId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "kind": {
          "enum": [
            "raster",
            "text",
            "group",
            "vector"
          ]
        },
        "sourceRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/EntityRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "text": {
          "anyOf": [
            {
              "type": "string",
              "minLength": 0,
              "maxLength": 65536
            },
            {
              "type": "null"
            }
          ]
        },
        "transform": {
          "type": "array",
          "items": {
            "type": "number",
            "minimum": -1000000000000,
            "maximum": 1000000000000
          },
          "minItems": 6,
          "maxItems": 6
        },
        "opacity": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "default": 1
        },
        "blendMode": {
          "enum": [
            "normal",
            "multiply",
            "screen"
          ]
        },
        "maskRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "effectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 256
        },
        "locked": {
          "type": "boolean"
        },
        "visible": {
          "type": "boolean"
        }
      }
    },
    "ImageDocument": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "width",
        "height",
        "color",
        "rootLayerIds",
        "layers",
        "fontRefs"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "width": {
          "type": "integer",
          "minimum": 1,
          "maximum": 32768
        },
        "height": {
          "type": "integer",
          "minimum": 1,
          "maximum": 32768
        },
        "color": {
          "const": "linear-rec709"
        },
        "rootLayerIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "layers": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Layer"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "fontRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 100000
        }
      }
    },
    "Font": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "family",
        "style",
        "hash",
        "licenseRef",
        "embedAllowed",
        "fallbackFamilies"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "family": {
          "type": "string",
          "minLength": 1,
          "maxLength": 256
        },
        "style": {
          "type": "string",
          "minLength": 1,
          "maxLength": 128
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "licenseRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "embedAllowed": {
          "type": "boolean"
        },
        "fallbackFamilies": {
          "type": "array",
          "items": {
            "type": "string",
            "minLength": 1,
            "maxLength": 256
          },
          "minItems": 0,
          "maxItems": 32
        }
      }
    },
    "ModelRef": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "profileId",
        "packageHash",
        "weightLicenseId",
        "engineLicenseId"
      ],
      "properties": {
        "profileId": {
          "$ref": "#/$defs/Id"
        },
        "packageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "weightLicenseId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "engineLicenseId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Reference": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "assetRef",
        "role",
        "rightsId"
      ],
      "properties": {
        "assetRef": {
          "$ref": "#/$defs/EntityRef"
        },
        "role": {
          "enum": [
            "subject",
            "style",
            "firstFrame",
            "lastFrame",
            "audio",
            "source"
          ]
        },
        "rightsId": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Brief": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "locale",
        "audience",
        "objective",
        "targetDuration",
        "aspect",
        "deliveryPresetId",
        "requiredFacts",
        "forbiddenClaims",
        "referenceRefs",
        "brandPolicy",
        "audioPolicy",
        "textPolicy",
        "budget",
        "purpose",
        "purposePayload"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "locale": {
          "type": "string",
          "minLength": 1,
          "maxLength": 64
        },
        "audience": {
          "type": "string",
          "minLength": 0,
          "maxLength": 1024
        },
        "objective": {
          "type": "string",
          "minLength": 1,
          "maxLength": 4096
        },
        "targetDuration": {
          "$ref": "#/$defs/Time"
        },
        "aspect": {
          "enum": [
            "9:16",
            "16:9",
            "1:1"
          ]
        },
        "deliveryPresetId": {
          "$ref": "#/$defs/Id"
        },
        "requiredFacts": {
          "type": "array",
          "items": {
            "type": "string",
            "minLength": 0,
            "maxLength": 2048
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "forbiddenClaims": {
          "type": "array",
          "items": {
            "type": "string",
            "minLength": 0,
            "maxLength": 2048
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "referenceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Reference"
          },
          "minItems": 0,
          "maxItems": 64
        },
        "brandPolicy": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "palette",
            "logoAssetRef",
            "safeArea",
            "restrictedTopics",
            "rightsAttestationId"
          ],
          "properties": {
            "palette": {
              "type": "array",
              "items": {
                "type": "string",
                "minLength": 0,
                "maxLength": 64
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "logoAssetRef": {
              "anyOf": [
                {
                  "$ref": "#/$defs/EntityRef"
                },
                {
                  "type": "null"
                }
              ]
            },
            "safeArea": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": 0,
                "maximum": 1
              },
              "minItems": 4,
              "maxItems": 4
            },
            "restrictedTopics": {
              "type": "array",
              "items": {
                "type": "string",
                "minLength": 0,
                "maxLength": 256
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "rightsAttestationId": {
              "$ref": "#/$defs/Id"
            }
          }
        },
        "audioPolicy": {
          "enum": [
            "originalOnly",
            "providedMusic",
            "generated",
            "silent"
          ]
        },
        "textPolicy": {
          "const": "editableOverlay"
        },
        "budget": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "currency",
            "maxMicros"
          ],
          "properties": {
            "currency": {
              "type": "string",
              "pattern": "^[A-Z]{3}$"
            },
            "maxMicros": {
              "$ref": "#/$defs/U64"
            }
          }
        },
        "purpose": {
          "enum": [
            "productAd",
            "social",
            "story",
            "tutorial",
            "photoMotion",
            "musicVisual"
          ]
        },
        "purposePayload": {
          "type": "object"
        }
      },
      "oneOf": [
        {
          "properties": {
            "purpose": {
              "const": "productAd"
            },
            "purposePayload": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "productName",
                "verifiedClaims",
                "audience",
                "cta",
                "referenceAssetId",
                "offer",
                "endDate",
                "brandPalette"
              ],
              "properties": {
                "productName": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 256
                },
                "verifiedClaims": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 1024
                  },
                  "minItems": 1,
                  "maxItems": 5
                },
                "audience": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "cta": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "referenceAssetId": {
                  "$ref": "#/$defs/Id"
                },
                "offer": {
                  "anyOf": [
                    {
                      "type": "string",
                      "minLength": 0,
                      "maxLength": 1024
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "endDate": {
                  "anyOf": [
                    {
                      "$ref": "#/$defs/Timestamp"
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "brandPalette": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "minLength": 0,
                    "maxLength": 64
                  },
                  "minItems": 0,
                  "maxItems": 100000
                }
              }
            }
          }
        },
        {
          "properties": {
            "purpose": {
              "const": "social"
            },
            "purposePayload": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "platform",
                "audience",
                "topic",
                "hookText",
                "payoff",
                "trendReference",
                "captionsStyle"
              ],
              "properties": {
                "platform": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 128
                },
                "audience": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "topic": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "hookText": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "payoff": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "trendReference": {
                  "anyOf": [
                    {
                      "$ref": "#/$defs/EntityRef"
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "captionsStyle": {
                  "anyOf": [
                    {
                      "type": "string",
                      "minLength": 0,
                      "maxLength": 128
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              }
            }
          }
        },
        {
          "properties": {
            "purpose": {
              "const": "story"
            },
            "purposePayload": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "logline",
                "characterIds",
                "location",
                "conflict",
                "ending",
                "rating",
                "dialogue",
                "continuityBible"
              ],
              "properties": {
                "logline": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 4096
                },
                "characterIds": {
                  "type": "array",
                  "items": {
                    "$ref": "#/$defs/Id"
                  },
                  "minItems": 1,
                  "maxItems": 100000
                },
                "location": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 2048
                },
                "conflict": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 4096
                },
                "ending": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 4096
                },
                "rating": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 64
                },
                "dialogue": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "minLength": 0,
                    "maxLength": 4096
                  },
                  "minItems": 0,
                  "maxItems": 100000
                },
                "continuityBible": {
                  "anyOf": [
                    {
                      "type": "string",
                      "minLength": 0,
                      "maxLength": 16384
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              }
            }
          }
        },
        {
          "properties": {
            "purpose": {
              "const": "tutorial"
            },
            "purposePayload": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "learningGoal",
                "steps",
                "factsSourceRefs",
                "targetAudience",
                "screenRecordingAsset",
                "safetyWarnings"
              ],
              "properties": {
                "learningGoal": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 2048
                },
                "steps": {
                  "type": "array",
                  "items": {
                    "type": "object",
                    "additionalProperties": false,
                    "required": [
                      "action",
                      "expectedResult"
                    ],
                    "properties": {
                      "action": {
                        "type": "string",
                        "minLength": 1,
                        "maxLength": 2048
                      },
                      "expectedResult": {
                        "type": "string",
                        "minLength": 1,
                        "maxLength": 2048
                      }
                    }
                  },
                  "minItems": 1,
                  "maxItems": 100
                },
                "factsSourceRefs": {
                  "type": "array",
                  "items": {
                    "$ref": "#/$defs/EntityRef"
                  },
                  "minItems": 1,
                  "maxItems": 100000
                },
                "targetAudience": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "screenRecordingAsset": {
                  "anyOf": [
                    {
                      "$ref": "#/$defs/EntityRef"
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "safetyWarnings": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "minLength": 0,
                    "maxLength": 2048
                  },
                  "minItems": 0,
                  "maxItems": 100000
                }
              }
            }
          }
        },
        {
          "properties": {
            "purpose": {
              "const": "photoMotion"
            },
            "purposePayload": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "photoAssetId",
                "rightsConfirmed",
                "motionRegion",
                "cameraMotion",
                "preserveRegions",
                "loop",
                "endFrameAssetId"
              ],
              "properties": {
                "photoAssetId": {
                  "$ref": "#/$defs/Id"
                },
                "rightsConfirmed": {
                  "type": "boolean"
                },
                "motionRegion": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 4096
                },
                "cameraMotion": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "preserveRegions": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "minLength": 0,
                    "maxLength": 1024
                  },
                  "minItems": 0,
                  "maxItems": 100000
                },
                "loop": {
                  "type": "boolean"
                },
                "endFrameAssetId": {
                  "anyOf": [
                    {
                      "$ref": "#/$defs/Id"
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              }
            }
          }
        },
        {
          "properties": {
            "purpose": {
              "const": "musicVisual"
            },
            "purposePayload": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "audioAssetId",
                "musicRights",
                "beatGridRef",
                "mood",
                "visualMotif",
                "targetRange",
                "lyrics",
                "bpm"
              ],
              "properties": {
                "audioAssetId": {
                  "$ref": "#/$defs/Id"
                },
                "musicRights": {
                  "$ref": "#/$defs/Id"
                },
                "beatGridRef": {
                  "$ref": "#/$defs/Hash"
                },
                "mood": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "visualMotif": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 2048
                },
                "targetRange": {
                  "$ref": "#/$defs/Range"
                },
                "lyrics": {
                  "anyOf": [
                    {
                      "type": "string",
                      "minLength": 0,
                      "maxLength": 16384
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "bpm": {
                  "anyOf": [
                    {
                      "type": "number",
                      "minimum": 1,
                      "maximum": 400
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              }
            }
          }
        }
      ]
    },
    "Character": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "name",
        "appearanceRef",
        "motivation",
        "constraints",
        "rightsId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "name": {
          "type": "string",
          "minLength": 1,
          "maxLength": 256
        },
        "appearanceRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/EntityRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "motivation": {
          "type": "string",
          "minLength": 0,
          "maxLength": 4096
        },
        "constraints": {
          "type": "array",
          "items": {
            "type": "string",
            "minLength": 0,
            "maxLength": 2048
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "rightsId": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Script": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "briefId",
        "title",
        "sceneIds",
        "language",
        "status"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "briefId": {
          "$ref": "#/$defs/Id"
        },
        "title": {
          "type": "string",
          "minLength": 0,
          "maxLength": 256
        },
        "sceneIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "language": {
          "type": "string",
          "minLength": 0,
          "maxLength": 64
        },
        "status": {
          "enum": [
            "draft",
            "approved",
            "stale"
          ]
        }
      }
    },
    "Scene": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "scriptId",
        "order",
        "summary",
        "characterIds",
        "shotIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "scriptId": {
          "$ref": "#/$defs/Id"
        },
        "order": {
          "type": "integer",
          "minimum": 0,
          "maximum": 2147483647
        },
        "summary": {
          "type": "string",
          "minLength": 0,
          "maxLength": 16384
        },
        "characterIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "shotIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 100000
        }
      }
    },
    "Shot": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "sceneId",
        "order",
        "purposeBeat",
        "targetTimelineRange",
        "subjectRefs",
        "setting",
        "action",
        "camera",
        "lighting",
        "continuity",
        "captionPlan",
        "voicePlan",
        "musicRange",
        "generationMode",
        "firstFrameRef",
        "lastFrameRef",
        "referenceRefs",
        "targetProviderProfileId",
        "selectedCandidateId",
        "lockedFields"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "sceneId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "order": {
          "type": "integer",
          "minimum": 0,
          "maximum": 2147483647
        },
        "purposeBeat": {
          "type": "string",
          "minLength": 0,
          "maxLength": 1024
        },
        "targetTimelineRange": {
          "$ref": "#/$defs/Range"
        },
        "subjectRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/EntityRef"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "setting": {
          "type": "string",
          "minLength": 0,
          "maxLength": 4096
        },
        "action": {
          "type": "string",
          "minLength": 0,
          "maxLength": 4096
        },
        "camera": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "size",
            "motion",
            "lensIntent"
          ],
          "properties": {
            "size": {
              "type": "string",
              "minLength": 0,
              "maxLength": 128
            },
            "motion": {
              "type": "string",
              "minLength": 0,
              "maxLength": 1024
            },
            "lensIntent": {
              "type": "string",
              "minLength": 0,
              "maxLength": 1024
            }
          }
        },
        "lighting": {
          "type": "string",
          "minLength": 0,
          "maxLength": 2048
        },
        "continuity": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "characterRefs",
            "wardrobe",
            "screenDirection",
            "propRefs",
            "mustPreserve"
          ],
          "properties": {
            "characterRefs": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/EntityRef"
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "wardrobe": {
              "type": "string",
              "minLength": 0,
              "maxLength": 2048
            },
            "screenDirection": {
              "type": "string",
              "minLength": 0,
              "maxLength": 1024
            },
            "propRefs": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/EntityRef"
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "mustPreserve": {
              "type": "array",
              "items": {
                "type": "string",
                "minLength": 0,
                "maxLength": 2048
              },
              "minItems": 0,
              "maxItems": 100000
            }
          }
        },
        "captionPlan": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "text",
              "range"
            ],
            "properties": {
              "text": {
                "type": "string",
                "minLength": 0,
                "maxLength": 4096
              },
              "range": {
                "$ref": "#/$defs/Range"
              }
            }
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "voicePlan": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "text",
              "range",
              "speakerId"
            ],
            "properties": {
              "text": {
                "type": "string",
                "minLength": 0,
                "maxLength": 4096
              },
              "range": {
                "$ref": "#/$defs/Range"
              },
              "speakerId": {
                "anyOf": [
                  {
                    "$ref": "#/$defs/Id"
                  },
                  {
                    "type": "null"
                  }
                ]
              }
            }
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "musicRange": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "generationMode": {
          "enum": [
            "t2v",
            "i2v",
            "firstLast",
            "reference"
          ]
        },
        "firstFrameRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/EntityRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "lastFrameRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/EntityRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "referenceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Reference"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "targetProviderProfileId": {
          "$ref": "#/$defs/Id"
        },
        "selectedCandidateId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "lockedFields": {
          "type": "array",
          "items": {
            "type": "string",
            "minLength": 0,
            "maxLength": 256
          },
          "minItems": 0,
          "maxItems": 100000
        }
      }
    },
    "GenerationRecord": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "candidateIds",
        "provider",
        "modelId",
        "providerModelVersion",
        "templateId",
        "templateVersion",
        "promptHash",
        "promptText",
        "negativePrompt",
        "parameterProfileId",
        "inputAssetRefs",
        "seed",
        "parameters",
        "rights",
        "outputAssetRefs",
        "jobId",
        "createdAt"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "candidateIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "provider": {
          "$ref": "#/$defs/Id"
        },
        "modelId": {
          "$ref": "#/$defs/Id"
        },
        "providerModelVersion": {
          "anyOf": [
            {
              "type": "string",
              "minLength": 0,
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "templateId": {
          "$ref": "#/$defs/Id"
        },
        "templateVersion": {
          "type": "string",
          "minLength": 1,
          "maxLength": 64
        },
        "promptHash": {
          "$ref": "#/$defs/Hash"
        },
        "promptText": {
          "anyOf": [
            {
              "type": "string",
              "minLength": 0,
              "maxLength": 65536
            },
            {
              "type": "null"
            }
          ]
        },
        "negativePrompt": {
          "anyOf": [
            {
              "type": "string",
              "minLength": 0,
              "maxLength": 8192
            },
            {
              "type": "null"
            }
          ]
        },
        "parameterProfileId": {
          "$ref": "#/$defs/Id"
        },
        "inputAssetRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/EntityRef"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "seed": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "parameters": {
          "type": "object",
          "maxProperties": 128
        },
        "rights": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "attestationId",
            "licenseSnapshotRef"
          ],
          "properties": {
            "attestationId": {
              "$ref": "#/$defs/Id"
            },
            "licenseSnapshotRef": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            }
          }
        },
        "outputAssetRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/EntityRef"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "createdAt": {
          "$ref": "#/$defs/Timestamp"
        }
      }
    },
    "RetainedSource": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "kind",
        "id",
        "version",
        "definitionBlobHash",
        "dependencyBlobHashes"
      ],
      "properties": {
        "kind": {
          "enum": [
            "asset",
            "sequence",
            "imageDocument"
          ]
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "definitionBlobHash": {
          "$ref": "#/$defs/Hash"
        },
        "dependencyBlobHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 100000
        }
      }
    },
    "InversePatch": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "kind",
        "commandId",
        "beforeHash",
        "afterHash",
        "beforeContentHash",
        "afterContentHash",
        "changedEntities",
        "blobPins"
      ],
      "properties": {
        "schemaVersion": {
          "const": "2.0.0"
        },
        "kind": {
          "const": "restoreSnapshot"
        },
        "commandId": {
          "$ref": "#/$defs/Id"
        },
        "beforeHash": {
          "$ref": "#/$defs/Hash"
        },
        "afterHash": {
          "$ref": "#/$defs/Hash"
        },
        "beforeContentHash": {
          "$ref": "#/$defs/Hash"
        },
        "afterContentHash": {
          "$ref": "#/$defs/Hash"
        },
        "changedEntities": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "id",
              "beforeVersion",
              "afterVersion"
            ],
            "properties": {
              "id": {
                "$ref": "#/$defs/Id"
              },
              "beforeVersion": {
                "anyOf": [
                  {
                    "$ref": "#/$defs/U64"
                  },
                  {
                    "type": "null"
                  }
                ]
              },
              "afterVersion": {
                "anyOf": [
                  {
                    "$ref": "#/$defs/U64"
                  },
                  {
                    "type": "null"
                  }
                ]
              }
            }
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "blobPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 100000
        }
      }
    }
  }
}
```

| 命令kind完整覆盖 | 附加前置→结果→逆操作/错误 |
| --- | --- |
| move / split / insert / overwrite / delete / trim / roll / slip / slide | payload以命令schema为准，区间算法见第3节；IDs非空/去重，delta非0；delete lift用ids且range=null，ripple用range且ids可空，rippleTrackIds必须显式有效。normal trim不允许rippleTrackIds非空；roll/slide邻接，源handle与链接先整体校验。结果为受影响实体before/after+精确失效区间。统一快照逆恢复源范围/Gap/组/效果；COLLISION/SOURCE_OUT_OF_RANGE/SYNC_LOCKED则无写。 |
| trackState / link / unlink / group / ungroup / paste | trackState至少一个字段非null，null=不改；link/group成员唯一，anchor在成员内，不能跨Sequence；unlink/ungroup目标必须存在。paste先校验clipboard blob的Studio剪贴格式与trackMap一一映射，再稳定派生新ID，不能让剪贴板运行代码。逆保存原组关系/轨道状态/全部新增ID，缺映射或锁定整组拒绝。 |
| setKeyframe / removeKeyframe / setEffect / removeEffect | effect/owner存在且版本/参数能力匹配；setKeyframe同param/time明确替换原点，不能同时保重复点；removeKeyframe必须命中。removeEffect同时移除owner.effectIds；被Caption.styleEffectId引用时先展示默认style替代才允许删除。逆恢复完整Effect/引用/原keyframe。UNKNOWN_PARAMETER/PLUGIN_UNAVAILABLE/REFERENCE_IN_USE拒绝。 |
| retime / setTransition / removeTransition | retime的timeMap首尾就是最终新timelineDuration/sourceDuration；ripple保持原source需求，fit保持原timelineDuration，二者与给定映射不一致即拒绝，不忽略参数。音频策略仅resamplePitchChanges或mute；首版平滑/倒放不支持就CAPABILITY_UNSUPPORTED。transition按handles公式先验；逆恢复旧映射/转场/所有联动范围，remove不存在返回NOT_FOUND不假成功。 |
| compound / upgradeNest | compound显式targetTrackId/newSequenceId/newClipId，跨轨选择迁入子坐标、所有受影响母轨用Gap清出，目标轨放Nest，外部链接按reject/unlink策略；新ID不得复用。upgradeNest必须精确from/to已解析版本，trim模式新源不足也拒绝，不偷freeze。逆恢复原多轨布局和source版本，循环/深度超限/NEST_VERSION_MISSING拒绝。 |
| setCaption / setFieldLocks / replaceTake | setCaption的id始终必填；id已存在则精确版本替换，不存在则新建且version=1；不允许改变track归属而不列入writeSet。setFieldLocks只支持有lockedFields字段的Clip/Shot，路径限相应实体字段注册表中的相对JSON Pointer（如/timelineRange）；不是任意SQL。Caption人工改字由setCaption维护manualFields保护，整条字幕轨可Track.locked，不能往Caption偷偷加未定义lockedFields。replaceTake只写source/candidate/provenance及用户明确sourceRange，不改timeline/字幕；P1不足必须reject；freeze值仅为预留请求能力，P1返回CAPABILITY_UNSUPPORTED，因为当前TimeMap没有hold段，不能伪装成可保存的Clip冻结。Transition自身missingHandlePolicy=freeze只冻结转场窗口采样，另有明确字段，不受此限制。逆保原Caption/锁/视频引用；LOCKED/STALE_CANDIDATE拒绝。 |
| addTrack / removeTrack / setAudioBus / relinkAsset / setSequence | addTrack必须同Sequence且order无冲突；removeTrack非空默认rejectIfNotEmpty，removeContents需diff列出clip/caption/group/转场影响。bus修改先验路由DAG。relinkFileToken仅本地受信文件选择器产出，同hash幂等；允许异hash时新AssetVersion并重新预览受影响引用。setSequence改变fps需conversionPolicy=regridExplicit并展示边界量化diff；尺寸变化展示图层位置/裁切diff且不得静默缩放。逆恢复旧轨/总线/源版本/完整序列，资源blob不覆写。 |
| updateCreative / setImageDocument / attachArtifacts / batch | updateCreative是指定对象的upsert+显式remove，不替换整张表；删除前检查所有引用，REF_IN_USE整批拒绝，不级联删用户内容。setImageDocument完整校验Layer树/效果/字体/锁字段，不能写媒体原件。attachArtifacts只从本机受信IngestStore的ready bundleToken选择assetIds/fontIds及其权利/溯源依赖；token绑定namespace/批准，模型不能把任意路径/JSON注册成媒体，空选择拒绝。batch只能含1..256个原子Operation且禁止嵌套；先展开全部读写/锁/引用依赖并模拟全部操作，校验最终proposedSnapshot再一次提交（允许同batch创建互相引用的新Script/Scene/Shot），失败零写，逆恢复整批before。新建分镜、入NLE所需attach+insert+setCaption因此可以与DDL保持一Command/一Revision，不凭空使用未定义的saveShot接口。 |
| undo / redo | 只接受commandId/undoCommandId，不能提供任意before JSON。当前contentHash（排除Project.revision）等于目标afterContentHash时可恢复before内容并写新revision；有后续编辑则验证changedEntities/readSet，冲突返回UNDO_CONFLICT并允许从历史快照分支，绝不整库回退。redo使用已保存after，不重新运行模型/云生成/转码；撤销后新编辑使旧redo不可自动应用。 |
| 共通取消、幂等与逆资源生命周期 | 提交前cancelEpoch获胜不写；提交后返回ALREADY_COMMITTED并提供undo入口。idempotencyKey同inputHash返回同receipt，异hash拒绝。InversePatch.beforeHash/afterHash与blobPins持有到历史宽限结束；移除片段不立刻GC原件。setSelection/复制/seek/报价/生成Job不是文档Operation，不伪造revision。 |

带完整versioned实体的setCaption/setEffect/setSequence/setImageDocument/updateCreative输入里，已有对象version表示调用方读到的base版本，必须匹配readSet；新对象输入version=1。真正输出版本由RevisionPlanner在事务中分配为该ID历史max(version)+1（新ID为1），而非currentVersion+1；undo恢复旧定义后再编辑也不得复用已用过的版本号。batch.operations不得含undo/redo；它们只允许单独顶层执行，业务验证拒绝混入，防逆操作嵌套。setSequence仅改序列设置，传入tracks/外部实体必须与base一致，重网格由planner展开；不能借整个对象绕过clip专用命令/轨道锁。所有set/upsert都先展开实际字段diff与反向引用写入，再与批准writeSet对比。attachArtifacts仅登记到工程JSON，底层字节早已在workspace CAS，不为1:N复制媒体；不在包内导出bundleToken。新资源ID同已存ID且内容相同可复用，异内容拒绝ID_CONFLICT。relinkAsset同hash只修复本机locator而不制造无意义revision；异hash需allowNewVersion=true及明确非空selectionIds，预览所选引用的Asset新版本/Clip.source变更，并清空这些Clip的candidateId/provenanceId（它们已不是原生成输出），保留历史记录及手工字幕，不能伪造GenerationRecord。未选引用继续绑定旧版本快照，新的素材使用权必须重新确认。

命令结果的beforeImageRef/afterImageRef是含Project.revision的完整canonical ProjectDocument snapshot hash；InversePatch另存beforeContentHash/afterContentHash（仅排除Project.revision后再JCS hash），用于undo/redo内容比较。恢复时取旧快照内容后写新Project.revision再重新hash，不能让新revision继续引用旧hash；实体version是不可变定义版本，可恢复旧版本引用，不把它当唯一并发时钟。inversePatchRef指向按InversePatch结构存储的内容；eventSeq是此次commit后的流尾序号。invalidatedRanges每项必须同时给sequenceId和range；compound/嵌套/undo可影响多个序列，不能只返回无归属秒数。序列失效范围合并同sequenceId的相交区间并限制在该序列有效域；删除序列改发entityRemoved事件。inputHash=SHA256(JCS(对象：method='execute'，以及envelope除id/idempotencyKey/inputHash/issuedAt四字段外的全部字段))，包含namespace、revision、读写集合、gestureGroupId和payload；相同key不同语义返回IDEMPOTENCY_CONFLICT，不能只hash命令kind。所有随机派生ID以commandId+角色索引稳定派生，重复请求不产生新Clip。UI类TrimCommand/RollCommand等只构造schema对应payload，DocumentValidator/TimelineEditor.plan才有写语义，Provider永不写DB。

Manifest也完整闭合；archiveId标识一次归档，不复用云Job或用户批准。sessionArchive=null时包内不允许sessions正文，以免“未勾选导出会话”却残留上次归档数据。snapshotPath的64位hex必须等于snapshotHash去掉sha256前缀后的值（语义校验，不是regex能证明）。checksums.json列出除自身外全部归档条目的path/hash/bytes，包括manifest；不建立自引用hash。路径只允许相对POSIX路径，拒绝..、绝对路径、反斜杠、symlink及大小写折叠/Unicode规范化后重名；导入先限制总展开大小/压缩比，防zip bomb。models/references.json和索引/thumbnail均为快照投影，不是第二份真相；镜像字段不一致报PACKAGE_PROJECTION_MISMATCH，缺缩略图可重建，缺模型绝不自动下载。

```text
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "format",
    "schemaVersion",
    "minReaderVersion",
    "archiveId",
    "projectId",
    "namespace",
    "revision",
    "snapshotPath",
    "snapshotHash",
    "packMode",
    "includedGroups",
    "missingExternalRefs",
    "checksumsPath",
    "createdAt",
    "writerVersion",
    "sessionArchive"
  ],
  "properties": {
    "format": {
      "const": "studio-project"
    },
    "schemaVersion": {
      "const": "2.0.0"
    },
    "minReaderVersion": {
      "const": "2.0.0"
    },
    "archiveId": {
      "$ref": "#/$defs/Id"
    },
    "projectId": {
      "$ref": "#/$defs/Id"
    },
    "namespace": {
      "$ref": "#/$defs/Namespace"
    },
    "revision": {
      "$ref": "#/$defs/U64"
    },
    "snapshotPath": {
      "type": "string",
      "pattern": "^snapshots/[0-9a-f]{64}\\.json$"
    },
    "snapshotHash": {
      "$ref": "#/$defs/Hash"
    },
    "packMode": {
      "enum": [
        "linked",
        "embedded"
      ]
    },
    "includedGroups": {
      "type": "array",
      "items": {
        "enum": [
          "originals",
          "generated",
          "sessions",
          "fonts",
          "history"
        ]
      },
      "minItems": 0,
      "maxItems": 5,
      "uniqueItems": true
    },
    "missingExternalRefs": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/Id"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "checksumsPath": {
      "const": "checksums.json"
    },
    "createdAt": {
      "$ref": "#/$defs/Timestamp"
    },
    "writerVersion": {
      "$ref": "#/$defs/Version"
    },
    "sessionArchive": {
      "anyOf": [
        {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "path",
            "schemaVersion",
            "revisionMapPath",
            "contentIncluded",
            "commandBodiesIncluded"
          ],
          "properties": {
            "path": {
              "const": "sessions/archive.json"
            },
            "schemaVersion": {
              "const": "2.0.0"
            },
            "revisionMapPath": {
              "const": "sessions/revision-map.json"
            },
            "contentIncluded": {
              "type": "boolean"
            },
            "commandBodiesIncluded": {
              "const": false
            }
          }
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "urn:studio:manifest:2.0.0",
  "$defs": {
    "Id": {
      "type": "string",
      "pattern": "^[A-Za-z0-9][A-Za-z0-9._:@-]{0,127}$"
    },
    "Text": {
      "type": "string",
      "minLength": 0,
      "maxLength": 4096
    },
    "I64": {
      "type": "string",
      "pattern": "^(0|-[1-9][0-9]{0,18}|[1-9][0-9]{0,18})$"
    },
    "U64": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,18})$"
    },
    "Hash": {
      "type": "string",
      "pattern": "^sha256:[0-9a-f]{64}$"
    },
    "Time": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "n",
        "d"
      ],
      "properties": {
        "n": {
          "$ref": "#/$defs/I64"
        },
        "d": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000000000
        }
      }
    },
    "Range": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "start",
        "duration"
      ],
      "properties": {
        "start": {
          "$ref": "#/$defs/Time"
        },
        "duration": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "Rate": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "n",
        "d"
      ],
      "properties": {
        "n": {
          "type": "integer",
          "minimum": 1,
          "maximum": 240000
        },
        "d": {
          "type": "integer",
          "minimum": 1,
          "maximum": 100000
        }
      }
    },
    "Timestamp": {
      "type": "string",
      "format": "date-time",
      "pattern": "Z$"
    },
    "Version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "Namespace": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "appId",
        "tenantId",
        "workspaceId"
      ],
      "properties": {
        "appId": {
          "$ref": "#/$defs/Id"
        },
        "tenantId": {
          "$ref": "#/$defs/Id"
        },
        "workspaceId": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Extensions": {
      "type": "object",
      "propertyNames": {
        "pattern": "^[a-z][a-z0-9_.-]{1,127}$"
      },
      "additionalProperties": true,
      "maxProperties": 64
    },
    "EntityRef": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "Source": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "kind",
        "id",
        "version",
        "streamId"
      ],
      "properties": {
        "kind": {
          "enum": [
            "asset",
            "sequence",
            "imageDocument"
          ]
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "streamId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Color": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "primaries",
        "transfer",
        "matrix",
        "range",
        "bitDepth",
        "alpha"
      ],
      "properties": {
        "primaries": {
          "type": "string",
          "minLength": 1,
          "maxLength": 64
        },
        "transfer": {
          "type": "string",
          "minLength": 1,
          "maxLength": 64
        },
        "matrix": {
          "type": "string",
          "minLength": 1,
          "maxLength": 64
        },
        "range": {
          "enum": [
            "full",
            "limited",
            "unspecified"
          ]
        },
        "bitDepth": {
          "type": "integer",
          "minimum": 1,
          "maximum": 32
        },
        "alpha": {
          "enum": [
            "none",
            "straight",
            "premultiplied"
          ]
        }
      }
    },
    "Stream": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "type",
        "codec",
        "profile",
        "width",
        "height",
        "pixelFormat",
        "timeBase",
        "startPTS",
        "duration",
        "nominalFrameRate",
        "variableFrameRate",
        "rotationDeg",
        "color",
        "sampleRate",
        "channels",
        "channelLayout"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "type": {
          "enum": [
            "video",
            "audio",
            "image"
          ]
        },
        "codec": {
          "type": "string",
          "minLength": 1,
          "maxLength": 128
        },
        "profile": {
          "anyOf": [
            {
              "type": "string",
              "minLength": 0,
              "maxLength": 128
            },
            {
              "type": "null"
            }
          ]
        },
        "width": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            {
              "type": "null"
            }
          ]
        },
        "height": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            {
              "type": "null"
            }
          ]
        },
        "pixelFormat": {
          "anyOf": [
            {
              "type": "string",
              "minLength": 0,
              "maxLength": 64
            },
            {
              "type": "null"
            }
          ]
        },
        "timeBase": {
          "$ref": "#/$defs/Time"
        },
        "startPTS": {
          "$ref": "#/$defs/I64"
        },
        "duration": {
          "$ref": "#/$defs/Time"
        },
        "nominalFrameRate": {
          "anyOf": [
            {
              "$ref": "#/$defs/Rate"
            },
            {
              "type": "null"
            }
          ]
        },
        "variableFrameRate": {
          "type": "boolean"
        },
        "rotationDeg": {
          "enum": [
            0,
            90,
            180,
            270
          ]
        },
        "color": {
          "anyOf": [
            {
              "$ref": "#/$defs/Color"
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleRate": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 8000,
              "maximum": 384000
            },
            {
              "type": "null"
            }
          ]
        },
        "channels": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 64
            },
            {
              "type": "null"
            }
          ]
        },
        "channelLayout": {
          "anyOf": [
            {
              "type": "string",
              "minLength": 0,
              "maxLength": 128
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Proxy": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "blobHash",
        "pipelineHash",
        "sourceVersion",
        "ptsMapBlobHash",
        "width",
        "height",
        "frameRate",
        "colorPolicy"
      ],
      "properties": {
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "pipelineHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceVersion": {
          "$ref": "#/$defs/U64"
        },
        "ptsMapBlobHash": {
          "$ref": "#/$defs/Hash"
        },
        "width": {
          "type": "integer",
          "minimum": 2,
          "maximum": 8192
        },
        "height": {
          "type": "integer",
          "minimum": 2,
          "maximum": 8192
        },
        "frameRate": {
          "$ref": "#/$defs/Rate"
        },
        "colorPolicy": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Asset": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "name",
        "kind",
        "originalBlobHash",
        "externalLocator",
        "streams",
        "proxyRefs",
        "rightsId",
        "contentFingerprint",
        "status"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "name": {
          "type": "string",
          "minLength": 1,
          "maxLength": 256
        },
        "kind": {
          "enum": [
            "video",
            "audio",
            "image",
            "mask",
            "model3d"
          ]
        },
        "originalBlobHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "externalLocator": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "streams": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Stream"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "proxyRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Proxy"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "rightsId": {
          "$ref": "#/$defs/Id"
        },
        "contentFingerprint": {
          "$ref": "#/$defs/Hash"
        },
        "status": {
          "enum": [
            "ready",
            "missing",
            "quarantined"
          ]
        }
      }
    },
    "Blob": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "hash",
        "bytes",
        "mime",
        "packagePath",
        "role"
      ],
      "properties": {
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "bytes": {
          "$ref": "#/$defs/U64"
        },
        "mime": {
          "type": "string",
          "minLength": 1,
          "maxLength": 128
        },
        "packagePath": {
          "type": "string",
          "pattern": "^(assets|originals|fonts|proxies|renders|thumbnails|snapshots|extensions)/[A-Za-z0-9_./-]+$"
        },
        "role": {
          "enum": [
            "original",
            "generated",
            "proxy",
            "render",
            "mask",
            "font",
            "thumbnail",
            "snapshot",
            "evidence",
            "ptsMap"
          ]
        }
      }
    },
    "TimeMap": {
      "oneOf": [
        {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "rate"
          ],
          "properties": {
            "kind": {
              "const": "linear"
            },
            "rate": {
              "$ref": "#/$defs/Time"
            }
          }
        },
        {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "knots",
            "interpolation"
          ],
          "properties": {
            "kind": {
              "const": "piecewise"
            },
            "knots": {
              "type": "array",
              "items": {
                "type": "object",
                "additionalProperties": false,
                "required": [
                  "u",
                  "v"
                ],
                "properties": {
                  "u": {
                    "$ref": "#/$defs/Time"
                  },
                  "v": {
                    "$ref": "#/$defs/Time"
                  }
                }
              },
              "minItems": 2,
              "maxItems": 2048
            },
            "interpolation": {
              "const": "linear"
            }
          }
        }
      ]
    },
    "Clip": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "trackId",
        "name",
        "source",
        "timelineRange",
        "sourceRange",
        "timeMap",
        "enabled",
        "lockedFields",
        "linkGroupId",
        "selectionGroupId",
        "effectIds",
        "shotId",
        "candidateId",
        "provenanceId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "trackId": {
          "$ref": "#/$defs/Id"
        },
        "name": {
          "type": "string",
          "minLength": 0,
          "maxLength": 256
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "timelineRange": {
          "$ref": "#/$defs/Range"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "timeMap": {
          "$ref": "#/$defs/TimeMap"
        },
        "enabled": {
          "type": "boolean",
          "default": true
        },
        "lockedFields": {
          "type": "array",
          "items": {
            "type": "string",
            "minLength": 1,
            "maxLength": 256
          },
          "minItems": 0,
          "maxItems": 256
        },
        "linkGroupId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "selectionGroupId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "effectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 256
        },
        "shotId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "candidateId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "provenanceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Gap": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "trackId",
        "timelineRange"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "trackId": {
          "$ref": "#/$defs/Id"
        },
        "timelineRange": {
          "$ref": "#/$defs/Range"
        }
      }
    },
    "Item": {
      "oneOf": [
        {
          "$ref": "#/$defs/Clip"
        },
        {
          "$ref": "#/$defs/Gap"
        }
      ]
    },
    "Track": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "sequenceId",
        "name",
        "kind",
        "order",
        "locked",
        "muted",
        "solo",
        "syncLock",
        "targeted",
        "busId",
        "items"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "sequenceId": {
          "$ref": "#/$defs/Id"
        },
        "name": {
          "type": "string",
          "minLength": 0,
          "maxLength": 256
        },
        "kind": {
          "enum": [
            "video",
            "audio",
            "caption"
          ]
        },
        "order": {
          "type": "integer",
          "minimum": 0,
          "maximum": 2147483647
        },
        "locked": {
          "type": "boolean",
          "default": false
        },
        "muted": {
          "type": "boolean",
          "default": false
        },
        "solo": {
          "type": "boolean",
          "default": false
        },
        "syncLock": {
          "type": "boolean",
          "default": true
        },
        "targeted": {
          "type": "boolean",
          "default": false
        },
        "busId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "items": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Item"
          },
          "minItems": 0,
          "maxItems": 100000
        }
      }
    },
    "Sequence": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "name",
        "version",
        "canvas",
        "frameRate",
        "sampleRate",
        "workingColor",
        "outputColor",
        "backgroundRGBA",
        "duration",
        "tracks",
        "markerIds",
        "masterBusId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "name": {
          "type": "string",
          "minLength": 0,
          "maxLength": 256
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "canvas": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "width",
            "height",
            "pixelAspect"
          ],
          "properties": {
            "width": {
              "type": "integer",
              "minimum": 2,
              "maximum": 8192,
              "multipleOf": 2
            },
            "height": {
              "type": "integer",
              "minimum": 2,
              "maximum": 8192,
              "multipleOf": 2
            },
            "pixelAspect": {
              "$ref": "#/$defs/Time"
            }
          }
        },
        "frameRate": {
          "$ref": "#/$defs/Rate"
        },
        "sampleRate": {
          "const": 48000
        },
        "workingColor": {
          "const": "linear-rec709"
        },
        "outputColor": {
          "const": "rec709"
        },
        "backgroundRGBA": {
          "type": "array",
          "items": {
            "type": "number",
            "minimum": 0,
            "maximum": 1
          },
          "minItems": 4,
          "maxItems": 4
        },
        "duration": {
          "$ref": "#/$defs/Time"
        },
        "tracks": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Track"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "markerIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "masterBusId": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Keyframe": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "param",
        "localTime",
        "value",
        "interpolation",
        "easing"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "param": {
          "type": "string",
          "minLength": 1,
          "maxLength": 128
        },
        "localTime": {
          "$ref": "#/$defs/Time"
        },
        "value": {
          "oneOf": [
            {
              "type": "number",
              "minimum": -1000000000000,
              "maximum": 1000000000000
            },
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 2,
              "maxItems": 2
            },
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 3,
              "maxItems": 3
            },
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 4,
              "maxItems": 4
            },
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            }
          ]
        },
        "interpolation": {
          "enum": [
            "hold",
            "linear"
          ]
        },
        "easing": {
          "type": "null"
        }
      }
    },
    "TransformParams": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "translateX",
        "translateY",
        "scaleX",
        "scaleY",
        "rotationDeg",
        "anchorX",
        "anchorY"
      ],
      "properties": {
        "translateX": {
          "type": "number",
          "minimum": -1000000000000,
          "maximum": 1000000000000,
          "default": 0
        },
        "translateY": {
          "type": "number",
          "minimum": -1000000000000,
          "maximum": 1000000000000,
          "default": 0
        },
        "scaleX": {
          "type": "number",
          "minimum": 0,
          "maximum": 100,
          "default": 1,
          "exclusiveMinimum": 0
        },
        "scaleY": {
          "type": "number",
          "minimum": 0,
          "maximum": 100,
          "default": 1,
          "exclusiveMinimum": 0
        },
        "rotationDeg": {
          "type": "number",
          "minimum": -360000,
          "maximum": 360000,
          "default": 0
        },
        "anchorX": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "default": 0.5
        },
        "anchorY": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "default": 0.5
        }
      }
    },
    "CropParams": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "left",
        "top",
        "right",
        "bottom"
      ],
      "properties": {
        "left": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "default": 0
        },
        "top": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "default": 0
        },
        "right": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "default": 1
        },
        "bottom": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "default": 1
        }
      }
    },
    "TextParams": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "fontRef",
        "fontSizePx",
        "fillRGBA",
        "strokePx",
        "shadow",
        "lineHeight",
        "letterSpacing",
        "alignment",
        "layoutRect"
      ],
      "properties": {
        "fontRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "fontSizePx": {
          "type": "number",
          "minimum": 6,
          "maximum": 1024,
          "default": 48
        },
        "fillRGBA": {
          "type": "array",
          "items": {
            "type": "number",
            "minimum": 0,
            "maximum": 1
          },
          "minItems": 4,
          "maxItems": 4
        },
        "strokePx": {
          "type": "number",
          "minimum": 0,
          "maximum": 32,
          "default": 0
        },
        "shadow": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "offsetX",
            "offsetY",
            "blurPx",
            "rgba"
          ],
          "properties": {
            "offsetX": {
              "type": "number",
              "minimum": -1024,
              "maximum": 1024
            },
            "offsetY": {
              "type": "number",
              "minimum": -1024,
              "maximum": 1024
            },
            "blurPx": {
              "type": "number",
              "minimum": 0,
              "maximum": 128
            },
            "rgba": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": 0,
                "maximum": 1
              },
              "minItems": 4,
              "maxItems": 4
            }
          }
        },
        "lineHeight": {
          "type": "number",
          "minimum": 0.5,
          "maximum": 4,
          "default": 1.2
        },
        "letterSpacing": {
          "type": "number",
          "minimum": -100,
          "maximum": 100,
          "default": 0
        },
        "alignment": {
          "enum": [
            "left",
            "center",
            "right",
            "justify"
          ]
        },
        "layoutRect": {
          "type": "array",
          "items": {
            "type": "number",
            "minimum": -1000000000000,
            "maximum": 1000000000000
          },
          "minItems": 4,
          "maxItems": 4
        }
      }
    },
    "Effect": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "owner",
        "pluginVersion",
        "enabled",
        "keyframes",
        "extensions",
        "type",
        "parameters"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "owner": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "id"
          ],
          "properties": {
            "kind": {
              "enum": [
                "clip",
                "track",
                "sequence",
                "caption",
                "imageLayer",
                "audioBus"
              ]
            },
            "id": {
              "$ref": "#/$defs/Id"
            }
          }
        },
        "pluginVersion": {
          "$ref": "#/$defs/Version"
        },
        "enabled": {
          "type": "boolean"
        },
        "keyframes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Keyframe"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "extensions": {
          "$ref": "#/$defs/Extensions"
        },
        "type": {
          "type": "string",
          "minLength": 1,
          "maxLength": 256
        },
        "parameters": {
          "type": "object"
        }
      },
      "oneOf": [
        {
          "properties": {
            "type": {
              "const": "transform2d"
            },
            "parameters": {
              "$ref": "#/$defs/TransformParams"
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "crop"
            },
            "parameters": {
              "$ref": "#/$defs/CropParams"
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "opacity"
            },
            "parameters": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "value"
              ],
              "properties": {
                "value": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 1,
                  "default": 1
                }
              }
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "colorBasic"
            },
            "parameters": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "exposureStops",
                "contrast",
                "saturation"
              ],
              "properties": {
                "exposureStops": {
                  "type": "number",
                  "minimum": -8,
                  "maximum": 8,
                  "default": 0
                },
                "contrast": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 2,
                  "default": 1
                },
                "saturation": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 2,
                  "default": 1
                }
              }
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "mask"
            },
            "parameters": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "blobHash",
                "transform",
                "invert"
              ],
              "properties": {
                "blobHash": {
                  "$ref": "#/$defs/Hash"
                },
                "transform": {
                  "type": "array",
                  "items": {
                    "type": "number",
                    "minimum": -1000000000000,
                    "maximum": 1000000000000
                  },
                  "minItems": 6,
                  "maxItems": 6
                },
                "invert": {
                  "type": "boolean",
                  "default": false
                }
              }
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "gain"
            },
            "parameters": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "gainDb"
              ],
              "properties": {
                "gainDb": {
                  "type": "number",
                  "minimum": -96,
                  "maximum": 12,
                  "default": 0
                }
              }
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "pan"
            },
            "parameters": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "value",
                "mode"
              ],
              "properties": {
                "value": {
                  "type": "number",
                  "minimum": -1,
                  "maximum": 1,
                  "default": 0
                },
                "mode": {
                  "enum": [
                    "monoEqualPower",
                    "stereoBalance"
                  ]
                }
              }
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "limiter"
            },
            "parameters": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "ceilingDb",
                "lookaheadMs",
                "releaseMs"
              ],
              "properties": {
                "ceilingDb": {
                  "type": "number",
                  "minimum": -24,
                  "maximum": 0,
                  "default": -1
                },
                "lookaheadMs": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 20,
                  "default": 5
                },
                "releaseMs": {
                  "type": "number",
                  "minimum": 1,
                  "maximum": 2000,
                  "default": 100
                }
              }
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "textStyle"
            },
            "parameters": {
              "$ref": "#/$defs/TextParams"
            }
          }
        },
        {
          "properties": {
            "type": {
              "type": "string",
              "pattern": "^[a-z][a-z0-9_.-]+/[A-Za-z0-9_.-]+$"
            },
            "parameters": {
              "type": "object",
              "maxProperties": 256
            }
          }
        }
      ]
    },
    "Transition": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "sequenceId",
        "trackId",
        "leftClipId",
        "rightClipId",
        "cut",
        "before",
        "after",
        "kind",
        "curve",
        "missingHandlePolicy",
        "enabled"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "sequenceId": {
          "$ref": "#/$defs/Id"
        },
        "trackId": {
          "$ref": "#/$defs/Id"
        },
        "leftClipId": {
          "$ref": "#/$defs/Id"
        },
        "rightClipId": {
          "$ref": "#/$defs/Id"
        },
        "cut": {
          "$ref": "#/$defs/Time"
        },
        "before": {
          "$ref": "#/$defs/Time"
        },
        "after": {
          "$ref": "#/$defs/Time"
        },
        "kind": {
          "enum": [
            "dissolve",
            "audioEqualPower"
          ]
        },
        "curve": {
          "const": "linear"
        },
        "missingHandlePolicy": {
          "enum": [
            "reject",
            "freeze"
          ]
        },
        "enabled": {
          "type": "boolean"
        }
      }
    },
    "Anchor": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "kind",
        "clipId",
        "range"
      ],
      "properties": {
        "kind": {
          "enum": [
            "absolute",
            "clipLocal",
            "source"
          ]
        },
        "clipId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "range": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Caption": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "trackId",
        "timelineRange",
        "text",
        "language",
        "styleEffectId",
        "anchor",
        "manualFields",
        "words",
        "speakerId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "trackId": {
          "$ref": "#/$defs/Id"
        },
        "timelineRange": {
          "$ref": "#/$defs/Range"
        },
        "text": {
          "type": "string",
          "minLength": 0,
          "maxLength": 4096
        },
        "language": {
          "type": "string",
          "pattern": "^[A-Za-z]{2,8}(-[A-Za-z0-9]{1,8})*$"
        },
        "styleEffectId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "anchor": {
          "$ref": "#/$defs/Anchor"
        },
        "manualFields": {
          "type": "array",
          "items": {
            "enum": [
              "text",
              "timing",
              "style",
              "speaker"
            ]
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "words": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "text",
              "sourceRange",
              "confidence"
            ],
            "properties": {
              "text": {
                "type": "string",
                "minLength": 0,
                "maxLength": 128
              },
              "sourceRange": {
                "$ref": "#/$defs/Range"
              },
              "confidence": {
                "type": "number",
                "minimum": 0,
                "maximum": 1
              }
            }
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "speakerId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "AudioBus": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "name",
        "inputBusIds",
        "gainDb",
        "pan",
        "effectIds",
        "muted",
        "solo",
        "outputBusId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "name": {
          "type": "string",
          "minLength": 0,
          "maxLength": 256
        },
        "inputBusIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "gainDb": {
          "type": "number",
          "minimum": -96,
          "maximum": 12,
          "default": 0
        },
        "pan": {
          "type": "number",
          "minimum": -1,
          "maximum": 1,
          "default": 0
        },
        "effectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 256
        },
        "muted": {
          "type": "boolean"
        },
        "solo": {
          "type": "boolean"
        },
        "outputBusId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Marker": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "sequenceId",
        "label",
        "colorRGBA",
        "anchor",
        "time",
        "duration",
        "ripple"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "sequenceId": {
          "$ref": "#/$defs/Id"
        },
        "label": {
          "type": "string",
          "minLength": 0,
          "maxLength": 1024
        },
        "colorRGBA": {
          "type": "array",
          "items": {
            "type": "number",
            "minimum": 0,
            "maximum": 1
          },
          "minItems": 4,
          "maxItems": 4
        },
        "anchor": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "clipId"
          ],
          "properties": {
            "kind": {
              "enum": [
                "absolute",
                "clipLocal"
              ]
            },
            "clipId": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Id"
                },
                {
                  "type": "null"
                }
              ]
            }
          }
        },
        "time": {
          "$ref": "#/$defs/Time"
        },
        "duration": {
          "$ref": "#/$defs/Time"
        },
        "ripple": {
          "type": "boolean"
        }
      }
    },
    "Rights": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "kind",
        "assetIds",
        "holder",
        "statement",
        "evidenceBlobHash",
        "providerTermsRef",
        "allowedUses",
        "territories",
        "expiresAt",
        "consentId",
        "verified"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "userAttestation",
            "license",
            "providerTerms"
          ]
        },
        "assetIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "holder": {
          "type": "string",
          "minLength": 0,
          "maxLength": 1024
        },
        "statement": {
          "type": "string",
          "minLength": 0,
          "maxLength": 16384
        },
        "evidenceBlobHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "providerTermsRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "allowedUses": {
          "type": "array",
          "items": {
            "enum": [
              "edit",
              "export",
              "upload",
              "redistribute"
            ]
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "territories": {
          "type": "array",
          "items": {
            "type": "string",
            "minLength": 0,
            "maxLength": 64
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "expiresAt": {
          "anyOf": [
            {
              "$ref": "#/$defs/Timestamp"
            },
            {
              "type": "null"
            }
          ]
        },
        "consentId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified": {
          "type": "boolean"
        }
      }
    },
    "LinkGroup": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "anchorClipId",
        "members",
        "syncPolicy"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "anchorClipId": {
          "$ref": "#/$defs/Id"
        },
        "members": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "clipId",
              "offset"
            ],
            "properties": {
              "clipId": {
                "$ref": "#/$defs/Id"
              },
              "offset": {
                "$ref": "#/$defs/Time"
              }
            }
          },
          "minItems": 2,
          "maxItems": 100000
        },
        "syncPolicy": {
          "enum": [
            "preserve",
            "allowOutOfSync"
          ]
        }
      }
    },
    "SelectionGroup": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "memberClipIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "memberClipIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 100000
        }
      }
    },
    "Layer": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "parentId",
        "kind",
        "sourceRef",
        "text",
        "transform",
        "opacity",
        "blendMode",
        "maskRef",
        "effectIds",
        "locked",
        "visible"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "parentId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "kind": {
          "enum": [
            "raster",
            "text",
            "group",
            "vector"
          ]
        },
        "sourceRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/EntityRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "text": {
          "anyOf": [
            {
              "type": "string",
              "minLength": 0,
              "maxLength": 65536
            },
            {
              "type": "null"
            }
          ]
        },
        "transform": {
          "type": "array",
          "items": {
            "type": "number",
            "minimum": -1000000000000,
            "maximum": 1000000000000
          },
          "minItems": 6,
          "maxItems": 6
        },
        "opacity": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "default": 1
        },
        "blendMode": {
          "enum": [
            "normal",
            "multiply",
            "screen"
          ]
        },
        "maskRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "effectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 256
        },
        "locked": {
          "type": "boolean"
        },
        "visible": {
          "type": "boolean"
        }
      }
    },
    "ImageDocument": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "width",
        "height",
        "color",
        "rootLayerIds",
        "layers",
        "fontRefs"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "width": {
          "type": "integer",
          "minimum": 1,
          "maximum": 32768
        },
        "height": {
          "type": "integer",
          "minimum": 1,
          "maximum": 32768
        },
        "color": {
          "const": "linear-rec709"
        },
        "rootLayerIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "layers": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Layer"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "fontRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 100000
        }
      }
    },
    "Font": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "family",
        "style",
        "hash",
        "licenseRef",
        "embedAllowed",
        "fallbackFamilies"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "family": {
          "type": "string",
          "minLength": 1,
          "maxLength": 256
        },
        "style": {
          "type": "string",
          "minLength": 1,
          "maxLength": 128
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "licenseRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "embedAllowed": {
          "type": "boolean"
        },
        "fallbackFamilies": {
          "type": "array",
          "items": {
            "type": "string",
            "minLength": 1,
            "maxLength": 256
          },
          "minItems": 0,
          "maxItems": 32
        }
      }
    },
    "ModelRef": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "profileId",
        "packageHash",
        "weightLicenseId",
        "engineLicenseId"
      ],
      "properties": {
        "profileId": {
          "$ref": "#/$defs/Id"
        },
        "packageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "weightLicenseId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "engineLicenseId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Reference": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "assetRef",
        "role",
        "rightsId"
      ],
      "properties": {
        "assetRef": {
          "$ref": "#/$defs/EntityRef"
        },
        "role": {
          "enum": [
            "subject",
            "style",
            "firstFrame",
            "lastFrame",
            "audio",
            "source"
          ]
        },
        "rightsId": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Brief": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "locale",
        "audience",
        "objective",
        "targetDuration",
        "aspect",
        "deliveryPresetId",
        "requiredFacts",
        "forbiddenClaims",
        "referenceRefs",
        "brandPolicy",
        "audioPolicy",
        "textPolicy",
        "budget",
        "purpose",
        "purposePayload"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "locale": {
          "type": "string",
          "minLength": 1,
          "maxLength": 64
        },
        "audience": {
          "type": "string",
          "minLength": 0,
          "maxLength": 1024
        },
        "objective": {
          "type": "string",
          "minLength": 1,
          "maxLength": 4096
        },
        "targetDuration": {
          "$ref": "#/$defs/Time"
        },
        "aspect": {
          "enum": [
            "9:16",
            "16:9",
            "1:1"
          ]
        },
        "deliveryPresetId": {
          "$ref": "#/$defs/Id"
        },
        "requiredFacts": {
          "type": "array",
          "items": {
            "type": "string",
            "minLength": 0,
            "maxLength": 2048
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "forbiddenClaims": {
          "type": "array",
          "items": {
            "type": "string",
            "minLength": 0,
            "maxLength": 2048
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "referenceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Reference"
          },
          "minItems": 0,
          "maxItems": 64
        },
        "brandPolicy": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "palette",
            "logoAssetRef",
            "safeArea",
            "restrictedTopics",
            "rightsAttestationId"
          ],
          "properties": {
            "palette": {
              "type": "array",
              "items": {
                "type": "string",
                "minLength": 0,
                "maxLength": 64
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "logoAssetRef": {
              "anyOf": [
                {
                  "$ref": "#/$defs/EntityRef"
                },
                {
                  "type": "null"
                }
              ]
            },
            "safeArea": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": 0,
                "maximum": 1
              },
              "minItems": 4,
              "maxItems": 4
            },
            "restrictedTopics": {
              "type": "array",
              "items": {
                "type": "string",
                "minLength": 0,
                "maxLength": 256
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "rightsAttestationId": {
              "$ref": "#/$defs/Id"
            }
          }
        },
        "audioPolicy": {
          "enum": [
            "originalOnly",
            "providedMusic",
            "generated",
            "silent"
          ]
        },
        "textPolicy": {
          "const": "editableOverlay"
        },
        "budget": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "currency",
            "maxMicros"
          ],
          "properties": {
            "currency": {
              "type": "string",
              "pattern": "^[A-Z]{3}$"
            },
            "maxMicros": {
              "$ref": "#/$defs/U64"
            }
          }
        },
        "purpose": {
          "enum": [
            "productAd",
            "social",
            "story",
            "tutorial",
            "photoMotion",
            "musicVisual"
          ]
        },
        "purposePayload": {
          "type": "object"
        }
      },
      "oneOf": [
        {
          "properties": {
            "purpose": {
              "const": "productAd"
            },
            "purposePayload": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "productName",
                "verifiedClaims",
                "audience",
                "cta",
                "referenceAssetId",
                "offer",
                "endDate",
                "brandPalette"
              ],
              "properties": {
                "productName": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 256
                },
                "verifiedClaims": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 1024
                  },
                  "minItems": 1,
                  "maxItems": 5
                },
                "audience": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "cta": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "referenceAssetId": {
                  "$ref": "#/$defs/Id"
                },
                "offer": {
                  "anyOf": [
                    {
                      "type": "string",
                      "minLength": 0,
                      "maxLength": 1024
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "endDate": {
                  "anyOf": [
                    {
                      "$ref": "#/$defs/Timestamp"
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "brandPalette": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "minLength": 0,
                    "maxLength": 64
                  },
                  "minItems": 0,
                  "maxItems": 100000
                }
              }
            }
          }
        },
        {
          "properties": {
            "purpose": {
              "const": "social"
            },
            "purposePayload": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "platform",
                "audience",
                "topic",
                "hookText",
                "payoff",
                "trendReference",
                "captionsStyle"
              ],
              "properties": {
                "platform": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 128
                },
                "audience": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "topic": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "hookText": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "payoff": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "trendReference": {
                  "anyOf": [
                    {
                      "$ref": "#/$defs/EntityRef"
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "captionsStyle": {
                  "anyOf": [
                    {
                      "type": "string",
                      "minLength": 0,
                      "maxLength": 128
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              }
            }
          }
        },
        {
          "properties": {
            "purpose": {
              "const": "story"
            },
            "purposePayload": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "logline",
                "characterIds",
                "location",
                "conflict",
                "ending",
                "rating",
                "dialogue",
                "continuityBible"
              ],
              "properties": {
                "logline": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 4096
                },
                "characterIds": {
                  "type": "array",
                  "items": {
                    "$ref": "#/$defs/Id"
                  },
                  "minItems": 1,
                  "maxItems": 100000
                },
                "location": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 2048
                },
                "conflict": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 4096
                },
                "ending": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 4096
                },
                "rating": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 64
                },
                "dialogue": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "minLength": 0,
                    "maxLength": 4096
                  },
                  "minItems": 0,
                  "maxItems": 100000
                },
                "continuityBible": {
                  "anyOf": [
                    {
                      "type": "string",
                      "minLength": 0,
                      "maxLength": 16384
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              }
            }
          }
        },
        {
          "properties": {
            "purpose": {
              "const": "tutorial"
            },
            "purposePayload": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "learningGoal",
                "steps",
                "factsSourceRefs",
                "targetAudience",
                "screenRecordingAsset",
                "safetyWarnings"
              ],
              "properties": {
                "learningGoal": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 2048
                },
                "steps": {
                  "type": "array",
                  "items": {
                    "type": "object",
                    "additionalProperties": false,
                    "required": [
                      "action",
                      "expectedResult"
                    ],
                    "properties": {
                      "action": {
                        "type": "string",
                        "minLength": 1,
                        "maxLength": 2048
                      },
                      "expectedResult": {
                        "type": "string",
                        "minLength": 1,
                        "maxLength": 2048
                      }
                    }
                  },
                  "minItems": 1,
                  "maxItems": 100
                },
                "factsSourceRefs": {
                  "type": "array",
                  "items": {
                    "$ref": "#/$defs/EntityRef"
                  },
                  "minItems": 1,
                  "maxItems": 100000
                },
                "targetAudience": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "screenRecordingAsset": {
                  "anyOf": [
                    {
                      "$ref": "#/$defs/EntityRef"
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "safetyWarnings": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "minLength": 0,
                    "maxLength": 2048
                  },
                  "minItems": 0,
                  "maxItems": 100000
                }
              }
            }
          }
        },
        {
          "properties": {
            "purpose": {
              "const": "photoMotion"
            },
            "purposePayload": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "photoAssetId",
                "rightsConfirmed",
                "motionRegion",
                "cameraMotion",
                "preserveRegions",
                "loop",
                "endFrameAssetId"
              ],
              "properties": {
                "photoAssetId": {
                  "$ref": "#/$defs/Id"
                },
                "rightsConfirmed": {
                  "type": "boolean"
                },
                "motionRegion": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 4096
                },
                "cameraMotion": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "preserveRegions": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "minLength": 0,
                    "maxLength": 1024
                  },
                  "minItems": 0,
                  "maxItems": 100000
                },
                "loop": {
                  "type": "boolean"
                },
                "endFrameAssetId": {
                  "anyOf": [
                    {
                      "$ref": "#/$defs/Id"
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              }
            }
          }
        },
        {
          "properties": {
            "purpose": {
              "const": "musicVisual"
            },
            "purposePayload": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "audioAssetId",
                "musicRights",
                "beatGridRef",
                "mood",
                "visualMotif",
                "targetRange",
                "lyrics",
                "bpm"
              ],
              "properties": {
                "audioAssetId": {
                  "$ref": "#/$defs/Id"
                },
                "musicRights": {
                  "$ref": "#/$defs/Id"
                },
                "beatGridRef": {
                  "$ref": "#/$defs/Hash"
                },
                "mood": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "visualMotif": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 2048
                },
                "targetRange": {
                  "$ref": "#/$defs/Range"
                },
                "lyrics": {
                  "anyOf": [
                    {
                      "type": "string",
                      "minLength": 0,
                      "maxLength": 16384
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "bpm": {
                  "anyOf": [
                    {
                      "type": "number",
                      "minimum": 1,
                      "maximum": 400
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              }
            }
          }
        }
      ]
    },
    "Character": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "name",
        "appearanceRef",
        "motivation",
        "constraints",
        "rightsId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "name": {
          "type": "string",
          "minLength": 1,
          "maxLength": 256
        },
        "appearanceRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/EntityRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "motivation": {
          "type": "string",
          "minLength": 0,
          "maxLength": 4096
        },
        "constraints": {
          "type": "array",
          "items": {
            "type": "string",
            "minLength": 0,
            "maxLength": 2048
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "rightsId": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Script": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "briefId",
        "title",
        "sceneIds",
        "language",
        "status"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "briefId": {
          "$ref": "#/$defs/Id"
        },
        "title": {
          "type": "string",
          "minLength": 0,
          "maxLength": 256
        },
        "sceneIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "language": {
          "type": "string",
          "minLength": 0,
          "maxLength": 64
        },
        "status": {
          "enum": [
            "draft",
            "approved",
            "stale"
          ]
        }
      }
    },
    "Scene": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "scriptId",
        "order",
        "summary",
        "characterIds",
        "shotIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "scriptId": {
          "$ref": "#/$defs/Id"
        },
        "order": {
          "type": "integer",
          "minimum": 0,
          "maximum": 2147483647
        },
        "summary": {
          "type": "string",
          "minLength": 0,
          "maxLength": 16384
        },
        "characterIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "shotIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 100000
        }
      }
    },
    "Shot": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "sceneId",
        "order",
        "purposeBeat",
        "targetTimelineRange",
        "subjectRefs",
        "setting",
        "action",
        "camera",
        "lighting",
        "continuity",
        "captionPlan",
        "voicePlan",
        "musicRange",
        "generationMode",
        "firstFrameRef",
        "lastFrameRef",
        "referenceRefs",
        "targetProviderProfileId",
        "selectedCandidateId",
        "lockedFields"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "sceneId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "order": {
          "type": "integer",
          "minimum": 0,
          "maximum": 2147483647
        },
        "purposeBeat": {
          "type": "string",
          "minLength": 0,
          "maxLength": 1024
        },
        "targetTimelineRange": {
          "$ref": "#/$defs/Range"
        },
        "subjectRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/EntityRef"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "setting": {
          "type": "string",
          "minLength": 0,
          "maxLength": 4096
        },
        "action": {
          "type": "string",
          "minLength": 0,
          "maxLength": 4096
        },
        "camera": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "size",
            "motion",
            "lensIntent"
          ],
          "properties": {
            "size": {
              "type": "string",
              "minLength": 0,
              "maxLength": 128
            },
            "motion": {
              "type": "string",
              "minLength": 0,
              "maxLength": 1024
            },
            "lensIntent": {
              "type": "string",
              "minLength": 0,
              "maxLength": 1024
            }
          }
        },
        "lighting": {
          "type": "string",
          "minLength": 0,
          "maxLength": 2048
        },
        "continuity": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "characterRefs",
            "wardrobe",
            "screenDirection",
            "propRefs",
            "mustPreserve"
          ],
          "properties": {
            "characterRefs": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/EntityRef"
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "wardrobe": {
              "type": "string",
              "minLength": 0,
              "maxLength": 2048
            },
            "screenDirection": {
              "type": "string",
              "minLength": 0,
              "maxLength": 1024
            },
            "propRefs": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/EntityRef"
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "mustPreserve": {
              "type": "array",
              "items": {
                "type": "string",
                "minLength": 0,
                "maxLength": 2048
              },
              "minItems": 0,
              "maxItems": 100000
            }
          }
        },
        "captionPlan": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "text",
              "range"
            ],
            "properties": {
              "text": {
                "type": "string",
                "minLength": 0,
                "maxLength": 4096
              },
              "range": {
                "$ref": "#/$defs/Range"
              }
            }
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "voicePlan": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "text",
              "range",
              "speakerId"
            ],
            "properties": {
              "text": {
                "type": "string",
                "minLength": 0,
                "maxLength": 4096
              },
              "range": {
                "$ref": "#/$defs/Range"
              },
              "speakerId": {
                "anyOf": [
                  {
                    "$ref": "#/$defs/Id"
                  },
                  {
                    "type": "null"
                  }
                ]
              }
            }
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "musicRange": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "generationMode": {
          "enum": [
            "t2v",
            "i2v",
            "firstLast",
            "reference"
          ]
        },
        "firstFrameRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/EntityRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "lastFrameRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/EntityRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "referenceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Reference"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "targetProviderProfileId": {
          "$ref": "#/$defs/Id"
        },
        "selectedCandidateId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "lockedFields": {
          "type": "array",
          "items": {
            "type": "string",
            "minLength": 0,
            "maxLength": 256
          },
          "minItems": 0,
          "maxItems": 100000
        }
      }
    },
    "GenerationRecord": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "candidateIds",
        "provider",
        "modelId",
        "providerModelVersion",
        "templateId",
        "templateVersion",
        "promptHash",
        "promptText",
        "negativePrompt",
        "parameterProfileId",
        "inputAssetRefs",
        "seed",
        "parameters",
        "rights",
        "outputAssetRefs",
        "jobId",
        "createdAt"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "candidateIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "provider": {
          "$ref": "#/$defs/Id"
        },
        "modelId": {
          "$ref": "#/$defs/Id"
        },
        "providerModelVersion": {
          "anyOf": [
            {
              "type": "string",
              "minLength": 0,
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "templateId": {
          "$ref": "#/$defs/Id"
        },
        "templateVersion": {
          "type": "string",
          "minLength": 1,
          "maxLength": 64
        },
        "promptHash": {
          "$ref": "#/$defs/Hash"
        },
        "promptText": {
          "anyOf": [
            {
              "type": "string",
              "minLength": 0,
              "maxLength": 65536
            },
            {
              "type": "null"
            }
          ]
        },
        "negativePrompt": {
          "anyOf": [
            {
              "type": "string",
              "minLength": 0,
              "maxLength": 8192
            },
            {
              "type": "null"
            }
          ]
        },
        "parameterProfileId": {
          "$ref": "#/$defs/Id"
        },
        "inputAssetRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/EntityRef"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "seed": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "parameters": {
          "type": "object",
          "maxProperties": 128
        },
        "rights": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "attestationId",
            "licenseSnapshotRef"
          ],
          "properties": {
            "attestationId": {
              "$ref": "#/$defs/Id"
            },
            "licenseSnapshotRef": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            }
          }
        },
        "outputAssetRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/EntityRef"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "createdAt": {
          "$ref": "#/$defs/Timestamp"
        }
      }
    },
    "RetainedSource": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "kind",
        "id",
        "version",
        "definitionBlobHash",
        "dependencyBlobHashes"
      ],
      "properties": {
        "kind": {
          "enum": [
            "asset",
            "sequence",
            "imageDocument"
          ]
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "definitionBlobHash": {
          "$ref": "#/$defs/Hash"
        },
        "dependencyBlobHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 100000
        }
      }
    }
  }
}
```

| 工程包/本地DB边界 | 导出、导入与revision映射的具体规则 |
| --- | --- |
| 默认便携包 | 默认只含当前快照、当前所需不可变资源及retainedSources闭包；不含SQLite/WAL、secret、上传URL/书签、Context KV、运行lease、审批凭据/预算reservation。外链只留opaque locator ID和缺失清单，新设备重新授权定位。原件/字体嵌入需用户选择与许可；模型仍只有引用。 |
| 会话选配 | 用户显式选择sessions才导出SessionArchive{schemaVersion:2.0.0,archiveId,sessionHeaders,branchEdges,turns,events,revisionMap,contentIndex}，正文是否导出另选；contentIncluded=false时所有contentRef为脱敏占位ID，不留正文blob。Run只作historical记录，进行中任务写interruptedOnExport；审批/remote task binding/凭据/可执行tool body不导出，导入后不resume副作用。 |
| 会话与revision的保留/排除 | 每个branch baseTimelineRevision、Proposal.baseRevision、message中的实体引用都经revisionMap关联originProject/revision/snapshotHash。未选history只保当前revision的snapshot，旧引用标unavailable而不是指向当前内容；选history才携带所引用历史快照，所有必要Blob pin一同收集。无会话包不带任何session IDs。 |
| 跨App/跨设备导入 | ImportCoordinator创建新namespace与默认新Project ID，重映射当前与冻结快照全部实体ID，按依赖从叶向根重算快照/hash。重映射仅按schema声明的ID/引用路径进行，不替换prompt/字幕中的同名字符串，也不改provider jobId、外部profileId或资源原始bytes。导入当前内容成为本地rev0；ImportRecord保存origin(archiveId,projectId,revision,hash)→local(projectId,rev0,newHash)。旧历史快照只读保留，localRevision=null，不能冒充本地已执行Command；用户cherry-pick才产生本地新revision。 |
| RevisionMap最小记录 | 每条为{originProjectId,originRevision,originSnapshotHash,localProjectId,localRevision:null\|I64,importedSnapshotHash,availability:current\|historical\|unavailable}；只含审计引用不含权限。恢复导入Session时先映射scope，片段不在导入集合则scope invalid，用户重选后才开新Run；所有旧审批失效。 |
| 设计包与审计journal | journal/commands.jsonl仅CommandArchive{commandId,origin,revisionBefore,revisionAfter,payloadHash,changedEntityIds,eventIds,redactedSummary}，不导出原payload/newFileToken。若选history，inverse snapshots可以读但不能原样执行旧Undo；新项目undo栈从空开始。SQLite只作本机执行/索引与事件恢复真相，工程包不会混入临时会话数据库。生命周期RestoreVersion只在本机命令存储使用独立payload_format，导出审计journal仍不带可执行正文；导入时不得回放。 |
| DB与JSON一致性 | Project.revision/U64写SQLite前校验≤I64_MAX。project_heads/revisions.snapshot_hash对应同一canonical JSON中的revision；Sequence.version/Asset.version是实体版本，不强等于Project.revision。每Command提交同时维护entity_versions(ns,projectId,entityId,version,kind,contentHash,tombstoned)。事件、receipt和文档投影同事务；文件先发布后DB窗口靠journal恢复，绝不声称跨文件/DB原子。 |

| 跨端/多App不兼容或资源缺失 | 读取、编辑、导出决定 |
| --- | --- |
| Schema版本 | 本地有精确2.0.0 validator则全校验；已登记旧版用copy-on-write迁移，写MigrationReport后保原包。高major或未知闭合minor不猜字段：只显示manifest/封面、保原bytes并拒绝编辑；“只读”不意味着能渲染未知内容。没有已知schema不能先删未知键另存。 |
| 同schema但App功能不同 | 取requiredFeatures∩宿主能力；缺nest/复杂效果的简版App默认项目只读，但可查看受支持内容并原样导出包。用户可显式创建“降级副本”执行CapabilityTransform，删除/烘焙/替代每项列入diff，赋新Project ID与capability记录，原项目不受损。 |
| 缺媒体/代理/字体 | missing source用离线卡，不替换内容；原件缺失但代理有可低清编辑，原件导出拒绝，明确代理交付需批准并标记。字体必须按hash命中；字体缺失展示fallback预览水印/警告，最终导出需装hash匹配字体，或用户确认替代字体的新revision并重算断行；组件商业许可缺口按1C仅风险提示。 |
| 缺Effect/plugin或版本 | 保留参数与原hash，预览显示不支持标记；不能悄然关闭效果声称一致。可选：安装受信已授权插件、用原平台批准生成的烘焙资产、或创建明确bypass的新revision；bypass不是原片等价渲染。未知shader/脚本不会因项目携带代码自动加载。 |
| 缺codec/model/provider | codec按第7节受控fallback/归一，仍不支持则阻导出；缺本地模型只禁对应Agent不阻手动NLE。缺云profile目录只保溯源和已下载候选，不能根据归档modelId自行连接新服务。地区策略不同要求重新报价/上传确认。 |

迁移1.0→2.0为纯数据函数：深拷贝原快照；保留所有源hash、trim、caption文字/手改标记和实体版本；补briefs/scripts/scenes/characters/retainedSources为空集合，defaultFontRef=null；旧GenerationRecord无prompt正文时补promptText=null、negativePrompt=null、parameterProfileId=legacy-unresolved而不是编造历史。存在旧nest却没有冻结定义时列SOURCE_VERSION_MISSING，要求用户定位原快照，不自动绑定最新。完成结构/语义校验后才能保存新包；资源问题保留在MigrationReport，最终渲染仍受门禁。此处1.0是本方案旧合成格式，不声称兼容未知第三方或未定义的所有历史工程。

合成验证方法、证据与放行门禁见第13节。完整Schema已有定义；尚未生成/编译生产Dart实体和原生媒体代码。结构验证通过也不等于项目媒体/字体实际存在或能在手机导出。
