Class %IPM.ResourceProcessor.Default.Include Extends %IPM.ResourceProcessor.Default.Routine
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Standard resource processor for include files.";

/// May be set to determine the value of <property>Extension</property> based on a static value rather than based on the resource name.
Parameter EXTENSION = "INC";

/// Directory relative to module root containing the exported resource.
/// Normally defaults to the resource's extension (lower-case) if unspecified;
/// In this case, overridden because the default Routine processor hard-codes to "rtn"
Property Directory As %String(MAXLEN = "") [ InitialExpression = "inc" ];

/// Extension for individual filename(s) that comprise this resource
Property FilenameExtension As %String [ InitialExpression = "inc" ];

}
