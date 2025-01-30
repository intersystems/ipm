Class MyPyWheel.Main
{

ClassMethod RunOnLoad() [ CodeMode = objectgenerator ]
{
    Set dummyPackage = ##class(%SYS.Python).Import("ipm_dummy_package")
}

}
