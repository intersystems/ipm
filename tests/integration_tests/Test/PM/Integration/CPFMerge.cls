Class Test.PM.Integration.CPFMerge Extends Test.PM.Integration.Base
{

Parameter TargetModuleName As STRING = "cpf-merge";

Method TestCPFMerge()
{
    Set tModuleDir = ..GetModuleDir(..#TargetModuleName)

    Set tSC = ##class(%IPM.Main).Shell("load -v "_tModuleDir)
    Do $$$AssertStatusOK(tSC, "Loaded module successfully")

    // TODO - Add more tests here
}

}
