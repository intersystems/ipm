/// Provides information on how to configure the namespace used for the Verify phase (for integration tests),
/// and perhaps also at some point the settings used for a new namespace created to install an application-packaged module.
Class %ZPM.Storage.ModuleSetting.NamespaceConfig Extends %ZPM.Storage.ModuleSetting
{

Parameter DEFAULTGLOBAL = "^ZPM.Storage.ModSet.NSConfig";

/*
	If this class is eventually used to represent common details for installation of application-packaged modules,
	the set of options here will likely need future expansion.
	
*/
/// Set to 1 if the Verify namespace should be Ensemble-enabled
Property EnableEnsemble As %Boolean(XMLPROJECTION = "ATTRIBUTE") [ InitialExpression = 0 ];

/// Set to 1 if the Verify namespace should be HealthShare-enabled
/// May only be set to 1 if EnableEnsemble is also 1.
Property EnableHealthShare As %Boolean(XMLPROJECTION = "ATTRIBUTE") [ InitialExpression = 0 ];

Method MergeFrom(pOtherConfig As %ZPM.Storage.ModuleSetting.NamespaceConfig) As %ZPM.Storage.ModuleSetting.NamespaceConfig
{
	Set ..EnableEnsemble = ..EnableEnsemble || pOtherConfig.EnableEnsemble
	Set ..EnableHealthShare = ..EnableHealthShare || pOtherConfig.EnableHealthShare
	Quit $This
}

Storage Default
{
<Data name="NamespaceConfigState">
<Subscript>"NamespaceConfig"</Subscript>
<Value name="1">
<Value>EnableEnsemble</Value>
</Value>
<Value name="2">
<Value>EnableHealthShare</Value>
</Value>
</Data>
<State>NamespaceConfigState</State>
<Type>%Storage.Serial</Type>
}

}
