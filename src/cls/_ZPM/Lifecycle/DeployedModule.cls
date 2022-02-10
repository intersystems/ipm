/// Module lifecycle, but with different default handling for deployment of resources. If no value is specified for the "Deploy" attribute,
/// the resource is marked for deployment.
Class %ZPM.Lifecycle.DeployedModule Extends %ZPM.Lifecycle.Module
{

Parameter DEPLOYBYDEFAULT As BOOLEAN = 1;

}
