/// For enforcing the value list
Class %ZPM.PackageManager.Developer.Annotation.Tag.Modifier.Availability Extends %Library.String
{

/// note that these values have associated macros, e.g. $$$ZPMAvailabilityForbidden
Parameter VALUELIST = ",Universal,InterSystems,Forbidden";

Parameter XMLPROJECTION = "attribute";

}
