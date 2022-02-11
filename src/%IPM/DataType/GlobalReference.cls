Class %IPM.DataType.GlobalReference Extends %String [ ClassType = datatype ]
{

/// 511 is an upper bound for the maximum length of a global reference - see:
/// <a href="https://docs.intersystems.com/latest/csp/docbook/DocBook.UI.Page.cls?KEY=GGBL_structure#GGBL_structure_maxsubscrlen">Maximum Length of a Global Reference</a>
Parameter MAXLEN = 511;

ClassMethod IsValid(%val As %Library.RawString) As %Status [ ServerOnly = 0 ]
{
	Set tOldZReference = $ZReference
	Set tSC = $$$OK
	Try {
		Set $ZReference = %val
	} Catch e {
		// The above SET will throw a <SYNTAX> exception for an invalid global reference
		Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Invalid global reference: %1",%val))
	}
	Set $ZReference = tOldZReference
	Quit tSC
}

}
