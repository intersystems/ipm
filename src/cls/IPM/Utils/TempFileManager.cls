/// Helper class to ensure temp files/folders are cleaned up
/// @API.Object
/// @Modifier Availability InterSystems
/// @API.Object.Instantiable
/// @Modifier Availability Forbidden
Class %IPM.Utils.TempFileManager Extends %IPM.General.Singleton
{

Property Files [ MultiDimensional, Private ];

Property Folders [ MultiDimensional, Private ];

/// Gets a temporary file name
/// @API.Method
/// @Modifier Availability InterSystems
Method GetTempFileName(pExtension As %String) As %String
{
    set tTempFileName = ##class(%Library.File).TempFilename(pExtension)
    set ..Files($increment(..Files)) = tTempFileName
    quit tTempFileName
}

/// Gets a temporary folder name (and creates a folder with that name)
/// @API.Method
/// @Modifier Availability InterSystems
Method GetTempFolderName() As %String
{
    set tTempFileName = ##class(%Library.File).TempFilename()
    if ##class(%Library.File).Exists(tTempFileName) {
        // In IRIS, TempFilename() creates the file. Flag for later cleanup.
        set ..Files($increment(..Files)) = tTempFileName
    }
    set tTempFolderName = tTempFileName_"d/" // Append "d/" for uniqueness on IRIS.
    $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(tTempFolderName))
    set ..Folders($increment(..Folders)) = tTempFolderName
    quit tTempFolderName
}

Method Cleanup() As %Status
{
    set tSC = $$$OK
    for tIndex=1:1:$get(..Files) {
        set tSC = $$$ADDSC(tSC,##class(%Library.File).Delete(..Files(tIndex)))
    }
    kill ..Files

    for tIndex=1:1:$get(..Folders) {
        set tSC = $$$ADDSC(tSC,##class(%IPM.Utils.File).RemoveDirectoryTree(..Folders(tIndex)))
    }
    kill ..Folders
    quit tSC
}

Method %OnClose() As %Status [ Private, ServerOnly = 1 ]
{
    quit $$$ADDSC(##super(),..Cleanup())
}

}
