<#
    SınıfCepte — Firestore güvenlik kuralı testlerini çalıştırır.

    Neden bu betik var:
    Firebase emülatörü JDK 21+ ister. Bu makinede sistem genelinde Java 8
    kurulu ve Oracle'ın "java8path" kısayolu PATH'in başına sabitlenmiş
    durumda; bu yüzden JAVA_HOME ayarlamak tek başına yetmiyor. Betik,
    Java 21'i PATH'in en başına koyup Java 8 girdilerini geçici olarak
    ayıklar. Sisteminizdeki Java kurulumuna dokunmaz.

    Kullanım:
        cd test_rules
        .\run-tests.ps1                      # JDK'yı otomatik arar
        .\run-tests.ps1 -JdkPath "C:\jdk-21" # belirli bir JDK ile
#>
param(
    [string]$JdkPath = ""
)

$ErrorActionPreference = "Stop"

function Find-Jdk21 {
    # 1. Parametre verildiyse onu kullan
    if ($JdkPath -and (Test-Path "$JdkPath\bin\java.exe")) { return $JdkPath }

    # 2. Sistemde kurulu olağan konumlar
    $candidates = @()
    foreach ($root in @(
            "$env:ProgramFiles\Eclipse Adoptium",
            "$env:ProgramFiles\Java",
            "$env:ProgramFiles\Microsoft",
            "$env:ProgramFiles\Zulu",
            "$env:LOCALAPPDATA\Programs\Eclipse Adoptium")) {
        if (Test-Path $root) {
            $candidates += Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match 'jdk-?(2[1-9]|[3-9][0-9])' }
        }
    }

    # 3. Claude oturumunun indirdiği taşınabilir JDK (varsa)
    $scratch = Join-Path $env:LOCALAPPDATA "Temp\claude"
    if (Test-Path $scratch) {
        $candidates += Get-ChildItem $scratch -Directory -Recurse -Depth 4 -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^jdk-2[1-9]' }
    }

    foreach ($c in $candidates) {
        if (Test-Path "$($c.FullName)\bin\java.exe") { return $c.FullName }
    }
    return ""
}

$jdk = Find-Jdk21

if (-not $jdk) {
    Write-Host ""
    Write-Host "JDK 21 veya uzeri bulunamadi." -ForegroundColor Red
    Write-Host ""
    Write-Host "Firebase emulatoru JDK 21+ gerektiriyor. Kurulum:"
    Write-Host "  https://adoptium.net/temurin/releases/?version=21"
    Write-Host "  (Kurulumda 'Set JAVA_HOME variable' secenegini isaretleyin.)"
    Write-Host ""
    Write-Host "Ya da elinizdeki JDK yolunu verin:"
    Write-Host "  .\run-tests.ps1 -JdkPath `"C:\yol\jdk-21`""
    Write-Host ""
    exit 1
}

Write-Host "JDK bulundu: $jdk" -ForegroundColor Green

# Java 8 shim'lerini PATH'ten ayikla, Java 21'i basa al
$cleanPath = ($env:PATH -split ';' |
    Where-Object { $_ -notmatch 'java8path|jre1\.8|Java\\latest' }) -join ';'

$env:JAVA_HOME = $jdk
$env:PATH = "$jdk\bin;$cleanPath"

# Not: 'java -version' ciktisini stderr'e yazar ve Windows PowerShell 5.1
# bunu NativeCommandError'a cevirir. Bu yuzden surum yazdirilmiyor;
# emulator zaten uyumsuz surumde acik acik hata verir.

Write-Host ""
Write-Host "Kural testleri baslatiliyor..." -ForegroundColor Cyan
Write-Host ""

npm test
exit $LASTEXITCODE
