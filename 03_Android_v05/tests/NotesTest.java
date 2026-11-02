import cn.fpga.instrument.Notes;
public class NotesTest {
 static void check(boolean ok){if(!ok)throw new AssertionError();}
 public static void main(String[] a){check(Notes.NAMES.length==32);check(Notes.NAMES[0].equals("C4"));check(Notes.NAMES[11].equals("B4"));check(Notes.NAMES[12].equals("C5"));check(Notes.NAMES[24].equals("C6"));check(Notes.NAMES[31].equals("G6"));
 byte[] r=new byte[8];r[3]=1;check(Notes.capacity(r)==12);r[3]=0;r[4]=32;r[5]=1;check(Notes.capacity(r)==32);r[4]=12;try{Notes.capacity(r);throw new AssertionError();}catch(IllegalArgumentException expected){}
 check(Notes.start(2)==24 && Notes.end(2,32)==32);check(Notes.end(0,12)==12);System.out.println("PASS Notes: 32 pitch names, bank bounds, new capability and old-board fallback");}
}
