Class %IPM.DataType.PythonWheelName Extends %IPM.DataType.RegExString
{

Parameter MAXLEN As INTEGER = 512;

/// wheel files contain only letter, numbers, hyphens
Parameter REGEX = "^[a-zA-Z0-9\-_.]+\.((whl)|(WHL))$";

}
