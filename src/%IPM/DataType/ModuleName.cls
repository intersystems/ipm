Class %IPM.DataType.ModuleName Extends %String [ ClassType = datatype ]
{

Parameter MAXLEN = 255;

/// Tests if the logical value <var>%val</var>, which is a string, is valid.
/// The validation is based on the class parameter settings used for the class attribute this data type is associated with.
/// In this case, <a href="#MINLEN">MINLEN</a>, <a href="#MAXLEN">MAXLEN</a>, <a href="#VALUELIST">VALUELIST</a>, and <a href="#PATTERN">PATTERN</a>.
ClassMethod IsValid(%val As %Library.RawString) As %Status
{
    If ($Length(%val) > ..#MAXLEN) {
        Return $$$ERROR($$$DTMaxLen, %val, ..#MAXLEN)
    }
    
    // Module names may not contain spaces.
    If (%val [ " ") {
	    // "##safexpression" idea copied from %Dictionary.Classname
	    // When used as a datatype for a property, this reports the class and property name.
    	Return $$$ERROR($$$DatatypeValidationFailed,##safeexpression(""""_$Get(%classname,"???")_":"_$Get(%membername,"???")_""""),%val)
    }
    
    Quit $$$OK
}

}
