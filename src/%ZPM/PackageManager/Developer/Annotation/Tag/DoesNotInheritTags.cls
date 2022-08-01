Class %ZPM.PackageManager.Developer.Annotation.Tag.DoesNotInheritTags Extends %ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag
{

/// we don't want tags of this class to appear in the XML; trying to achieve this by setting XMLENABLED = 0 results in errors 
/// when we export to XML
Parameter IncludeInObjectTree = 0;

Method HandleExtraContent(ByRef pCommentBlock As %Library.RawString, pContextObject As %ZPM.PackageManager.Developer.Annotation.CosEntity.CommentableEntity) [ Private ]
{
	// Strictly speaking, this method is supposed to handle "extra" content on the line after the tag itself, but this tag has no extra content 
	// and we use this method as an opportunity to register its effect on the COS object proxy it's attached to. 
	set pContextObject.SkipTagInheritance = 1
	
	do ##super()
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
