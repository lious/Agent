"""Offline TEST ONLY: deterministic public Ed25519 seeds via cryptography.
No native Dart signing helper, downloaded executable, service or credentials.
Run from any directory; --check compares deterministic checked-in bytes.
"""
import base64
import copy
import hashlib
import json
from pathlib import Path
import sys
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat

HERE = Path(__file__).parent
NS = dict(appId='studio', tenantId='test', workspaceId='local')
TYPE = 'application/vnd.studio.filmcraft.import.v1+json'
KEYS = [Ed25519PrivateKey.from_private_bytes(bytes((i+n)%256 for i in range(32))) for n in range(3)]
def raw(x): return json.dumps(x, ensure_ascii=False, separators=(',', ':')).encode()
def digest(x): return 'sha256:'+hashlib.sha256(x).hexdigest()
def b64(x): return base64.b64encode(x).decode()
def policy(indices=(0,), threshold=1):
 return dict(policyVersion='filmcraft-import-v1', policyEpoch=1, appId='studio', namespace=NS,
  threshold=threshold, trustedSigners=[dict(publicKeyBase64=b64(pk:=KEYS[i].public_key().public_bytes(Encoding.Raw,PublicFormat.Raw)),keyFingerprint=digest(pk),role='filmCraftPublisher',notBefore=10,notAfter=10000,revoked=False) for i in indices],maxEnvelopeBytes=4194304,maxPayloadBytes=2097152,maxFileBytes=1048576)

def pack():
 film=dict(schemaVersion='1.0.0',id='camera.test',version='1.0.0',namespace=NS,family='camera_craft',title='测试镜头',tags=[],narrativeUses=[],counterExamples=[],parameterSlots=[],capabilityMappings=[],steps=[dict(id='a',action='analyze',dependsOn=[],toolId='media.analyze',argumentsTemplateHash='sha256:'+'0'*64,outputSchemaHash='sha256:'+'1'*64,budgetPolicy='inheritOnly')],requiredTools=['media.analyze'],requiredFeatures=[],reviewChecks=[],license=dict(codeLicense='unknown',weightLicense=None,termsHash='sha256:'+'0'*64,attributionText='unverified test assertion',sourceUrls=['https://example.invalid/never-fetched']),provenanceRefs=[],signatureRef=None,testFixturesHash='')
 manifest=dict(version='1.0.0',contentType='filmCraft',requiredTools=['media.analyze'],inputSchema=dict(type='object',properties={},required=[],additionalProperties=False),outputSchema=dict(type='string'),testFixtures={},payloadPath='film-skill.json')
 return film,manifest,dict(cases=[dict(input={},expectedOutput='ok')])
def payload(film=None, manifest=None, fixtures=None, raw_files=None):
 f,m,t=pack();f=copy.deepcopy(film or f);m=copy.deepcopy(manifest or m);t=copy.deepcopy(fixtures or t)
 ft=raw(t);fh=digest(ft);f['testFixturesHash']=fh;m['testFixtures']=dict(path='test-fixtures.json',sha256=fh)
 files=raw_files or {'film-skill.json':raw(f),'skill-manifest.json':raw(m),'test-fixtures.json':ft}
 return dict(schemaVersion='1.0.0',contentType='filmCraft',skillId='camera.test',version='1.0.0',manifestHash=digest(files['skill-manifest.json']),entrypoint='film-skill.json',files=[dict(path=p,mediaType='application/json',byteLength=len(b),sha256=digest(b),data=b64(b)) for p,b in files.items()],licenseEvidence=[])
def envelope(p=None, indices=(0,), body=None, typ=TYPE):
 b=body if body is not None else raw(p if p is not None else payload());tb=typ.encode();pae=b'DSSEv1 '+str(len(tb)).encode()+b' '+tb+b' '+str(len(b)).encode()+b' '+b
 return dict(payloadType=typ,payload=b64(b),signatures=[dict(keyid='untrusted-hint',sig=b64(KEYS[i].sign(pae))) for i in indices])

