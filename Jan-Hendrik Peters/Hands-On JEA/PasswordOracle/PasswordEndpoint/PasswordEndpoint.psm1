$dataFilePath = (Get-Module PasswordEndpoint -ListAvailable)[0].PrivateData['StoragePath']
$thumbPrint = (Get-Module PasswordEndpoint -ListAvailable)[0].PrivateData['CertificateThumbprint']

function Get-Password
{
    param
    (
        [Parameter(Mandatory)]
        [string]
        $ObjectName,

        [Parameter()]
        [string]
        $Prefix
    )

    $filePath = Join-Path -Path (Join-Path -Path $dataFilePath -ChildPath $Prefix) -ChildPath $ObjectName

    if (-not (Test-Path -Path $filePath))
    {
        Write-Verbose -Message "$Prefix\$ObjectName not found"
        return
    }

    try
    {

        $content = Get-Content -Path $filePath | Get-CmsMessage -ErrorAction Stop
    }
    catch
    {
        Write-Error -Exception $_.Exception
        return
    }

    $caller = $PSSenderInfo.UserInfo.WindowsIdentity.Name
    if (-not $caller -and $PSSenderInfo)
    {
        Write-Error -Message "Cmdlet executed remotely but no identity found."
        return
    }

    if (-not $caller -or -not ([System.Security.Principal.WindowsIdentity]::GetCurrent()).Name )
    {
        Write-Verbose -Message "Could not determine calling user properly. Not returning anything."
        return
    }

    return ($content | Unprotect-CmsMessage | Protect-CmsMessage -To $PSSenderInfo.UserInfo.Name)
}

function Set-Password
{
    param
    (
        [Parameter(Mandatory)]
        [string]
        $ObjectName,

        [Parameter()]
        [string]
        $Prefix,

        [Parameter(Mandatory)]
        [string]
        $CmsMessage,

        [switch]
        $Force
    )

    try
    {
        $encryptedData = Get-CmsMessage -Content $CmsMessage -ErrorAction Stop
        if ($encryptedData.Recipients.IssuerName -notcontains (Get-Item -Path cert:\LocalMachine\my\$thumbPrint -ErrorAction SilentlyContinue).Subject)
        {
            Write-Error -Message ("Message not encrypted for recipient. We are {0}" -f (Get-Item -Path cert:\LocalMachine\my\$thumbPrint -ErrorAction SilentlyContinue).Subject)
            return
        }
    }
    catch
    {
        Write-Error -Message "Encrypted content was not accessible." -Exception $cmsError.Exception -TargetObject $ObjectName
        return
    }

    $filePath = Join-Path -Path (Join-Path -Path $dataFilePath -ChildPath $Prefix) -ChildPath $ObjectName

    if ((Test-Path $filePath) -and -not $Force)
    {
        Write-Verbose -Message "Entry for $ObjectName exists. Skipping"
        return
    }

    Set-Content -Path $filePath -Value $CmsMessage -Force
}

function Remove-Password
{
    param
    (
        [Parameter(Mandatory)]
        [string]
        $ObjectName,

        [Parameter()]
        [string]
        $Prefix
    )

    $filePath = Join-Path -Path (Join-Path -Path $dataFilePath -ChildPath $Prefix) -ChildPath $ObjectName

    if (Test-Path -Path $filePath)
    {
        Remove-Item -Path $filePath -ErrorAction SilentlyContinue -Force
    }
}

function Get-ServerThumbprint
{
    return $thumbPrint
}
