Class AllResources.Main
{

ClassMethod Process() As %String
{
    #include AllResources
    return "Processing with constant: " _ $$$CONSTANT
}

}