cases={}
def add(name, env, expected=None): cases[name]=dict(envelope=b64(raw(env)),expected=expected)
add('valid',envelope());add('twoKeys',envelope(indices=(0,1)));add('duplicateKey',envelope(indices=(0,0)),'SIGNATURE');add('attacker',envelope(indices=(2,)),'SIGNATURE');add('unsigned',envelope(indices=()))
e=envelope();e['payload']=b64(base64.b64decode(e['payload'])+b' ');add('tamper',e,'SIGNATURE')
e=envelope();e['signatures'][0]['sig']=b64(bytes(64));e['signed']=True;add('invalidSigned',e,'SIGNATURE')
add('whitespaceUnicode',envelope(body=b' \n'+raw(payload())+b'\n '))
for name,change in [
 ('traversal',lambda p:p['files'][0].update(path='../film-skill.json')),
 ('absolutePath',lambda p:p['files'][0].update(path='/film-skill.json')),
 ('duplicatePath',lambda p:p['files'][0].update(path='skill-manifest.json')),
 ('hashMismatch',lambda p:p['files'][0].update(sha256='0'*64)),
 ('lengthMismatch',lambda p:p['files'][0].update(byteLength=1)),
 ('oversizedFileClaim',lambda p:p['files'][0].update(byteLength=1048577)),
 ('signedPayloadClaim',lambda p:p.update(signed=True)),
 ('externalEntrypoint',lambda p:p.update(entrypoint='https://example.invalid/x')),
 ('base64File',lambda p:p['files'][0].update(data='A===')),
]:
 p=payload();change(p);add(name,envelope(p),None if name in ('valid',) else 'ANY')
f,m,t=pack();f['unknown']=True;add('filmSchema',envelope(payload(film=f)),'SCHEMA')
f,m,t=pack();m['inputSchema']={'$ref':'https://example.invalid/never'};add('remoteSchema',envelope(payload(manifest=m)),'SCHEMA')
f,m,t=pack();m['inputSchema']={'type':'integer','const':9007199254740993};t['cases'][0]['input']=9007199254740993;add('precision',envelope(payload(manifest=m,fixtures=t)),'ENCODING')
for name,body in [('duplicateJson',b'{"schemaVersion":"1.0.0","schemaVersion":"1.0.0"}'),('utf8',b'\xff'),('bom',b'\xef\xbb\xbf{}'),('surrogate',b'{"a":"\\ud800"}'),('depth',b'['*34+b'0'+b']'*34)]:add(name,envelope(body=body),'ANY')
p=payload();p['licenseEvidence']=[{'path':'../license','sha256':'0'*64}];add('licenseEvidencePath',envelope(p),'ANY')
f,m,t=pack();m['inputSchema']={'type':'integer','const':4};t['cases'][0]['input']=3;add('fixtureMismatch',envelope(payload(manifest=m,fixtures=t)),'SCHEMA')
e=envelope();e['signatures']*=9;add('signatureCount',e,'ANY')
f,m,t=pack();defs={'leaf':True}
for i in range(15):
 target='leaf' if i==0 else 'n'+str(i-1);defs['n'+str(i)]={'type':'object','properties':{p:{'$ref':'#/$defs/'+target} for p in ('a','b')},'additionalProperties':False}
m['inputSchema']={'$defs':defs,'$ref':'#/$defs/n14'};add('schemaWork',envelope(payload(manifest=m)),'LIMIT')
# Bounds are generated in the browser from this signed payload to avoid megabytes
# of redundant source fixtures. A smaller App policy bounds the SAME valid bytes.
result=dict(note='TEST ONLY public deterministic seeds 00..1f, 01..20, 02..21; no production roots',namespace=NS,policies=dict(one=policy(),two=policy((0,1),2),empty=policy(())),cases=cases)
text=json.dumps(result,ensure_ascii=False,indent=2)+'\n';path=HERE/'fixtures.json'
if '--check' in sys.argv:
 assert path.read_text()==text,'regenerate fixtures'
else:path.write_text(text)
