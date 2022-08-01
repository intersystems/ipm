/// container class for a list of class proxy objects, for use in generating a single 
/// XML document for a set of classes (e.g. a module's API). This seems to be the only way to 
/// control the output element for the members of a collection, via a property of this 
/// type with XMLNAME and XMLPROJECTION property parameters. 
Class %ZPM.PackageManager.Developer.Annotation.CosEntity.ListOf.ClassProxy Extends %Library.ListOfObjects
{

Parameter ELEMENTTYPE = "%ZPM.PackageManager.Developer.Annotation.CosEntity.ClassProxy";

Storage Custom
{
<Type>%Library.CompleteCustomStorage</Type>
}

}
