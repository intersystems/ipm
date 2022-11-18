/// Module lifecycle, but with different default handling for deployment of resources. If no value is specified for the "Deploy" attribute,
/// the resource is marked for deployment.
Class %IPM.Lifecycle.DeployedModule Extends %IPM.Lifecycle.Module
{

Parameter DEPLOYBYDEFAULT As BOOLEAN = 1;

}
