/// A string datatype definition which extends <class>%Library.String</class> with additional regex pattern validation. <br />
/// From https://community.intersystems.com/post/string-datatype-regular-expression-validation
Class %IPM.DataType.RegExString Extends %Library.String [ ClassType = datatype ]
{

/// Set PATTERN to empty and final, as it is not relevant on
/// this type, but is inherited from <class>%Library.String</class>
Parameter PATTERN [ Final ];

/// Set VALUELIST to empty and final, as it is not relevant on
/// this type, but is inherited from <class>%Library.String</class>
Parameter VALUELIST [ Final ];

/// Set DISPLAYLIST to empty and final, as it is not relevant on
/// this type, but is inherited from <class>%Library.String</class>
Parameter DISPLAYLIST [ Final ];

/// Set a valid regex pattern for value validation
Parameter REGEX As STRING;

/// The XMLPATTERN to regex by default. Can be overridden.
Parameter XMLPATTERN = {..#REGEX};

/// Tests if the logical value <var>%val</var>, which is a string, is valid.
/// The validation is based on the class parameter settings used for the class attribute this data type is associated with.
/// In this case, <a href="#MINLEN">MINLEN</a>, <a href="#MAXLEN">MAXLEN</a>, and <a href="#REGEX">REGEX</a>.
ClassMethod IsValid(%val As %CacheString) As %Status [ ServerOnly = 0 ]
{
    // Length checks
    if (..#MAXLEN '= "") {
        if ($length(%val) > ..#MAXLEN) {
            return $$$ERROR($$$DTMaxLen, %val, ..#MAXLEN)
        }
    }
    if (..#MINLEN '= "") {
        if ($length(%val) < ..#MINLEN) {
            return $$$ERROR($$$DTMinLen, %val, ..#MINLEN)
        }
    }
    // Regex check
    if (..#REGEX '= "") {
        try {
            if '$MATCH(%val, ..#REGEX) {
                return $$$ERROR($$$DTPattern, %val, ..#REGEX)
            }
        } catch e {
            return e.AsStatus()
        }
    }
    return $$$OK
}

ClassMethod FromWildCard(wildcard As %String) As %String
{
    Set regex = ""
    For i=1:1:$Length(wildcard) {
        Set char = $Extract(wildcard, i)
        If char = "*" {
            Set regex = regex_".*"
        } Else {
            Set regex = regex_char
        }
    }
    // Is there a way to return an instance of this class instead of %String?
    Quit "^(?i)"_regex_"$"
}

}
