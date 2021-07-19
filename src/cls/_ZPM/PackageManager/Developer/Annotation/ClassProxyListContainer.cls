/// Container class used by the package manager code (outside this package) to build the set of class proxies 
/// that define a module's API. This class and the "list of" class 
/// <class>%ZPM.PackageManager.Developer.Annotation.CosEntity.ListOf.ClassProxy</class> exist in order to 
/// allow us to control the XML output via class parameters and property parameters. 
Class %ZPM.PackageManager.Developer.Annotation.ClassProxyListContainer Extends (%RegisteredObject, %XML.Adaptor)
{

Parameter XMLNAME = "API";

Property ClassProxies As %ZPM.PackageManager.Developer.Annotation.CosEntity.ListOf.ClassProxy(XMLNAME = "Class", XMLPROJECTION = "element");

}
