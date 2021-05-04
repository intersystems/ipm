/// abstract base class for tag classes that support the Availability modifier. used only 
/// as a secondary ancestor class
Class %ZPM.PackageManager.Developer.Annotation.Tag.SupportsAvailability [ Abstract, NoExtent ]
{

Property Availability As %String(VALUELIST = ",Universal,InterSystems,Forbidden", XMLPROJECTION = "attribute") [ InitialExpression = "Universal" ];

}
