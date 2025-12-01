Class %IPM.General.LockFile.Repository Extends (%RegisteredObject, %JSON.Adaptor)
{

Property Type As %String(%JSONFIELDNAME = "type", MAXLEN = "");

Property Enabled As %Boolean(%JSONFIELDNAME = "enabled");

Property OverriddenSortOrder As %Integer(%JSONFIELDNAME = "overriddenSortOrder");

Property ReadOnly As %Boolean(%JSONFIELDNAME = "readOnly");

Property Root As %String(%JSONFIELDNAME = "root", MAXLEN = "");

Property Depth As %Integer(%JSONFIELDNAME = "depth");

Property URL As %IPM.DataType.RepoLocation(%JSONFIELDNAME = "url");

Property DeploymentEnabled As %Boolean(%JSONFIELDNAME = "deploymentEnabled");

Property OrasNamespace As %IPM.DataType.OrasNamespace(%JSONFIELDNAME = "orasNamespace");

}
