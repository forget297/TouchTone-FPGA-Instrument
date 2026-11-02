import cn.fpga.instrument.Protocol;
import java.util.*;
public class ProtocolTest {
    static void check(boolean yes,String msg){if(!yes)throw new AssertionError(msg);}
    static byte[] hex(String s){String[] a=s.split(" ");byte[] out=new byte[a.length];for(int i=0;i<a.length;i++)out[i]=(byte)Integer.parseInt(a[i],16);return out;}
    public static void main(String[] args){
        check(Arrays.equals(Protocol.encode(1,3,0,0,0),hex("A5 01 03 00 00 00 A7 5A")),"R9 held-note on");
        check(Arrays.equals(Protocol.encode(2,4,0,0,0),hex("A5 02 04 00 00 00 A3 5A")),"R9 release-note off");
        check(Arrays.equals(Protocol.encode(1,0x20,0,2,0),hex("A5 01 20 00 02 00 86 5A")),"R8 verified mapping command");
        Protocol.Decoder d=new Protocol.Decoder();byte[] good=hex("A5 02 A1 00 02 01 05 5A");
        check(d.feed(new byte[]{82,69,65,68,89}).size()==0,"ignore READY");
        check(d.feed(Arrays.copyOfRange(good,0,3)).isEmpty(),"fragment1");
        check(Arrays.equals(d.feed(Arrays.copyOfRange(good,3,8)).get(0),good),"fragment2");
        byte[] broken=good.clone();broken[6]^=1;
        d.feed(broken);check(d.feed(good).size()==1,"resync after invalid xor");
        byte[] two=new byte[16];System.arraycopy(good,0,two,0,8);System.arraycopy(good,0,two,8,8);
        check(d.feed(two).size()==2,"two notifications coalesced");
        check(Protocol.matches(good,2,0x21),"matching reply");
        check(!Protocol.matches(good,3,0x21),"wrong seq ignored");
        check(!Protocol.matches(good,2,0x20),"wrong command ignored");
        for(int split=0;split<=8;split++){d.reset();List<byte[]> a=d.feed(Arrays.copyOfRange(good,0,split));List<byte[]> b=d.feed(Arrays.copyOfRange(good,split,8));check(a.size()+b.size()==1,"all fragment boundaries");}
        int[] events=new int[32];for(int i=0;i<32;i++)events[i]=16+i%12;
        List<int[]> list=Protocol.scoreCommands(events);check(list.size()==18,"18 packets");
        check(list.get(17)[2]==160 && list.get(17)[3]==2,"verified R7 score sum");
        for(int i=0;i<16;i++){int[] c=list.get(i+1);check(c[1]==i*2 && c[2]==events[i*2] && c[3]==events[i*2+1],"event coverage");}
        events[0]=0;try{Protocol.scoreCommands(events);throw new AssertionError("zero duration accepted");}catch(IllegalArgumentException expected){}
        events[0]=0x1c;try{Protocol.scoreCommands(events);throw new AssertionError("invalid key accepted");}catch(IllegalArgumentException expected){}
        events[0]=0x1f;check(Protocol.scoreCommands(events).size()==18,"rest accepted");
        System.out.println("PASS Protocol: verified R7/R8 packets, fragmented/coalesced ACKs, resync, sequence, score validation");
    }
}
