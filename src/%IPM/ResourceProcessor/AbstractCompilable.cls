Class %IPM.ResourceProcessor.AbstractCompilable Extends %IPM.ResourceProcessor.Abstract [ Abstract ]
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING;

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "CompileAfter,Flags";

/// Comma-separated list of resource names after which this resource should be compiled.
Property CompileAfter As %String(MAXLEN = "");

/// Flags/qualifiers to compile with (overriding any more general defaults); "verbose" added per lifecycle command.
Property Flags As %String(MAXLEN = "") [ InitialExpression = "ck" ];

/// Flags/qualifiers to export items with.
Property ExportFlags As %String(MAXLEN = "");

}
