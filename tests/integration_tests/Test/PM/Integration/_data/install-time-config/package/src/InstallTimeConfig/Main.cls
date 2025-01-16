Class InstallTimeConfig.Main Extends InstallTimeConfigDependency.Main
{

Parameter MagicValue = 42;

Parameter PackageName = "install-time-config";

// Copying because apparently we can't auto inherit the [ CodeMode = objectgenerator ] method ?!

ClassMethod RunOnLoad() [ CodeMode = objectgenerator ]
{
    #dim config As %IPM.General.EnvironmentConfig
    Set config = ##class(%IPM.General.EnvironmentConfig).%Get()
    Set magicValue = config.GetArg(..#PackageName, "nested", "magic")
    If magicValue '= ..#MagicValue {
        If magicValue = "" {
            Set errorText = $$$FormatText("Magic value is not set. Did you provide an env.json?")
        } Else {
            Set errorText = $$$FormatText("Magic value is not '%1', but '%2'", ..#MagicValue, magicValue)
        }
        $$$ThrowStatus($$$ERROR($$$GeneralError, errorText))
    }
    Write !, "Successfully acquired magic value: ", magicValue
}

}
