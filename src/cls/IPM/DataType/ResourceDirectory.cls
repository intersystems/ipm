Class %IPM.DataType.ResourceDirectory Extends %Library.String [ ClassType = datatype ]
{

Parameter MAXLEN = 255;

/// Tests if the logical value <var>%val</var>, which is a string, is valid.
/// The validation is based on the class parameter settings used for the class attribute this data type is associated with.
/// In this case, <a href="#MINLEN">MINLEN</a>, <a href="#MAXLEN">MAXLEN</a>, <a href="#VALUELIST">VALUELIST</a>, and <a href="#PATTERN">PATTERN</a>.
ClassMethod IsValid(%val As %RawString) As %Status [ ServerOnly = 0 ]
{
    if $extract(%val) = "/" {
        return $$$ERROR($$$GeneralError, "Resource directory cannot start with a slash.")
    }
    set segments = $listfromstring(%val, "/")
    set ptr = 0
    while $listnext(segments, ptr, seg) {
        if seg = ".." {
            return $$$ERROR($$$GeneralError, "For security reasons, resource directory cannot contain '..'.")
        }
    }
    return $$$OK
}

}
