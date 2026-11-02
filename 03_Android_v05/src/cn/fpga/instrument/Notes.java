package cn.fpga.instrument;
public final class Notes {
    private Notes(){}
    public static final String[] NAMES=names();
    private static String[] names(){String[] tones={"C","C♯","D","D♯","E","F","F♯","G","G♯","A","A♯","B"};String[] a=new String[32];for(int n=0;n<32;n++)a[n]=tones[n%12]+(4+n/12);return a;}
    public static int capacity(byte[] r){if(r.length!=8)throw new IllegalArgumentException("音域应答长度错误");if((r[3]&255)==1)return 12;if(r[3]!=0 || (r[4]&255)!=32 || r[5]!=1)throw new IllegalArgumentException("音域应答异常");return 32;}
    public static int start(int octave){if(octave<0 || octave>2)throw new IllegalArgumentException("八度错误");return octave*12;}
    public static int end(int octave,int capacity){return Math.min(start(octave)+12,capacity);}
}
