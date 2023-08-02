using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

function Resize-Image {
    <#
    .SYNOPSIS
        Resize-Image resizes an image file.
 
    .DESCRIPTION
        This function uses the native .NET API to resize an image file and save it to a file.
        It supports the following image formats: BMP, GIF, JPEG, PNG, TIFF
 
    .PARAMETER InputFile
        Type [string]
        The parameter InputFile is used to define the value of image name or path to resize.

     .PARAMETER Extension
        Type [string]
        The parameter Extension is used to define the Extension of the image.
  
    .PARAMETER Width
        Type [int32]
        The parameter Width is used to define the value of new width to image.
 
    .PARAMETER Height
        Type [int32]
        The parameter Height is used to define the value of new height to image.
 
    .PARAMETER ProportionalResize
        Type [bool]
        The optional parameter ProportionalResize is used to define if execute proportional resize.
 
    .EXAMPLE
        Resize-Image -InputFile $Input -Extension $Extension -Width 500 -Height 500 -ProportionalResize $true
 
    .NOTES
       
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$InputFile,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Extension,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int32]$Width,
        [Parameter(Mandatory = $true)]
        [int32]$Height,
        [Parameter(Mandatory = $false)]
        [bool]$ProportionalResize = $true)
Try 
{
    # Add assemblies
    Add-Type -AssemblyName System
    Add-Type -AssemblyName System.Drawing
    Add-type -AssemblyName System.IO

    Write-Host "Create Stream."

    $ByteArray = [Convert]::FromBase64String($InputFile)
    
    $ms = new-object System.IO.MemoryStream(,$ByteArray)
    $image = [System.Drawing.Image]::FromStream($ms)

    $ratioX = $Width / $image.Width;
    $ratioY = $Height / $image.Height;
    $ratio = [System.Math]::Min($ratioX, $ratioY);

    [int32]$newWidth = If ($ProportionalResize) { $image.Width * $ratio } Else { $Width }
    [int32]$newHeight = If ($ProportionalResize) { $image.Height * $ratio } Else { $Height }

    $destImage =  new-object System.Drawing.Bitmap($newWidth, $newHeight)

    # Draw new image on the empty canvas
    $graphics = [System.Drawing.Graphics]::FromImage($destImage)
    $graphics.DrawImage($image, 0, 0, $newWidth, $newHeight)
    $graphics.Dispose()


    $MemoryStream = New-Object System.IO.MemoryStream
    $destImage.save($MemoryStream, [System.Drawing.Imaging.ImageFormat]::$Extension)
    $Bytes = $MemoryStream.ToArray()
    $MemoryStream.Flush()
    $MemoryStream.Dispose()
    $base64 = [convert]::ToBase64String($Bytes)

    return $base64
}
    catch {
        Write-Host "Error occurred while resizing the image: $($_.Exception.Message)"
        return $null
    }
}

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

$name = $Request.Body.Name
$Extension = $Request.Body.Extension
$Input = $Request.Body.InputFile
write-Host $Request.Body
Write-Host $name

if($Extension -eq 'jpg')
{$Extension = "jpeg" }

Write-Host $Extension

$statusCode = [HttpStatusCode]::OK
$body = $null

if ($name) {


    $body = Resize-Image -InputFile $Input -Extension $Extension -Width 500 -Height 500 -ProportionalResize $true

    }
    else {
        $statusCode = [HttpStatusCode]::InternalServerError
        $body = "Image resizing failed. Please check the input and try again."
    }


# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $statusCode
    Body = $body
})
