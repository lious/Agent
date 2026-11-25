#!/usr/bin/env python3
"""Owned fixture: actual SIGKILL around persistent undo/redo transactions.
Unmodified current code executes all normal/reopen checks. Only the pre-COMMIT
barrier uses an explicitly instrumented temporary library mirror, never users DBs.
"""
import argparse,datetime,hashlib,json,os,select,shutil,subprocess,tempfile
from pathlib import Path
from urllib.parse import urljoin
ROOT=Path(__file__).resolve().parents[2]
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--report',type=Path,required=True);args=parser.parse_args();checks=[]
 with tempfile.TemporaryDirectory(prefix='command-history-kill-') as tmp:
  root=Path(tmp);configpath=ROOT/'.dart_tool/package_config.json';config=json.loads(configpath.read_text())
  for p in config['packages']:p['rootUri']=urljoin(configpath.as_uri(),p['rootUri'])
  current=root/'current.json';current.write_text(json.dumps(config))
  mirror=root/'store';shutil.copytree(ROOT/'packages/studio_store/lib',mirror/'lib');store=mirror/'lib/studio_store.dart';source=store.read_text();target='        _pinBlobs(after);';assert source.count(target)==1
  injection="        fixtureIo.File('/dev/stdout').writeAsStringSync('UNCOMMITTED\\n');\n        fixtureIo.stdin.readByteSync();\n"
  source="import 'dart:io' as fixtureIo;\n"+source.replace(target,injection+target);store.write_text(source)
  altered=json.loads(json.dumps(config));next(p for p in altered['packages'] if p['name']=='studio_store')['rootUri']=mirror.as_uri()+'/'
  alteredpath=root/'altered.json';alteredpath.write_text(json.dumps(altered))
  worker=root/'worker.dart';worker.write_text("""import 'dart:io';import 'dart:convert';import 'package:studio_store/studio_store.dart';import 'package:studio_document/studio_document.dart';
void main(List<String>a){final ns=Namespace('history','local','kill');final r=DocumentRepository.open(a[0],ns);if(a[1]=='setup')r.create(ProjectDocument.empty(namespace:ns,projectId:'p',title:'base'));final w=r.acquireWriter('p','worker',expectedEpoch:r.writerEpoch('p'));
if(a[1]=='setup'){for(final title in ['A','B']){r.rename(writer:w,commandId:title,receiptKey:title,expectedRevision:r.read('p')!.revision,title:title);}}
if(a[1].startsWith('undo')){final h=r.commandHistory('p');r.undoCommand(writer:w,commandId:'u',receiptKey:'u',expectedRevision:r.read('p')!.revision,targetCommandId:h.undoCommandId!);}
if(a[1]=='redo'){final h=r.commandHistory('p');r.redoCommand(writer:w,commandId:'r',receiptKey:'r',expectedRevision:r.read('p')!.revision,undoCommandId:h.redoUndoCommandId!);}
if(a[1]=='undoWait'){File('/dev/stdout').writeAsStringSync('COMMITTED\\n');stdin.readByteSync();}
final h=r.commandHistory('p');print(jsonEncode({'title':r.read('p')!.title,'revision':r.read('p')!.revision.toString(),'undo':h.undoDepth,'redo':h.redoDepth}));r.close();}
""")
  db=root/'db'
  def command(mode,conf=current):return ['dart',f'--packages={conf}',str(worker),str(db),mode]
  def run(mode):
   p=subprocess.run(command(mode),cwd=ROOT,capture_output=True,text=True,timeout=60)
   assert p.returncode==0,p.stderr
   return json.loads(p.stdout)
  def kill(mode,conf,marker):
   p=subprocess.Popen(command(mode,conf),cwd=ROOT,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
   try:
    assert select.select([p.stdout],[],[],60)[0],'barrier timeout'
    line=p.stdout.readline().strip();assert line==marker,(line,p.stderr.read())
    p.kill();p.communicate(timeout=10);assert p.returncode==-9
   finally:
    if p.poll() is None:p.kill();p.communicate(timeout=10)
   checks.append({'phase':mode,'marker':marker,'SIGKILL':True,'instrumentedMirrorOnly':conf==alteredpath})
  assert run('setup')=={'title':'B','revision':'2','undo':2,'redo':0}
  kill('undo',alteredpath,'UNCOMMITTED');assert run('read')=={'title':'B','revision':'2','undo':2,'redo':0}
  kill('undoWait',current,'COMMITTED');assert run('read')=={'title':'A','revision':'3','undo':1,'redo':1}
  kill('redo',alteredpath,'UNCOMMITTED');assert run('read')=={'title':'A','revision':'3','undo':1,'redo':1}
  restored=run('redo');assert restored=={'title':'B','revision':'4','undo':2,'redo':0}
  checks.append({'phase':'unmodified-reopen-redo','actual':restored})
  report={'asOf':datetime.datetime.now().astimezone().isoformat(),'timezone':'Asia/Shanghai','result':'passed','checks':checks,'instrumentedMirrorSha256':hashlib.sha256(source.encode()).hexdigest(),'scope':'Actual3 SIGKILLs, two pre-COMMIT instrumented owned-mirror transactions and one after real unmodified COMMIT; current unmodified reopen each time, no DB outside temp fixture','fullTaskComplete':False}
  args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
