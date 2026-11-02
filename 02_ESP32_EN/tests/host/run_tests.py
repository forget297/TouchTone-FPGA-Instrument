from pathlib import Path
import subprocess,shutil
root=Path(__file__).resolve().parent
gcc=shutil.which('gcc') or 'C:/Users/27799/Desktop/mingw64/bin/gcc.exe'
commands=[[gcc,'-std=c11','-I',str(root),str(root/'test.c'),'-o',str(root/'test.exe')],[str(root/'test.exe')],[gcc,'-std=c11',str(root/'test_wave_v06.c'),str(root.parent.parent/'main/wave_view.c'),'-o',str(root/'test_wave.exe'),'-lm'],[str(root/'test_wave.exe')]]
for cmd in commands:subprocess.run(cmd,check=True)
