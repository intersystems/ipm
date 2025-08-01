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
    set tSC = ##super(pResourceReference)
    if (..Format = "") {
        set ..Format = $case($$$lcase(..FilenameExtension),"dfi":"UDL",:"XML")
    }
    quit tSC
}

Method OnExportItem(
	pFullExportPath As %String,
	pItemName As %String,
	ByRef pItemParams,
	ByRef pParams,
	Output pItemHandled As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    set tVerbose = $get(pParams("Verbose"))
    if ..Format = "XML" {
        set tSC = $system.OBJ.Export(pItemName,pFullExportPath,"-d"_"/createdirs")
    } elseif (..Format = "UDL") {
        set tSC = $system.OBJ.ExportUDL(pItemName,pFullExportPath,"-d"_"/createdirs")
    }
    set pItemHandled = 1
    if $$$ISOK(tSC),tVerbose {
        write !,"Exported '",pItemName,"' to ",pFullExportPath
    }
    quit tSC
}

Method OnPhase(
	pPhase As %String,
	ByRef pParams,
	Output pResourceHandled As %Boolean = 0) As %Status
{
    set tInScope = ..ResourceReference.IsInScope(pPhase,.tInCurrentPhase)
    if (..ResourceReference.Name '[ "*") || '(((pPhase = "Reload") && tInScope) || tInCurrentPhase) || ..ResourceReference.Generated || ..ResourceReference.Preload {
        quit ##super(pPhase, .pParams, .pResourceHandled)
    }

    set tVerbose = $get(pParams("Verbose"), 0)
    set tSC = $$$OK
    set pResourceHandled = 0
    try {
        set tNameExt = "." _ $$$lcase($piece(..ResourceReference.Name, ".", *))
        set tName = $piece(..ResourceReference.Name, ".", 1, *-1)
        set tName = $translate(tName, "*"_..FilenameTranslateIdentifier, "*"_..FilenameTranslateAssociator)
        set tRoot = ..ResourceReference.Module.Root

        set tSubDirectory = $select(..ResourceReference.Preload:"preload/",1:"")
        set tResourceDirectory = tRoot _ "/" _ tSubDirectory

        set tSourceRoot = ..ResourceReference.Module.SourcesRoot
        if tSourceRoot'="","\/"'[$extract(tSourceRoot, *) {
            set tSourceRoot = tSourceRoot _ "/"
        }
        set tDirectory = ..Directory
        if tDirectory'="","\/"'[$extract(tDirectory, *) {
            set tDirectory = tDirectory _ "/"
        } else {
            set tDirectory = "dfi/"
        }
        set tResourceDirectory = ##class(%File).NormalizeDirectory(tResourceDirectory_tSourceRoot_tDirectory)
        set tFileExt = ".xml"
        set tWildcards = tName _ tFileExt _ ";" _ tName _ tNameExt
        if $$$isUNIX {
            set tWildcards = tWildcards _ tName _ $$$ucase(tFileExt) _ ";" _ tName _ $$$ucase(tNameExt)
        }
        do ##class(%IPM.Utils.File).FindFiles(tResourceDirectory, tWildcards, .tList)
        for i=1:1:tList {
            set $listbuild(tDocName, tResourcePath) = tList(i)
            $$$ThrowOnError(..OnLoad(tResourcePath, tVerbose, tInCurrentPhase, .tLoadedList, .pParams))
        }
    } catch ex {
        set tSC = ex.AsStatus()
    }
    quit tSC
}

Method OnResolveChildren(ByRef pResourceArray) As %Status
{
    set tItem = ""
    for {
        set tItem = $order(pResourceArray(tItem))
        if (tItem = "") {
            quit
        }
        set tItemName = $piece(tItem, "." , 1, *-1)
        set tFullName = ##class(%DeepSee.UserLibrary.FolderItem).fullNameFromDocumentName(tItem)
        #dim tObj As %DeepSee.UserLibrary.FolderItem = ##class(%DeepSee.UserLibrary.Utils).%OpenFolderItem(tFullName, .tSC)
        if ('$isobject(tObj)) {
            kill pResourceArray(tItem)
            continue
        }
        if (..Keywords'="") {
            set tKeywords = $listfromstring(tObj.keywords)
            set tDesiredKeywords = $listfromstring(..Keywords)
            set tGood = 1
            for i=1:1:$listlength(tDesiredKeywords) {
                if ('$listfind(tKeywords, $listget(tDesiredKeywords, i))) {
                    set tGood = 0
                    quit
                }
            }
            if ('tGood) {
                kill pResourceArray(tItem)
                continue
            }
        }
        set tSourceRoot = ..ResourceReference.Module.SourcesRoot
        if tSourceRoot'="","\/"'[$extract(tSourceRoot, *) {
            set tSourceRoot = tSourceRoot _ "/"
        }
        set tItemName = $translate(tItemName, ..FilenameTranslateIdentifier, ..FilenameTranslateAssociator)
        set pResourceArray(tItem,"RelativePath") = tSourceRoot_..Directory_"/"_tItemName_"."_..FilenameExtension
    }
    quit $$$OK
}

Method OnGetUniqueName(Output pUniqueName)
{
    if (..Keywords '= "") {
        set pUniqueName = ..Keywords
    }
}

}
