/// intermediate class for class members with arguments. Consolidates common argument handling 
/// behavior for methods and class queries. 
Class %ZPM.PackageManager.Developer.Annotation.CosEntity.MemberWithArguments Extends %ZPM.PackageManager.Developer.Annotation.CosEntity.ClassMemberProxy [ Abstract ]
{

Parameter ParsedSpecKey;

Relationship Arguments As %ZPM.PackageManager.Developer.Annotation.CosEntity.ArgumentProxy(XMLIO = "IN", XMLPROJECTION = "element", XMLTYPECONSTRAINT = "choice") [ Cardinality = many, Inverse = ParentMember ];

Property CalculatedArguments As list Of %ZPM.PackageManager.Developer.Annotation.CosEntity.ArgumentProxy(XMLIO = "OUT", XMLPROJECTION = "element", XMLTYPECONSTRAINT = "choice") [ Calculated ];

/// an array containing the positions in the <property>Arguments</property> relationship so that we can find them 
/// quickly by name; the values from this array are then used in .GetAt() calls. 
Property ArgumentKeysByName [ MultiDimensional ];

Method CalculatedArgumentsGet() As %Collection.AbstractListOfObj [ CodeMode = objectgenerator ]
{
	// use an array collection to get things in order 
	set tCodeStream = %code
	do ##class(%ZPM.PackageManager.Developer.GeneratorUtils).BuildRelationshipSorter(tCodeStream, "Arguments", "Name")
	
	quit $$$OK
}

Method HandleExtraProperties()
{
	// go through arguments
	set tFormalSpec = $$$comMemberKeyGet(..ParentClassName, ..#DictionaryKey, ..Name, ..#ParsedSpecKey)
	
	/* 		
	tFormalSpec is a list of lists of argument info. The main list contains one sub-list  
	per argument. The info for an argument is a list of 4 things: 
	
	1. the argument name
	2. the argument type
	3. "*" for Output, "&" for ByRef, "" for input
	4. default value
	
	"..." arguments like "args..." just show up in the list as if that were their name. 
	
	Example: 
	
	$lb(
		$lb("p1","%Library.Integer","",""),
		$lb("p2","%Library.String","*","""some default value like hello"""),
		$lb("args...","%Library.String","","")
		)
	
	so if we want to do special handling for these, we need to examine the "argument name" 
	and see whether ends with "...". (Currently we do not.)
	
	*/
	
	set tPointer = 0
	while $listnext(tFormalSpec, tPointer, tArgInfo) { 
		set tNewArgProxy = ##class(%ZPM.PackageManager.Developer.Annotation.CosEntity.ArgumentProxy).%New()
		
		// if things get more complex we can move the following into a constructor for the ArgumentProxy class
		set tNewArgProxy.Name = $listget(tArgInfo, 1)
		set tNewArgProxy.DataType = $listget(tArgInfo, 2)
		
		// for ByVal (input) parameters we just leave it blank as the implied default
		set tNewArgProxy.PassedAs = $case($listget(tArgInfo, 3), 
			"": "",
			"*": "Output",
			"&": "ByRef")
		set tNewArgProxy.DefaultValue = $listget(tArgInfo, 4)			
		set tNewArgProxy.ParentMember = $this
		
		// track them by name so we can find them quickly, later
		
		set ..ArgumentKeysByName(tNewArgProxy.Name) = ..Arguments.FindOref(tNewArgProxy)
	}
}

Method AssignTag(pNewTag As %ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag) As %Status
{
	if pNewTag.%IsA("%ZPM.PackageManager.Developer.Annotation.Tag.Argument") {				
		#dim tArgObject as %ZPM.PackageManager.Developer.Annotation.CosEntity.ArgumentProxy
		if $data(..ArgumentKeysByName(pNewTag.ArgumentName),tKey)#2 {
			set tArgObject = ..Arguments.GetAt(tKey)
			if '$isobject(tArgObject) {
				quit $$$ERROR($$$GeneralError, "Argument " _ pNewTag.ArgumentName _ " not found in method " _ ..Name _ " in class " _ ..ParentClassName)
			}
			quit tArgObject.AssignTag(pNewTag)
		} else {
			quit $$$ERROR($$$GeneralError, "Invalid argument annotation for " _ pNewTag.ArgumentName _ " in method " _ ..Name _ " in class " _ ..ParentClassName)
		}
	}
	
	quit ##super(pNewTag)
}

Method SpecialMemberInheritance(pSuperMember As %ZPM.PackageManager.Developer.Annotation.CosEntity.MemberWithArguments)
{
	// inherit stuff for the arguments
	
	#dim tArgProxy as ArgumentProxy
	set tTagCountLimit = $listlength(##class(ArgumentProxy).AcceptableTagList())
	
	set tKey = ""
	while 1 {
		set tArgProxy = ..Arguments.GetNext(.tKey)
		if tKey = "" {
			quit
		}
		
		do tArgProxy.InitializeTagNameArray(.tTagNameArray, .tTagCount)
		if tTagCount = tTagCountLimit {
			// this argument already has all the tags, no need to look for more
			continue
		}
		if $data(pSuperMember.ArgumentKeysByName(tArgProxy.Name), tSuperArgKey) > 0 {
			// the super version of this method has the argument (it's not new in the subclass)
			set tSuperArg = pSuperMember.Arguments.GetAt(tSuperArgKey)
			do tArgProxy.InheritTags(.tTagNameArray, .tTagCount, tSuperArg)
		}
	}
}

Method SupplyMissingTags()
{
	do ##super()
	
	#dim tArgProxy as ArgumentProxy
	set tKey = ""
	while 1 {
		set tArgProxy = ..Arguments.GetNext(.tKey)
		if tKey = "" {
			quit
		}
		
		do tArgProxy.SupplyMissingTags()
	}
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
