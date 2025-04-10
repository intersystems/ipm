Class %IPM.DataType.PhaseWhen Extends %Library.String [ ClassType = datatype ]
{

/// The maximum number of characters the string can contain.
Parameter MAXLEN As INTEGER = 50;

/// Used for enumerated (multiple-choice) attributes.
/// <var>VALUELIST</var> is either a null string ("") or a delimiter
/// separated list (where the delimiter is the first character) of logical values.
/// If a non-null value is present, then the attribute is restricted to values
/// in the list, and the validation code simply checks to see if the value is in the list.
Parameter VALUELIST = ",Before,After";

}
