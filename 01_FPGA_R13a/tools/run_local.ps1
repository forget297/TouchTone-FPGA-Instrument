param([ValidateSet('test','analyze','pnr','package')][string]$Action='test', [string]$Suite='')
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if(!$Suite) { $Suite=Join-Path $projectPath '..\..\work\oss-cad-suite' }
$Suite=(Resolve-Path -LiteralPath $Suite).Path
$env:PATH="$Suite\bin;$Suite\lib;$env:PATH"
$env:IVERILOG_BASE="$Suite\lib\ivl"
$pythonPath=Join-Path $Suite 'lib\python3.exe'
switch($Action) {
    'test' { & $pythonPath (Join-Path $PSScriptRoot 'run_tests.py') }
    'analyze' { & $pythonPath (Join-Path $PSScriptRoot 'analyze_extended.py') }
    'pnr' { & $pythonPath (Join-Path $PSScriptRoot 'build_open.py') --pnr }
    'package' { & $pythonPath (Join-Path $PSScriptRoot 'package_project.py') }
}
if($LASTEXITCODE -ne 0) { throw "Task $Action failed: exit $LASTEXITCODE" }
