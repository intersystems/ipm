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
    set tStatus = $$$OK
    try {
        set tStatus = ..OutputToFile(##class(%File).TempFilename())
        if $$$ISERR(tStatus) {
            quit
        }
        set tStatus = ##class(%Studio.SASchemaUtil).loadSchema(..#XMLNAMESPACE,1,1)
    } catch e {
        set tStatus = e.AsStatus()
    }
    quit tStatus
}

/// Outputs the schema to the current device.
/// Useful for testing/debugging.
ClassMethod Display()
{
    try {
        set tStream = ##class(%Stream.GlobalCharacter).%New()
        $$$ThrowOnError(..OutputToStream(tStream))
        do tStream.OutputToDevice()
    } catch e {
        write $system.Status.GetErrorText(e.AsStatus())
    }
}

/// Overridden to handle wrapped collections and relationships
ClassMethod GetSchemaForClasses(ByRef pClassList As %String) As %Status
{
    set tSC = $$$OK
    do {
        #; start with list of top-level elements
        #; find list of all possible elements
        set tClass = $order(pClassList(""))
        while (tClass '= "") {
            set tTopName = ..GetXMLNameForClass(tClass)
            set ppDefaultNS = ..XMLName2NameSpace(tTopName)

            if ppDefaultNS="" {
                set tSC=$$$ERROR($$$NoDefaultNamespaceForClass,tClass) quit
            }

            set ppCurrentNS = ppDefaultNS
            set %VisitedClasses(tClass) = ""
            set %VisitedElements(tTopName) = ""
            set tFixedTopName = ..XMLName2DisplayName(tTopName,ppCurrentNS)
            if ('+$get(%useronly) || (tClass'["%")) {
                set ^||%Studio.Schema(ppDefaultNS,ppCurrentNS,tFixedTopName,"top")=1
            }

            set tSC = ..HandleClassElements(ppCurrentNS,ppDefaultNS,tFixedTopName,tClass,.tLocalList,.tRefClasses,.tElementList)
            if $$$ISERR(tSC) {
                quit
            }

            #; merge elements into list of ALL elements
            merge tElementList = tLocalList

            set tClass = $order(pClassList(tClass))
        }
        if $$$ISERR(tSC) quit

        #; now walk over set of possible elements
        #; and make list of what elements are contained by other elements
        set tElement = $order(tElementList(""))
        while (tElement '= "") {
            #; skip if visited
            set tClass = tElementList(tElement)

            if ('$data(%VisitedClasses(tClass)) && '$data(%VisitedElements(tElement))) {
                set %VisitedClasses(tClass) = ""
                set %VisitedElements(tElement) = ""
                kill tLocalList

                #; see if we need to switch NS
                set ppCurrentNS = ..XMLName2NameSpace(tElement)
                set tFixedName = ..XMLName2DisplayName(tElement,ppCurrentNS)

                set tSC = ..HandleClassElements(ppCurrentNS,ppDefaultNS,tFixedName,tClass,.tLocalList,.tRefClasses,.tElementList)
                if $$$ISERR(tSC) {
                    quit
                }

                merge tAllLocalList = tLocalList
            }
            set tElement = $order(tElementList(tElement))
        }

        merge tElementList = tAllLocalList

        set count = 0 // loop counter
        set done = '+$data(tRefClasses)
        while ('done && (count < 100)) {
            set count = count + 1
            // now process list of classes that were referenced by other elements
            kill tRefClasses2
            set tClass = $order(tRefClasses(""))
            while (tClass '= "") {
                set tElement = ..GetXMLNameForClass(tClass)

                if ((..XMLName2NameSpace(tElement)'="") && '$data(%VisitedClasses(tClass))&&'$data(%VisitedElements(tElement))) {
                    set %VisitedClasses(tClass) = ""
                    set %VisitedElements(tElement) = ""
                    #; add to list to pick up attrs
                    set tElementList(tElement) = tClass

                    kill tLocalList

                    #; write out subelements, if any
                    #; see if we need to switch NS
                    set ppCurrentNS = ..XMLName2NameSpace(tElement)
                    set tFixedName = ..XMLName2DisplayName(tElement,ppCurrentNS)

                    set tSC = ..HandleClassElements(ppCurrentNS,ppDefaultNS,tFixedName,tClass,.tLocalList,.tRefClasses,.tElementList)
                    if $$$ISERR(tSC) {
                        quit
                    }
                }
                set tClass = $order(tRefClasses(tClass))
            }

            #; more to do
            if ($data(tRefClasses2)) {
                set done = 0
                kill tRefClasses
                merge tRefClasses = tRefClasses2
            }
            else {
                set done = 1
            }
        }

        #; JMD544
        #; Make sure every topclass gets its attributes processed
        set tClass = $order(pClassList(""))
        while (tClass '= "") {
            set tElementList(..GetXMLNameForClass(tClass)) = tClass
            set tClass = $order(pClassList(tClass))
        }

        #; now walk over set of all possible elements
        #; and write out attribute definitions for each
        set tElement = $order(tElementList(""))
        while (tElement '= "") {
            kill tAttrList
            set tClass = tElementList(tElement)
            set tSC = ..GetAttrsForClass(tClass,.tAttrList)
            if $$$ISERR(tSC) quit

            #; test for additional key attributes for this element
            #; JMD381
            for tSearchKey = tClass,tElement {
                if $data(%saKeyAttrs(tSearchKey)) {
                    set parcls = $order(%saKeyAttrs(tSearchKey,""))
                    while (parcls '= "") {
                        set prop = $order(%saKeyAttrs(tSearchKey,parcls,""),1,tAttributeName)
                        while (prop '= "") {
                            if (tAttributeName '= "") {
                                set tAttrList(tAttributeName) = ""
                            }
                            set prop = $order(%saKeyAttrs(tSearchKey,parcls,prop),1,tAttributeName)
                        }
                        set parcls = $order(%saKeyAttrs(tSearchKey,parcls))
                    }
                }
            }

            if ('+$get(%useronly) || (tClass'["%")) {
                if $data(tAttrList) {
                    set tSkip = 0
                    if ($data(%saCategories)) {
                        // check categories
                        set tCat = $$$UPPER($$$comMemberKeyGet(tClass,$$$cCLASSparameter,"SACATEGORY",$$$cPARAMdefault))
                        if ((tCat="")||'$data(%saCategories(tCat))) {
                            set tSkip = 1
                        }
                    }
                    if ('tSkip) {
                        #; see if we need to switch NS
                        set ppCurrentNS = ..XMLName2NameSpace(tElement)
                        set n = 0
                        set tFixedElementName=..XMLName2DisplayName(tElement,ppCurrentNS)
                        set tAttr = $order(tAttrList(""))
                        while (tAttr '= "") {
                            set tType = tAttrList(tAttr)
                            set ^||%Studio.Schema(ppDefaultNS,ppCurrentNS,tFixedElementName,"att",tAttr)=tType
                            set n = n + 1
                            set tAttr = $order(tAttrList(tAttr))
                        }
                    }
                }
            }
            set tElement = $order(tElementList(tElement))
        }
        if $$$ISERR(tSC) quit

    } while(0)

    quit tSC
}

ClassMethod HandleClassElements(
	pCurrentNS As %String,
	pDefaultNS As %String,
	pTopName As %String,
	pClass As %String,
	Output pLocalList,
	ByRef pRefClasses,
	ByRef pElementList) As %Status
{
    set tSC = $$$OK
    try {
        kill pLocalList

        #; get list of elements within this top-level
        set tSC = ..GetElementsForClass(pClass,.pLocalList,.pRefClasses,.pElementList)
        if $$$ISERR(tSC) quit

        set tEl = $order(pLocalList(""))
        while (tEl '= "") {
            #; Skip if INCLUDEGROUP = 0
            set tIncGroup = $$$comMemberKeyGet(pLocalList(tEl),$$$cCLASSparameter,"XMLINCLUDEINGROUP",$$$cPARAMdefault)
            if (tIncGroup '= 0) {
                if ('+$get(%useronly) || (pLocalList(tEl)'["%")) {
                    set tSkip = 0
                    if ($data(%saCategories)) {
                        // check categories
                        set tCat = $$$UPPER($$$comMemberKeyGet(pLocalList(tEl),$$$cCLASSparameter,"SACATEGORY",$$$cPARAMdefault))
                        if ((tCat="")||'$data(%saCategories(tCat))) {
                            set tSkip = 1
                        }
                    }
                    if ('tSkip) {
                        set tElDisplayName = ..XMLName2DisplayName(tEl,pCurrentNS)
                        set ^||%Studio.Schema(pDefaultNS,pCurrentNS,pTopName,"sub",tElDisplayName)=""
                        set tTypeInfo = pLocalList(tEl)
                        if $listvalid(tTypeInfo) && $listlength(tTypeInfo) && $listget(tTypeInfo,3) {
                            // wrapped collection: add another element for the wrapper
                            set tSubNames = ""
                            set tSubName = $listbuild($listget(tEl),$listget(tTypeInfo))
                            if $listget(tTypeInfo,4) = "substitutiongroup" {
                                set tType = $listget(tTypeInfo,2)
                                kill tSubclassElements
                                do ..GetXMLElementsForClass(tType,.tSubclassElements)
                                set tXMLNameKey = ""
                                for {
                                    set tXMLNameKey = $order(tSubclassElements(tXMLNameKey),1,tSubClassName)
                                    if (tXMLNameKey = "") {
                                        quit
                                    }
                                    if $$$comClassKeyGet(tSubClassName,$$$cCLASSabstract) {
                                        continue
                                    }
                                    set pRefClasses(tSubClassName) = ""
                                    set tSubNames = tSubNames_$listbuild(tXMLNameKey)
                                }
                            } else {
                                set tSubNames = $listbuild(tSubName)
                            }
                            set tSubNamePointer = 0
                            while $listnext(tSubNames,tSubNamePointer,tSubName) {
                                set ^||%Studio.Schema(pDefaultNS,pCurrentNS,tElDisplayName,"sub",..XMLName2DisplayName(tSubName,pCurrentNS))=""
                            }
                        }
                    }
                }
            }
            set tEl = $order(pLocalList(tEl))
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Overridden to handle list collections and relationships
ClassMethod GetElementsForClass(
	pClass As %String,
	Output pElementList,
	Output pReferencedClasses,
	Output pXMLNameAliases) As %Status
{
    set tSC = $$$OK

    do {
        #; only deal with compiled classes
        #; gather properties as attributes or elements
        if ($$$comClassDefined(pClass)) {
            set tAbstract = +$$$comClassKeyGet(pClass,$$$cCLASSabstract)
            if ('tAbstract) {
                #; get all properties of this class
                set tRS = ##class(%ResultSet).%New("%Dictionary.CompiledClass.MemberSummary")
                set tSC = tRS.%Execute(pClass,$$$cCLASSproperty)
                if $$$ISERR(tSC) quit

                while (tRS.%Next(.tSC)) {
                    if $$$ISERR(tSC) quit
                    set tName = tRS.Data("Name")
                    if (tName ["%%") continue  // internal property
                    if $classmethod(pClass,"%Extends","%Persistent")&&(tName="%Concurrency") continue // omit this one specifically
                    set tType = $$$comMemberKeyGet(pClass,$$$cCLASSproperty,tName,$$$cPROPtype)
                    set tCollect = $$$comMemberKeyGet(pClass,$$$cCLASSproperty,tName,$$$cPROPcollection)
                    set tXML = $$$comMemberArrayGet(pClass,$$$cCLASSproperty,tName,$$$cPROPparameter,"XMLPROJECTION")
                    set tXMLName = $$$comMemberArrayGet(pClass,$$$cCLASSproperty,tName,$$$cPROPparameter,"XMLNAME")
                    set tXMLItemName = $$$comMemberArrayGet(pClass,$$$cCLASSproperty,tName,$$$cPROPparameter,"XMLITEMNAME")
                    set tXMLKey = $$$comMemberArrayGet(pClass,$$$cCLASSproperty,tName,$$$cPROPparameter,"XMLKEYNAME")
                    set tTypeConstraint = $$$comMemberArrayGet(pClass,$$$cCLASSproperty,tName,$$$cPROPparameter,"XMLTYPECONSTRAINT")

                    set tXML = $zconvert(tXML,"L")
                    set tTypeConstraint = $zconvert(tTypeConstraint,"L")
                    set:tXML="" tXML=$case(tCollect,"":"element",:"wrapped")
                    set:tXMLName="" tXMLName = tName

                    if (tXML = "element") || (tXML = "wrapped") {
                        #; find out if this an object-valued property
                        #; get normalized type of property
                        #; figure out the classtype for the property
                        #; first normalize the type name
                        if ((tType '[ ".") && (tType '[ "%")) {
                            #; assume this type belongs to our package
                            set tType = $piece(pClass,".",1,$length(pClass,".")-1) _ "." _ tType
                        }
                        set tType = $$$NormalizeClassname(tType)

                        if ($$$classIsDataType(tType)) {
                            #; add literal element to list
                            set tDTNS = ..XMLName2NameSpace(..GetXMLNameForClass(pClass))
                            if (tDTNS'="") {
                                if (tCollect="array") {
                                    if (tXMLKey '= "") {
                                        #; We use the globally visible variable, %saKeyAttrs,
                                        #; to track additional elements used as array keys.
                                        #; This implementation is not correct; in the general case
                                        #; the same element could be used in different contexts with
                                        #; different key names. This is not very typical, however.
                                        set %saKeyAttrs($listbuild(tDTNS,tXMLName),tType,tName) = tXMLKey
                                    }
                                }
                                set pElementList($listbuild(tDTNS,tXMLName)) = tType
                            }
                        } else {
                            if (tCollect="array") {
                                if (tXMLKey '= "") {
                                    #; See comment above.
                                    set %saKeyAttrs(pClass,tType,tName) = tXMLKey
                                }
                            }

                            set pReferencedClasses(tType) = ""
                            #; Skip if INCLUDEGROUP = 0
                            set tIncGroup = +$$$comMemberKeyGet(tType,$$$cCLASSparameter,"XMLINCLUDEINGROUP",$$$cPARAMdefault)
                            if (tIncGroup '= 0) {
                                if (tCollect="") {
                                    set tElements(tXMLName) = tType
                                    set tElementsRef(tXMLName,tName) = "" // JMD517
                                } else {
                                    set tDTNS = ..XMLName2NameSpace(..GetXMLNameForClass(pClass))
                                    set tReferenceXMLName = ..GetXMLNameForClass(tType)
                                    set tItemNamespace = ..XMLName2NameSpace(tReferenceXMLName)
                                    if (tXMLItemName = "") {
                                        set tXMLItemName = ..XMLName2ShortName(tReferenceXMLName)
                                    } else {
                                        set pXMLNameAliases($listbuild(tItemNamespace,tXMLItemName)) = tType
                                    }
                                    if (tItemNamespace'="") {
                                        set tIsWrapped = (tXML = "wrapped")
                                        set pElementList($listbuild(tDTNS,tXMLName)) = $listbuild(tXMLItemName,tType,tIsWrapped,tTypeConstraint)
                                    }
                                }
                            }
                        }
                    }
                }
                if $$$ISERR(tSC) quit

                #; process elements
                #; (for each element expand into available subclasses)
                set tEl = $order(tElements(""))
                while (tEl '= "") {
                    kill tChoiceList
                    set tSubClass = tElements(tEl)

                    if tSubClass'="%Library.RegisteredObject",tSubClass'="%Library.SerialObject",tSubClass'="%Library.Persistent" {
                        set tSC = ..GetXMLElementsForClass(tSubClass,.tChoiceList)
                        if $$$ISERR(tSC) quit
                    }

                    set k = $order(tChoiceList(""))
                    while (k'="") {
                        if $data(tElementsRef(tEl)) { // non-collection, reference property
                            // for each property that refers to this, there is an entry
                            set xn = $order(tElementsRef(tEl,""))
                            while (xn'="") {
                                set k2 = k
                                set $list(k2,2) = xn
                                set pElementList(k2) = tChoiceList(k)
                                set tType = $$$NormalizeClassname(tChoiceList(k))
                                set xn = $order(tElementsRef(tEl,xn))
                            }
                        } else {
                            set tType = $$$NormalizeClassname(tChoiceList(k))
                            if ('$$$classIsDataType(tType)) {
                                #; JMD544
                                #; Skip if INCLUDEGROUP = 0 OR abstract
                                set tIncGroup = $$$comMemberKeyGet(tType,$$$cCLASSparameter,"XMLINCLUDEINGROUP",$$$cPARAMdefault)
                                set tTypeAbstract = +$$$comClassKeyGet(tType,$$$cCLASSabstract)
                                if ('tTypeAbstract && (tIncGroup '= 0)) {
                                    set pElementList(k) = tChoiceList(k)
                                    set pReferencedClasses(tType) = ""
                                }
                            } else {
                                set pElementList(k) = tChoiceList(k)
                            }
                        }
                        set k = $order(tChoiceList(k))
                    }
                    set tEl = $order(tElements(tEl))
                }
                if $$$ISERR(tSC) quit
            }
        }
    } while(0)

    quit tSC
}

}
