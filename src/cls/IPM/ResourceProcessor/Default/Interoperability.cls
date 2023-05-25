Class %IPM.ResourceProcessor.Default.Interoperability Extends %IPM.ResourceProcessor.Default.Document
{

Property Directory As %String(MAXLEN = "") [ InitialExpression = "i14y/" ];

Property FilenameTranslateIdentifier As %String [ InitialExpression = "-,("")" ];

Property FilenameTranslateAssociator As %String [ InitialExpression = "/___" ];

/// Extension for individual filename(s) that comprise this resource
Property FilenameExtension As %String [ InitialExpression = "xml" ];

Method DirectoryGet() As %String
{
    If i%DirectoryDefined Return i%Directory
    Set tRoot = ##class(%File).NormalizeDirectory(..ResourceReference.Module.SourcesRoot, ..ResourceReference.Module.Root)
    For name = "i14y", "misc" {
        If ##class(%File).DirectoryExists(##class(%File).NormalizeDirectory(name, tRoot)) {
            Set i%DirectoryDefined = 1
            Set i%Directory = name _ "/"
            Return i%Directory
        }
    }
    Quit "i14y/"
}

}
