package cn.fpga.instrument;

import java.util.ArrayList;
import java.util.List;

/** Fixed eight-byte R8 protocol. No Android dependency: executable unit tests. */
public final class Protocol {
    public static byte[] encode(int seq,int cmd,int arg,int lo,int hi) {
        int[] values={seq,cmd,arg,lo,hi};
        for(int v:values) if(v<0 || v>255) throw new IllegalArgumentException("字段范围错误");
        byte[] b={(byte)0xa5,(byte)seq,(byte)cmd,(byte)arg,(byte)lo,(byte)hi,0,0x5a};
        for(int i=0;i<6;i++) b[6]^=b[i];
        return b;
    }
    public static boolean matches(byte[] reply,int seq,int cmd) {
        return reply.length==8 && (reply[1]&255)==seq && (reply[2]&255)==(cmd|128);
    }
    public static List<int[]> scoreCommands(int[] events) {
        if(events.length!=32) throw new IllegalArgumentException("曲谱需要32个步骤");
        List<int[]> commands=new ArrayList<>();commands.add(new int[]{0x10,0,0,0});
        int sum=0;
        for(int event:events) {
            int key=event&15,beats=event>>>4;
            if(event<0 || event>255 || beats<1 || beats>15 || (key>11 && key!=15))
                throw new IllegalArgumentException("曲谱音符或时值错误");
            sum+=event;
        }
        for(int i=0;i<32;i+=2) commands.add(new int[]{0x11,i,events[i],events[i+1]});
        commands.add(new int[]{0x12,0,sum&255,sum>>>8});
        return commands;
    }
    public static final class Decoder {
        private final ArrayList<Byte> buffer=new ArrayList<>();
        public void reset(){buffer.clear();}
        public List<byte[]> feed(byte[] bytes) {
            for(byte b:bytes)buffer.add(b);
            List<byte[]> out=new ArrayList<>();
            while(!buffer.isEmpty()) {
                if((buffer.get(0)&255)!=0xa5){buffer.remove(0);continue;}
                if(buffer.size()<8)break;
                byte xor=0;for(int i=0;i<6;i++)xor^=buffer.get(i);
                if(xor!=buffer.get(6) || (buffer.get(7)&255)!=0x5a){buffer.remove(0);continue;}
                byte[] frame=new byte[8];for(int i=0;i<8;i++)frame[i]=buffer.remove(0);
                out.add(frame);
            }
            return out;
        }
    }
    private Protocol(){}
}
