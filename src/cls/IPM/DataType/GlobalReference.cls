Class %IPM.DataType.GlobalReference Extends %String [ ClassType = datatype ]
{

/// 511 is an upper bound for the maximum length of a global reference - see:
/// <a href="https://docs.intersystems.com/latest/csp/docbook/DocBook.UI.Page.cls?KEY=GGBL_structure#GGBL_structure_maxsubscrlen">Maximum Length of a Global Reference</a>
Parameter MAXLEN = 511;

ClassMethod IsValid(%val As %Library.RawString) As %Status [ ServerOnly = 0 ]
{
    set tOldZReference = $zreference
    set tSC = $$$OK
    try {
        set $zreference = %val
    } catch e {
        // The above SET will throw a <SYNTAX> exception for an invalid global reference
        set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Invalid global reference: %1",%val))
    }
    set $zreference = tOldZReference
    quit tSC
}

}
