Class %IPM.General.Archive Extends %IPM.General.IConfigurable
{

/// Creates an archive with the contents of <var>pSourceDirectory</var> in <var>pArchiveFileName</var>
ClassMethod Create(
	pSourceDirectory As %String,
	pArchiveFileName As %String,
	Output pOutput) As %Status
{
    set tSC = $$$OK
    try {
        kill pOutput
        set pOutput = 0

        if ($get(pSourceDirectory) = "") {
            set tSC = $$$ERROR($$$GeneralError,"Source directory not specified.")
            quit
        }
        if ($get(pArchiveFileName) = "") {
            set tSC = $$$ERROR($$$GeneralError,"Archive filename not specified.")
            quit
        }
        if '##class(%File).DirectoryExists(pSourceDirectory) {
            set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Directory %1 does not exist",pArchiveFileName))
            quit
        }
        set pSourceDirectory = ##class(%File).NormalizeFilenameWithSpaces(##class(%File).NormalizeDirectory(pSourceDirectory))
        set pArchiveFileName = ##class(%File).NormalizeFilenameWithSpaces(pArchiveFileName)

        set archive = ##class(%IPM.Utils.FileBinaryTar).Compact(pSourceDirectory, 1, pArchiveFileName, pSourceDirectory)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Extracts the contents of <var>pArchiveFileName</var> into <var>pTargetDirectory</var>
ClassMethod Extract(
	pArchiveFileName As %String,
	pTargetDirectory As %String,
	Output pOutput) As %Status
{
    set tSC = $$$OK
    try {
        kill pOutput
        set pOutput = 0
        if ($get(pArchiveFileName) = "") {
            set tSC = $$$ERROR($$$GeneralError,"Archive filename not specified.")
            quit
        }
        if ($get(pTargetDirectory) = "") {
            set tSC = $$$ERROR($$$GeneralError,"Target directory not specified.")
            quit
        }
        if '##class(%File).DirectoryExists(pTargetDirectory) {
            set tResult = ##class(%File).CreateDirectoryChain(pTargetDirectory,.tReturn)
            if 'tResult {
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error creating directory chain %1: %2",pTargetDirectory,tReturn))
                quit
            }
        }
        if $isobject(pArchiveFileName),pArchiveFileName.%IsA("%Stream.Object") {
            set tStream = ##class(%Stream.FileBinary).%New()
            set tStream.Filename = ##class(%File).TempFilename("tgz")
            do tStream.CopyFromAndSave(pArchiveFileName)
            set tStream2 = ##class(%Stream.FileBinaryGzip).%New()
            set tStream2.Filename = tStream.Filename
            set extracted = ##class(%IPM.Utils.FileBinaryTar).ExtractStream(tStream2, pTargetDirectory)
        } else {
            set extracted = ##class(%IPM.Utils.FileBinaryTar).ExtractFile(pArchiveFileName, 1, pTargetDirectory)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

}
