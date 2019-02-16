# Script obtained from Appveyor team and modified to support the ruby versions needed for the Puppet environment.
# Some deprecated versions (e.g. 1.9.3) have been removed as they are no longer required.
$PackerScriptsDir = $Env:PACKER_SCRIPTS_DIR
. $PackerScriptsDir/windows-env.ps1

# download SSL certificates
(New-Object Net.WebClient).DownloadFile('http://curl.haxx.se/ca/cacert.pem', "$env:temp\cacert.pem")
$env:SSL_CERT_FILE = "$env:temp\cacert.pem"

$rubies = @(
    @{
        "version" = "Ruby 2.0.0-p648"
        "install_path" = "C:\Ruby200"
        "download_url" = "http://dl.bintray.com/oneclick/rubyinstaller/ruby-2.0.0-p648-i386-mingw32.7z"
        "install_psych" = "true"
    }
    @{
        "version" = "Ruby 2.0.0-p648 (x64)"
        "install_path" = "C:\Ruby200-x64"
        "download_url" = "http://dl.bintray.com/oneclick/rubyinstaller/ruby-2.0.0-p648-x64-mingw32.7z"
        "install_psych" = "true"
    }
    @{
        "version" = "Ruby 2.1.9"
        "install_path" = "C:\Ruby21"
        "download_url" = "http://dl.bintray.com/oneclick/rubyinstaller/ruby-2.1.9-i386-mingw32.7z"
    }
    @{
        "version" = "Ruby 2.1.9 (x64)"
        "install_path" = "C:\Ruby21-x64"
        "download_url" = "http://dl.bintray.com/oneclick/rubyinstaller/ruby-2.1.9-x64-mingw32.7z"
    }
    @{
        "version" = "Ruby 2.2.6"
        "install_path" = "C:\Ruby22"
        "download_url" = "http://dl.bintray.com/oneclick/rubyinstaller/ruby-2.2.6-i386-mingw32.7z"
    }
    @{
        "version" = "Ruby 2.2.6 (x64)"
        "install_path" = "C:\Ruby22-x64"
        "download_url" = "http://dl.bintray.com/oneclick/rubyinstaller/ruby-2.2.6-x64-mingw32.7z"
    }
    @{
        "version" = "Ruby 2.3.3"
        "install_path" = "C:\Ruby23"
        "download_url" = "http://dl.bintray.com/oneclick/rubyinstaller/ruby-2.3.3-i386-mingw32.7z"
        "devkit_url" = "http://dl.bintray.com/oneclick/rubyinstaller/DevKit-mingw64-32-4.7.2-20130224-1151-sfx.exe"
        "devkit_paths" = @("C:/Ruby200", "C:/Ruby21", "C:/Ruby22", "C:/Ruby23")
    }
    @{
        "version" = "Ruby 2.3.3 (x64)"
        "install_path" = "C:\Ruby23-x64"
        "download_url" = "http://dl.bintray.com/oneclick/rubyinstaller/ruby-2.3.3-x64-mingw32.7z"
        "devkit_url" = "http://dl.bintray.com/oneclick/rubyinstaller/DevKit-mingw64-64-4.7.2-20130224-1432-sfx.exe"
        "devkit_paths" = @("C:/Ruby200-x64", "C:/Ruby21-x64", "C:/Ruby22-x64", "C:/Ruby23-x64")
    }
    @{
        "version" = "Ruby 2.4.3-1"
        "install_path" = "C:\Ruby24"
        "download_url" = "https://github.com/oneclick/rubyinstaller2/releases/download/rubyinstaller-2.4.3-1/rubyinstaller-2.4.3-1-x86.exe"
        "devkit_url" = ""
        "devkit_paths" = @()
    }
    @{
        "version" = "Ruby 2.4.3-1 (x64)"
        "install_path" = "C:\Ruby24-x64"
        "download_url" = "https://github.com/oneclick/rubyinstaller2/releases/download/rubyinstaller-2.4.3-1/rubyinstaller-2.4.3-1-x64.exe"
        "devkit_url" = ""
        "devkit_paths" = @()
    }
    @{
        "version" = "Ruby 2.5.0-1"
        "install_path" = "C:\Ruby25"
        "download_url" = "https://github.com/oneclick/rubyinstaller2/releases/download/rubyinstaller-2.5.0-1/rubyinstaller-2.5.0-1-x86.exe"
        "devkit_url" = ""
        "devkit_paths" = @()
    }
    @{
        "version" = "Ruby 2.5.0-1 (x64)"
        "install_path" = "C:\Ruby25-x64"
        "download_url" = "https://github.com/oneclick/rubyinstaller2/releases/download/rubyinstaller-2.5.0-1/rubyinstaller-2.5.0-1-x64.exe"
        "devkit_url" = ""
        "devkit_paths" = @()
    }
)

