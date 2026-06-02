$ErrorActionPreference = 'Stop'
$url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.3-stable.zip"
$zipFile = "C:\Users\chakri\Downloads\flutter.zip"
$extractPath = "C:\Users\chakri\"

Write-Host "Downloading Flutter SDK..."
Invoke-WebRequest -Uri $url -OutFile $zipFile

Write-Host "Extracting Flutter SDK (this may take a few minutes)..."
Expand-Archive -Path $zipFile -DestinationPath $extractPath -Force

Write-Host "Adding Flutter to User PATH..."
$flutterBin = "C:\Users\chakri\flutter\bin"
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$flutterBin*") {
    $newPath = $userPath + ";$flutterBin"
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    Write-Host "Added $flutterBin to User PATH."
} else {
    Write-Host "Flutter is already in User PATH."
}

Write-Host "Cleaning up..."
Remove-Item $zipFile -Force

Write-Host "Installation Complete!"
