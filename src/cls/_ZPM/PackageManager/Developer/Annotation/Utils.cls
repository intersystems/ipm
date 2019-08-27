Class %ZPM.PackageManager.Developer.Annotation.Utils
{

/// @PublicAPI
ClassMethod ExtractAnnotations(pClassName As %String, pAnnotations As %Library.ListOfObjects(ELEMENTTYPE="%ZPM.PackageManager.Developer.Annotation")) As %Status
{
	Set tStatus = $$$OK
	Try {
		If '$IsObject($Get(pAnnotations)) {
			Set pAnnotations = ##class(%Library.ListOfObjects).%New()
		}
		
		Set tTemplate = ##class(%ZPM.PackageManager.Developer.Annotation).%New()
		Set tTemplate.Classname = pClassName
		Set tStatus = ..ParseAnnotations($$$comClassKeyGet(pClassName,$$$cCLASSdescription),pAnnotations,tTemplate)
		If $$$ISERR(tStatus) {
			Quit
		}
		
		Set tSources = $ListBuild(
			$ListBuild($$$cCLASSfkey,$$$cFKEYdescription,"ForeignKey"),
			$ListBuild($$$cCLASSindex,$$$cINDEXdescription,"Index"),
			$ListBuild($$$cCLASSmethod,$$$cMETHdescription,"Method"),
			$ListBuild($$$cCLASSparameter,$$$cPARAMdescription,"Parameter"),
			$ListBuild($$$cCLASSprojection,$$$cPROJdescription,"Projection"),
			$ListBuild($$$cCLASSproperty,$$$cPROPdescription,"Property"),
			$ListBuild($$$cCLASSquery,$$$cQUERYdescription,"Query"),
			$ListBuild($$$cCLASSstorage,$$$cSDEFdescription,"Storage"),
			$ListBuild($$$cCLASStrigger,$$$cTRIGGERdescription,"Trigger"),
			$ListBuild($$$cCLASSxdata,$$$cXDATAdescription,"XData")
		)
		Set tPtr = 0
		While $ListNext(tSources,tPtr,tSource) {
			Set $ListBuild(tMemberType,tDescKey,tTypeDesc) = tSource
			Set tMember = ""
			For {
				Set tMember = $$$comMemberNext(pClassName,tMemberType,tMember)
				Quit:tMember=""
				
				Set tTemplate.MemberType = tTypeDesc
				Set tTemplate.MemberName = tMember
				Set tStatus = ..ParseAnnotations($$$comMemberKeyGet(pClassName,tMemberType,tMember,tDescKey),pAnnotations,tTemplate)
				If $$$ISERR(tStatus) {
					Quit
				}
			}
			If $$$ISERR(tStatus) {
				Quit
			}
		}
	} Catch e {
		Set tStatus = e.AsStatus()
	}
	Quit tStatus
}

ClassMethod ParseAnnotations(pDescription As %String, pAnnotations As %Library.ListOfObjects(ELEMENTTYPE="%ZPM.PackageManager.Developer.Annotation"), pTemplate As %ZPM.PackageManager.Developer.Annotation) As %Status [ Private ]
{
	Set tStatus = $$$OK
	Try {
		Set tParts = $ListFromString(pDescription,$$$NL)
		Set tPtr = 0
		While $ListNext(tParts,tPtr,tPart) {
			If ($Extract(tPart) = "@") {
				Set tPart = $Extract(tPart,2,*)
				Set tTag = $Piece(tPart,"(""")
				If (tTag '= "") {
					Set tAnnotation = pTemplate.%ConstructClone()
					Set tAnnotation.Tag = tTag
					Set tAnnotation.Value = $Piece($Piece(tPart,"(""",2),""")")
					Set tStatus = pAnnotations.Insert(tAnnotation)
					If $$$ISERR(tStatus) {
						Quit
					}
				}
			}
		}
	} Catch e {
		Set tStatus = e.AsStatus()
	}
	Quit tStatus
}

}
