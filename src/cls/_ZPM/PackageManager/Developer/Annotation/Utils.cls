Include (%occErrors, %ZPM.PackageManager.Developer.Annotation)

Class %ZPM.PackageManager.Developer.Annotation.Utils
{

/// utility method that works like using $piece(foo, " ",...) to find the first set of non-whitespace 
/// text from a string, extract it, and trim down the remainder. But instead of matching a single space 
/// it uses <class>%Regex.Matcher</class> to match 1-or-more whitespace characters. If no whitespace 
/// is found, it just returns the original string and sets the original string to empty. 
ClassMethod PopWhitespacePiece(ByRef pWorkingString As %Library.RawString) As %String
{
	set tMatcher = ##class(%Regex.Matcher).%New("\s+") // whitespace
	set tMatcher.Text = pWorkingString
	if tMatcher.Locate() {
		set tBlockEnd = tMatcher.End
		set pPoppedPiece = $extract(pWorkingString, 1, tMatcher.Start-1)
		set pWorkingString = $extract(pWorkingString, tMatcher.End, *)
	}
	else {
		set pPoppedPiece = pWorkingString
		set pWorkingString = ""
	}
	
	quit pPoppedPiece
}

/// utility to pop the first line from a <class>%Library.RawString</class>
ClassMethod PopCommentLine(ByRef tWorkingCommentBlock As %Library.RawString) As %String
{
	set tLineBreak = $char(13,10)	
	set tFirstLine = $piece(tWorkingCommentBlock,tLineBreak,1)
	set tWorkingCommentBlock = $piece(tWorkingCommentBlock,tLineBreak,2,*)
	
	quit tFirstLine
}

ClassMethod EraseAnnotationDataForModule(pModuleName As %String) As %Status
{
	set tSC = $$$OK
	try {
		&sql(delete %ZPM_PackageManager_Developer_Annotation.Warning 
			where ModuleName = :pModuleName)
		If SQLCODE < 0 {
			set tSQLError = $$$ERROR($$$SQLCode,SQLCODE,$get(%msg))
			set tErrorContext = $$$ERROR($$$GeneralError, "failed to remove existing warning data for the module prior to generating new data")
			$$$ThrowStatus($$$EMBEDSC(tErrorContext,tSQLError))
		}
		
		/* 
		trying to manage the deletes for tag objects using a cascading relationship does not work, 
		and neither does a trigger. Rather than declare 6 identical relationships on the non-abstract 
		COS entity classes (with more to come), we'll just do it explicitly here. This leaves us open 
		to problems if anybody is managing them manually with SQL or object commands, say in Terminal. 
		
		The storage format changed during the development process so we test to see whether there are 
		any numeric IDs in the storage globals. If so, we wipe everything. If not, we only delete 
		the relevant info for the module at hand. 
		*/ 
		
		set tSampleID = $order(^%ZPM.Dev.Annotation.AnchorTagD(""))
		set tSampleID2 = $order(^%ZPM.Dev.Annotation.CosEntityD(""))
		if $isvalidnum(tSampleID) || $isvalidnum(tSampleID2)
		{
			// note: the following sometimes wipes out the Data global but not the Index global. If that happens 
			// we may need to wipe them manually with kill commands. 
			do ##class(%ZPM.PackageManager.Developer.Annotation.CosEntity.NonModuleSuperclass).%KillExtent()		
			do ##class(%ZPM.PackageManager.Developer.Annotation.Tag.AnchorTag).%KillExtent()
			do ##class(%ZPM.PackageManager.Developer.Annotation.CosEntity).%KillExtent()
		}
		else {
			&sql(delete %ZPM_PackageManager_Developer_Annotation_Tag.AnchorTag
				where OwnerClass->ModuleName = :pModuleName)			
			If SQLCODE < 0 {
				set tSQLError = $$$ERROR($$$SQLCode,SQLCODE,$get(%msg))
				set tErrorContext = $$$ERROR($$$GeneralError, "failed to remove existing tag annotation data for the module prior to generating new data")
				$$$ThrowStatus($$$EMBEDSC(tErrorContext,tSQLError))
			}
			
			&sql(delete %ZPM_PackageManager_Developer_Annotation_CosEntity.ClassProxy
				where ModuleName = :pModuleName)
			If SQLCODE < 0 {
				set tSQLError = $$$ERROR($$$SQLCode,SQLCODE,$get(%msg))
				set tErrorContext = $$$ERROR($$$GeneralError, "failed to remove existing annotation data for the module prior to generating new data")
				$$$ThrowStatus($$$EMBEDSC(tErrorContext,tSQLError))
			}
		}
	} catch tException {
		set tSC = tException.AsStatus()
	}
	
	quit tSC
}

ClassMethod ProcessAnnotationsForModule(pModuleName As %String, pListOfModulesDependedOn As %Library.List = "", Output pAnnotationXML As %Stream.TmpCharacter, Output pWarnings As %Library.ListOfDataTypes(ELEMENTTYPE="%Library.String")) As %Status
{
	Set tSC = $$$OK
	Set tCommitted = 0
	Set tInitLevel = $TLEVEL
	
	Try {
		Set pWarnings = ##class(%Library.ListOfDataTypes).%New()
		Set pAnnotationXML = ##class(%Stream.TmpCharacter).%New()
		New $$$ZPMClassOriginInfo
		
		Set tAnnotationList = ##class(%ZPM.PackageManager.Developer.Annotation.ClassProxyListContainer).%New()
		#Dim tPackageMemberClassProxy as %ZPM.PackageManager.Developer.Annotation.CosEntity.ClassProxy
		
		TSTART
		
		// clean up any pre-existing persistent data
		set tSC = ..EraseAnnotationDataForModule(pModuleName)
		$$$ThrowOnError(tSC)
		
		// initialize compiled XSLT cache
		set tCompiledXSLTCache = ##class(%ZPM.PackageManager.Core.CompiledXSLTCache).%Get(.tSC)
		$$$ThrowOnError(tSC)
		
		// initialize some info about namespaces
		new %ModuleName
		set %ModuleName = pModuleName
		
		new %HomeNamespace
		set %HomeNamespace = $namespace
				
		/*
		Now we can proceed. we'll get the module resource and start digging. 
		
		We will build an array of IDs for resources we care about; we'll examine them one by one. 
		We use SQL for rather than object methods to refer to pre-existing module/resource information
		because we might be hopping between namespaces, and opening objects becomes unreliable due to ID overlaps. 
		
		We skip "generated" resources as a convenient way to avoid cases like the HS.Util classes  
		in the HSMOD.UserAdmin module. These packages are identified as resources in the module 
		manifest but they are just "guest" classes. 
		
		If this becomes too tricky, then we may need to create a new attribute in the manifest XML to 
		identify "guest" packages like this, which should be skipped during this work. Then we could 
		wash our hands of the "generated" flag here. 
		*/
		Set tResourceResults = ##class(%SQL.Statement).%ExecDirect(,
					"select ID, UniqueName " _ 
					"from %ZPM_Storage.ResourceReference " _
					"where ""Module""->Name = ? " _
					"and isnull(IsAPI,1) = 1 " _ 
					"and isnull(Generated, 0) = 0 " _ 
					"and UniqueName is not null ",
					pModuleName)
		If (tResourceResults.%SQLCODE < 0) {
			$$$ThrowStatus($$$ERROR($$$SQLCode,tResourceResults.%SQLCODE,tResourceResults.%Message))
		}
		While tResourceResults.%Next(.tSC) {
			$$$ThrowOnError(tSC)			
			Set tResourceIDs(tResourceResults.%Get("ID")) = tResourceResults.%Get("UniqueName")
		}
		
		// now loop through the list and call other routines to find out about the resource contents
		#Dim tNewProxy as %ZPM.PackageManager.Developer.Annotation.CosEntity.ClassProxy
		Set tResourceID = ""
		While 1 {
			set tResourceID = $Order(tResourceIDs(tResourceID),1,tResourceName)
			quit:tResourceID=""
			
			// get child classes for the resource
			Set tResource = ##class(%ZPM.Storage.ResourceReference).%OpenId(tResourceID,,.tSC)
			$$$ThrowOnError(tSC)
			Set tSC = tResource.ResolveChildren(.tChildArray)
			$$$ThrowOnError(tSC)
			
			Kill tAPIClassArray
			Kill tAPIPackageArray
			Set tSC = ##class(%ZPM.Storage.ResourceReference).GetAPIScope(tResourceID, .tAPIClassArray, .tAPIPackageArray)
			$$$ThrowOnError(tSC)
			
			/*
			We want to address the annotations of classes in an order that assures us that each class's 
			superclass has already been handled, so that we can inherit annotations, comments etc. 
			Therefore we do some preliminary logic to build an ordered list of class names based on inheritance. 
			
			We have to save them all first before proceeding with the inheritance, because we want to look up 
			superclass annotations in the database regardless of whether they are in the current module or 
			some other module. In turn, this means that we have to loop through them twice. 
			
			Thus, strictly speaking, we don't need to figure out the inheritance ordering until the second go-round, 
			but we may as well get it out of the way. 
			
			tChildArray: all the classes actually in the module
			tAPIClassArray: all the classes listed explicitly in the module manifest as resources
			tAPIPackageArray: all the (sub-)packages listed explicitly in the module manifest as resources
			*/
						
			Set tChild = "" // name of class, .inc file, etc. etc. 
			Set tIncrement = 0
			For {
				Set tChild = $Order(tChildArray(tChild))
				Quit:tChild=""
				
				If (($Piece(tChild,".",*) = "CLS")
					&& ($Get(tChildArray(tChild, "Scope")) = "") // Skip test/verify-scoped resources, as they may not be loaded/compiled and shouldn't be API anyway
					&& (+$Get(tChildArray(tChild, "Generated")) = 0) // Skip generated resources subordinate to non-generated resources
					&& (+$Get(tChildArray(tChild, "IsAPI"),1) = 1)) { // Skip resources flagged by their processor class as not API (e.g., unit tests)
					Set tClassName = $piece(tChild, ".", 1, *-1) // trim off the ".CLS"
					
					If ($data(tAPIClassArray) '= 0) || ($data(tAPIPackageArray) '= 0) {
						/* 
						The resource specifies what's API. We want to skip everything that isn't. Note that 
						if tAPIClassArray and tAPIPackageArray are empty, we will scan everything because we 
						assume that anything can be API when we don't find any API elements for the resource. 
						*/
						
						Set tFoundMatch = 0
						If $data(tAPIClassArray(tClassName)) '= 0 {
							Set tFoundMatch = 1
						}
						Else {
							// loop through packages to try to find a match, but looping over a minimal set of candidates
							
							Set tLongestPossibleMatchingPackageName =  $piece(tClassName,".",1,*-1) 
							// first n-1 pieces of the target class name
							
							Set tPackageLoop = $order(tAPIPackageArray($piece(tClassName,".",1)),-1) 
							// one step previous to the earliest possible match based on just the first segment
							
							While 1 {
								// tAPIPackageArray is subscripted by package names, and the value is $length(packagename,".")
								Set tPackageLoop = $Order(tAPIPackageArray(tPackageLoop),1,tDotPieces)
								If tPackageLoop = "" {
									Quit
								}
								
								if tPackageLoop ]] tLongestPossibleMatchingPackageName {
									// we've gone past it -- the package we're checking sorts after the first n-1 parts of the class name
									Quit 
								}
								
								if $Piece(tClassName,".",1,tDotPieces) = tPackageLoop {
									Set tFoundMatch = 1
									Quit
								}
							}
						}
						
						If tFoundMatch = 0 {
							Continue // skip it
						}
					}
					
					Set tSuperClasses = $$$comClassKeyGet(tClassName, $$$cCLASSsuper)
					
					Set tClassArray(tClassName, "supers") = $listfromstring(tSuperClasses,",")
					Set tClassArray(tClassName, "position") = $i(tIncrement)
				}
			}
		}
		
		// now we go through and iteratively compare, as a sort of bubble-sort, swapping positions until everybody's happy. 
		// if class A extends class B, we want class B to have a lower position. 
		
		Set tFailsafe = 0
		While 1 {
			Set tMadeASwap = 0
			
			// the following can be thrown away once we're satisfied that the logic is right
			Set tFailsafe = tFailsafe + 1
			If tFailsafe > 10000
			{
				$$$ThrowStatus($$$ERROR($$$GeneralError, "infinite loop trying to untangle class dependencies"))
			}
			
			Set tClassLoop = ""
			While 1 {
				Set tClassLoop = $o(tClassArray(tClassLoop))
				If tClassLoop = "" {
					Quit
				}
				
				Set tCurrentPosition = tClassArray(tClassLoop, "position")
				Set tSupers = tClassArray(tClassLoop, "supers")
				
				Set tPointer = 0 
				While $listnext(tSupers, tPointer, tSuperclassName) {
					If $data(tClassArray(tSuperclassName)) {
						If tClassArray(tSuperclassName, "position") > tCurrentPosition {								
							Set tClassArray(tClassLoop, "position") = tClassArray(tSuperclassName, "position")
							Set tClassArray(tSuperclassName, "position") = tCurrentPosition								
							Set tMadeASwap = 1
							Quit
						}
					}
				}
				
				If tMadeASwap = 1 {
					Quit // bail out and start over
				}
			}
			
			If tMadeASwap = 0 {
				// all the ducks are in a row. we can stop looping
				Quit
			}
		}
		
		// now we can build an array of class names in the right order
		Set tClassLoop = ""
		While 1 {
			Set tClassLoop = $order(tClassArray(tClassLoop))
			If tClassLoop = "" {
				Quit
			}
			
			Set tSortedClasses(tClassArray(tClassLoop,"position")) = tClassLoop
		}
		
		// now we can proceed with handling the classes in a safe order	
		
		#dim tMemberObject as ClassMemberProxy
		Set tClassOrderLoop = ""
		While 1 {
			Set tClassOrderLoop = $order(tSortedClasses(tClassOrderLoop),1,tClassName)
			If tClassOrderLoop = "" {
				Quit
			}
			
			Kill tNewProxy
			Set tSC = ##class(%ZPM.PackageManager.Developer.Annotation.CosEntity.ClassProxy).BuildProxy(
					pModuleName, tClassName, pListOfModulesDependedOn, .tNewProxy) // note: this performs the "save"
			$$$ThrowOnError(tSC)
			
			If tNewProxy.IsAPI {
				Set tSC = tAnnotationList.ClassProxies.Insert(tNewProxy)
				$$$ThrowOnError(tSC)
			}
		}
		
		// output
		
		// grab the warnings
		#dim tWarningsStatement as %SQL.Statement
		set tWarningsStatement = ##class(%SQL.Statement).%New()
		set tSC = tWarningsStatement.%Prepare("select WarningText, OriginatingEntityIdentifierText " _ 
  			"from %ZPM_PackageManager_Developer_Annotation.Warning " _ 
  			"where ModuleName = '" _ pModuleName _ "'")
  		$$$ThrowOnError(tSC)
  	
  		#dim tRecords as %SQL.StatementResult
  		set tRecords = tWarningsStatement.%Execute()
	  	if tRecords.%SQLCODE < 0 {
		  	$$$ThrowStatus($$$ERROR($$$GeneralError, "Error " _ tRecords.%SQLCODE  _" while querying warnings table"))
	  	}
  		while tRecords.%Next() {
	  		set tSC = pWarnings.Insert(tRecords.%Get("WarningText") _ ": " _ tRecords.%Get("OriginatingEntityIdentifierText"))
  		}
		
		// write the XML to the stream		
		Set tWriter = ##class(%XML.Writer).%New()
		Set tWriter.Indent = 1
		
		Set tSC = tWriter.OutputToStream(pAnnotationXML)
		$$$ThrowOnError(tSC)
		/*
		Note on the above: the signature of the OutputToStream() method states that it produces
		%Library.BinaryStream, which is deprecated. However, you can apparently pass it a stream 
		from the newer %Stream family and it will work anyway. 
		*/
		
		Set tSC = tWriter.RootObject(tAnnotationList)
		$$$ThrowOnError(tSC)
		/*
		Note that if things go badly wrong with the RootObject() call, we can 
		crash/fail without throwing an exception and we don't land in the 
		catch{} block. It just gives up. Therefore if something goes haywire we have no opportunity 
		to call EndDocument() and close things; this can mean that the document 
		stream can have content from multiple failed attempts before it all gets 
		flushed out. So we should probably also try to clear the pipeline before start. (?)
		*/
		
		TCOMMIT
		Set tCommitted = 1
		
	} Catch tException {
		Set tSC = tException.AsStatus()
	}
	
	If 'tCommitted {		
		While ($TLEVEL > tInitLevel) { 
			TROLLBACK 1 
		}
	}
	
	Quit tSC
}

}
