Include ResourceTest.NestedInclude

Class ResourceTest.TestIncludeLoads
{

ClassMethod CallIncludeMacro()
{
    write !, "I call the macro within SimpleApp.NestedInclude.inc"
    write !, $$$TestMacro
}

}
