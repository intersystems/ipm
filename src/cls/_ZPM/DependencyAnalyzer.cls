Include %ZPM.PackageManager.Common

Class %ZPM.DependencyAnalyzer
{

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod RunForAllModules() As %Status
{
	Set tSC = $$$OK
	Set tOneSC = $$$OK
	Try {
		Set tRes = ##class(%SQL.Statement).%ExecDirect(,
			"select Name from %ZPM_PackageManager_Developer.""MODULE""")
		If (tRes.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
		}
		While tRes.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			Write !,"Processing: ",tRes.%Get("Name")
			Set tOneSC = $$$ADDSC(tOneSC,..RunForModule(tRes.%Get("Name"),,0))
		}
		$$$ThrowOnError(tSC)
		
		// Report aggregated errors.
		Set tSC = tOneSC
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod RunForModule(pModuleName As %String, Output pInvalidReferences, pVerbose As %Boolean = 1, pSave As %Boolean = 1, pProgressListener As %ZPM.PackageManager.Developer.IProgressListener = {$$$NULLOREF}, Output pRunID As %String) As %Status
{
	Set pRunID = ""
	Set tSC = $$$OK
	Try {
		Set tRun = ##class(%ZPM.DependencyAnalyzer.ModuleResults).%New()
		Set tRun.TargetModule = pModuleName
		
		Set tModule = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(pModuleName,,.tSC)
		$$$ThrowOnError(tSC)
		
		If $IsObject(pProgressListener) {
			Do pProgressListener.PushStage("Building dependency graph")
		}
		
		// Build dependency graph so that we can test if resources are coming from a dependent module.
		Set tSC = tModule.BuildDependencyGraph(.tGraph)
		$$$ThrowOnError(tSC)
		
		If $IsObject(pProgressListener) {
			Do pProgressListener.PopStage()
		}
		
		// Include this module in the graph.
		Set tGraph(pModuleName) = ""
		
		// Get packages in %SYS
		Do ..GetSysPackageNames(.tSYSPackages)
		
		// Parallelize search
		#dim tQueue As %SYSTEM.WorkMgr
		Set tQueue = $System.WorkMgr.Initialize(,.tSC)
		$$$ThrowOnError(tSC)
		
		// Aggregate results from workers in IRISTEMP
		Set tNextCounter = $$$ZPMDependencyTempDataNext
		Kill $$$ZPMDependencyTempData(tNextCounter)
		
		If $IsObject(pProgressListener) {
			Do pProgressListener.PushStage("Scanning classes in module")
		}
		Set tClassCount = 0
		
		Set tResourceKey = ""
		For {
			#dim tResource As %ZPM.PackageManager.Developer.ResourceReference
			Set tResource = tModule.Resources.GetNext(.tResourceKey)
			If (tResourceKey = "") {
				Quit
			}
			
			Kill tResourceArray
			Set tSC = tResource.ResolveChildren(.tResourceArray)
			$$$ThrowOnError(tSC)
			
			Set tChildKey = ""
			For {
				Set tChildKey = $Order(tResourceArray(tChildKey))
				If (tChildKey = "") {
					Quit
				}
				
				// Skips generated classes, stub classes
				If $Get(tResourceArray(tChildKey,"Generated"),0) {
					Continue
				}
				
				Set tExt = $Piece(tChildKey,".",*)
				If (tExt = "CLS") {
					Set tClass = $Piece(tChildKey,".",1,*-1)
					// Queue search of class
					Set tSC = tQueue.QueueCallback("##class("_$classname()_").ExtractClassReferencesToName","##class("_$classname()_").ClassExtractionComplete",tClass,tNextCounter,pProgressListener)
					$$$ThrowOnError(tSC)
					Set tClassCount = tClassCount + 1
				}
			}
		}
		
		If $IsObject(pProgressListener) {
			Do pProgressListener.SetStageTotalUnits(tClassCount)
		}
		
		Set tSC = tQueue.WaitForComplete()
		$$$ThrowOnError(tSC)
		
		If $IsObject(pProgressListener) {
			Do pProgressListener.PopStage()
			Do pProgressListener.PushStage("Checking module references.")
			Set tClassCount = 0
			Set tReferenceKey = ""
			For {
				Set tReferenceKey = $Order($$$ZPMDependencyTempData(tNextCounter,tReferenceKey))
				If (tReferenceKey = "") {
					Quit
				}
				Set tClassCount = tClassCount + 1
			}
			Do pProgressListener.SetStageTotalUnits(tClassCount)
		}
		
		// Iterate through classes and find home modules (or omit if it's a library class)
		Set tReferenceKey = ""
		For {
			Set tReferenceKey = $Order($$$ZPMDependencyTempData(tNextCounter,tReferenceKey))
			If (tReferenceKey = "") {
				Quit
			}
			
			// Track this beforehand because of all the "continue"s.
			If $IsObject(pProgressListener) {
				Do pProgressListener.NotifyUnitCompleted(tReferenceKey)
			}
			
			Set tTopPackage = $Piece(tReferenceKey,".")	
			// If tTopPackage happens to be empty, skip it rather than hitting <SUBSCRIPT> below. (Some weird code using macros for package names causes this right now.)
			If (tTopPackage = "") {
				Continue
			}
			// Special cases: skip packages in %SYS assuming methods using them run in %SYS or they are % packages always available.
			If $Data(tSYSPackages(tTopPackage)) {
				Continue
			}
			
			If '$$$comClassDefined(tReferenceKey) {
				// This is its own sort of issue - the class doesn't exist!
				Merge pInvalidReferences($Char(0),tReferenceKey) = $$$ZPMDependencyTempData(tNextCounter,tReferenceKey)
				Continue
			}
			
			// Do not flag references to non-%Z* % classes (making an exception for %ZEN), %ZPM or Ens* package classes.
			If $Match(tReferenceKey,"^(%([^Z]|ZHSLIB|ZEN)|Ens([^.])*)\.(.)*$") {
				Continue
			}
			
			Set tHomeModule = ##class(%ZPM.PackageManager.Developer.Extension.Utils).FindHomeModule(tReferenceKey_".CLS")
			If $IsObject(tHomeModule) && $Data(tGraph(tHomeModule.Name)) {
				Continue
			}
			
			// The class may also be generated by another class in the module.
			// Example: HS.Data.OIDMapIdentityCodeAliases generated by HS.Data.OIDMap
			Set tGeneratedBy = $$$comClassKeyGet(tReferenceKey,$$$cCLASSgeneratedby)
			If (tGeneratedBy '= "") && ($$$comClassKeyGet(tReferenceKey,$$$cCLASSdeployed) = 2) {
				Set tHomeModule = ##class(%ZPM.PackageManager.Developer.Extension.Utils).FindHomeModule(tGeneratedBy)
				If $IsObject(tHomeModule) && $Data(tGraph(tHomeModule.Name)) {
					Continue
				}
			}
			
			Set tHomeModuleName = $Char(0)
			If $IsObject(tHomeModule) {
				Set tHomeModuleName = tHomeModule.Name
			}
			Merge pInvalidReferences(tHomeModuleName,tReferenceKey) = $$$ZPMDependencyTempData(tNextCounter,tReferenceKey)
		}
		
		If $IsObject(pProgressListener) {
			Do pProgressListener.PopStage()
			Do pProgressListener.PushStage("Saving Results.")
		}
		
		// Represent results as objects
		Set tModuleKey = ""
		For {
			Set tModuleKey = $Order(pInvalidReferences(tModuleKey))
			If (tModuleKey = "") {
				Quit
			}
			
			Set tReferencedClassKey = ""
			For {
				Set tReferencedClassKey = $Order(pInvalidReferences(tModuleKey,tReferencedClassKey))
				If (tReferencedClassKey = "") {
					Quit
				}
				
				Set tReferencingClassKey = ""
				For {
					Set tReferencingClassKey = $Order(pInvalidReferences(tModuleKey,tReferencedClassKey,tReferencingClassKey))
					If (tReferencingClassKey = "") {
						Quit
					}
					If (tReferencedClassKey = tReferencingClassKey) {
						// This sometimes happens if the class is not compiled.
						Continue
					}
					
					Set tMemberKey = ""
					For {
						Set tMemberKey = $Order(pInvalidReferences(tModuleKey,tReferencedClassKey,tReferencingClassKey,tMemberKey))
						If (tMemberKey = "") {
							Quit
						}
						
						Set tLineKey = ""
						For {
							Set tLineKey = $Order(pInvalidReferences(tModuleKey,tReferencedClassKey,tReferencingClassKey,tMemberKey,tLineKey),1,tLine)
							If (tLineKey = "") {
								Quit
							}
							
							Set tProblem = ##class(%ZPM.DependencyAnalyzer.Problem).%New()
							Set tProblem.ReferencedModule = $Case(tModuleKey,$c(0):"",:tModuleKey)
							Set tProblem.ReferencedClassExists = (tModuleKey '= $c(0))
							Set tProblem.ReferencedClass = tReferencedClassKey
							Set tProblem.ProblemClass = tReferencingClassKey
							Set tProblem.ProblemMember = tMemberKey
							Set tProblem.ProblemLine = tLineKey
							Set tProblem.ProblemCode = tLine
							Set tSC = tProblem.%ValidateObject()
							If $$$ISOK(tSC) {
								Do tRun.Problems.Insert(tProblem)
							} Else {
								Do ##class(%ZPM.General.LogManager).Warning("Could not save problem: "_tProblem.ToString()_$c(13,10,9)_"Error: "_$System.Status.GetErrorText(tSC),1)
							}
						}
					}
				}
			}
		}
		
		If pSave {
			$$$ThrowOnError(tRun.%Save())
			Set pRunID = tRun.%Id()
		}
		
		If $IsObject(pProgressListener) {
			Do pProgressListener.PopStage()
		}
		
		If pVerbose {
			Do tRun.Display()
		}
	} Catch e {
		Set tSC = e.AsStatus()
		If pVerbose {
			Write !,$System.Status.GetErrorText(e.AsStatus())
		}
	}
	Quit tSC
}

/// Get the names of all non % packages in %SYS as keys of the output
/// subscripted array.
ClassMethod GetSysPackageNames(Output pSysPackageNameArray) [ Internal ]
{
	Kill pSysPackageNameArray
	New $Namespace
	Set $Namespace = "%SYS"
	Set query = "SELECT DISTINCT $Piece(Name, '.') As Package FROM %Dictionary.CompiledClass"
	Set statement = ##class(%SQL.Statement).%New()
	$$$ThrowOnError(statement.%Prepare(query))
	Set resultSet = statement.%Execute()
	If (resultSet.%SQLCODE < 0) {
		Throw ##class(%Exception.SQL).CreateFromSQLCODE(resultSet.%SQLCODE, resultSet.%Message)
	}
	While resultSet.%Next(.sc) {
		$$$ThrowOnError(sc)
		Set pSysPackageNameArray(resultSet.%Get("Package")) = ""
	}
	$$$ThrowOnError(sc)
}

/// @API.Query
/// @Modifier Availability InterSystems
Query LatestResults(pProblemModule As %String) As %SQLQuery [ SqlProc ]
{
	select Run->TargetModule,ProblemClass,ReferencedModule,ReferencedClass,ProblemMember,ProblemLine,ProblemCode
	from %ZPM_DependencyAnalyzer.Problem
	where :pProblemModule is null or :pProblemModule = Run->TargetModule
	having Run->ID = MAX(Run->ID %FOREACH (Run->TargetModule))
}

ClassMethod ExtractClassReferencesToName(pSourceClass As %String, pTargetSubscript As %String, pProgressListener As %ZPM.PackageManager.Developer.IProgressListener) As %Status
{
	Set tSC = ..ExtractClassReferences(pSourceClass,.tResults)
	Merge $$$ZPMDependencyTempData(pTargetSubscript) = tResults
	Quit tSC
}

ClassMethod ClassExtractionComplete(pSourceClass As %String, pTargetSubscript As %String, pProgressListener As %ZPM.PackageManager.Developer.IProgressListener) As %Status
{
	Set pProgressListener = $$$objIntToOref(+pProgressListener)
	If $IsObject(pProgressListener) {
		Do pProgressListener.NotifyUnitCompleted(pSourceClass)
	}
	Quit $$$OK
}

ClassMethod ExtractClassReferences(pSourceClass As %String, ByRef pRefArray) As %Status
{
	Set tSC = $$$OK
	Try {
		// Get references in UDL
		$$$ThrowOnError(##class(%Compiler.UDL.TextServices).GetTextAsStream(,pSourceClass,.tSourceStream))
		
		Set tSC = ##class(%Library.SyntaxColorReader).FromCode(tSourceStream,"CLS","A",.tSCReader)
		$$$ThrowOnError(tSC)
		
		// Get references in COS
		$$$ThrowOnError(##class(%Compiler.UDL.TextServices).GetTextAsArray(,pSourceClass,.tDocumentText))
		Set tDocumentText = $Order(tDocumentText(""),-1) //Set top level node to # of lines.
		
		Set tMember = ""
		Set tInMember = ""
		Set tMemberStarted = 0
		For tDocLine=1:1:tDocumentText {
			Set tLine = tDocumentText(tDocLine)
			Do tSCReader.NextLine(.tLineTokenList)
			If (tInMember = "") {
				Set pExecutableFlags(tDocLine) = 0
			
				// Extract line offset of method in class
				Set tStart = $Extract(tLine,1,6)
				If (tStart = "ClassM") || (tStart = "Method") || (tStart = "Query ") {
					Set tMember = $Piece($Piece(tLine,"(")," ",2)
					Kill tMemberCode
					Set tInMember = $Case(tStart,"Query ":"query",:"method")
				}
				
				// Look at the next line of tokens from UDL.
				Do ..ExtractClassReferencesFromLine(pSourceClass," ",tDocLine,tLineTokenList,.pRefArray,.tDocumentText)
			} Else {
				If $Extract(tLine) = "{" {
					Set tMemberStarted = 1
					Set tMethodMap(tMember) = tDocLine + 1
				} ElseIf ($Extract(tLine) = "}") {
					If (tMember '= "") {
						If (tInMember = "method") {
							Set tSC = ..ExtractClassReferencesFromMethod(pSourceClass,tMember,.tMemberCode,.tMethodMap,.pRefArray)
							$$$ThrowOnError(tSC)
						} ElseIf (tInMember = "query") {
							Set tSC = ..ExtractClassReferencesFromQuery(pSourceClass,tMember,.tMemberCode,.tMethodMap,.pRefArray)
							$$$ThrowOnError(tSC)
						}
					}
					Set tInMember = ""
					Set tMemberStarted = 0
				} Else {
					// Aggregate lines from the method body to look at later.
					Set tMemberCode($i(tMemberCode)) = tLine
				} 
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod ExtractClassReferencesFromMethod(pSourceClass As %String, pMethod As %String, ByRef pMethodCode, ByRef pMethodMap, ByRef pRefArray) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tCodeMode = $$$defMemberKeyGet(pSourceClass,$$$cCLASSmethod,pMethod,$$$cMETHcodemode)
		If (tCodeMode = $$$cMETHCODEMODEGENERATOR) || (tCodeMode = $$$cMETHCODEMODEOBJECTGENERATOR) || '$Data(^rMAP(pSourceClass,"CLS","INT",pMethod)) {
			Quit
		}
		Set tSourceStream = ##class(%Stream.GlobalCharacter).%New()
		Set tSourceStream.LineTerminator = $c(13,10)
		For tMethodLine=1:1:$Get(pMethodCode) {
			Do tSourceStream.WriteLine(pMethodCode(tMethodLine))
		}
		
		Set tSC = ##class(%Library.SyntaxColorReader).FromCode(tSourceStream,"COS","A",.tSCReader)
		$$$ThrowOnError(tSC)
		
		Set tOffset = pMethodMap(pMethod)
		Set tLine = 1
		While tSCReader.NextLine(.tLineTokenList) {
			If (tLine = 0) && (tCodeMode = $$$cMETHCODEMODEEXPRESSION) {
				// Simulate a normal method.
				Set tLineTokenList = $ListBuild($ListBuild("COS","Command","Quit"))_tLineTokenList
			}
			Do ..ExtractClassReferencesFromLine(pSourceClass,pMethod,tLine,tLineTokenList,.pRefArray,.pMethodCode)
			Set tLine = tLine + 1
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod ExtractClassReferencesFromQuery(pSourceClass As %String, pQuery As %String, ByRef pMethodCode, ByRef pMethodMap, ByRef pRefArray) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tSourceStream = ##class(%Stream.GlobalCharacter).%New()
		Set tSourceStream.LineTerminator = $c(13,10)
		For tMethodLine=1:1:$Get(pMethodCode) {
			Do tSourceStream.WriteLine(pMethodCode(tMethodLine))
		}
		
		Set tSC = ##class(%Library.SyntaxColorReader).FromCode(tSourceStream,"SQL","A",.tSCReader)
		$$$ThrowOnError(tSC)
		
		Set tOffset = pMethodMap(pQuery)
		Set tLine = 1
		While tSCReader.NextLine(.tLineTokenList) {
			Do ..ExtractClassReferencesFromLine(pSourceClass,pQuery,tLine,tLineTokenList,.pRefArray,.pMethodCode)
			Set tLine = tLine + 1
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod ExtractClassReferencesFromLine(pSourceClass As %String, pMethod As %String, pLine As %Integer, tLineTokenList As %List, ByRef pRefArray, ByRef pMethodCode)
{
	/*
	// Like $$$NormalizeClassname from %occClassname.inc, but relative to another class (for references to the same package)
	#define NormalizeClassname(%class,%source) $s(%class="":"",%class[".":%class,$e(%class)'="%":$$$ClassPackageName(%source)_"."_%class,1:"%Library."_$e(%class,2,*))
	#define AddReference(%classname) Set pRefArray($$$NormalizeClassname(%classname,pSourceClass),pSourceClass,pMethod,pLine) = $ZStrip(pMethodCode(pLine),"<>W")
	*/
	#define AddReference(%classname) $$$NormalizeClassnameByDef(%classname,pSourceClass) Set pRefArray(%classname,pSourceClass,pMethod,pLine) = $ZStrip(pMethodCode(pLine),"<>W")
	Set tInClassname = 0
	Set tInTableName = 0
	Set tClassName = ""
	Set tTableName = ""
	Set tPointer = 0
	Set tTableState = 0
	While $ListNext(tLineTokenList,tPointer,tLineToken) {
		Set $ListBuild(tLanguage,tType,tValue) = tLineToken
		If tInTableName {
			// Table name has format:
			// Identifier Delimiter (.) Identifier
			// With possible intervening whitespace.
			
			// Values of tTableState:
			// 1: just saw something indicating that a table name might be about to appear (e.g., from, join), and expect an identifier.
			// 2: just saw first identifier (schema), and expect a delimiter.
			// 3: just saw delimiter (.), and expect a table name
			If (tType = "White Space") {
			} ElseIf (tType = "Delimiter") && (tValue = ".") && (tTableState = 2) {
				Set tTableName = tTableName_tValue
				Set tTableState = 3
			} ElseIf (tType = "Identifier") && ((tTableState = 1) || (tTableState = 3)) {
				Set tTableName = tTableName_$Translate(tValue,"""")
				Set tTableState = tTableState + 1
			} Else {
				If (tTableName '= "") {
					Set tSC = ..GetClassNameFromTableName(pSourceClass,tTableName,.tClassName)
					$$$ThrowOnError(tSC)
					If (tClassName '= "") {
						$$$AddReference(tClassName)
					}
				}
				Set tTableName = ""
				Set tInTableName = 0
				Set tTableState = 0
			}
		}
		If (tLanguage = "COS") {
			// ##class(Some.Class)
			If (tType = "Object (Class)") {
				Set tInClassname = 1
				Set tClassName = ""
			} ElseIf (tType = "Object name") {
				If ($Extract(tValue) = """") {
					// Quoted classname.
					Set tValue = $Extract(tValue,2,*-1)
				}
				Set tClassName = tClassName_tValue
			} ElseIf tInClassname && (tType = "Delimiter") && (tValue = ")") {
				// Avoid <SUBSCRIPT> in cases where the full class name is a macro (for example)
				If (tClassName '= "") {
					$$$AddReference(tClassName)
				}
				Set tClassName = ""
				Set tInClassname = 0
			}
		} ElseIf (tLanguage = "CLS") {
			If (tType = "Class Name") {
				Set tInClassname = 1
				Set tClassName = tClassName_tValue
			} ElseIf tInClassname {
				$$$AddReference(tClassName)
				Set tClassName = ""
				Set tInClassname = 0
			}
		} ElseIf (tLanguage = "SQL") {
			If 'tInTableName {
				Set tLowerValue = $ZConvert(tValue,"L")
				If (tType = "Qualifier keyword") && ((tLowerValue = "from") || (tLowerValue = "join")) {
					Set tInTableName = 1
					Set tTableState = 1
				}
			}
		}
	}
	
	// If we ended a table name on the line.
	If (tInTableName) && (tTableName '= "") {
		Set tSC = ..GetClassNameFromTableName(pSourceClass,tTableName,.tClassName)
		$$$ThrowOnError(tSC)
		If (tClassName '= "") {
			$$$AddReference(tClassName)
		}
	}
}

ClassMethod GetClassNameFromTableName(pSourceClass As %String, pFullTableName As %String, Output pClassName) As %Status
{
	Set tSC = $$$OK
	Try {
		Set pClassName = ""
		
		// Default: same SQL schema
		If ($Length(pFullTableName,".") > 1) {
			Set tSchemaName = $Piece(pFullTableName,".")
		} Else {
			Set tSchemaName = $$$comClassKeyGet(pSourceClass,$$$cCLASSsqlschemaname)
		}
		Set tTableName = $Piece(pFullTableName,".",*)
		
		Set tResult = ##class(%SQL.Statement).%ExecDirect(,
			"select NVL(NVL("_
			"(select CLASSNAME from INFORMATION_SCHEMA.TABLES where TABLE_SCHEMA = ? and TABLE_NAME = ?),"_
			"(select CLASSNAME from INFORMATION_SCHEMA.ROUTINES where SPECIFIC_SCHEMA = ? and SPECIFIC_NAME = ?)),"_
			"(select CLASSNAME from INFORMATION_SCHEMA.VIEWS where TABLE_SCHEMA = ? and TABLE_NAME = ?))",
			tSchemaName,tTableName,tSchemaName,tTableName,tSchemaName,tTableName)
		If (tResult.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tResult.%SQLCODE,tResult.%Message)
		}
		If tResult.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			Set pClassName = tResult.%GetData(1)
		} Else {
			$$$ThrowOnError(tSC)
		}
		If (pClassName = "") {
			Do ##class(%ZPM.General.LogManager).Warning("Table name not found: "_pFullTableName,1)
			Set pClassName = ""
		}
	} Catch e {
		Set pClassName = ""
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Left in as a tool for developers working to enhance this class in the future.
/// This shows all the tokens for a given class.
ClassMethod Test(pClass As %String) [ Internal ]
{
	Set tSC = $$$OK
	Try {
		$$$ThrowOnError(##class(%Compiler.UDL.TextServices).GetTextAsStream(,pClass,.tSourceStream))
		
		Set tSC = ##class(%Library.SyntaxColorReader).FromCode(tSourceStream,"CLS","A",.tSCReader)
		$$$ThrowOnError(tSC)
		
		While tSCReader.NextLine(.tLineTokenList) {
			zw tLineTokenList
		}
	} Catch e {
		Set tSC = e.AsStatus()
		Write !,$System.Status.GetErrorText(e)
	}
	Quit tSC
}

}
