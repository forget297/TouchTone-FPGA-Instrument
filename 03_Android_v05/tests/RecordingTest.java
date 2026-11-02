import cn.fpga.instrument.Recording;
import java.util.*;
public class RecordingTest {
    static void check(boolean yes,String s){if(!yes)throw new AssertionError(s);}
    static byte[] response(byte[] data){byte[] b=new byte[data.length+7];b[0]=(byte)0xa6;b[1]=9;b[2]=(byte)0xc2;b[4]=(byte)data.length;System.arraycopy(data,0,b,5,data.length);for(int i=0;i<data.length+5;i++)b[data.length+5]^=b[i];b[data.length+6]=0x5a;return b;}
    static byte[] stream(int seq,int offset,byte[] data){byte[] b=new byte[data.length+8];b[0]=(byte)0xa7;b[1]=(byte)seq;b[2]=(byte)offset;b[3]=(byte)(offset>>>8);b[4]=(byte)(offset>>>16);b[5]=(byte)data.length;System.arraycopy(data,0,b,6,data.length);for(int i=0;i<data.length+6;i++)b[data.length+6]^=b[i];b[data.length+7]=0x5a;return b;}
    public static void main(String[] args){
        check(Recording.crc32("123456789".getBytes())==0xcbf43926L,"standard CRC32 known vector");
        byte[] pcm={0,0,0,(byte)0x80,(byte)0xff,0x7f};check(Recording.peak(pcm)==32768,"signed16 peak");
        byte[] wav=Recording.wav(pcm,46875);check(wav.length==50,"WAV header length");check(Recording.le32(wav,24)==46875 && Recording.le32(wav,28)==93750,"actual FPGA rate");check(Recording.le32(wav,40)==6 && wav[22]==1 && wav[34]==16,"mono PCM format");check(Arrays.equals(Arrays.copyOfRange(wav,44,50),pcm),"PCM exact preservation");
        for(int n:new int[]{0,14,15,237}){byte[] d=new byte[n];for(int i=0;i<n;i++)d[i]=(byte)i;check(Arrays.equals(Recording.decode(response(d),9,0x42),d),"variable MTU chunk "+n);}
        byte[] bad=response(pcm);bad[5]^=1;try{Recording.decode(bad,9,0x42);throw new AssertionError("bad xor accepted");}catch(IllegalArgumentException expected){}
        try{Recording.decode(response(pcm),10,0x42);throw new AssertionError("wrong seq accepted");}catch(IllegalArgumentException expected){}
        byte[] meta={2,1,0x36,0x6e,1,0,0x1b,(byte)0xb7,0,0,0,0,0,0};check(Recording.le32(meta,2)==93750 && Recording.le32(meta,6)==46875,"firmware metadata offsets");
        for(int n:new int[]{2,1024,93750,234376,2812500}){
            for(int i=0;i<4;i++)meta[2+i]=(byte)(n>>>(8*i));
            check(Recording.pcmLength(meta)==n,"variable recording length "+n);
            byte[] variable=Recording.wav(new byte[n],46875);
            check(variable.length==n+44 && Recording.le32(variable,40)==n,"variable duration WAV "+n);
        }
        for(int n:new int[]{0,3,2812502}){
            for(int i=0;i<4;i++)meta[2+i]=(byte)(n>>>(8*i));
            try{Recording.pcmLength(meta);throw new AssertionError("invalid length accepted "+n);}catch(IllegalArgumentException expected){}
        }
        for(int n:new int[]{93750,2812500}){byte[] cap=new byte[4];for(int i=0;i<4;i++)cap[i]=(byte)(n>>>(8*i));check(Recording.capacity(cap)==n,"PSRAM/fallback capacity "+n);}
        try{Recording.capacity(new byte[4]);throw new AssertionError("zero capacity accepted");}catch(IllegalArgumentException expected){}
        byte[] dest=new byte[10];byte[] a=stream(7,0,new byte[]{1,2,3,4}),b=stream(7,4,new byte[]{5,6,7,8}),c=stream(7,8,new byte[]{9,10});
        int pos=Recording.acceptStream(a,7,dest,0);check(pos==4,"first notification");check(Recording.acceptStream(a,7,dest,pos)==4,"duplicate ignored");check(Recording.acceptStream(c,7,dest,pos)==4,"gap preserves prefix for retry");check(Recording.acceptStream(b,8,dest,pos)==4,"stale window ignored");
        pos=Recording.acceptStream(b,7,dest,pos);pos=Recording.acceptStream(c,7,dest,pos);check(pos==10 && Arrays.equals(dest,new byte[]{1,2,3,4,5,6,7,8,9,10}),"window reassembly exact PCM");
        b[6]^=1;try{Recording.acceptStream(b,7,dest,4);throw new AssertionError("corrupt stream accepted");}catch(IllegalArgumentException expected){}
        try{Recording.acceptStream(stream(7,9,new byte[]{1,2}),7,dest,9);throw new AssertionError("stream overflow accepted");}catch(IllegalArgumentException expected){}
        for(int n:new int[]{12,236}){byte[] chunk=new byte[n];Arrays.fill(chunk,(byte)0x55);check(Recording.acceptStream(stream(255,0,chunk),255,new byte[n],0)==n,"default/247 MTU stream "+n);}
        System.out.println("PASS Recording: standard CRC32, real sample rate WAV, PCM preservation, variable chunks, bad checksum/sequence rejection");
    }
}
