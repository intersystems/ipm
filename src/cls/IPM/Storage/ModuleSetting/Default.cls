/// Custom defaults for module
/// Each <Default Name="" Value="" /> element defines one parameter, that can be specified
/// during module installation
Class %IPM.Storage.ModuleSetting.Default Extends %IPM.Storage.ModuleSetting
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.ModSet.Default";

Property Name As %String(MAXLEN = 255, XMLPROJECTION = "ATTRIBUTE");

Property Value As %String(MAXLEN = 1000, XMLPROJECTION = "ATTRIBUTE");

ClassMethod GetCustomParameters(Output customParams, module As %IPM.Storage.Module, ByRef pParams) As %Status
{
    Kill customParams
    Set customParams = ""
    Set key = ""
    For {
        Set default = module.Defaults.GetNext(.key)
        Quit:(key="")
        If (default.%ClassName(1)="%IPM.Storage.ModuleSetting.Default") {
            Set customParams(default.Name) = default.Value
            If ($Data(pParams(default.Name))) {
                Set customParams(default.Name) = $Get(pParams(default.Name))
            }
        }
    }
    return $$$OK
}

ClassMethod EvaluateArgs(ByRef args, ByRef customParams) As %Status
{
    Set key = ""
    For {
        Set key = $Order(args(key))
        Quit:(key="")
        Set args(key) = ..EvaluateAttribute(args(key),.customParams)
    }
    return $$$OK
}

ClassMethod EvaluateAttribute(attribute As %String, ByRef customParams) As %String
{
    Set name=""
    For {
        Set name = $Order(customParams(name), 1, value)
        Quit:(name="")
        Set attribute = ##class(%IPM.Utils.Module).%RegExReplace(attribute, name, value)
    }
    return attribute
}

Storage Default
{
<Data name="DefaultState">
<Subscript>"Default"</Subscript>
<Value name="1">
<Value>Name</Value>
</Value>
<Value name="2">
<Value>Value</Value>
</Value>
</Data>
<State>DefaultState</State>
<Type>%Storage.Serial</Type>
}

}
