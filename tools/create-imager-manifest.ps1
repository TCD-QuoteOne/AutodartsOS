param(
  [Parameter(Mandatory = $true)]
  [string]$ImagePath,

  [string]$OutputPath = "imager\autodarts-pi-os-local.rpi-imager-manifest",

  [string]$Name = "Autodarts Pi OS Lite",

  [string]$Description = "Raspberry Pi OS Lite appliance image for Autodarts with setup hotspot, kiosk and first-boot customisation.",

  [string]$IconUrl = "https://raw.githubusercontent.com/TCD-QuoteOne/AutodartsOS/main/assets/boot/autodarts-pi-os-splash.png",

  [string]$ImageUrl = ""
)

$ErrorActionPreference = "Stop"

$resolvedImage = Resolve-Path -LiteralPath $ImagePath
$imageItem = Get-Item -LiteralPath $resolvedImage
$resolvedOutput = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
$outputDir = Split-Path -Parent $resolvedOutput
if ($outputDir -and !(Test-Path -LiteralPath $outputDir)) {
  New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedImage
$imageUri = if ($ImageUrl) { $ImageUrl } else { [System.Uri]::new($imageItem.FullName).AbsoluteUri }
$releaseDate = Get-Date -Format "yyyy-MM-dd"

function Get-StreamSha256 {
  param([System.IO.Stream]$Stream)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $buffer = New-Object byte[] (1024 * 1024)
    $total = [Int64]0
    while (($read = $Stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
      $total += $read
      [void]$sha.TransformBlock($buffer, 0, $read, $null, 0)
    }
    [void]$sha.TransformFinalBlock([byte[]]::new(0), 0, 0)
    $digest = -join ($sha.Hash | ForEach-Object { $_.ToString("x2") })
    return [ordered]@{
      size = $total
      sha256 = $digest
    }
  } finally {
    $sha.Dispose()
  }
}

function Get-ExtractedImageInfo {
  param([System.IO.FileInfo]$Image)

  if ($Image.Extension.ToLowerInvariant() -eq ".zip") {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Image.FullName)
    try {
      $entries = @($archive.Entries | Where-Object { $_.Length -gt 0 })
      $imgEntries = @($entries | Where-Object { $_.FullName.ToLowerInvariant().EndsWith(".img") })
      $candidateEntries = if ($imgEntries.Count -gt 0) { $imgEntries } else { $entries }
      $entry = @($candidateEntries | Sort-Object Length -Descending)[0]
      if (!$entry) {
        throw "No file entry found in ZIP: $($Image.FullName)"
      }
      $stream = $entry.Open()
      try {
        return Get-StreamSha256 -Stream $stream
      } finally {
        $stream.Dispose()
      }
    } finally {
      $archive.Dispose()
    }
  }

  return [ordered]@{
    size = $Image.Length
    sha256 = $hash.Hash.ToLowerInvariant()
  }
}

$extractInfo = Get-ExtractedImageInfo -Image $imageItem

$manifest = [ordered]@{
  imager = [ordered]@{
    latest_version = "2.0.0"
    url = "https://www.raspberrypi.com/software/"
    devices = @(
      [ordered]@{
        name = "Raspberry Pi"
        tags = @("pi")
        default = $true
        matching_type = "inclusive"
        description = "Raspberry Pi boards supported by Raspberry Pi OS Bookworm."
      }
    )
  }
  os_list = @(
    [ordered]@{
      name = $Name
      description = $Description
      icon = $IconUrl
      url = $imageUri
      extract_size = [Int64]$extractInfo.size
      extract_sha256 = $extractInfo.sha256
      image_download_size = $imageItem.Length
      image_download_sha256 = $hash.Hash.ToLowerInvariant()
      release_date = $releaseDate
      init_format = "systemd"
      devices = @("pi")
    }
  )
}

$json = $manifest | ConvertTo-Json -Depth 20
Set-Content -LiteralPath $resolvedOutput -Value $json -Encoding UTF8

Write-Host "Created Raspberry Pi Imager manifest:"
Write-Host $resolvedOutput
Write-Host ""
Write-Host "Open this .rpi-imager-manifest file with Raspberry Pi Imager instead of selecting the image through 'Use custom'."
