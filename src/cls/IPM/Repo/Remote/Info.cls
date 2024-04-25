Class %IPM.Repo.Remote.Info Extends (%RegisteredObject, %JSON.Adaptor)
{

Parameter %JSONIGNOREINVALIDFIELD As BOOLEAN = 1;

Property version As %String;

Property available As %Boolean [ InitialExpression = 1 ];

Method ToString() As %String
{
    Quit $Select(..available:..version,1:"currently unavailable")
}

}
