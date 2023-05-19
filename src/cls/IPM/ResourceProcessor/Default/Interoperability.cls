Class %IPM.ResourceProcessor.Default.Interoperability Extends %IPM.ResourceProcessor.Default.Document
{

Property Directory As %String(MAXLEN = "") [ InitialExpression = "i14y/" ];

Property FilenameTranslateIdentifier As %String [ InitialExpression = "-,("")" ];

Property FilenameTranslateAssociator As %String [ InitialExpression = "/___" ];

/// Extension for individual filename(s) that comprise this resource
Property FilenameExtension As %String [ InitialExpression = "xml" ];

}
