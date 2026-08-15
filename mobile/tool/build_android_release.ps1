param(
  [switch]$NoPub
)

$ErrorActionPreference = "Stop"

$mobileRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $mobileRoot
$envFile = Join-Path $repoRoot ".env.local"
$flutter = Join-Path $env:USERPROFILE "development\flutter\bin\flutter.bat"
$keyProperties = Join-Path $mobileRoot "android\key.properties"

if (!(Test-Path $flutter)) {
  throw "Flutter was not found at $flutter"
}

if (!(Test-Path $envFile)) {
  throw "Missing $envFile"
}

if (!(Test-Path $keyProperties)) {
  throw "Missing android\key.properties - the release build will fall back to debug signing, which won't update in place on a phone that already has a signed release installed. See android/key.properties.example."
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

$arguments = @(
  "build",
  "apk",
  "--release",
  "--dart-define=SUPABASE_URL=$supabaseUrl",
  "--dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey"
)

if ($NoPub) {
  $arguments += "--no-pub"
}

& $flutter @arguments

Write-Host ""
Write-Host "Signed release APK: mobile\build\app\outputs\flutter-apk\app-release.apk"