function GetUninstallString($productName) {
    $x64items = @(Get-ChildItem "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")
    ($x64items + @(Get-ChildItem "HKLM:SOFTWARE\wow6432node\Microsoft\Windows\CurrentVersion\Uninstall") `
        | ForEach-object { Get-ItemProperty Microsoft.PowerShell.Core\Registry::$_ } `
        | Where-Object { $_.DisplayName -and $_.DisplayName -eq $productName } `
        | Select UninstallString).UninstallString
}

function Get-FileNameFromUrl($url) {
    $fileName = $url.Trim('/')
    $idx = $fileName.LastIndexOf('/')
    if($idx -ne -1) {
        $fileName = $fileName.substring($idx + 1)
        $idx = $fileName.IndexOf('?')
        if($idx -ne -1) {
            $fileName = $fileName.substring(0, $idx)
        }
    }
    return $fileName
}

function Install-Ruby($ruby) {
    Write-Host "Installing $($ruby.version)" -ForegroundColor Cyan

    if($ruby.download_url.contains('github.com')) {
        #########################
        ##
        ##  New 2.4 installer
        ##
        #########################

        # uninstall existing
        $rubyUninstallPath = "$ruby.install_path\unins000.exe"
        if([IO.File]::Exists($rubyUninstallPath)) {
            Write-Host "  Uninstalling previous Ruby 2.4..." -ForegroundColor Gray
            "`"$rubyUninstallPath`" /silent" | out-file "$env:temp\uninstall-ruby.cmd" -Encoding ASCII
            & "$env:temp\uninstall-ruby.cmd"
            del "$env:temp\uninstall-ruby.cmd"
            Start-Sleep -s 5
        }

        if(Test-Path $ruby.install_path) {
            Write-Host "  Deleting $($ruby.install_path)" -ForegroundColor Gray
            Remove-Item $ruby.install_path -Force -Recurse
        }

        $exePath = "$($env:TEMP)\rubyinstaller.exe"

        Write-Host "  Downloading $($ruby.version) from $($ruby.download_url)" -ForegroundColor Gray
        (New-Object Net.WebClient).DownloadFile($ruby.download_url, $exePath)

        Write-Host "Installing..." -ForegroundColor Gray
        $zproc = Start-Process $exePath @SprocParms -ArgumentList "/verysilent /dir=`"$($ruby.install_path.replace('\', '/'))`" /tasks=`"noassocfiles,nomodpath,noridkinstall`""
        $zproc.WaitForExit()
        del $exePath
        Write-Host "Installed" -ForegroundColor Green

        # setup Ruby
        $env:Path = "$($ruby.install_path)\bin;$($env:Path)"
        Write-Host "ruby --version" -ForegroundColor Gray
        $zproc = Start-Process ruby @SprocParms -ArgumentList "--version"
        $zproc.WaitForExit()

        Write-Host "gem --version" -ForegroundColor Gray
        $zproc = Start-Process gem @SprocParms -ArgumentList "--version"
        $zproc.WaitForExit()

        # list installed gems
        Write-Host "gem list --local" -ForegroundColor Gray
        $zproc = Start-Process gem @SprocParms -ArgumentList "list --local"
        $zproc.WaitForExit()

    } else {
        #########################
        ##
        ##  Old installer
        ##
        #########################

        # delete if exists
        if(Test-Path $ruby.install_path) {
            Write-Host "  Deleting $($ruby.install_path)" -ForegroundColor Gray
            Remove-Item $ruby.install_path -Force -Recurse
        }

        # create temp directory for all downloads
        $tempPath = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
        New-Item $tempPath -ItemType Directory | Out-Null

        $distFileName = Get-FileNameFromUrl $ruby.download_url
        $distName = [IO.Path]::GetFileNameWithoutExtension($distFileName)
        $distLocalFileName = (Join-Path $tempPath $distFileName)

        # download archive to a temp
        Write-Host "  Downloading $($ruby.version) from $($ruby.download_url)" -ForegroundColor Gray
        (New-Object Net.WebClient).DownloadFile($ruby.download_url, $distLocalFileName)

        # extract archive to C:\
        Write-Host "  Extracting Ruby files..." -ForegroundColor Gray
        $zproc = Start-Process 7z.exe @SprocParms -ArgumentList "x $distLocalFileName -oC:\"
        $zproc.WaitForExit()

        # rename
        Rename-Item "C:\$distName" $ruby.install_path

        # setup Ruby
        $env:Path = "$($ruby.install_path)\bin;$($env:Path)"
        Write-Host "ruby --version" -ForegroundColor Gray
        $zproc = Start-Process ruby @SprocParms -ArgumentList "--version"
        $zproc.WaitForExit()

        Write-Host "gem --version" -ForegroundColor Gray
        $zproc = Start-Process gem @SprocParms -ArgumentList "list --local"
        $zproc.WaitForExit()

        # list installed gems
        Write-Host "gem list --local" -ForegroundColor Gray
        $zproc = Start-Process gem @SprocParms -ArgumentList "list --local"
        $zproc.WaitForExit()

        # download DevKit
        if($ruby.devkit_url) {
            Write-Host "  Downloading DevKit from $($ruby.devkit_url)" -ForegroundColor Gray
            $devKitFileName = Get-FileNameFromUrl $ruby.devkit_url
            $devKitLocalFileName = (Join-Path $tempPath $devKitFileName)
            (New-Object Net.WebClient).DownloadFile($ruby.devkit_url, $devKitLocalFileName)

            # extract DevKit
            $devKitPath = (Join-Path $ruby.install_path 'DevKit')
            Write-Host "  Extracting DevKit to $devKitPath..." -ForegroundColor Gray
            $zproc = Start-Process 7z @SprocParms -ArgumentList "x $devKitLocalFileName -o`"$devKitPath`""
            $zproc.WaitForExit()

            # create config.yml
            $configYamlPath = (Join-Path $devKitPath 'config.yml')
            New-Item $configYamlPath -ItemType File | Out-Null
            Add-Content $configYamlPath "---`n"
            for($i = 0; $i -lt $ruby.devkit_paths.Count; $i++) {
                Add-Content $configYamlPath "- $($ruby.devkit_paths[$i])`n"
            }

            # install DevKit
            Write-Host "  Installing DevKit..." -ForegroundColor Gray
            $origPath = (pwd).Path
            cd $devKitPath
            $zproc = Start-Process ruby @SprocParms -ArgumentList "dk.rb install"
            $zproc.WaitForExit()
            cd $origPath
        }
    }

    # delete temp path
    if($tempPath) {
        Write-Host "  Cleaning up..." -ForegroundColor Gray
        Remove-Item $tempPath -Force -Recurse
    }

    Write-Host "  Done!" -ForegroundColor Green
}

function Update-Ruby($ruby) {
    Write-Host "Updating $($ruby.version)" -ForegroundColor Cyan

    $env:Path = "$($ruby.install_path)\bin;$($env:Path)"

    if ($ruby.install_psych) {
        Write-Host "gem install psych -v 2.2.4" -ForegroundColor Gray
        $zproc = Start-Process gem @SprocParms -ArgumentList "install psych -v 2.2.4"
        $zproc.WaitForExit()
    } elseif ($ruby.update_psych) {
        Write-Host "gem update psych" -ForegroundColor Gray
        $zproc = Start-Process gem @SprocParms -ArgumentList "update psych"
        $zproc.WaitForExit()
    }

    Write-Host "gem update --system" -ForegroundColor Gray
    $zproc = Start-Process gem @SprocParms -ArgumentList "update --system"
    $zproc.WaitForExit()

    # cleanup old gems
    Write-Host "gem cleanup" -ForegroundColor Gray
    $zproc = Start-Process gem @SprocParms -ArgumentList "cleanup"
    $zproc.WaitForExit()

    # list installed gems
    Write-Host "gem list --local" -ForegroundColor Gray
    $zproc = Start-Process gem @SprocParms -ArgumentList "list --local"
    $zproc.WaitForExit()

    # install bundler package
    Write-Host "gem install bundler --force" -ForegroundColor Gray
    $zproc = Start-Process gem @SprocParms -ArgumentList "install bundler --force"
    $zproc.WaitForExit()

    Write-Host "  Done!" -ForegroundColor Green
}

# save current directory
$currentDir = (pwd).Path

for($i = 0; $i -lt $rubies.Count; $i++) {
    Install-Ruby $rubies[$i]
}

for($i = 0; $i -lt $rubies.Count; $i++) {
    Update-Ruby $rubies[$i]
}

# Fix bundler.bat
# @("Ruby193","Ruby200","Ruby200-x64","Ruby21","Ruby21-x64","Ruby22","Ruby22-x64","Ruby23","Ruby23-x64","Ruby24","Ruby24-x64") | % { Copy-Item "C:\$_\bin\bundle.bat" -Destination "C:\$_\bin\bundler.bat" -Force; Copy-Item "C:\$_\bin\bundle" -Destination "C:\$_\bin\bundler" -Force }

# print summary
for($i = 0; $i -lt $rubies.Count; $i++) {
    $ruby = $rubies[$i]
    Write-Host "$($ruby.version)" -ForegroundColor Cyan
    Write-Host "ruby --version: $(cmd /c "$($ruby.install_path)\bin\ruby" --version)"
    Write-Host "gem --version: $(cmd /c "$($ruby.install_path)\bin\gem" --version)"
    Write-Host "bundle --version: $(cmd /c "$($ruby.install_path)\bin\bundle" --version)"
    Write-Host "bundler --version: $(cmd /c "$($ruby.install_path)\bin\bundler" --version)"
}

Add-Path 'C:\Ruby200\bin'
