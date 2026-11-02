"""Native Android build, JDK17 + official SDK34; no Gradle/Maven dependencies."""
from pathlib import Path
import subprocess,zipfile,os,shutil,hashlib,struct,json
ROOT=Path(__file__).resolve().parent
CONFIG=json.loads((ROOT/'local_tools.json').read_text(encoding='utf-8')) if (ROOT/'local_tools.json').exists() else {}
SDK=Path(os.environ.get('FPGA_ANDROID_SDK',CONFIG.get('sdkRoot',str(ROOT.parent/'android_sdk'))))
JAVA=Path(os.environ.get('FPGA_JAVA_HOME',CONFIG.get('javaHome','C:/Program Files/Java/jdk-17')))/'bin'
TOOLS=SDK/'build-tools/android-14'
ANDROID=SDK/'platform/android-34/android.jar'
BUILD=ROOT/'build';BUILD.mkdir(exist_ok=True)
CLASSES=BUILD/'classes';CLASSES.mkdir(exist_ok=True)
ENV=os.environ.copy();ENV['JAVA_HOME']=str(JAVA.parent);ENV['PATH']=str(JAVA)+';'+ENV.get('PATH','')
def run(*args):
 print('RUN',Path(str(args[0])).name,flush=True)
 subprocess.run([str(x) for x in args],cwd=ROOT,env=ENV,check=True)
manifest=ROOT/'AndroidManifest.xml'
content=manifest.read_text(encoding='utf-8')
if 'android:icon=' not in content:
 content=content.replace('android:label="FPGA 乐器助手"','android:label="FPGA 乐器助手" android:icon="@drawable/ic_app"')
 manifest.write_text(content,encoding='utf-8')
run(JAVA/'javac.exe','-encoding','UTF-8','-source','8','-target','8','-bootclasspath',str(ANDROID)+';'+str(TOOLS/'core-lambda-stubs.jar'),'-d',CLASSES,*sorted((ROOT/'src').rglob('*.java')))
TEST=BUILD/'tests';TEST.mkdir(exist_ok=True)
run(JAVA/'javac.exe','-encoding','UTF-8','-d',TEST,ROOT/'src/cn/fpga/instrument/Protocol.java',ROOT/'src/cn/fpga/instrument/Recording.java',ROOT/'src/cn/fpga/instrument/Notes.java',*sorted((ROOT/'tests').glob('*.java')))
run(JAVA/'java.exe','-cp',TEST,'ProtocolTest')
run(JAVA/'java.exe','-cp',TEST,'RecordingTest')
run(JAVA/'java.exe','-cp',TEST,'NotesTest')
jar=BUILD/'app.jar'
with zipfile.ZipFile(jar,'w',zipfile.ZIP_DEFLATED) as z:
 for f in CLASSES.rglob('*.class'):z.write(f,f.relative_to(CLASSES).as_posix())
run(JAVA/'java.exe','-cp',TOOLS/'lib/d8.jar','com.android.tools.r8.D8','--lib',ANDROID,'--min-api','23','--output',BUILD,jar)
unsigned=BUILD/'unsigned.apk'
run(TOOLS/'aapt2.exe','compile',ROOT/'res/drawable/ic_app.xml','-o',BUILD)
PACKAGE=BUILD/'package';(PACKAGE/'res/drawable').mkdir(parents=True,exist_ok=True)
run(TOOLS/'aapt2.exe','link','--output-to-dir','-o',PACKAGE,'--manifest',manifest,'-I',ANDROID,BUILD/'drawable_ic_app.xml.flat','--version-code','5','--version-name','0.5.0')
with zipfile.ZipFile(unsigned,'w',zipfile.ZIP_DEFLATED) as z:
 for f in PACKAGE.rglob('*'):
  if f.is_file():z.write(f,f.relative_to(PACKAGE).as_posix(),compress_type=zipfile.ZIP_STORED if f.name=='resources.arsc' else zipfile.ZIP_DEFLATED)
 z.write(BUILD/'classes.dex','classes.dex')
aligned=BUILD/'aligned.apk';apk=BUILD/'FPGA_Instrument_Assistant_v0.5.0.apk'
# Native ZIP writers on this host crash; align stored entries with standard ZIP extra fields.
with zipfile.ZipFile(unsigned) as src,zipfile.ZipFile(aligned,'w') as out:
 for old in src.infolist():
  info=zipfile.ZipInfo(old.filename);info.compress_type=old.compress_type
  offset=out.fp.tell()+30+len(old.filename.encode('utf-8'))
  if info.compress_type==zipfile.ZIP_STORED and offset%4:
   pad=(-(offset+4))%4;info.extra=struct.pack('<HH',0xffff,pad)+bytes(pad)
  out.writestr(info,src.read(old.filename))
with zipfile.ZipFile(aligned) as z,aligned.open('rb') as stream:
 for info in z.infolist():
  if info.compress_type==zipfile.ZIP_STORED:
   stream.seek(info.header_offset);header=stream.read(30)
   name_len,extra_len=struct.unpack_from('<HH',header,26)
   assert (info.header_offset+30+name_len+extra_len)%4==0
KEY=ROOT/'signing/local-debug.jks';KEY.parent.mkdir(exist_ok=True)
if not KEY.exists():run(JAVA/'keytool.exe','-genkeypair','-keystore',KEY,'-storepass','android','-keypass','android','-alias','androiddebugkey','-keyalg','RSA','-keysize','2048','-validity','3650','-dname','CN=FPGA Instrument Local Debug,O=Student Project,C=CN')
run(JAVA/'java.exe','-jar',TOOLS/'lib/apksigner.jar','sign','--ks',KEY,'--ks-pass','pass:android','--key-pass','pass:android','--out',apk,aligned)
run(JAVA/'java.exe','-jar',TOOLS/'lib/apksigner.jar','verify','--verbose',apk)
run(TOOLS/'aapt.exe','dump','badging',apk)
print('APK',apk,'SHA256',hashlib.sha256(apk.read_bytes()).hexdigest(),flush=True)
