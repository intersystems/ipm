Class %IPM.ResourceProcessor.Default.Interoperability Extends %IPM.ResourceProcessor.Default.Document
{

Property Directory As %String(MAXLEN = "") [ InitialExpression = "i14y/" ];

Property FilenameTranslateIdentifier As %String [ InitialExpression = "-,("")" ];

Property FilenameTranslateAssociator As %String [ InitialExpression = "/___" ];

/// Extension for individual filename(s) that comprise this resource
Property FilenameExtension As %String [ InitialExpression = "xml" ];

Method DirectoryGet() As %String
{
    if i%DirectoryDefined return i%Directory
    set tRoot = ##class(%File).NormalizeDirectory(..ResourceReference.Module.SourcesRoot, ..ResourceReference.Module.Root)
    for name = "i14y", "misc" {
        if ##class(%File).DirectoryExists(##class(%File).NormalizeDirectory(name, tRoot)) {
            set i%DirectoryDefined = 1
            set i%Directory = name _ "/"
            return i%Directory
        }
    }
    quit "i14y/"
}

}
