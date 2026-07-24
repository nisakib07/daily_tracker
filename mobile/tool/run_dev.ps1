param(
  [string]$Device = "chrome",
  [int]$Port = 52710,
  [switch]$NoPub,
  [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"

$mobileRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $mobileRoot
$envFile = Join-Path $repoRoot ".env.local"
$flutter = Join-Path $env:USERPROFILE "development\flutter\bin\flutter.bat"

if (!(Test-Path $flutter)) {
  throw "Flutter was not found at $flutter"
}

if (!(Test-Path $envFile)) {
  throw "Missing $envFile"
}

$values = @{}
Get-Content $envFile | ForEach-Object {
  $line = $_.Trim()
  if (!$line -or $line.StartsWith("#") -or !$line.Contains("=")) {
    return
  }

  $parts = $line.Split("=", 2)
  $values[$parts[0].Trim()] = $parts[1].Trim()
}

$supabaseUrl = $values["NEXT_PUBLIC_SUPABASE_URL"]
$supabaseAnonKey = $values["NEXT_PUBLIC_SUPABASE_ANON_KEY"]

if (!$supabaseUrl -or !$supabaseAnonKey) {
  throw ".env.local must contain NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY"
}

if ($NoLaunch) {
  $Device = "web-server"
}

$arguments = @(
  "run",
  "-d", $Device,
  "--dart-define=SUPABASE_URL=$supabaseUrl",
  "--dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey"
)

if ($Device -eq "chrome" -or $Device -eq "web-server") {
  $arguments += @("--web-hostname", "127.0.0.1", "--web-port", "$Port")
}

if ($NoPub) {
  $arguments += "--no-pub"
}

& $flutter @arguments
