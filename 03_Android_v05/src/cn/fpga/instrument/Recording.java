package cn.fpga.instrument;
import java.util.Arrays;
import java.util.zip.CRC32;
public final class Recording {
    public static final int MAX_PCM=2812500;
    public static int capacity(byte[] r){
        if(r.length!=4)throw new IllegalArgumentException("录音容量应答长度错误");
        long bytes=le32(r,0);
        if(bytes<93750 || bytes>MAX_PCM || bytes%2!=0)throw new IllegalArgumentException("ESP32录音缓冲区不可用");
        return (int)bytes;
    }
    public static int pcmLength(byte[] r){
        if(r.length!=14 || (r[0]&255)!=2 || (r[1]&255)!=1 || le32(r,6)!=46875)throw new IllegalArgumentException("录音格式与预期不符");
        long bytes=le32(r,2);
        if(bytes<2 || bytes>MAX_PCM || bytes%2!=0)throw new IllegalArgumentException("录音长度超出范围");
        return (int)bytes;
    }
    public static int status(byte[] frame,int seq,int cmd){
        if(frame.length<7 || (frame[0]&255)!=0xa6 || (frame[1]&255)!=seq || (frame[2]&255)!=(cmd|128))throw new IllegalArgumentException("录音应答标识不匹配");
        int len=frame[4]&255;if(frame.length!=len+7 || (frame[6+len]&255)!=0x5a)throw new IllegalArgumentException("录音应答长度错误");
        byte sum=0;for(int i=0;i<len+5;i++)sum^=frame[i];if(sum!=frame[len+5])throw new IllegalArgumentException("录音应答校验失败");
        return frame[3]&255;
    }
    public static byte[] decode(byte[] frame,int seq,int cmd){
        int status=status(frame,seq,cmd);if(status!=0)throw new IllegalArgumentException(status==6?"ESP32无法初始化录音，检查串口日志":status==3?"录音尚未就绪":"录音状态码 "+status);
        return Arrays.copyOfRange(frame,5,frame.length-2);
    }
    public static int acceptStream(byte[] frame,int seq,byte[] dest,int offset){
        if(frame.length<9 || (frame[0]&255)!=0xa7)throw new IllegalArgumentException("音频通知格式错误");
        if((frame[1]&255)!=seq)return offset; // Late notification from an earlier window.
        int n=frame[5]&255;if(n==0 || frame.length!=n+8 || (frame[n+7]&255)!=0x5a)throw new IllegalArgumentException("音频通知长度错误");
        byte sum=0;for(int i=0;i<n+6;i++)sum^=frame[i];if(sum!=frame[n+6])throw new IllegalArgumentException("音频通知校验失败");
        int start=(frame[2]&255)|((frame[3]&255)<<8)|((frame[4]&255)<<16);
        if(start+n>dest.length)throw new IllegalArgumentException("音频通知超出缓存");
        if(start!=offset)return offset; // Duplicate or gap: retry from the contiguous prefix.
        System.arraycopy(frame,6,dest,start,n);return offset+n;
    }
    public static long le32(byte[] b,int p){return (b[p]&255L)|((b[p+1]&255L)<<8)|((b[p+2]&255L)<<16)|((b[p+3]&255L)<<24);}
    public static long crc32(byte[] bytes){CRC32 c=new CRC32();c.update(bytes);return c.getValue();}
    public static int peak(byte[] pcm){int peak=0;for(int i=0;i+1<pcm.length;i+=2){int v=(short)((pcm[i]&255)|((pcm[i+1]&255)<<8));peak=Math.max(peak,Math.abs(v));}return peak;}
    static void put32(byte[] b,int p,int n){for(int i=0;i<4;i++)b[p+i]=(byte)(n>>(8*i));}
    static void ascii(byte[] b,int p,String s){for(int i=0;i<s.length();i++)b[p+i]=(byte)s.charAt(i);}
    public static byte[] wav(byte[] pcm,int rate){
        if(rate<=0 || pcm.length%2!=0)throw new IllegalArgumentException("PCM参数错误");
        byte[] b=new byte[pcm.length+44];ascii(b,0,"RIFF");put32(b,4,b.length-8);ascii(b,8,"WAVE");ascii(b,12,"fmt ");put32(b,16,16);b[20]=1;b[22]=1;put32(b,24,rate);put32(b,28,rate*2);b[32]=2;b[34]=16;ascii(b,36,"data");put32(b,40,pcm.length);System.arraycopy(pcm,0,b,44,pcm.length);return b;
    }
}
