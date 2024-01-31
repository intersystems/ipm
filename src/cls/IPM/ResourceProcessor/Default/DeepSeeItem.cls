Class %IPM.ResourceProcessor.Default.DeepSeeItem Extends %IPM.ResourceProcessor.Default.Document
{

Parameter EXTENSION = ".DFI";

Parameter ATTRIBUTES As STRING = "Directory,Keywords,FilenameTranslateIdentifier,FilenameTranslateAssociator";

/// Export format
Property Format As %String;

Property Directory As %String(MAXLEN = "") [ InitialExpression = "dfi" ];

Property FilenameExtension As %String [ InitialExpression = "xml" ];

Property Keywords As %String;

/// Characters in the filename to use as the identifier in $translate when determining the resource's filename on disk
/// The default behavior is to replace "." with "/" and ignore "%"
Property FilenameTranslateIdentifier As %String [ InitialExpression = "-% ,("")" ];

/// Characters in the filename to use as the associator in $translate when determining the resource's filename on disk
/// The default behavior is to replace "." with "/" and ignore "%"
Property FilenameTranslateAssociator As %String [ InitialExpression = "/_____" ];

Method %OnNew(pResourceReference As %IPM.Storage.ResourceReference) As %Status [ Private, ServerOnly = 1 ]
{
    Set tSC = ##super(pResourceReference)
    If (..Format = "") {
        Set ..Format = $Case($$$lcase(..FilenameExtension),"dfi":"UDL",:"XML")
    }
    Quit tSC
}

Method OnExportItem(pFullExportPath As %String, pItemName As %String, ByRef pItemParams, ByRef pParams, Output pItemHandled As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Set tVerbose = $Get(pParams("Verbose"))
	If ..Format = "XML" {
        Set tSC = $System.OBJ.Export(pItemName,pFullExportPath,"-d")
	} ElseIf (..Format = "UDL") {
	    Set tSC = $System.OBJ.ExportUDL(pItemName,pFullExportPath,"-d")
	}
	Set pItemHandled = 1
	If $$$ISOK(tSC),tVerbose {
		Write !,"Exported '",pItemName,"' to ",pFullExportPath
	}
	Quit tSC
}

Method OnPhase(pPhase As %String, ByRef pParams, Output pResourceHandled As %Boolean = 0) As %Status
{
  Set tInScope = ..ResourceReference.IsInScope(pPhase,.tInCurrentPhase)
  If (..ResourceReference.Name '[ "*") || '(((pPhase = "Reload") && tInScope) || tInCurrentPhase) || ..ResourceReference.Generated || ..ResourceReference.Preload {
    Quit ##super(pPhase, .pParams, .pResourceHandled)
  }

  Set tVerbose = $Get(pParams("Verbose"), 0)
  Set tSC = $$$OK
  Set pResourceHandled = 0
  try {
    Set tNameExt = "." _ $$$lcase($Piece(..ResourceReference.Name, ".", *))
    Set tName = $Piece(..ResourceReference.Name, ".", 1, *-1)
    Set tName = $Translate(tName, "*"_..FilenameTranslateIdentifier, "*"_..FilenameTranslateAssociator)
    Set tRoot = ..ResourceReference.Module.Root

    Set tSubDirectory = $Select(..ResourceReference.Preload:"preload/",1:"")
    Set tResourceDirectory = tRoot _ "/" _ tSubDirectory

    Set tSourceRoot = ..ResourceReference.Module.SourcesRoot
    If tSourceRoot'="","\/"'[$Extract(tSourceRoot, *) {
      Set tSourceRoot = tSourceRoot _ "/"
    }
    Set tDirectory = ..Directory
    If tDirectory'="","\/"'[$Extract(tDirectory, *) {
      Set tDirectory = tDirectory _ "/"
    } Else {
      Set tDirectory = "dfi/"
    }
    Set tResourceDirectory = ##class(%File).NormalizeDirectory(tResourceDirectory_tSourceRoot_tDirectory)
    Set tFileExt = ".xml"
    Set tWildcards = tName _ tFileExt _ ";" _ tName _ tNameExt
    If $$$isUNIX {
      Set tWildcards = tWildcards _ tName _ $$$ucase(tFileExt) _ ";" _ tName _ $$$ucase(tNameExt)
    }
    Do ##class(%IPM.Utils.File).FindFiles(tResourceDirectory, tWildcards, .tList)
    For i=1:1:tList {
      Set $ListBuild(tDocName, tResourcePath) = tList(i)
      $$$ThrowOnError(..OnLoad(tResourcePath, tVerbose, tInCurrentPhase, .tLoadedList, .pParams))
    }
  } 
  catch ex {
    Set tSC = ex.AsStatus()
  }
  Quit tSC
}

Method OnResolveChildren(ByRef pResourceArray) As %Status
{
    Set tItem = ""
    For {
        Set tItem = $Order(pResourceArray(tItem))
        If (tItem = "") {
            Quit
        }
        Set tItemName = $Piece(tItem, "." , 1, *-1)
        Set tFullName = ##class(%DeepSee.UserLibrary.FolderItem).fullNameFromDocumentName(tItem)
        #dim tObj As %DeepSee.UserLibrary.FolderItem = ##class(%DeepSee.UserLibrary.Utils).%OpenFolderItem(tFullName, .tSC)
        If ('$IsObject(tObj)) {
            Kill pResourceArray(tItem)
            Continue
        }
        If (..Keywords'="") {
            Set tKeywords = $ListFromString(tObj.keywords)
            Set tDesiredKeywords = $ListFromString(..Keywords)
            Set tGood = 1
            For i=1:1:$ListLength(tDesiredKeywords) {
                If ('$ListFind(tKeywords, $ListGet(tDesiredKeywords, i))) {
                    Set tGood = 0
                    Quit
                }
            }
            If ('tGood) {
                Kill pResourceArray(tItem)
                Continue
            }
        }
        Set tSourceRoot = ..ResourceReference.Module.SourcesRoot
        If tSourceRoot'="","\/"'[$Extract(tSourceRoot, *) {
            Set tSourceRoot = tSourceRoot _ "/"
        }
        Set tItemName = $Translate(tItemName, ..FilenameTranslateIdentifier, ..FilenameTranslateAssociator)
        Set pResourceArray(tItem,"RelativePath") = tSourceRoot_..Directory_"/"_tItemName_"."_..FilenameExtension
    }
    Quit $$$OK
}

Method OnGetUniqueName(Output pUniqueName)
{
    If (..Keywords '= "") {
        Set pUniqueName = ..Keywords
    }
}

}
