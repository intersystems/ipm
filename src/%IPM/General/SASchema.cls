Class %IPM.General.SASchema Extends %Studio.SASchemaClass
{

/// This is a comma-separated list of the classes whose xml elements
/// can be used as the root level element of a document separated with a ':' and the
/// XML tag name to correlate this with e.g. "User.Person:person,User.Company:company".
Parameter ROOTCLASSES As STRING = "%IPM.Storage.Module:Module";

/// This is the namespace value used to identify this SA schema.
/// This corresponds to the XMLNamespace keyword of a Studio XData block.
Parameter XMLNAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

ClassMethod Install() As %Status
{
	Set tStatus = $$$OK
	Try {
		Set tStatus = ..OutputToFile(##class(%File).TempFilename())
		If $$$ISERR(tStatus) {
			Quit
		}
		Set tStatus = ##class(%Studio.SASchemaUtil).loadSchema(..#XMLNAMESPACE,1,1)
	} Catch e {
		Set tStatus = e.AsStatus()
	}
	Quit tStatus
}

/// Outputs the schema to the current device.
/// Useful for testing/debugging.
ClassMethod Display()
{
	Try {
		Set tStream = ##class(%Stream.GlobalCharacter).%New()
		$$$ThrowOnError(..OutputToStream(tStream))
		Do tStream.OutputToDevice()
	} Catch e {
		Write $System.Status.GetErrorText(e.AsStatus())
	}
}

/// Overridden to handle wrapped collections and relationships
ClassMethod GetSchemaForClasses(ByRef pClassList As %String) As %Status
{
	Set tSC = $$$OK
	Do {
		#; start with list of top-level elements
		#; find list of all possible elements
 		Set tClass = $O(pClassList(""))
		While (tClass '= "") {
			Set tTopName = ..GetXMLNameForClass(tClass)
			Set ppDefaultNS = ..XMLName2NameSpace(tTopName)

			If ppDefaultNS="" {
				Set tSC=$$$ERROR($$$NoDefaultNamespaceForClass,tClass) Quit
			}

			Set ppCurrentNS = ppDefaultNS
			Set %VisitedClasses(tClass) = ""
			Set %VisitedElements(tTopName) = ""
			Set tFixedTopName = ..XMLName2DisplayName(tTopName,ppCurrentNS)
			If ('+$G(%useronly) || (tClass'["%")) {
				set ^||%Studio.Schema(ppDefaultNS,ppCurrentNS,tFixedTopName,"top")=1
			}
			
			Set tSC = ..HandleClassElements(ppCurrentNS,ppDefaultNS,tFixedTopName,tClass,.tLocalList,.tRefClasses,.tElementList)
			If $$$ISERR(tSC) {
				Quit
			}

			#; merge elements into list of ALL elements
			Merge tElementList = tLocalList

			Set tClass = $O(pClassList(tClass))
		}
		If $$$ISERR(tSC) Quit

		#; now walk over set of possible elements
		#; and make list of what elements are contained by other elements
		Set tElement = $O(tElementList(""))
		While (tElement '= "") {
			#; skip if visited
			Set tClass = tElementList(tElement)

			If ('$D(%VisitedClasses(tClass)) && '$D(%VisitedElements(tElement))) {
				Set %VisitedClasses(tClass) = ""
				Set %VisitedElements(tElement) = ""
				Kill tLocalList
				
				#; see if we need to switch NS
				Set ppCurrentNS = ..XMLName2NameSpace(tElement)
				Set tFixedName = ..XMLName2DisplayName(tElement,ppCurrentNS)
			
				Set tSC = ..HandleClassElements(ppCurrentNS,ppDefaultNS,tFixedName,tClass,.tLocalList,.tRefClasses,.tElementList)
				If $$$ISERR(tSC) {
					Quit
				}
				
				Merge tAllLocalList = tLocalList
			}
			Set tElement = $O(tElementList(tElement))
		}

		Merge tElementList = tAllLocalList

		Set count = 0 // loop counter
		Set done = '+$D(tRefClasses)
		While ('done && (count < 100)) {
			Set count = count + 1
			// now process list of classes that were referenced by other elements
			Kill tRefClasses2
			Set tClass = $O(tRefClasses(""))
			While (tClass '= "") {
				Set tElement = ..GetXMLNameForClass(tClass)

				If ((..XMLName2NameSpace(tElement)'="") && '$D(%VisitedClasses(tClass))&&'$D(%VisitedElements(tElement))) {
					Set %VisitedClasses(tClass) = ""
					Set %VisitedElements(tElement) = ""
					#; add to list to pick up attrs
					Set tElementList(tElement) = tClass

					Kill tLocalList

					#; write out subelements, if any
					#; see if we need to switch NS
					Set ppCurrentNS = ..XMLName2NameSpace(tElement)
					Set tFixedName = ..XMLName2DisplayName(tElement,ppCurrentNS)
			
					Set tSC = ..HandleClassElements(ppCurrentNS,ppDefaultNS,tFixedName,tClass,.tLocalList,.tRefClasses,.tElementList)
					If $$$ISERR(tSC) {
						Quit
					}
				}
				Set tClass = $O(tRefClasses(tClass))
			}
			
			#; more to do
			If ($D(tRefClasses2)) {
				Set done = 0
				Kill tRefClasses
				Merge tRefClasses = tRefClasses2
			}
			Else {
				Set done = 1
			}
		}

		#; JMD544
		#; Make sure every topclass gets its attributes processed
 		Set tClass = $O(pClassList(""))
		While (tClass '= "") {
			Set tElementList(..GetXMLNameForClass(tClass)) = tClass
			Set tClass = $O(pClassList(tClass))
		}

		#; now walk over set of all possible elements
		#; and write out attribute definitions for each
		Set tElement = $O(tElementList(""))
		While (tElement '= "") {
			Kill tAttrList
			Set tClass = tElementList(tElement)
			Set tSC = ..GetAttrsForClass(tClass,.tAttrList)
			If $$$ISERR(tSC) Quit

			#; test for additional key attributes for this element
			#; JMD381
			For tSearchKey = tClass,tElement {
				If $D(%saKeyAttrs(tSearchKey)) {
					Set parcls = $O(%saKeyAttrs(tSearchKey,""))
					While (parcls '= "") {
						Set prop = $O(%saKeyAttrs(tSearchKey,parcls,""),1,tAttributeName)
						While (prop '= "") {
							If (tAttributeName '= "") {
								Set tAttrList(tAttributeName) = ""
							}
							Set prop = $O(%saKeyAttrs(tSearchKey,parcls,prop),1,tAttributeName)
						}
						Set parcls = $O(%saKeyAttrs(tSearchKey,parcls))
					}
				}
			}

			If ('+$G(%useronly) || (tClass'["%")) {
				If $D(tAttrList) {
					Set tSkip = 0
					If ($D(%saCategories)) {
						// check categories
						Set tCat = $$$UPPER($$$comMemberKeyGet(tClass,$$$cCLASSparameter,"SACATEGORY",$$$cPARAMdefault))
						If ((tCat="")||'$D(%saCategories(tCat))) {
							Set tSkip = 1
						}
					}
					If ('tSkip) {
						#; see if we need to switch NS
						Set ppCurrentNS = ..XMLName2NameSpace(tElement)
						Set n = 0
						set tFixedElementName=..XMLName2DisplayName(tElement,ppCurrentNS)
						Set tAttr = $O(tAttrList(""))
						While (tAttr '= "") {
							Set tType = tAttrList(tAttr)
							set ^||%Studio.Schema(ppDefaultNS,ppCurrentNS,tFixedElementName,"att",tAttr)=tType
							Set n = n + 1
							Set tAttr = $O(tAttrList(tAttr))
						}
					}
				}
			}
			Set tElement = $O(tElementList(tElement))
		}
		If $$$ISERR(tSC) Quit

	} While(0)

	Quit tSC
}

ClassMethod HandleClassElements(pCurrentNS As %String, pDefaultNS As %String, pTopName As %String, pClass As %String, Output pLocalList, ByRef pRefClasses, ByRef pElementList) As %Status
{
	Set tSC = $$$OK
	Try {
		Kill pLocalList

		#; get list of elements within this top-level
		Set tSC = ..GetElementsForClass(pClass,.pLocalList,.pRefClasses,.pElementList)
		If $$$ISERR(tSC) Quit

		Set tEl = $O(pLocalList(""))
		While (tEl '= "") {
			#; Skip if INCLUDEGROUP = 0
			Set tIncGroup = $$$comMemberKeyGet(pLocalList(tEl),$$$cCLASSparameter,"XMLINCLUDEINGROUP",$$$cPARAMdefault)
			If (tIncGroup '= 0) {
				If ('+$G(%useronly) || (pLocalList(tEl)'["%")) {
					Set tSkip = 0
					If ($D(%saCategories)) {
						// check categories
						Set tCat = $$$UPPER($$$comMemberKeyGet(pLocalList(tEl),$$$cCLASSparameter,"SACATEGORY",$$$cPARAMdefault))
						If ((tCat="")||'$D(%saCategories(tCat))) {
							Set tSkip = 1
						}
					}
					If ('tSkip) {
						Set tElDisplayName = ..XMLName2DisplayName(tEl,pCurrentNS)
						Set ^||%Studio.Schema(pDefaultNS,pCurrentNS,pTopName,"sub",tElDisplayName)=""
						Set tTypeInfo = pLocalList(tEl)
						If $ListValid(tTypeInfo) && $ListLength(tTypeInfo) && $ListGet(tTypeInfo,3) {
							// wrapped collection: add another element for the wrapper
							Set tSubNames = ""
							Set tSubName = $ListBuild($ListGet(tEl),$ListGet(tTypeInfo))
							If $ListGet(tTypeInfo,4) = "substitutiongroup" {
								Set tType = $ListGet(tTypeInfo,2)
								Kill tSubclassElements
								Do ..GetXMLElementsForClass(tType,.tSubclassElements)
								Set tXMLNameKey = ""
								For {
									Set tXMLNameKey = $Order(tSubclassElements(tXMLNameKey),1,tSubClassName)
									If (tXMLNameKey = "") {
										Quit
									}
									If $$$comClassKeyGet(tSubClassName,$$$cCLASSabstract) {
										Continue
									}
									Set pRefClasses(tSubClassName) = ""
									Set tSubNames = tSubNames_$ListBuild(tXMLNameKey)
								}
							} Else {
								Set tSubNames = $ListBuild(tSubName)
							}
							Set tSubNamePointer = 0
							While $ListNext(tSubNames,tSubNamePointer,tSubName) {
								Set ^||%Studio.Schema(pDefaultNS,pCurrentNS,tElDisplayName,"sub",..XMLName2DisplayName(tSubName,pCurrentNS))=""
							}
						}
					}
				}
			}
			Set tEl = $O(pLocalList(tEl))
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Overridden to handle list collections and relationships
ClassMethod GetElementsForClass(pClass As %String, Output pElementList, Output pReferencedClasses, Output pXMLNameAliases) As %Status
{
	Set tSC = $$$OK

	Do {
		#; only deal with compiled classes
		#; gather properties as attributes or elements
		If ($$$comClassDefined(pClass)) {
			Set tAbstract = +$$$comClassKeyGet(pClass,$$$cCLASSabstract)
			If ('tAbstract) {
				#; get all properties of this class
				Set tRS = ##class(%ResultSet).%New("%Dictionary.CompiledClass.MemberSummary")
				Set tSC = tRS.%Execute(pClass,$$$cCLASSproperty)
				If $$$ISERR(tSC) Quit

				While (tRS.%Next(.tSC)) {
					If $$$ISERR(tSC) Quit
					Set tName = tRS.Data("Name")
					If (tName ["%%") Continue  // internal property
					If $classmethod(pClass,"%Extends","%Persistent")&&(tName="%Concurrency") Continue // omit this one specifically
					Set tType = $$$comMemberKeyGet(pClass,$$$cCLASSproperty,tName,$$$cPROPtype)
					Set tCollect = $$$comMemberKeyGet(pClass,$$$cCLASSproperty,tName,$$$cPROPcollection)
					Set tXML = $$$comMemberArrayGet(pClass,$$$cCLASSproperty,tName,$$$cPROPparameter,"XMLPROJECTION")
					Set tXMLName = $$$comMemberArrayGet(pClass,$$$cCLASSproperty,tName,$$$cPROPparameter,"XMLNAME")
					Set tXMLItemName = $$$comMemberArrayGet(pClass,$$$cCLASSproperty,tName,$$$cPROPparameter,"XMLITEMNAME")
					Set tXMLKey = $$$comMemberArrayGet(pClass,$$$cCLASSproperty,tName,$$$cPROPparameter,"XMLKEYNAME")
					Set tTypeConstraint = $$$comMemberArrayGet(pClass,$$$cCLASSproperty,tName,$$$cPROPparameter,"XMLTYPECONSTRAINT")

					Set tXML = $ZCVT(tXML,"L")
					Set tTypeConstraint = $ZCVT(tTypeConstraint,"L")
					Set:tXML="" tXML=$Case(tCollect,"":"element",:"wrapped")
					Set:tXMLName="" tXMLName = tName
	
					If (tXML = "element") || (tXML = "wrapped") {
						#; find out if this an object-valued property
						#; get normalized type of property
						#; figure out the classtype for the property
						#; first normalize the type name
						If ((tType '[ ".") && (tType '[ "%")) {
							#; assume this type belongs to our package
							Set tType = $P(pClass,".",1,$L(pClass,".")-1) _ "." _ tType
						}
						Set tType = $$$NormalizeClassname(tType)

						If ($$$classIsDataType(tType)) {
							#; add literal element to list
							Set tDTNS = ..XMLName2NameSpace(..GetXMLNameForClass(pClass))
							If (tDTNS'="") {
								If (tCollect="array") {
									If (tXMLKey '= "") {
										#; We use the globally visible variable, %saKeyAttrs,
										#; to track additional elements used as array keys.
										#; This implementation is not correct; in the general case
										#; the same element could be used in different contexts with
										#; different key names. This is not very typical, however.
										Set %saKeyAttrs($LB(tDTNS,tXMLName),tType,tName) = tXMLKey
									}
								}
								Set pElementList($LB(tDTNS,tXMLName)) = tType
							}
						}
						Else {
							If (tCollect="array") {
								If (tXMLKey '= "") {
									#; See comment above.
									Set %saKeyAttrs(pClass,tType,tName) = tXMLKey
								}
							}
							
							Set pReferencedClasses(tType) = ""
							#; Skip if INCLUDEGROUP = 0
							Set tIncGroup = +$$$comMemberKeyGet(tType,$$$cCLASSparameter,"XMLINCLUDEINGROUP",$$$cPARAMdefault)
							If (tIncGroup '= 0) {
								If (tCollect="") {
									Set tElements(tXMLName) = tType
									Set tElementsRef(tXMLName,tName) = "" // JMD517
								} Else {
									Set tDTNS = ..XMLName2NameSpace(..GetXMLNameForClass(pClass))
									Set tReferenceXMLName = ..GetXMLNameForClass(tType)
									Set tItemNamespace = ..XMLName2NameSpace(tReferenceXMLName)
									If (tXMLItemName = "") {
										Set tXMLItemName = ..XMLName2ShortName(tReferenceXMLName)
									} Else {
										Set pXMLNameAliases($ListBuild(tItemNamespace,tXMLItemName)) = tType
									}
									If (tItemNamespace'="") {
										Set tIsWrapped = (tXML = "wrapped")
										Set pElementList($LB(tDTNS,tXMLName)) = $ListBuild(tXMLItemName,tType,tIsWrapped,tTypeConstraint)
									}
								}
							}
						}
					}
				}
				If $$$ISERR(tSC) Quit
				
				#; process elements
				#; (for each element expand into available subclasses)
				Set tEl = $O(tElements(""))
				While (tEl '= "") {
					Kill tChoiceList
					Set tSubClass = tElements(tEl)

					if tSubClass'="%Library.RegisteredObject",tSubClass'="%Library.SerialObject",tSubClass'="%Library.Persistent" {
						Set tSC = ..GetXMLElementsForClass(tSubClass,.tChoiceList)
						If $$$ISERR(tSC) Quit
					}

					Set k = $O(tChoiceList(""))
					While (k'="") {
						If $D(tElementsRef(tEl)) { // non-collection, reference property
							// for each property that refers to this, there is an entry
							Set xn = $O(tElementsRef(tEl,""))
							While (xn'="") {
								Set k2 = k
								Set $List(k2,2) = xn
								Set pElementList(k2) = tChoiceList(k)
								Set tType = $$$NormalizeClassname(tChoiceList(k))
								Set xn = $O(tElementsRef(tEl,xn))
							}
						}
						Else {
							Set tType = $$$NormalizeClassname(tChoiceList(k))
							If ('$$$classIsDataType(tType)) {
								#; JMD544
								#; Skip if INCLUDEGROUP = 0 OR abstract
								Set tIncGroup = $$$comMemberKeyGet(tType,$$$cCLASSparameter,"XMLINCLUDEINGROUP",$$$cPARAMdefault)
								Set tTypeAbstract = +$$$comClassKeyGet(tType,$$$cCLASSabstract)
								If ('tTypeAbstract && (tIncGroup '= 0)) {
									Set pElementList(k) = tChoiceList(k)		
									Set pReferencedClasses(tType) = ""
								}
							}
							Else {
								Set pElementList(k) = tChoiceList(k)
							}
						}
						Set k = $O(tChoiceList(k))
					}
					Set tEl = $O(tElements(tEl))
				}
				If $$$ISERR(tSC) Quit
			}
		}
	} While(0)

	Quit tSC
}

}
