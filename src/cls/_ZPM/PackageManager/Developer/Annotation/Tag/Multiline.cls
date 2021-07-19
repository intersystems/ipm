/// Used as a base class by tag classes with multi-line support. 
Class %ZPM.PackageManager.Developer.Annotation.Tag.Multiline Extends %ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag [ Abstract ]
{

/// name of class property where the multiline content should be placed
Parameter MultiLineProperty;

Method HandleExtraContent(ByRef pCommentBlock As %Library.RawString, pContextObject As %ZPM.PackageManager.Developer.Annotation.CosEntity.CommentableEntity) [ Private ]
{
	// in practice, the multi-line content might always/only be description/documentation-related. If that's the case, 
	// we should simplify by removing the MultiLineProperty parameter, and declaring the Documentation property 
	// here in the MultiLine base class. But for now we'll err on the side of future flexibility. 
	
	// Note that this implementation of HandleExtraContent does not call ##super
	
	set tWorking = ##class(%ZPM.PackageManager.Developer.Annotation.Utils).PopCommentLine(.pCommentBlock)
	
	set tFailsafe = 0
	while $extract(pCommentBlock, 1, 2) = "@ " {
		set tFailsafe = tFailsafe + 1
		if tFailsafe > 500 {
			quit
		}
		
		set tNewLine = ##class(%ZPM.PackageManager.Developer.Annotation.Utils).PopCommentLine(.pCommentBlock)
		set tWorking = tWorking _ $char(13,10) _ $extract(tNewLine, 3, *) // trim out the "@ "
	}
	set $property($this, ..#MultiLineProperty) = tWorking
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
