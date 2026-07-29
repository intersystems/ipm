Class SyncTest.SuperClass
{

Property BaseValue As %String [ InitialExpression = "original" ];

ClassMethod GetValue() As %String
{
    quit "original"
}

}
