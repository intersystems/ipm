Class %IPM.DataType.OrasNamespace Extends %IPM.DataType.RegExString
{

Parameter MAXLEN = 2048;

/// OCI repository names are lowercase, e.g. "/Packages/ipm/" -> "packages/ipm"
ClassMethod Normalize(%val As %RawString) As %IPM.DataType.OrasNamespace
{
    return $zconvert($zstrip(%val, "<>", "/"), "L")
}

}
