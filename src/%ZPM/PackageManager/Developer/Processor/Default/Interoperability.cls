Class %ZPM.PackageManager.Developer.Processor.Default.Interoperability Extends %ZPM.PackageManager.Developer.Processor.Default.Document
{

Property Directory As %String(MAXLEN = "") [ InitialExpression = "i14y/" ];

Property FilenameTranslateIdentifier As %String [ InitialExpression = "-,("")" ];

Property FilenameTranslateAssociator As %String [ InitialExpression = "/___" ];

/// Extension for individual filename(s) that comprise this resource
Property FilenameExtension As %String [ InitialExpression = "xml" ];

}
