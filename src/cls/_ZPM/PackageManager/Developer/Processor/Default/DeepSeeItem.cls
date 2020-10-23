Class %ZPM.PackageManager.Developer.Processor.Default.DeepSeeItem Extends %ZPM.PackageManager.Developer.Processor.Default.Document
{

Parameter EXTENSION = ".DFI";

Parameter ATTRIBUTES As STRING = "Directory,Keywords,FilenameTranslateIdentifier,FilenameTranslateAssociator";

/// Export format
Property Format As %String;

Property Directory As %String(MAXLEN = "") [ InitialExpression = "dfi" ];

Property FilenameExtension As %String [ InitialExpression = "xml" ];

Property Keywords As %String;

Property FilenameTranslateIdentifier As %String [ InitialExpression = "-%,("")" ];

Property FilenameTranslateAssociator As %String [ InitialExpression = "/___" ];

Method %OnNew(pResourceReference As %ZPM.PackageManager.Developer.ResourceReference) As %Status [ Private, ServerOnly = 1 ]
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
    Set tSC = $$$OK
    Set pResourceHandled = 0
    Try {
        Set tVerbose = $Get(pParams("Verbose"),0)
        Set tDeveloperMode = $Get(pParams("DeveloperMode"),0)
        Set tName = $Piece(..ResourceReference.Name,".",1,*-1)
        Set tRoot = ..ResourceReference.Module.Root

        If (pPhase = "Reload") {
            If '..ResourceReference.Generated { 
                Set tSubDirectory = $Select(..ResourceReference.Preload:"preload/",1:"")
                Set tResourceDirectory = tRoot_"/"_tSubDirectory
                
                Set tSourceRoot = ..ResourceReference.Module.SourcesRoot
                If tSourceRoot'="","\/"'[$EXTRACT(tSourceRoot, *) {
                    Set tSourceRoot = tSourceRoot _ "/"
                }

                Set tDirectory = ..Directory
                If tDirectory'="","\/"'[$EXTRACT(tDirectory, *) {
                    Set tDirectory = tDirectory _ "/"
                } Else {
                    Set tDirectory = "dfi/"
                }

                Set tResourceDirectory = ##class(%File).NormalizeDirectory(tResourceDirectory_tSourceRoot_tDirectory)
                
                If '..ResourceReference.Preload {
                    Set tResourcePath = tResourceDirectory_$tr(tName,..FilenameTranslateIdentifier,..FilenameTranslateAssociator)_".xml"
                    Set tSC = $System.OBJ.Load(tResourcePath,$Select(tVerbose:"/display",1:"/nodisplay")_"/nocompile")
                    If $$$ISERR(tSC) {
                        Quit
                    }
                }
            }
        }

    } Catch e {
		    Set tSC = e.AsStatus()
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
        If ('$ISOBJECT(tObj)) {
            Kill pResourceArray(tItem)
            Continue
        }
        If (..Keywords'="") {
            Set tKeywords = $LISTFROMSTRING(tObj.keywords)
            Set tDesiredKeywords = $LISTFROMSTRING(..Keywords)
            Set tGood = 1
            For i=1:1:$LISTLENGTH(tDesiredKeywords) {
                If ('$LISTFIND(tKeywords, $LISTGET(tDesiredKeywords, i))) {
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
        If tSourceRoot'="","\/"'[$EXTRACT(tSourceRoot, *) {
            Set tSourceRoot = tSourceRoot _ "/"
        }
        Set tItemName = $TRANSLATE(tItemName, "-", "/")
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

Storage Default
{
<Data name="DeepSeeItemDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>FilenameExtension</Value>
</Value>
<Value name="3">
<Value>Format</Value>
</Value>
</Data>
<DataLocation>^%ZPM.PackageMaE05F.DeepSeeItemD</DataLocation>
<DefaultData>DeepSeeItemDefaultData</DefaultData>
<IdLocation>^%ZPM.PackageMaE05F.DeepSeeItemD</IdLocation>
<IndexLocation>^%ZPM.PackageMaE05F.DeepSeeItemI</IndexLocation>
<StreamLocation>^%ZPM.PackageMaE05F.DeepSeeItemS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
