Class %ZPM.PackageManager.Developer.Processor.Default.DeepSeeItem Extends %ZPM.PackageManager.Developer.Processor.Default.Document
{

Parameter EXTENSION = ".DFI";

Parameter ATTRIBUTES As STRING = "Directory,Keywords";

/// Export format
Property Format As %String [ InitialExpression = "UDL" ];

Property Directory As %String(MAXLEN = "") [ InitialExpression = "dfi" ];

Property FilenameExtension As %String [ InitialExpression = "dfi" ];

Property Keywords As %String;

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
