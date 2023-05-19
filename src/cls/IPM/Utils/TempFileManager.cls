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
	Set tTempFileName = ##class(%Library.File).TempFilename(pExtension)
	Set ..Files($Increment(..Files)) = tTempFileName
	Quit tTempFileName
}

/// Gets a temporary folder name (and creates a folder with that name)
/// @API.Method
/// @Modifier Availability InterSystems
Method GetTempFolderName() As %String
{
	Set tTempFileName = ##class(%Library.File).TempFilename()
	If ##class(%Library.File).Exists(tTempFileName) {
		// In IRIS, TempFilename() creates the file. Flag for later cleanup.
		Set ..Files($Increment(..Files)) = tTempFileName
	}
	Set tTempFolderName = tTempFileName_"d/" // Append "d/" for uniqueness on IRIS.
	$$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(tTempFolderName))
	Set ..Folders($Increment(..Folders)) = tTempFolderName
	Quit tTempFolderName
}

Method Cleanup() As %Status
{
	Set tSC = $$$OK
	For tIndex=1:1:$Get(..Files) {
		Set tSC = $$$ADDSC(tSC,##class(%Library.File).Delete(..Files(tIndex)))
	}
	Kill ..Files
	
	For tIndex=1:1:$Get(..Folders) {
		Set tSC = $$$ADDSC(tSC,##class(%IPM.Utils.File).RemoveDirectoryTree(..Folders(tIndex)))
	}
	Kill ..Folders
	Quit tSC
}

Method %OnClose() As %Status [ Private, ServerOnly = 1 ]
{
	Quit $$$ADDSC(##super(),..Cleanup())
}

}
