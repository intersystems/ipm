Class PhaseConfig.Main
{

ClassMethod AfterCompile()
{
    Set config = ##class(%IPM.General.EnvironmentConfig).%Get()
    Set value = config.GetArg("phase-config", "after-compile")
    Write !, "AfterCompile: ", value
}

ClassMethod BeforeVerify()
{
    Set config = ##class(%IPM.General.EnvironmentConfig).%Get()
    Set value = config.GetArg("phase-config", "before-verify")
    Write !, "BeforeVerify: ", value
}

ClassMethod MyPhase()
{
    Set config = ##class(%IPM.General.EnvironmentConfig).%Get()
    Set value = config.GetArg("phase-config", "my-phase")
    Write !, "MyPhase: ", value
}

}
