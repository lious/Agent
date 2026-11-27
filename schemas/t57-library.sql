-- T57_LIBRARY_DDL_BEGIN
-- workspace w5 -> w6；事务迁移，引用CAS blob内容不可变，事件/outbox同原库。
CREATE TABLE library_versions (
 namespace TEXT NOT NULL,library_id TEXT NOT NULL,kind TEXT NOT NULL
 CHECK(kind IN ('character','filmSkill','musicRecipe')),entity_id TEXT NOT NULL,
 version TEXT NOT NULL,body_hash TEXT NOT NULL,
 PRIMARY KEY(namespace,library_id,kind,entity_id,version)
);
CREATE TRIGGER library_body_immutable BEFORE UPDATE ON library_versions
BEGIN SELECT RAISE(ABORT,'IMMUTABLE_VERSION'); END;
CREATE TABLE library_heads (
 namespace TEXT NOT NULL,library_id TEXT NOT NULL,kind TEXT NOT NULL,
 entity_id TEXT NOT NULL,head_version TEXT NOT NULL,
 PRIMARY KEY(namespace,library_id,kind,entity_id),
 FOREIGN KEY(namespace,library_id,kind,entity_id,head_version)
 REFERENCES library_versions(namespace,library_id,kind,entity_id,version)
);
CREATE TABLE character_look_index (
 namespace TEXT NOT NULL,library_id TEXT NOT NULL,kind TEXT NOT NULL CHECK(kind='character'),
 asset_id TEXT NOT NULL,asset_version TEXT NOT NULL,look_id TEXT NOT NULL,body_hash TEXT NOT NULL,
 PRIMARY KEY(namespace,library_id,asset_id,asset_version,look_id),
 FOREIGN KEY(namespace,library_id,kind,asset_id,asset_version)
 REFERENCES library_versions(namespace,library_id,kind,entity_id,version)
);
CREATE TABLE model_adapter_bindings (
 namespace TEXT NOT NULL,library_id TEXT NOT NULL,kind TEXT NOT NULL CHECK(kind='character'),
 asset_id TEXT NOT NULL,asset_version TEXT NOT NULL,binding_id TEXT NOT NULL,
 body_hash TEXT NOT NULL,base_fingerprint TEXT,
 PRIMARY KEY(namespace,library_id,asset_id,asset_version,binding_id),
 FOREIGN KEY(namespace,library_id,kind,asset_id,asset_version)
 REFERENCES library_versions(namespace,library_id,kind,entity_id,version)
);
CREATE TABLE portrait_rights_versions (
 namespace TEXT NOT NULL,rights_id TEXT NOT NULL,version TEXT NOT NULL,body_hash TEXT NOT NULL,
 PRIMARY KEY(namespace,rights_id,version)
);
CREATE TABLE portrait_rights_live (
 namespace TEXT NOT NULL,rights_id TEXT NOT NULL,epoch TEXT NOT NULL,
 state TEXT NOT NULL CHECK(state IN ('active','revoked','expired','unknown')),
 checked_at TEXT,lease_until TEXT,
 PRIMARY KEY(namespace,rights_id)
);
CREATE TABLE library_project_pins (
 namespace TEXT NOT NULL,project_id TEXT NOT NULL,revision TEXT NOT NULL,
 library_id TEXT NOT NULL,kind TEXT NOT NULL,entity_id TEXT NOT NULL,version TEXT NOT NULL,
 effective_ref_hash TEXT NOT NULL,
 PRIMARY KEY(namespace,project_id,revision,library_id,kind,entity_id,version,effective_ref_hash),
 FOREIGN KEY(namespace,library_id,kind,entity_id,version)
 REFERENCES library_versions(namespace,library_id,kind,entity_id,version)
);
CREATE TABLE audio_candidates (
 namespace TEXT NOT NULL,id TEXT NOT NULL,plan_hash TEXT NOT NULL,state TEXT NOT NULL,
 manifest_hash TEXT,record_version TEXT NOT NULL,
 PRIMARY KEY(namespace,id),CHECK(state IN ('processing','ready','rejected','selected','quarantined'))
);
CREATE TABLE license_decisions (
 namespace TEXT NOT NULL,id TEXT NOT NULL,context_hash TEXT NOT NULL,body_hash TEXT NOT NULL,
 state TEXT NOT NULL CHECK(state IN ('allow','block','needsReview')),valid_until TEXT,
 PRIMARY KEY(namespace,id)
);
CREATE VIRTUAL TABLE craft_fts USING fts5(namespace UNINDEXED,library_id UNINDEXED,
 skill_id UNINDEXED,version UNINDEXED,title,tags,uses,counterexamples);
-- ACL先在授权version集合中过滤，再join FTS结果；namespace列存在不代表自动有ACL。
-- 沿用artifact_dependencies登记rights/model/skill版本选择器，撤销走10A denylist/outbox。
-- seq/version数字比较仍用BigInt或规范非负串length,value排序，skill语义版本用SemVer比较器。
-- T57_LIBRARY_DDL_END
