/// Application lifecycle that deploys resources in all dependencies by default (unless Deploy="false" is expcitly stated in the dependency)
Class %ZPM.PackageManager.Developer.Lifecycle.DeployedApplication Extends %ZPM.PackageManager.Developer.Lifecycle.Application
{

Parameter DEPLOYBYDEFAULT As BOOLEAN = 1;

}
