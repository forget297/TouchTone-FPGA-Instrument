package cn.fpga.instrument;

import android.Manifest;
import android.app.*;
import android.bluetooth.*;
import android.bluetooth.le.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.os.*;
import android.provider.Settings;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class MainActivity extends Activity {
    private static final UUID SERVICE=UUID.fromString("12345678-1234-5678-1234-56789abcdef0");
    private static final UUID CHARACTERISTIC=UUID.fromString("12345678-1234-5678-1234-56789abcdef1");
    private static final UUID RECORDER=UUID.fromString("12345678-1234-5678-1234-56789abcdef2");
    private static final UUID CCCD=UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");
    private static final String[] NOTES=Notes.NAMES;
    private int noteCapacity=12,octave=0;
    private final Handler ui=new Handler(Looper.getMainLooper());
    private final Protocol.Decoder decoder=new Protocol.Decoder();
    private final ArrayDeque<Command> queue=new ArrayDeque<>();
    private final ArrayList<Button> actions=new ArrayList<>();
    private final HashSet<String> seen=new HashSet<>();
    private final int[] mappings=new int[12];
    private final StringBuilder history=new StringBuilder();
    private BluetoothAdapter adapter;
    private BluetoothLeScanner scanner;
    private BluetoothGatt gatt;
    private BluetoothGattCharacteristic channel,recordChannel;
    private final boolean[] held=new boolean[32];
    private Runnable heartbeat;
    private boolean servicesStarted,recordBusy,manualCapture,stopRequested,stopSent,paused;
    private Button stopRecordButton;
    private long captureStarted;
    private int maxRecordBytes=2812500;
    private int recordSeq,recordCmd,downloadOffset;
    private Success recordSuccess;
    private Runnable recordTimeout;
    private final Runnable recordPoll=this::pollRecording;
    private long recordDeadline,expectedCrc;
    private byte[] recordingPcm;
    private File lastWav;
    private boolean fastDownload,windowActive,windowAck;
    private int windowEnd,windowSeq,windowRetries;
    private long downloadStarted;
    private long lastProgressUpdate;
    private Runnable windowTimeout;
    private android.media.MediaPlayer player;

    private Command pending;
    private byte[] reply;
    private boolean ready,writeDone,destroyed,scanning;
    private int seq,page,scanEpoch;
    private LinearLayout body,devices;
    private TextView state,logView;
    private String last="尚未连接";
    private String scoreName="半音阶练习";
    private int[] score=demoScore();
    private int uploadCount,uploadTotal;
    private Runnable ackTimeout,connectTimeout;
    interface Success {void accept(byte[] result);}
    static class Command {
        final int seq,cmd,arg,lo,hi; final String label; final Success success;
        Command(int seq,int cmd,int arg,int lo,int hi,String label,Success success){
            this.seq=seq;this.cmd=cmd;this.arg=arg;this.lo=lo;this.hi=hi;this.label=label;this.success=success;
        }
    }
    static int[] demoScore(){int[] e=new int[32];for(int i=0;i<32;i++)e[i]=16+i%12;return e;}
    @Override public void onCreate(Bundle b){
        super.onCreate(b);Arrays.fill(mappings,-1);lastWav=latestRecording();
        BluetoothManager manager=(BluetoothManager)getSystemService(BLUETOOTH_SERVICE);
        adapter=manager==null?null:manager.getAdapter();
        build();
    }
    int dp(int n){return (int)(getResources().getDisplayMetrics().density*n+0.5f);}
    TextView text(String s,int size){TextView t=new TextView(this);t.setText(s);t.setTextSize(size);t.setTextColor(Color.rgb(30,48,56));t.setPadding(0,dp(8),0,dp(8));return t;}
    Button button(String s,Runnable r,boolean connected){
        Button b=new Button(this);b.setText(s);b.setAllCaps(false);b.setOnClickListener(v->r.run());
        if(connected){actions.add(b);b.setEnabled(ready && !recordBusy && !anyHeld() && pending==null && queue.isEmpty());}
        return b;
    }
    void build(){
        LinearLayout root=new LinearLayout(this);root.setOrientation(1);root.setPadding(dp(16),dp(14),dp(16),dp(10));root.setBackgroundColor(Color.rgb(244,248,247));
        root.addView(text("FPGA 乐器助手",25));
        root.addView(text("Tang Nano 20K  ·  蓝牙控制",13));
        state=text(last,15);state.setTextColor(Color.rgb(0,105,92));root.addView(state);
        LinearLayout tabs=new LinearLayout(this);
        String[] labels={"连接","演奏","键位","曲谱","录音"};
        for(int i=0;i<5;i++){final int n=i;Button b=button(labels[i],()->showPage(n),false);tabs.addView(b,new LinearLayout.LayoutParams(0,dp(48),1));}
        root.addView(tabs);
        ScrollView scroll=new ScrollView(this);body=new LinearLayout(this);body.setOrientation(1);body.setPadding(0,dp(10),0,dp(16));scroll.addView(body);root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
        setContentView(root);showPage(page);
    }
    void showPage(int n){
        if(page==1 && n!=1)releaseHeld();
        page=n;actions.clear();body.removeAllViews();logView=null;devices=null;
        if(n==0){
            body.addView(text("连接开发板",21));
            body.addView(text("先在 nRF Connect 中断开设备，再点扫描。两块开发板保持供电，Nano使用R11可解锁32个音；R9/R10只提供C4～B4。",15));
            body.addView(button("扫描 FPGA_BLE_UART",this::scan,false));
            body.addView(button("断开连接",()->disconnect("已主动断开"),false));
            devices=new LinearLayout(this);devices.setOrientation(1);body.addView(devices);
            body.addView(text("操作记录",18));logView=text(history.toString(),13);logView.setTextIsSelectable(true);body.addView(logView);
        } else if(n==1){
            body.addView(text("无线演奏",21));
            body.addView(text("按下发声，松开释放。关闭主板叠层可单独演奏所选音高；R11支持C4～G6共32个音。",15));
            LinearLayout octaves=new LinearLayout(this);
            for(int o=0;o<(noteCapacity+11)/12;o++){final int bank=o;octaves.addView(button((o==octave?"✓ ":"")+(o==0?"C4～B4":o==1?"C5～B5":"C6～G6"),()->{octave=bank;showPage(1);},true),new LinearLayout.LayoutParams(0,dp(52),1));}
            body.addView(octaves);
            final int begin=Notes.start(octave),end=Notes.end(octave,noteCapacity);
            for(int row=0;row<(end-begin+2)/3;row++){
                LinearLayout line=new LinearLayout(this);
                for(int col=0;col<3;col++){
                    final int key=begin+row*3+col;if(key>=end)break;Button live=new Button(this);live.setText(NOTES[key]);live.setAllCaps(false);
                    live.setOnTouchListener((v,event)->{
                        if(event.getActionMasked()==MotionEvent.ACTION_DOWN){v.getParent().requestDisallowInterceptTouchEvent(true);pressNote(key);return true;}
                        if(event.getActionMasked()==MotionEvent.ACTION_UP || event.getActionMasked()==MotionEvent.ACTION_CANCEL){v.getParent().requestDisallowInterceptTouchEvent(false);releaseNote(key);v.performClick();return true;}
                        return true;
                    });
                    line.addView(live,new LinearLayout.LayoutParams(0,dp(62),1));
                }body.addView(line);
            }
            body.addView(button("释放全部无线演奏键",this::releaseHeld,false));
            body.addView(text("定时试听",20));
            body.addView(text("点击试听一秒。试听直接选择音高，不经过触摸键映射。主板需处于普通演奏模式。",15));
            for(int row=0;row<(end-begin+2)/3;row++){
                LinearLayout line=new LinearLayout(this);
                for(int col=0;col<3;col++){final int key=begin+row*3+col;if(key>=end)break;line.addView(button(NOTES[key],()->single(1,key,232,3,"试听 "+NOTES[key],null),true),new LinearLayout.LayoutParams(0,dp(58),1));}
                body.addView(line);
            }
            body.addView(button("C4 持续五秒",()->single(1,0,136,19,"试听 C4 五秒",null),true));
            body.addView(button("停止远程音符",()->single(2,0,0,0,"停止远程音符",null),true));
            body.addView(text("停止后可能有包络尾音或回声；实体键仍按住时会继续发声。",13));
        } else if(n==2){
            body.addView(text("触摸键位设置",21));
            body.addView(text("松开所有触摸键后再修改。两个键选同一音高时共享一个声部。设置在主板复位或掉电后恢复默认。",15));
            body.addView(button("读取全部键位",this::readMappings,true));
            for(int i=0;i<12;i++){
                final int key=i;
                body.addView(text(i+" 号触摸键 · 当前 "+(mappings[i]<0?"未读取":NOTES[mappings[i]]),16));
                LinearLayout line=new LinearLayout(this);
                Spinner spinner=new Spinner(this);spinner.setAdapter(new ArrayAdapter<String>(this,android.R.layout.simple_spinner_dropdown_item,Arrays.copyOf(NOTES,noteCapacity)));spinner.setSelection(mappings[i]<0?i:mappings[i]);
                line.addView(spinner,new LinearLayout.LayoutParams(0,dp(54),1));
                line.addView(button("应用",()->setMapping(key,spinner.getSelectedItemPosition()),true),new LinearLayout.LayoutParams(dp(90),dp(54)));body.addView(line);
            }
            body.addView(button("恢复全部默认键位",()->new AlertDialog.Builder(this).setTitle("恢复默认键位？").setMessage("12个触摸键将恢复 C4～B4。").setNegativeButton("取消",null).setPositiveButton("恢复",(d,w)->resetMappings()).show(),true));
            body.addView(text("曲谱按物理键编号指引，改键位后同一曲谱的旋律也会改变。",13));
        } else if(n==3) {
            body.addView(text("曲谱下载",21));
            body.addView(text("当前："+scoreName+"\n32 个步骤 · "+scoreBeats()+" 拍",17));
            body.addView(text("上传后替换曲目0的灯光指引，不会自动发声。未安装琴键灯时可验证上传和读回。",15));
            body.addView(button("选择内置半音阶练习",()->{score=demoScore();scoreName="半音阶练习";showPage(3);},false));
            body.addView(button("从曲谱文件导入",this::pickScore,false));
            body.addView(button("上传并核对全部32步",()->new AlertDialog.Builder(this).setTitle("上传曲谱？").setMessage("将替换主板曲目0为“"+scoreName+"”。应用会自动传输并读回全部步骤。").setNegativeButton("取消",null).setPositiveButton("上传",(d,w)->uploadScore()).show(),true));
            body.addView(button("读回首个步骤",()->single(0x14,0,0,0,"读取曲谱首步骤",r->{int e=r[4]&255;require((r[5]&255)==1,"读回标记错误");message("首步骤："+((e&15)==15?"休止":(e&15)+"号键")+"，"+(e>>>4)+"拍");}),true));
            body.addView(button("恢复原曲目0",()->single(0x13,0,0,0,"恢复原曲目0",null),true));
            body.addView(text("下载曲谱保存在 FPGA 内存中：断开蓝牙仍保留，复位或掉电后丢失。当前不含在线曲库。",13));
        } else {
            body.addView(text("数字录音",21));
            body.addView(text(recordChannel==null?"需要新版 ESP32 录音固件及三根音频信号线。":"录音通道已发现",15));
            body.addView(text("可手动开始、结束，最长30秒；采样率仍为46,875Hz。录制 FPGA 实际输出音频。它会包含合成音色和已有音效，不录手机麦克风。",15));
            body.addView(button("开始录音",this::startManualRecording,true));
            stopRecordButton=button("结束录音并下载",this::stopRecording,false);body.addView(stopRecordButton);updateStopButton();
            body.addView(button("取回板上最近录音",this::recoverRecording,true));
            body.addView(button("录制一秒（触摸键演奏）",()->startRecording(false),true));
            body.addView(button("录制测试 C4",()->startRecording(true),true));
            body.addView(text("点击结束或录满后，通过蓝牙下载并核对完整CRC32。长录音下载更慢。传输期间保持应用前台；可先使用测试C4检查接线。",15));
            Button play=button("播放最近录音",this::playRecording,false);play.setEnabled(lastWav!=null);body.addView(play);
            Button save=button("保存为 WAV 文件",this::saveRecording,false);save.setEnabled(lastWav!=null);body.addView(save);
            body.addView(button("录音管理（播放／导出／删除）",this::manageRecordings,false));
            body.addView(text(lastWav==null?"尚无已校验的录音":"最近录音已存入应用，可播放或导出。",14));
            body.addView(text("换曲、键位和无线演奏操作会在录音传输期间暂停；实体触摸演奏仍由FPGA独立运行。",13));
        }
    }
    int scoreBeats(){int n=0;for(int e:score)n+=e>>>4;return n;}
    void message(String s){
        last=s;state.setText((ready?"已连接 · ":"")+s);
        history.append(s).append('\n');if(history.length()>5000)history.delete(0,history.length()-4000);
        if(logView!=null)logView.setText(history.toString());
    }
    void require(boolean ok,String msg){if(!ok)throw new IllegalArgumentException(msg);}
    void enableActions(){boolean e=ready && !recordBusy && !anyHeld() && pending==null && queue.isEmpty();for(Button b:actions)b.setEnabled(e);updateStopButton();}
    boolean permissions(){
        if(Build.VERSION.SDK_INT>=31)return checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN)==PackageManager.PERMISSION_GRANTED && checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)==PackageManager.PERMISSION_GRANTED;
        return checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED;
    }
    void scan(){
        if(!permissions()){
            String[] p=Build.VERSION.SDK_INT>=31?new String[]{Manifest.permission.BLUETOOTH_SCAN,Manifest.permission.BLUETOOTH_CONNECT}:new String[]{Manifest.permission.ACCESS_FINE_LOCATION};
            requestPermissions(p,1);return;
        }
        if(adapter==null){message("手机不支持蓝牙");return;}
        if(!adapter.isEnabled()){
            startActivity(new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE));message("打开蓝牙后再次点击扫描");return;
        }
        if(gatt!=null)disconnect("已断开旧连接，准备扫描");
        stopScan();seen.clear();if(devices!=null)devices.removeAllViews();
        scanner=adapter.getBluetoothLeScanner();if(scanner==null){message("无法启动扫描，请检查蓝牙开关");return;}
        try{
            scanning=true;scanner.startScan(null,new ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(),scanCallback);
            message("扫描中，找到设备后点击连接");
            final int epoch=++scanEpoch;
            ui.postDelayed(()->{if(scanning && scanEpoch==epoch){stopScan();message(seen.isEmpty()?"未找到设备：检查供电和其他蓝牙连接。安卓11及以下还需打开系统定位。":"扫描结束，点击设备连接");}},10000);
        }catch(Exception e){scanning=false;message("扫描失败："+e.getMessage());}
    }
    @Override public void onRequestPermissionsResult(int code,String[] p,int[] result){super.onRequestPermissionsResult(code,p,result);if(code==1){if(permissions())scan();else message("请在系统设置中允许本应用的蓝牙/附近设备权限；旧安卓还需要定位权限");}}
    final ScanCallback scanCallback=new ScanCallback(){
        @Override public void onScanResult(int type,ScanResult result){
            String name=result.getScanRecord()==null?null:result.getScanRecord().getDeviceName();
            if(!"FPGA_BLE_UART".equals(name))return;
            ui.post(()->{if(destroyed || !scanning)return;BluetoothDevice d=result.getDevice();if(!seen.add(d.getAddress()))return;
                if(devices!=null)devices.addView(button("连接 FPGA_BLE_UART\n"+d.getAddress(),()->connect(d),false));
                message("找到开发板，点击设备连接");
            });
        }
        @Override public void onScanFailed(int code){ui.post(()->{scanning=false;message("蓝牙扫描失败，错误码 "+code);});}
    };
    void stopScan(){scanEpoch++;if(scanning && scanner!=null){try{scanner.stopScan(scanCallback);}catch(Exception ignored){}}scanning=false;}
    void connect(BluetoothDevice device){
        stopScan();if(gatt!=null)disconnect("切换连接");
        message("正在连接开发板…");
        try{
            gatt=device.connectGatt(this,false,callback,BluetoothDevice.TRANSPORT_LE);
            final BluetoothGatt target=gatt;
            connectTimeout=()->{if(!ready && gatt==target)disconnect("连接超时，请确认 nRF Connect 和电脑已断开");};ui.postDelayed(connectTimeout,15000);
        }catch(Exception e){disconnect("连接失败："+e.getMessage());}
    }
    void disconnect(String reason){
        ui.removeCallbacks(recordPoll);if(windowTimeout!=null)ui.removeCallbacks(windowTimeout);windowActive=false;
        stopScan();ready=false;channel=null;recordChannel=null;servicesStarted=false;recordBusy=false;manualCapture=false;stopRequested=false;stopSent=false;recordingPcm=null;
        Arrays.fill(held,false);if(heartbeat!=null)ui.removeCallbacks(heartbeat);if(recordTimeout!=null)ui.removeCallbacks(recordTimeout);queue.clear();pending=null;reply=null;decoder.reset();Arrays.fill(mappings,-1);
        if(ackTimeout!=null)ui.removeCallbacks(ackTimeout);if(connectTimeout!=null)ui.removeCallbacks(connectTimeout);
        BluetoothGatt old=gatt;gatt=null;
        if(old!=null){try{old.disconnect();old.close();}catch(Exception ignored){}}
        enableActions();message(reason);
    }
    final BluetoothGattCallback callback=new BluetoothGattCallback(){
        @Override public void onConnectionStateChange(BluetoothGatt g,int status,int newState){ui.post(()->{
            if(destroyed || g!=gatt)return;
            if(status!=BluetoothGatt.GATT_SUCCESS || newState==BluetoothProfile.STATE_DISCONNECTED){disconnect("蓝牙已断开（"+status+"），请重新连接");return;}
            if(newState==BluetoothProfile.STATE_CONNECTED){message("已连接，正在准备控制通道…");if(!g.requestMtu(247))discover(g);}
        });}
        @Override public void onMtuChanged(BluetoothGatt g,int mtu,int status){ui.post(()->{if(!destroyed && g==gatt)discover(g);});}
        @Override public void onServicesDiscovered(BluetoothGatt g,int status){ui.post(()->{
            if(destroyed || g!=gatt)return;
            if(status!=0){disconnect("服务发现失败");return;}
            BluetoothGattService service=g.getService(SERVICE);channel=service==null?null:service.getCharacteristic(CHARACTERISTIC);
            recordChannel=service==null?null:service.getCharacteristic(RECORDER);
            if(channel==null){disconnect("找不到乐器控制服务，请检查 ESP32 固件");return;}
            BluetoothGattDescriptor d=channel.getDescriptor(CCCD);
            if(d==null || !g.setCharacteristicNotification(channel,true)){disconnect("无法启用应答通知");return;}
            boolean ok;
            if(Build.VERSION.SDK_INT>=33)ok=g.writeDescriptor(d,BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)==BluetoothStatusCodes.SUCCESS;
            else {d.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);ok=g.writeDescriptor(d);}
            if(!ok)disconnect("无法订阅通知");
        });}
        @Override public void onDescriptorWrite(BluetoothGatt g,BluetoothGattDescriptor d,int status){ui.post(()->{
            if(destroyed || g!=gatt)return;
            if(status!=0){disconnect("通知订阅失败");return;}
            ready=true;if(connectTimeout!=null)ui.removeCallbacks(connectTimeout);decoder.reset();
            noteCapacity=12;octave=0;Arrays.fill(mappings,-1);message("连接就绪，正在核对主板通信");add(0,0,0,0,"通信检查",r->{});add(0x23,0,0,0,"查询32音支持",r->{noteCapacity=Notes.capacity(r);message("主板音域："+(noteCapacity==32?"C4～G6（32音）":"C4～B4（旧版主板）"));});appendMappingReads();pump();
        });}
        @Override public void onCharacteristicWrite(BluetoothGatt g,BluetoothGattCharacteristic c,int status){ui.post(()->{
            if(destroyed || g!=gatt)return;
            if(c.getUuid().equals(RECORDER)){
                if(!recordBusy)return;
                if(status!=0 || !g.readCharacteristic(recordChannel))recordFailure("录音请求写入或读回失败");
                return;
            }
            if(pending==null)return;
            if(status!=0){disconnect("蓝牙写入失败（"+status+"），请重新连接");return;}
            writeDone=true;finishIfComplete();
        });}
        @Override public void onCharacteristicRead(BluetoothGatt g,BluetoothGattCharacteristic c,int status){byte[] v=c.getValue();recordResponse(g,status,v==null?new byte[0]:v.clone());}
        @Override public void onCharacteristicRead(BluetoothGatt g,BluetoothGattCharacteristic c,byte[] value,int status){recordResponse(g,status,value.clone());}
        @Override public void onCharacteristicChanged(BluetoothGatt g,BluetoothGattCharacteristic c){byte[] v=c.getValue();if(v!=null)receive(g,v.clone());}
        @Override public void onCharacteristicChanged(BluetoothGatt g,BluetoothGattCharacteristic c,byte[] value){receive(g,value.clone());}
    };
    void receive(BluetoothGatt g,byte[] value){ui.post(()->{
        if(destroyed || g!=gatt)return;
        if(value.length>0 && (value[0]&255)==0xa7){receiveStream(value);return;}
        for(byte[] r:decoder.feed(value)){
            if(pending!=null && Protocol.matches(r,pending.seq,pending.cmd) && reply==null){reply=r;finishIfComplete();}
        }
    });}
    void add(int cmd,int arg,int lo,int hi,String label,Success success){seq=(seq+1)&255;queue.add(new Command(seq,cmd,arg,lo,hi,label,success));}
    void single(int cmd,int arg,int lo,int hi,String label,Success success){if(!canStart())return;add(cmd,arg,lo,hi,label,success);pump();}
    boolean canStart(){if(recordBusy || anyHeld()){message("先结束无线演奏或等待录音完成");return false;}if(!ready){message("请先连接开发板");return false;}if(pending!=null || !queue.isEmpty()){message("请等待当前操作完成");return false;}return true;}
    void pump(){
        enableActions();if(!ready || recordBusy || pending!=null || queue.isEmpty())return;
        pending=queue.remove();reply=null;writeDone=false;
        final Command current=pending;byte[] bytes=Protocol.encode(current.seq,current.cmd,current.arg,current.lo,current.hi);
        message(current.label+"…");enableActions();
        try{
            boolean ok;
            if(Build.VERSION.SDK_INT>=33)ok=gatt.writeCharacteristic(channel,bytes,BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT)==BluetoothStatusCodes.SUCCESS;
            else {channel.setWriteType(BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT);channel.setValue(bytes);ok=gatt.writeCharacteristic(channel);}
            if(!ok){disconnect("发送失败，请重新连接后重试");return;}
            ackTimeout=()->{if(pending==current)disconnect("应答超时，结果未确认；请重新连接并读回配置");};ui.postDelayed(ackTimeout,3500);
        }catch(Exception e){disconnect("发送失败："+e.getMessage());}
    }
    void finishIfComplete(){
        if(pending==null || !writeDone || reply==null)return;
        ui.removeCallbacks(ackTimeout);Command current=pending;byte[] r=reply;
        pending=null;reply=null;
        int status=r[3]&255;
        if(status!=0 && !(current.cmd==0x23 && status==1)){queue.clear();Arrays.fill(held,false);if(heartbeat!=null)ui.removeCallbacks(heartbeat);message(current.label+"失败："+statusText(status));enableActions();return;}
        try{if(current.success!=null)current.success.accept(r);else message(current.label+"成功");}
        catch(Exception e){queue.clear();message("核对失败："+e.getMessage());enableActions();return;}
        if(queue.isEmpty()){enableActions();if(page==2 || (page==1 && !anyHeld()))showPage(page);}else ui.postDelayed(this::pump,20);
    }
    String statusText(int s){switch(s){case 1:return "主板不支持此命令，请使用R11";case 2:return "参数不符合主板要求";case 3:return "状态不满足，请松开触摸键或检查曲谱是否已下载";case 4:return "曲谱校验不一致，旧曲谱未替换";default:return "主板状态码 "+s;}}
    void appendMappingReads(){
        for(int i=0;i<12;i++){final int k=i;add(0x21,k,0,0,"读取 "+k+" 号键",r->{int v=r[4]&255;require(v<noteCapacity && (r[5]&255)==1,"键位响应异常");mappings[k]=v;if(k==11)message("12个键位已读回，连接就绪");});}
    }
    void readMappings(){if(!canStart())return;appendMappingReads();pump();}
    void setMapping(int key,int note){
        if(!canStart())return;
        add(0x20,key,note,0,"设置 "+key+" 号键为 "+NOTES[note],null);
        add(0x21,key,0,0,"核对键位",r->{require((r[4]&255)==note && (r[5]&255)==1,"键位未与设置一致");mappings[key]=note;message(key+"号键已设为 "+NOTES[note]+"，读回一致");});pump();
    }
    void resetMappings(){if(!canStart())return;add(0x22,0,0,0,"恢复默认键位",null);appendMappingReads();pump();}
    void uploadScore(){
        if(!canStart())return;
        final int[] expected=score.clone();List<int[]> list=Protocol.scoreCommands(expected);
        uploadCount=0;uploadTotal=list.size()+32;
        for(int[] c:list)add(c[0],c[1],c[2],c[3],"曲谱上传 "+(queue.size()+1)+"/18",r->{uploadCount++;message("传输完成 "+uploadCount+"/"+uploadTotal);});
        for(int i=0;i<32;i++){final int index=i;add(0x14,i,0,0,"核对曲谱 "+(i+1)+"/32",r->{
            require((r[4]&255)==expected[index] && (r[5]&255)==1,"第"+index+"步数据不一致");uploadCount++;
            message(index==31?"曲谱上传成功，32步已全部读回一致":"曲谱核对 "+(index+1)+"/32");
        });}pump();
    }
    void pickScore(){Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT);i.addCategory(Intent.CATEGORY_OPENABLE);i.setType("*/*");startActivityForResult(i,2);}
    @Override public void onActivityResult(int request,int result,Intent data){
        super.onActivityResult(request,result,data);
        if(request==3 && result==RESULT_OK && data!=null && lastWav!=null){
            try(InputStream in=new FileInputStream(lastWav);OutputStream out=getContentResolver().openOutputStream(data.getData())){
                byte[] b=new byte[4096];int n;while((n=in.read(b))!=-1)out.write(b,0,n);message("WAV文件已保存");
            }catch(Exception e){message("文件保存失败："+e.getMessage());}return;
        }
        if(request!=2 || result!=RESULT_OK || data==null)return;
        try(InputStream in=getContentResolver().openInputStream(data.getData())){
            ByteArrayOutputStream out=new ByteArrayOutputStream();byte[] chunk=new byte[4096];int n;
            while((n=in.read(chunk))!=-1){out.write(chunk,0,n);require(out.size()<=65536,"曲谱文件超过64KB");}
            JSONObject json=new JSONObject(new String(out.toByteArray(),StandardCharsets.UTF_8));JSONArray events=json.getJSONArray("events");require(events.length()==32,"曲谱必须有32个步骤");
            int[] parsed=new int[32];for(int i=0;i<32;i++){JSONObject event=events.getJSONObject(i);int k=event.getInt("key"),b=event.getInt("beats");require(event.get("key") instanceof Number && event.get("beats") instanceof Number && event.getDouble("key")==k && event.getDouble("beats")==b,"键号和拍数必须为整数");require((k>=0 && k<12 || k==-1) && b>=1 && b<=15,"第"+i+"步键号或拍数错误");parsed[i]=(b<<4)|(k==-1?15:k);}
            Protocol.scoreCommands(parsed);score=parsed;scoreName=json.optString("name","导入曲谱");if(scoreName.length()>60)scoreName=scoreName.substring(0,60);showPage(3);message("已导入曲谱，尚未上传");
        }catch(Exception e){message("曲谱导入失败："+e.getMessage());}
    }
    void discover(BluetoothGatt g){if(servicesStarted)return;servicesStarted=true;if(!g.discoverServices())disconnect("无法发现服务");}
    boolean anyHeld(){for(boolean h:held)if(h)return true;return false;}
    void pressNote(int key){
        if(!ready || recordBusy || (pending!=null && pending.cmd!=3 && pending.cmd!=4)){message("请先连接或等待当前操作完成");return;}
        for(Command c:queue)if(c.cmd!=3 && c.cmd!=4){message("请等待当前操作完成");return;}
        if(held[key])return;held[key]=true;
        add(3,key,0,0,"按下 "+NOTES[key],null);pump();enableActions();
        if(heartbeat!=null)ui.removeCallbacks(heartbeat);
        heartbeat=new Runnable(){public void run(){
            if(!ready || !anyHeld())return;
            for(int k=0;k<32;k++)if(held[k]){final int note=k;boolean queued=false;for(Command c:queue)if(c.cmd==3 && c.arg==k)queued=true;if(!queued)add(3,note,0,0,"保持 "+NOTES[note],r->{});}
            pump();ui.postDelayed(this,1800);
        }};ui.postDelayed(heartbeat,1800);
    }
    void releaseNote(int key){
        if(!held[key])return;held[key]=false;
        java.util.Iterator<Command> it=queue.iterator();while(it.hasNext()){Command c=it.next();if(c.cmd==3 && c.arg==key && c.label.startsWith("保持 "))it.remove();}
        if(ready)add(4,key,0,0,"松开 "+NOTES[key],null);
        if(!anyHeld() && heartbeat!=null)ui.removeCallbacks(heartbeat);pump();enableActions();
    }
    void releaseHeld(){for(int i=0;i<32;i++)if(held[i])releaseNote(i);}
    @Override public void onResume(){super.onResume();paused=false;}
    @Override public void onPause(){paused=true;releaseHeld();if(manualCapture && recordBusy)stopRecording();super.onPause();}
    void requestRecord(int cmd,int arg,int lo,int hi,Success success){
        recordCmd=cmd;seq=(seq+1)&255;recordSeq=seq;recordSuccess=success;
        byte[] req=Protocol.encode(recordSeq,cmd,arg,lo,hi);
        try{
            boolean ok;
            if(Build.VERSION.SDK_INT>=33)ok=gatt.writeCharacteristic(recordChannel,req,BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT)==BluetoothStatusCodes.SUCCESS;
            else{recordChannel.setWriteType(BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT);recordChannel.setValue(req);ok=gatt.writeCharacteristic(recordChannel);}
            if(!ok){recordFailure("录音命令发送失败");return;}
            recordTimeout=()->{if(recordBusy)disconnect("录音应答超时，请重新连接");};ui.postDelayed(recordTimeout,3500);
        }catch(Exception e){recordFailure("录音发送失败："+e.getMessage());}
    }
    void recordResponse(BluetoothGatt g,int status,byte[] value){ui.post(()->{
        if(destroyed || g!=gatt || !recordBusy)return;
        if(recordTimeout!=null)ui.removeCallbacks(recordTimeout);
        try{require(status==0,"录音读回失败");
            if(recordCmd==0x46){int code=Recording.status(value,recordSeq,recordCmd);if(code==1 || code==5){recordSuccess=null;fallbackDownload();return;}if(code==3){recordSuccess=null;retryWindow();return;}}
            byte[] payload=Recording.decode(value,recordSeq,recordCmd);Success action=recordSuccess;recordSuccess=null;if(action!=null)action.accept(payload);}
        catch(Exception e){recordFailure(e.getMessage());}
    });}
    void recordFailure(String reason){ui.removeCallbacks(recordPoll);if(windowTimeout!=null)ui.removeCallbacks(windowTimeout);windowActive=false;if(recordTimeout!=null)ui.removeCallbacks(recordTimeout);recordBusy=false;manualCapture=false;recordSuccess=null;recordingPcm=null;if(gatt!=null && ready)gatt.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_BALANCED);message("录音未完成："+reason);enableActions();}
    void updateStopButton(){if(stopRecordButton!=null)stopRecordButton.setEnabled(ready && recordBusy && manualCapture && !stopRequested);}
    void stopRecording(){
        if(!recordBusy || !manualCapture || stopRequested)return;
        stopRequested=true;updateStopButton();message("正在结束录音，稍后自动下载…");
        ui.removeCallbacks(recordPoll);if(windowTimeout!=null)ui.removeCallbacks(windowTimeout);windowActive=false;if(recordSuccess==null)ui.post(recordPoll);
        // The next poll sends STOP after any current GATT transaction completes.
    }
    void recoverRecording(){
        if(!canStart() || recordChannel==null)return;
        recordBusy=true;manualCapture=false;stopRequested=true;stopSent=false;
        recordDeadline=android.os.SystemClock.elapsedRealtime()+20000;enableActions();pollRecording();
    }
    void startManualRecording(){
        if(!canStart())return;
        if(recordChannel==null){message("没有录音服务，请更新ESP32固件");return;}
        recordBusy=true;manualCapture=false;stopRequested=false;stopSent=false;enableActions();
        requestRecord(0x45,0,0,0,r->{
            maxRecordBytes=Recording.capacity(r);
            requestRecord(0x40,0,0,0,ack->{
                manualCapture=true;stopRequested=paused;captureStarted=android.os.SystemClock.elapsedRealtime();
                recordDeadline=captureStarted+(long)maxRecordBytes*1000/93750+20000;
                message("录音已开始，请触摸演奏；上限 "+(maxRecordBytes/93750)+" 秒，点击结束保存");
                updateStopButton();ui.postDelayed(recordPoll,300);
            });
        });
    }
    void startRecording(boolean test){
        if(!canStart())return;
        if(recordChannel==null){message("没有录音服务，请先烧录ESP32新版录音固件");return;}
        if(test){single(1,0,136,19,"准备测试 C4",r->ui.postDelayed(()->startRecording(false),50));return;}
        recordBusy=true;manualCapture=false;stopRequested=false;stopSent=false;enableActions();
        message("正在采集一秒音频，请触摸演奏");recordDeadline=android.os.SystemClock.elapsedRealtime()+6000;
        requestRecord(0x40,1,0,0,r->ui.postDelayed(recordPoll,300));
    }
    void pollRecording(){
        if(!recordBusy || !ready)return;
        if(stopRequested && !stopSent){
            stopSent=true;manualCapture=false;updateStopButton();
            recordDeadline=android.os.SystemClock.elapsedRealtime()+20000;
            requestRecord(0x44,0,0,0,r->ui.postDelayed(recordPoll,250));return;
        }
        requestRecord(0x41,0,0,0,r->{
            require(r.length==14,"录音信息长度错误");int status=r[0]&255;
            if(status==1){
                require(android.os.SystemClock.elapsedRealtime()<recordDeadline,"音频采集或结束超时，检查音频线");
                if(manualCapture && !stopRequested)state.setText("已连接 · 正在录音 "+String.format(java.util.Locale.US,"%.1f",Recording.le32(r,2)/93750.0)+" 秒 / "+(maxRecordBytes/93750)+" 秒");
                ui.postDelayed(recordPoll,stopRequested?0:400);return;
            }
            require(status==2,"ESP32采集失败或没有可取回的录音，请检查音频线");
            long bytes=Recording.pcmLength(r);manualCapture=false;updateStopButton();
            expectedCrc=Recording.le32(r,10);recordingPcm=new byte[(int)bytes];downloadOffset=0;fastDownload=true;windowActive=false;windowRetries=0;downloadStarted=android.os.SystemClock.elapsedRealtime();gatt.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_HIGH);
            message("采集结束，正在下载 "+String.format(java.util.Locale.US,"%.2f",bytes/93750.0)+" 秒录音…");downloadRecording();
        });
    }
    void downloadRecording(){
        if(!recordBusy || !ready)return;
        if(downloadOffset==recordingPcm.length){
            try{
                require(Recording.crc32(recordingPcm)==expectedCrc,"完整音频CRC32不一致");
                File f=new File(getFilesDir(),"recording_"+new java.text.SimpleDateFormat("yyyyMMdd_HHmmss_SSS",java.util.Locale.US).format(new java.util.Date())+".wav");try(FileOutputStream out=new FileOutputStream(f)){out.write(Recording.wav(recordingPcm,46875));}
                if(windowTimeout!=null)ui.removeCallbacks(windowTimeout);windowActive=false;gatt.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_BALANCED);lastWav=f;int peak=Recording.peak(recordingPcm);double seconds=recordingPcm.length/93750.0;recordingPcm=null;recordBusy=false;manualCapture=false;enableActions();showPage(4);
                message(peak==0?"录音已下载且校验通过，但内容全静音，请检查演奏/音频数据线":"录音完成："+String.format(java.util.Locale.US,"%.2f",seconds)+"秒WAV，校验通过；下载用时"+String.format(java.util.Locale.US,"%.1f",(android.os.SystemClock.elapsedRealtime()-downloadStarted)/1000.0)+"秒，可播放或保存");
            }catch(Exception e){recordFailure(e.getMessage());}return;
        }
        if(fastDownload){startWindow();return;}
        final int offset=downloadOffset;
        requestRecord(0x42,offset&255,(offset>>>8)&255,(offset>>>16)&255,r->{
            require(r.length>0 && offset+r.length<=recordingPcm.length,"音频分块长度异常");
            System.arraycopy(r,0,recordingPcm,offset,r.length);downloadOffset+=r.length;
            state.setText("已连接 · 下载录音 "+(downloadOffset*100/recordingPcm.length)+"%");
            ui.post(this::downloadRecording);
        });
    }
    void startWindow(){
        if(windowActive)return;windowActive=true;windowAck=false;windowEnd=-1;windowSeq=(seq+1)&255;
        int offset=downloadOffset;
        requestRecord(0x46,offset&255,(offset>>>8)&255,(offset>>>16)&255,r->{
            require(r.length==4,"高速下载窗口应答错误");windowEnd=(int)Recording.le32(r,0);
            require(windowEnd>offset && windowEnd<=recordingPcm.length && downloadOffset<=windowEnd,"高速下载窗口范围错误");
            windowAck=true;windowTimeout=this::retryWindow;ui.postDelayed(windowTimeout,5000);completeWindow();
        });
    }
    void receiveStream(byte[] packet){
        if(!recordBusy || !windowActive || recordingPcm==null)return;
        try{
            downloadOffset=Recording.acceptStream(packet,windowSeq,recordingPcm,downloadOffset);
            if(windowAck)require(downloadOffset<=windowEnd,"音频超出下载窗口");
            long now=android.os.SystemClock.elapsedRealtime();
            if(now-lastProgressUpdate>=200 || downloadOffset==recordingPcm.length){lastProgressUpdate=now;state.setText("已连接 · 高速下载 "+(downloadOffset*100/recordingPcm.length)+"%");}completeWindow();
        }catch(Exception e){recordFailure(e.getMessage());}
    }
    void completeWindow(){
        if(!windowActive || !windowAck || downloadOffset!=windowEnd)return;
        if(windowTimeout!=null)ui.removeCallbacks(windowTimeout);windowActive=false;windowRetries=0;ui.post(this::downloadRecording);
    }
    void retryWindow(){
        if(!recordBusy || recordingPcm==null)return;
        if(windowTimeout!=null)ui.removeCallbacks(windowTimeout);windowActive=false;
        if(++windowRetries>3){fallbackDownload();return;}
        ui.postDelayed(this::downloadRecording,100);
    }
    void fallbackDownload(){
        if(windowTimeout!=null)ui.removeCallbacks(windowTimeout);windowActive=false;fastDownload=false;
        message("切换兼容下载，继续校验数据");ui.post(this::downloadRecording);
    }
    File[] recordingFiles(){
        File[] files=getFilesDir().listFiles((dir,name)->name.equals("fpga_recording.wav") || (name.startsWith("recording_") && name.endsWith(".wav")));
        if(files==null)return new File[0];Arrays.sort(files,(a,b)->Long.compare(b.lastModified(),a.lastModified()));return files;
    }
    File latestRecording(){File[] files=recordingFiles();return files.length==0?null:files[0];}
    void manageRecordings(){
        File[] files=recordingFiles();if(files.length==0){message("没有已下载的录音");return;}
        String[] labels=new String[files.length];for(int i=0;i<files.length;i++)labels[i]=files[i].getName()+"\n"+String.format(java.util.Locale.US,"%.2f 秒 · %.1f KB",Math.max(0,files[i].length()-44)/93750.0,files[i].length()/1024.0);
        new AlertDialog.Builder(this).setTitle("录音管理 · "+files.length+" 条").setItems(labels,(d,index)->{
            File selected=files[index];new AlertDialog.Builder(this).setTitle(selected.getName()).setItems(new String[]{"播放","导出为WAV","删除这条录音"},(a,choice)->{
                if(choice<2){lastWav=selected;if(choice==0)playRecording();else saveRecording();}
                else confirmDelete(new File[]{selected});
            }).setNegativeButton("取消",null).show();
        }).setNeutralButton("清空全部录音",(d,w)->confirmDelete(files)).setNegativeButton("关闭",null).show();
    }
    void confirmDelete(File[] files){
        new AlertDialog.Builder(this).setTitle("删除录音？").setMessage("将删除应用内的 "+files.length+" 条录音，已导出的文件仍保留。").setNegativeButton("取消",null).setPositiveButton("删除",(d,w)->{
            if(player!=null){player.release();player=null;}
            int count=0;for(File f:files)if(f.delete())count++;
            if(lastWav==null || !lastWav.exists())lastWav=latestRecording();showPage(page);message("已删除 "+count+" 条录音");
        }).show();
    }
    void playRecording(){
        if(lastWav==null)return;
        try{if(player!=null)player.release();player=new android.media.MediaPlayer();player.setDataSource(lastWav.getAbsolutePath());player.setOnCompletionListener(p->message("录音播放结束"));player.prepare();player.start();message("正在播放最近录音");}catch(Exception e){message("无法播放录音："+e.getMessage());}
    }
    void saveRecording(){if(lastWav==null)return;Intent i=new Intent(Intent.ACTION_CREATE_DOCUMENT);i.addCategory(Intent.CATEGORY_OPENABLE);i.setType("audio/wav");i.putExtra(Intent.EXTRA_TITLE,"FPGA_"+new java.text.SimpleDateFormat("yyyyMMdd_HHmmss",java.util.Locale.US).format(new java.util.Date())+".wav");startActivityForResult(i,3);}

    @Override public void onDestroy(){destroyed=true;if(player!=null){player.release();player=null;}stopScan();ui.removeCallbacksAndMessages(null);BluetoothGatt old=gatt;gatt=null;if(old!=null)try{old.disconnect();old.close();}catch(Exception ignored){}super.onDestroy();}
}
