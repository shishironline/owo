# SPDX-License-Identifier: GPL-3.0

# Import Markup Pack utilities
Import-Module .\src\Conversion\Conversion-Markup.psm1

Function Set-ContentNoBom {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,Position = 0, ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
        [AllowEmptyString()]
        [string]
        $LiteralPath
    ,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [array]
        $Value
    )
    process {
        if ($PSVersionTable.PSVersion.Major -le 5) {
            try {
                $content = $Value -join ''
                [IO.File]::WriteAllText($LiteralPath, $content)
            }catch {
                if ($ErrorActionPreference -eq 'Stop') {
                    throw
                }else {
                    Write-Error -ErrorRecord $_
                }
            }
        }else {
            Set-Content @PSBoundParameters
        }
    }
}

Function Convert-OneNotePage {
    [CmdletBinding(DefaultParameterSetName='default')]
    param (
        # Onenote connection object
        [Parameter(Mandatory)]
        [object]
        $OneNoteConnection
    ,
        # OneUp configuration object
        [Parameter(Mandatory)]
        [object]
        $Config
    ,
        # Conversion object
        [Parameter(Mandatory,ParameterSetName='default')]
        [ValidateNotNullOrEmpty()]
        [object]
        $ConversionConfig
    ,
        [Parameter(Mandatory,ParameterSetName='pipeline',ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [object]
        $InputObject
    )

    process {
        if ($InputObject) {
            $ConversionConfig = $InputObject
        }
        if ($null -eq $ConversionConfig) {
            throw "No config specified."
        }

        try {
            $pageCfg = $ConversionConfig

            "$( '#' * ($pageCfg['levelsFromRoot'] + $pageCfg['pageLevel']) ) $( $pageCfg['object'].name ) [$( $pageCfg['kind'] )]" | Write-Host
            "Uri: $( $pageCfg['uri'] )" | Write-Verbose

            # Create directories
            foreach ($d in $pageCfg['directoriesToCreate']) {
                try {
                    "Directory: $( $d )" | Write-Verbose
                    if ($config['dryRun']['value'] -eq 1) {
                        $item = New-Item -Path $d -ItemType Directory -Force -ErrorAction Stop
                    }
                }catch {
                    throw "Failed to create directory '$d': $( $_.Exception.Message )"
                }
            }

            if ($config['usedocx']['value'] -eq 1) {
                # Remove any existing docx files, don't proceed if it fails
                try {
                    "Removing existing docx file: $( $pageCfg['docxExportFilePath'] )" | Write-Verbose
                    if ($config['dryRun']['value'] -eq 1) {
                        if (Test-Path -LiteralPath $pageCfg['docxExportFilePath']) {
                            Remove-Item -LiteralPath $pageCfg['docxExportFilePath'] -Force -ErrorAction Stop
                        }
                    }
                }catch {
                    throw "Error removing intermediary docx file $( $pageCfg['docxExportFilePath'] ): $( $_.Exception.Message )"
                }
            }

            # Publish OneNote page to Word, don't proceed if it fails
            if (! (Test-Path -LiteralPath $pageCfg['docxExportFilePath']) ) {
                try {
                    "Publishing new docx file: $( $pageCfg['docxExportFilePath'] )" | Write-Verbose
                    if ($config['dryRun']['value'] -eq 1) {
                        Publish-OneNotePage -OneNoteConnection $OneNoteConnection -PageId $pageCfg['object'].ID -Destination $pageCfg['docxExportFilePath'] -PublishFormat 'pfWord'
                    }
                }catch {
                    throw "Error while publishing page to docx file $( $pageCfg['docxExportFilePath'] ): $( $_.Exception.Message )"
                }
            }else {
                "Existing docx file: $( $pageCfg['docxExportFilePath'] )" | Write-Verbose
            }

            # Publish OneNote page to pdf, don't proceed if it fails
            if ($config['exportPdf']['value'] -eq 2) {
                if (! (Test-Path -LiteralPath $pageCfg['pdfExportFilePath']) ) {
                    try {
                        "Publishing new pdf file: $( $pageCfg['pdfExportFilePath'] )" | Write-Verbose
                        if ($config['dryRun']['value'] -eq 1) {
                            Publish-OneNotePage -OneNoteConnection $OneNoteConnection -PageId $pageCfg['object'].ID -Destination $pageCfg['pdfExportFilePathTmp'] -PublishFormat 'pfPdf'
                            Move-Item $pageCfg['pdfExportFilePathTmp'] $pageCfg['pdfExportFilePath']
                        }
                        "pdf file ready: $( $pageCfg['pdfExportFilePath'] )" | Write-Host -ForegroundColor Green
                    }catch {
                        throw "Error while publishing page to pdf file $( $pageCfg['pdfExportFilePath'] ): $( $_.Exception.Message )"
                    }
                }else {
                    "Existing pdf file: $( $pageCfg['pdfExportFilePath'].Substring(4) )" | Write-Host -ForegroundColor Green
                }
            }

            # https://gist.github.com/heardk/ded40b72056cee33abb18f3724e0a580
            # Convert .docx files, don't proceed if it fails
            $stderrFile = "$( $pageCfg['tmpPath'] )/pandoc-stderr.txt"
            try {
                # Start-Process has no way of capturing stderr / stdterr to variables, so we need to use temp files.
                "Converting docx file to markup file: $( $pageCfg['filePath'] )" | Write-Verbose
                if ($config['dryRun']['value'] -eq 1) {
                    $argumentList = @( '-f', 'docx',
                                       '-t', $pageCfg['conversion'], 
                                       '-i', $pageCfg['docxExportFilePath'], 
                                       '-o', $pageCfg['filePathNormal'], 
                                       '--wrap=none',
                                       # '--markup-headings=atx',         # Option apparently unavailable as of Pandoc 2.2.2.3.2
                                       "--extract-media=$( $pageCfg['mediaParentPathPandoc'] )" )
                    "Command line: pandoc.exe $argumentList" | Write-Verbose
                    $process = Start-Process -ErrorAction Stop -RedirectStandardError $stderrFile -PassThru -NoNewWindow -Wait -FilePath pandoc.exe -ArgumentList $argumentList # extracts into ./media of the supplied folder
                    if ($process.ExitCode -ne 0) {
                        $stderr = Get-Content $stderrFile -Raw
                        throw "pandoc failed to convert: $stderr"
                    }
                }
            }catch {
                throw "Error while converting docx file $( $pageCfg['docxExportFilePath'] ) to markup file $( $pageCfg['filePathNormal'] ): $( $_.Exception.Message )"
            }finally {
                if (Test-Path $stderrFile) {
                    Remove-Item $stderrFile -Force
                }
            }

            # Cleanup Word files
            if ($config['keepdocx']['value'] -eq 1) {
                try {
                    "Removing existing docx file: $( $pageCfg['docxExportFilePath'] )" | Write-Verbose
                    if ($config['dryRun']['value'] -eq 1) {
                        if (Test-Path -LiteralPath $pageCfg['docxExportFilePath']) {
                            Remove-Item -LiteralPath $pageCfg['docxExportFilePath'] -Force -ErrorAction Stop
                        }
                    }
                }catch {
                    Write-Error "Error removing intermediary docx file $( $pageCfg['docxExportFilePath'] ): $( $_.Exception.Message )"
                }
            }

            # Save any attachments
            foreach ($attachmentCfg in $pageCfg['insertedAttachments']) {
                try {
                    "Saving inserted attachment: $( $attachmentCfg['destination'] )" | Write-Verbose
                    if ($config['dryRun']['value'] -eq 1) {
                        Copy-Item -Path $attachmentCfg['source'] -Destination $attachmentCfg['destination'] -Force -ErrorAction Stop
                    }
                }catch {
                    Write-Error "Error while saving attachment from $( $attachmentCfg['source'] ) to $( $attachmentCfg['destination'] ): $( $_.Exception.Message )"
                }
            }

            # Rename images to have unique names - NoteName-Image#-HHmmssff.xyz
            if ($config['dryRun']['value'] -eq 1) {
                $images = Get-ChildItem -Path $pageCfg['mediaPathPandoc'] -Recurse -Force -ErrorAction SilentlyContinue
                foreach ($image in $images) {
                    # Rename Image
                    try {
                        $newimageName = if ($config['medialocation']['value'] -eq 2) {
                            "$( $pageCfg['filePathRelUnderscore'] )-$($image.BaseName)$($image.Extension)"
                        }else {
                            "$( $pageCfg['pathFromRootCompat'] )-$($image.BaseName)$($image.Extension)"
                        }
                        $newimagePath = [io.path]::combine( $pageCfg['mediaPath'], $newimageName )
                        "Moving image: $( $image.FullName ) to $( $newimagePath )" | Write-Verbose
                        if ($config['dryRun']['value'] -eq 1) {
                            $item = Move-Item -Path "$( $image.FullName )" -Destination $newimagePath -Force -ErrorAction Stop -PassThru
                        }
                    }catch {
                        Write-Error "Error while renaming image $( $image.FullName ) to $( $item.FullName ): $( $_.Exception.Message )"
                    }
                    # Change MD file Image filename References
                    try {
                        "Mutation of markup: Rename image references to unique name. Find '$( $image.Name )', Replacement: '$( $newimageName )'" | Write-Verbose
                        if ($config['dryRun']['value'] -eq 1) {
                            $content = Get-Content -LiteralPath $pageCfg['filePath'] -Raw -ErrorAction Stop # Use -LiteralPath so that characters like '(', ')', '[', ']', '`', "'", '"' are supported. Or else we will get an error "Cannot find path 'xxx' because it does not exist"
                            $content = $content.Replace("$($image.Name)", "$($newimageName)")
                            Set-ContentNoBom -LiteralPath $pageCfg['filePath'] -Value $content -ErrorAction Stop # Use -LiteralPath so that characters like '(', ')', '[', ']', '`', "'", '"' are supported. Or else we will get an error "Cannot find path 'xxx' because it does not exist"
                        }
                    }catch {
                        Write-Error "Error while renaming image file name references to '$( $newimageName ): $( $_.Exception.Message )"
                    }
                }
            }

            # Format markup content
            try {
                # If not in a dryrun
                if ($config['dryRun']['value'] -eq 1) {
                    # Get markup content
                    $content = @( Get-Content -LiteralPath $pageCfg['filePath'] -ErrorAction Stop ) # Use -LiteralPath so that characters like '(', ')', '[', ']', '`', "'", '"' are supported. Or else we will get an error "Cannot find path 'xxx' because it does not exist"
                    $content = @(
                        # If the page is not empty
                        if ($content.Count -gt 6) {
                            # If a Markup Pack is available for the chosen markup format
                            if (1) {
                                # The header and creation timestamp are removed to be rewritten later according to our preferences, as laid down in the appropriate Markup Pack
                                $content[6..($content.Count - 1)]
                            }else{
                                $content
                            }                            
                        }else {
                            # Empty page
                            ''
                        }
                    ) -join "`n"
                }

                # Mutate
                foreach ($m in $pageCfg['mutations']) {
                    foreach ($r in $m['replacements']) {
                        try {
                            "Mutation of markup: $( $m['description'] ). Regex: '$( $r['searchRegex'] )', Replacement: '$( $r['replacement'].Replace("`r", '\r').Replace("`n", '\n') )'" | Write-Verbose
                            if ($config['dryRun']['value'] -eq 1) {
                                $content = $content -replace $r['searchRegex'], $r['replacement']
                            }
                        }catch {
                            Write-Error "Failed to mutating markup content with mutation '$( $m['description'] )': $( $_.Exception.Message )"
                        }
                    }
                }
                
                # Remove trailing newlines
                $content = $content.Trim()
                
                if ($config['dryRun']['value'] -eq 1) {
                    Set-ContentNoBom -LiteralPath $pageCfg['filePath'] -Value $content -ErrorAction Stop # Use -LiteralPath so that characters like '(', ')', '[', ']', '`', "'", '"' are supported. Or else we will get an error "Cannot find path 'xxx' because it does not exist"
                }
            }catch {
                Write-Error "Error while mutating markup content: $( $_.Exception.Message )"
            }

            "Markdown file ready: $( $pageCfg['filePathNormal'] )" | Write-Host -ForegroundColor Green

        }catch {
            Write-Host "Failed to convert page: $( $pageCfg['pathFromRoot'] ). Reason: $( $_.Exception.Message )" -ForegroundColor Red
            Write-Error "Failed to convert page: $( $pageCfg['pathFromRoot'] ). Reason: $( $_.Exception.Message )"
        }

    }
}