@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
cl /nologo /std:c11 /W3 /I stubs /I ../02_ESP32_EN/main test_host.c ../02_ESP32_EN/main/visual_protocol.c /Fe:test_host.exe
if errorlevel 1 exit /b 1
test_host.exe
