Include (%occSAX, %syGluedef)

IncludeGenerator %occSAX

Class %ZPM.PackageManager.Developer.CLI
{

/// Description of commands to use for this CLI
XData Commands [ XMLNamespace = "http://www.intersystems.com/PackageManager/CLI" ]
{
<?xml version="1.0"?>
<commands>
</commands>
}

/// This is the Schema which defines the form of the Commands XData block
XData Schema [ Internal ]
{
<?xml version="1.0"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" >

<xs:element name="commands">
<xs:complexType>
<xs:choice minOccurs="0" maxOccurs="unbounded">
<xs:element name="command">
<xs:complexType>
<xs:choice minOccurs="0" maxOccurs="unbounded">

<!-- A modifier is a flag that controls the behavior of the command. -->
<xs:element name="modifier">
<xs:complexType>
<!-- Modifier name -->
<xs:attribute name="name" type="string" use="required"/>

<!-- Modifier name -->
<xs:attribute name="required" type="xs:boolean" use="optional" default="false"/>

<!-- Comma-separated list of aliases -->
<xs:attribute name="aliases" type="string" use="optional"/>

<!-- If true, the modifier name is followed in the command string by a value -->
<xs:attribute name="value" type="xs:boolean" use="optional" default="false"/>

<!-- If true, the modifier name is followed in the command string by a value -->
<xs:attribute name="description" type="string" use="optional"/>

<!-- If set, this provides a fixed list of valid values for the modifier -->
<xs:attribute name="valueList" type="string" use="optional"/>

<!-- If set, the value is put into the specified subscript of "data" instead of "parameters" -->
<xs:attribute name="dataAlias" type="string" use="optional"/>

<!-- If set, the specified value is put into the info("data","<dataAlias>") - for commands that don't take values -->
<xs:attribute name="dataValue" type="string" use="optional"/>
</xs:complexType>
</xs:element>

<!-- A parameter is a space-delimted string provided to a command without a modifier. These appear in order at the end of the command. -->
<xs:element name="parameter">
<xs:complexType>
<!-- Parameter name -->
<xs:attribute name="name" type="string" use="required"/>

<!-- Parameter required? -->
<xs:attribute name="required" type="xs:boolean" use="optional" default="false"/>

<!-- Description of what this parameter does -->
<xs:attribute name="description" type="string" use="optional"/>

<!-- If set to true (default is false), parameter will take all trailing input (including spaces) -->
<xs:attribute name="trailing" type="xs:boolean" use="optional" default="false"/>
</xs:complexType>
</xs:element>

<!-- Example of how to use the command -->
<xs:element name="example" type="example" />

<!-- Description of command -->
<xs:element name="description" type="description"/>
</xs:choice>

<!-- Name of the command -->
<xs:attribute name="name" type="string" use="optional"/>

<!-- If set to true, this is the default command if the parser does not match any. The name is ignored, and is instead treated as the first parameter. -->
<xs:attribute name="default" type="xs:boolean" use="optional" default="false"/>

<!-- Comma-separated list of aliases -->
<xs:attribute name="aliases" type="string" use="optional"/>

<!-- If true, modifiers are at the end of the command. -->
<xs:attribute name="trailingModifiers" type="xs:boolean" use="optional" default="false" />

<!-- If set, modifiers starting with this prefix are put into the "data" subscript of the command array. -->
<xs:attribute name="dataPrefix" type="string" use="optional" />
</xs:complexType>
</xs:element>
</xs:choice>
</xs:complexType>
</xs:element>

<!-- example element with content -->
<xs:complexType name="example">
<xs:simpleContent>
<xs:extension base="string">
<xs:attribute name="description" type="string" />
</xs:extension>
</xs:simpleContent>
</xs:complexType>

<!-- description element with content -->
<xs:complexType name="description">
<xs:simpleContent>
<xs:extension base="string">
</xs:extension>
</xs:simpleContent>
</xs:complexType>

<!-- disallow, allow, require  -->
<xs:simpleType name="modifierValue">
  <xs:restriction base="xs:string">
    <xs:enumeration value="disallow" />
    <xs:enumeration value="allow" />
    <xs:enumeration value="require" />
  </xs:restriction>
</xs:simpleType>

<!-- String of minimum length 1 -->
<xs:simpleType name="string">
<xs:restriction base="xs:string">
<xs:minLength value="1"/>
</xs:restriction>
</xs:simpleType>

</xs:schema>
}

/// Displays help for a given command
ClassMethod %Help(ByRef pCommandInfo) [ Final ]
{
	Set tCommand = $Get(pCommandInfo("parameters","command"))
	Set tVerbose = ''$Data(pCommandInfo("modifiers","verbose"))
	Set tMarkdown = ''$Data(pCommandInfo("modifiers","markdown"))
	Do ..%GetCommandStructure(.tCommandStruct)
	
	If (tCommand '= "") && '$Data(tCommandStruct(tCommand)) {
		// See if it's an alias. (If not, we'll show help for everything.)
		If $Data(tCommandStruct(1,tCommand),tCommand)
	}
	
	If (tCommand '= "") && (tCommand '= +tCommand) && $Data(tCommandStruct(tCommand)) {
		Kill tOneCommandStruct
		Merge tOneCommandStruct = tCommandStruct(tCommand)
		Do ..%HelpForCommand(tCommand,.tOneCommandStruct,1,tMarkdown)
	} Else {
		// For markdown mode only, merge aliases into main part of tCommandStruct array.
		// This gets the commands in alphabetical order.
		If tMarkdown {
			Set tCommand = ""
			For {
				Set tCommand = $Order(tCommandStruct(1,tCommand))
				Quit:(tCommand="")
				
				Set tCommandStruct(tCommand) = tCommandStruct(1,tCommand)
			}
		}
		
		// List commands
		Write:'tMarkdown !,"Available commands: "
		Set tCommand = ""
		For {
			Set tCommand = $Order(tCommandStruct(tCommand))
			Quit:(tCommand="")
			Continue:(tCommand=+tCommand) // Skip numbered subscripts.
			
			Kill tOneCommandStruct
			Merge tOneCommandStruct = tCommandStruct(tCommand)
			Do ..%HelpForCommand(tCommand,.tOneCommandStruct,tVerbose,tMarkdown)
			
			Write !
		}
		
		Write:'tVerbose !,"For more detail, run:",!?2,"help <command-name>",!,"or",!?2,"help -v"
	}
}

ClassMethod %HelpForCommand(pCommandName As %String, ByRef pCommandStruct, pDetailed As %Boolean = 0, pMarkdownFormat As %Boolean = 0)
{
	#define ESCAPE(%string) $Select(pMarkdownFormat:$Replace(%string,"[","\["),1:%string)
	Set tIndent = 2
	Set tIsAlias = $Data(pCommandStruct)<10
	If pMarkdownFormat && tIsAlias {
		Write !,"----",!,"h2. ",pCommandName
		Write !,"_Alias for [",pCommandStruct,"|#",pCommandStruct,"]_"
	}
	
	// Don't show full documentation for aliases 
	Quit:tIsAlias
	
	Write !,$Select(pMarkdownFormat:"----",1:""),!
	Write:pMarkdownFormat "h2. "
	Write pCommandName
	
	Write:pMarkdownFormat !,"Syntax: {{",pCommandName
	
	If $Data(pCommandStruct("modifiers")) && '$Get(pCommandStruct("trailingModifiers"),0) {
		Write $$$ESCAPE(" [flags]")
	}
	
	If $Data(pCommandStruct("parameters")) {
		Set tKey = ""
		Set tEndingBrackets = 0
		For {
			Set tKey = $Order(pCommandStruct("parameters",tKey),1,tParamName)
			Quit:(tKey="")
			Quit:(tKey'=+tKey) //Only deal with ordered parameters, not named
			
			Write " "
			If 'pCommandStruct("parameters",tParamName,"required") {
				Write $$$ESCAPE("[")
				Set tEndingBrackets = tEndingBrackets + 1
			}
			Write "<",tParamName,">"
		}
		
		For i=1:1:tEndingBrackets {
			Write $$$ESCAPE("]")
		}
	}
	
	If $Data(pCommandStruct("modifiers")) && $Get(pCommandStruct("trailingModifiers"),0) {
		Write $$$ESCAPE(" [flags]")
	}
	
	Write:pMarkdownFormat "}}"
	
	Write:$Data(pCommandStruct("aliases")) !,"Alias",$Case($Length(pCommandStruct("aliases"),","),1:"",:"es"),": ",$Replace(pCommandStruct("aliases"),",",", ")
	
	Write:$Data(pCommandStruct("description")) !,?tIndent,pCommandStruct("description")
	If (pDetailed) {
		// Modifiers
		If $Data(pCommandStruct("modifiers")) {
			Write !!
			If (pMarkdownFormat) {
				Write "h3."
			} Else {
				Write ?tIndent
			}
			Write "Flags"
			If pMarkdownFormat {
				Write !,"||Flag||Description||Aliases||"
			}
			Set tKey = 1000
			For {
				Set tKey = $Order(pCommandStruct("modifiers",tKey))
				Quit:(tKey="")
				
				Write !
				If pMarkdownFormat {
					Write "|"
				} Else {
					Write ?(tIndent*2)
				}
				Write "-",tKey
				
				Kill tModInfo Merge tModInfo = pCommandStruct("modifiers",tKey)
				If $Get(tModInfo("value")) {
					If $Data(tModInfo("valueList"),tValueList) {
						Write " <",$Replace(tValueList,",","/"),">"
					} Else {
						Write " <value>"
					}
				}
				Write:pMarkdownFormat " |"
				If ($Data(tModInfo("description"),tDesc)) {
					If 'pMarkdownFormat {
						Write !,?(tIndent*3)
					}
					Write tDesc
				}
				Write:pMarkdownFormat " |"
				If ($Data(tModInfo("aliases"),tAliases)) {
					If 'pMarkdownFormat {
						Write !,?(tIndent*3),"alias(es): -"
					}
					Write $Replace(tAliases,",",", -")
				}
				Write:pMarkdownFormat " |"
			}
		}
		
		// Arguments
		If $Data(pCommandStruct("parameters")) {
			Write !!
			If (pMarkdownFormat) {
				Write "h3."
			} Else {
				Write ?tIndent
			}
			Write "Arguments"
			If pMarkdownFormat {
				Write !,"||Name||Description||"
			}
			Set tKey = ""
			For {
				Set tKey = $Order(pCommandStruct("parameters",tKey),1,tParamName)
				Quit:(tKey="")
				Quit:(tKey'=+tKey) //Only deal with ordered parameters, not named
				
				Write !
				If pMarkdownFormat {
					Write "|"
				} Else {
					Write ?(tIndent*2)
				}
				Write tParamName
				Write:pMarkdownFormat " |"
				
				Kill tParamInfo Merge tParamInfo = pCommandStruct("parameters",tParamName)
				If ($Data(tParamInfo("description"),tDesc)) {
					If 'pMarkdownFormat {
						Write !,?(tIndent*3)
					}
					Write tDesc
				}
				Write:pMarkdownFormat " |"
			}
		}
		
		// Examples
		If $Data(pCommandStruct("examples")) {
			Write !!
			If (pMarkdownFormat) {
				Write "h3."
			} Else {
				Write ?tIndent
			}
			Write "Examples"
			If pMarkdownFormat {
				Write !,"||Command||Description||"
			}
			Set tKey = ""
			For {
				Set tKey = $Order(pCommandStruct("examples",tKey))
				Quit:(tKey="")
				
				
				Write !
				Write:pMarkdownFormat "|{{"
				Write pCommandStruct("examples",tKey)
				Write:pMarkdownFormat "}}|"
				Write:'pMarkdownFormat ?(tIndent*2)
				If $Data(pCommandStruct("examples",tKey,"description"),tDesc) {
					Write:'pMarkdownFormat !,?(tIndent*3)
					Write tDesc
				} Else {
					Write:'pMarkdownFormat ?(tIndent*2)
				}
				Write:pMarkdownFormat " |"
			}
		}
	}
}

/// Parses a command, validating it based on the Commands XData block and structuring output as follows:
/// pCommandInfo = "<command name>"
/// pCommandInfo("modifiers","<modifier-name>") = "<modifier-value>"
/// pCommandInfo("parameters","<parameter-name>") = "<parameter-value>"
/// pCommandInfo("data","<data-name>") = "<data-value>"
ClassMethod %ParseCommandInput(pCommandString As %String, Output pCommandInfo) As %Status [ Final ]
{
	Set tSC = $$$OK
  Kill pCommandInfo
	Try {
		Do ..%GetCommandStructure(.tCommandStructure)
		
		// Parser states:
		// 0 - looking for next item (following a space)
		// 1 - in command
		// 2 - in modifier identifier
		// 3 - in modifier value
		// 4 - in quoted modifier value
		// 5 - in parameter value
		// 6 - in quoted parameter value
		// 7 - just saw the escape character (\) while in a quoted string
		// 8 - in a trailing parameter, so capture the rest of the string as the final parameter (including spaces)
		// 9 - in the name for a data element (following command's dataPrefix)
		
		#define PREARGUMENT 0
		#define COMMAND 1
		#define MODIFIERNAME 2
		#define MODIFIERVALUE 3
		#define MODIFIERVALUEQUOTED 4
		#define PARAMETERVALUE 5
		#define PARAMETERVALUEQUOTED 6
		#define ESCAPECHAR 7
		#define TRAILINGPARAMETERVALUE 8
		#define DATANAME 9
		
		Set tState = $$$COMMAND
		Set tPos = 1
		Set tAccum = ""
		Set tModifier = ""
		Set tDataName = ""
		Set tParamCount = 0
		Set tPreEscapeState = ""
		For {
			Set tChar = $Extract(pCommandString,tPos)
			Set tPos = tPos + 1
			
			If (tChar = " ") || (tChar = "") {
				If (tState = $$$COMMAND) && (tAccum'="") {
					If $Data(tCommandStructure(tAccum)) {
						// tAccum contains command name.
						Set pCommandInfo = tAccum
					} ElseIf $Data(tCommandStructure(1,tAccum),tAliasFor) {
						// tAccum contains an alias - use the real name.
						Set pCommandInfo = tAliasFor
					} ElseIf $Data(tCommandStructure(0,"default"),tDefaultCommand) {
						// tAccum just got the first parameter, so pass it along to the default command.
						Set pCommandInfo = tDefaultCommand
						Set tParamName = $Get(tCommandStructure(tDefaultCommand,"parameters",$i(tParamCount)))
						If (tParamName = "") {
							$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Too many parameters to command '%1'; only %2 expected.",pCommandInfo,tParamCount-1)))
						}
						Set pCommandInfo("parameters",tParamName) = tAccum
					} Else {
						$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Unknown command: %1",tAccum)))
					}
					Set tAccum = ""
					Set tState = $$$PREARGUMENT
				} ElseIf (tState = $$$MODIFIERNAME) {
					If $Data(tCommandStructure(pCommandInfo,"modifiers",tAccum)) {
						Set tModifier = tAccum
					} ElseIf $Data(tCommandStructure(pCommandInfo,"modifiers",1,tAccum),tAliasFor) {
						Set tModifier = tAliasFor
					} Else {
						$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Unknown modifier for command '%1': %2",pCommandInfo,tAccum)))
					}
					If $Data(tCommandStructure(pCommandInfo,"modifiers",tModifier,"dataAlias"),tDataAlias) {
						Set tDataName = tDataAlias
						If $Data(tCommandStructure(pCommandInfo,"modifiers",tModifier,"dataValue"),tDataValue) {
							Do ..SetData(.pCommandInfo,tDataAlias,tDataValue)
							Set tState = $$$PREARGUMENT
						} Else {
							Set tState = $$$MODIFIERVALUE
						}
					} ElseIf tCommandStructure(pCommandInfo,"modifiers",tModifier,"value") {
						Set tState = $$$MODIFIERVALUE
					} Else {
						Set pCommandInfo("modifiers",tModifier) = ""
						Set tState = $$$PREARGUMENT
					}
					Set tAccum = ""
				} ElseIf (tState = $$$MODIFIERVALUE) {
					If ($Get(tDataName) '= "") {
						Do ..SetData(.pCommandInfo,tDataName,tAccum)
						Set tDataName = ""
					} Else {
						Set pCommandInfo("modifiers",tModifier) = tAccum
					}
					Set tAccum = ""
					Set tState = $$$PREARGUMENT
				} ElseIf (tState = $$$PARAMETERVALUE) || ((tState = $$$TRAILINGPARAMETERVALUE) && (tChar = "")) {
					Set tParamName = $Get(tCommandStructure(pCommandInfo,"parameters",$i(tParamCount)))
					If (tParamName = "") {
						$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Too many parameters to command '%1'; only %2 expected.",pCommandInfo,tParamCount-1)))
					}
					Set pCommandInfo("parameters",tParamName) = tAccum
					Set tAccum = ""
					Set tState = $$$PREARGUMENT
				} ElseIf (tState = $$$TRAILINGPARAMETERVALUE) {
					Set tAccum = tAccum_tChar
				}
				
				If '((tState = $$$MODIFIERVALUEQUOTED) || (tState = $$$PARAMETERVALUEQUOTED)) {
					Quit:(tChar="")
					Continue
				}
			} ElseIf (tChar = "-") {
				If (tState = $$$PREARGUMENT) {
					Set tState = $$$MODIFIERNAME
					Set tModifier = ""
					Continue
				} ElseIf ((tState = $$$PARAMETERVALUE) || (tState = $$$TRAILINGPARAMETERVALUE))
					&& $Get(tCommandStructure(pCommandInfo,"trailingModifiers")) {
						Set tParamName = $Get(tCommandStructure(pCommandInfo,"parameters",$i(tParamCount)))
						If (tParamName = "") {
							$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Too many parameters to command '%1'; only %2 expected.",pCommandInfo,tParamCount-1)))
						}
						If ($Extract(tAccum,*) = " ") {
							Set pCommandInfo("parameters",tParamName) = $Extract(tAccum,1,*-1) // Strip the space.
						} Else {
							Set pCommandInfo("parameters",tParamName) = tAccum
						}
						Set tAccum = ""
						Set tState = $$$MODIFIERNAME
						Set tModifier = ""
						Continue
					}
			} ElseIf (tChar = "\") {
				If (tState = $$$MODIFIERVALUEQUOTED) || (tState = $$$PARAMETERVALUEQUOTED) {
					Set tPreEscapeState = tState
					Set tState = $$$ESCAPECHAR
					Continue
				}
			} ElseIf (tChar = """") {
				If (tState = $$$PREARGUMENT) {
					Set tState = $$$PARAMETERVALUEQUOTED
					Continue
				} If (tState = $$$MODIFIERVALUE) && (tAccum = "") {
					Set tState = $$$MODIFIERVALUEQUOTED
					Continue
				} ElseIf (tState = $$$PARAMETERVALUE) && (tAccum = "") {
					Set tState = $$$PARAMETERVALUEQUOTED
					Continue
				} ElseIf (tState = $$$MODIFIERVALUEQUOTED) {
					If ($Get(tDataName) '= "") {
						Do ..SetData(.pCommandInfo,tDataName,tAccum)
					} Else {
						Set pCommandInfo("modifiers",tModifier) = tAccum
					}
					Set tAccum = ""
					Set tState = $$$PREARGUMENT
					Continue
				} ElseIf (tState = $$$PARAMETERVALUEQUOTED) {
					Set tParamName = $Get(tCommandStructure(pCommandInfo,"parameters",$i(tParamCount)))
					If (tParamName = "") {
						$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Too many parameters to command '%1'; only %2 expected.",pCommandInfo,tParamCount-1)))
					}
					Set pCommandInfo("parameters",tParamName) = tAccum
					Set tAccum = ""
					Set tState = $$$PREARGUMENT
					Continue
				}
			} ElseIf (tChar = "=") {
				If (tState = $$$DATANAME) {
					Set tDataName = tAccum
					Set tState = $$$MODIFIERVALUE
					Set tAccum = ""
					Continue
				}
			} Else {
				If (tState = $$$PREARGUMENT) {
					Set tParamName = $Get(tCommandStructure(pCommandInfo,"parameters",tParamCount+1))
					If (tParamName = "") {
						$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Too many parameters to command '%1'; only %2 expected.",pCommandInfo,tParamCount)))
					}
					If $Get(tCommandStructure(pCommandInfo,"parameters",tParamName,"trailing")) {
						Set tState = $$$TRAILINGPARAMETERVALUE
					} Else {
						Set tState = $$$PARAMETERVALUE
						Set tEndPos = $Locate(pCommandString, "\s", tPos)
						If (tEndPos > 0) {
							Set tAccum = tChar_ $Extract(pCommandString, tPos, tEndPos - 1)
						} Else {
							Set tAccum = tChar_ $Extract(pCommandString, tPos, *)
						}
						Set tPos = tEndPos
						Continue
					}
				} ElseIf (tState = $$$MODIFIERNAME) {
					Set tDataPrefix = $Get(tCommandStructure(pCommandInfo,"dataPrefix"))
					If (tAccum = "") && (tDataPrefix '= "") && (tChar = tDataPrefix) {
						Set tState = $$$DATANAME
						Set tDataName = ""
						Continue
					}
				}
			}
			
			If (tChar = "") {
				$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Invalid trailing input: %1",tAccum)))
			}
			
			// Default: accumulate
			Set tAccum = tAccum _ tChar
			
			If (tState = $$$ESCAPECHAR) {
				Set tState = tPreEscapeState
			}
		}
		
		// TODO: Extra validation.
	} Catch e {
		If e.%IsA("%Exception.SystemException") {
			Set tSC = $System.Status.EmbedStatus($$$ERROR($$$GeneralError,$$$FormatText("Error parsing command: %1",pCommandString)),e.AsStatus())
		} Else {
			Set tSC = e.AsStatus()
		}
	}
	Quit tSC
}

ClassMethod %GetCommandStructure(Output pCommandStructure) As %Status [ CodeMode = objectgenerator, Private ]
{
	Set tSC = $$$OK
	Try {
		Set tClassName = %classname

		#; Don't run on base class
		If (tClassName = "%ZPM.PackageManager.Developer.CLI") {
			Quit
		}

		#; Find named XDATA block
		If ##class(%Dictionary.CompiledXData).%ExistsId(tClassName_"||Commands") {
			Set tCompiledClass = ##class(%Dictionary.CompiledClass).%OpenId(tClassName,,.tSC)
			If '$IsObject(tCompiledClass)||$$$ISERR(tSC) Quit

			Set tIndex = tCompiledClass.XDatas.FindObjectId(tClassName_"||Commands")
			If (tIndex = "") {
				Set tSC = $$$ERROR($$$XDataBlockMissing,tClassName,"Commands")
				Quit
			}

			#; Get XDATA as stream
			Set tStream = tCompiledClass.XDatas.GetAt(tIndex).Data
			Do tStream.Rewind()

			#; Create an XML import handler ( use the internal handler )
			Set tHandler = ##class(%XML.ImportHandler).%New("CacheTemp",$$$IntHandler) 

			#; Create the Entity Resolver
			Set tResolver = ##class(%XML.SAX.XDataEntityResolver).%New(tClassName)

			#; Parse the XML data in the specfied stream
			Set tSC = ##Class(%XML.SAX.Parser).ParseStream(tStream,tHandler,tResolver,,,"Schema")
			If $$$ISERR(tSC) {
				Quit
			}
        
            #; Copy tree because handler will delete it's copy when it goes out of scope
            Merge tMap = ^CacheTemp(tHandler.Tree)
            
			If $Data(tMap("error"))||$Data(tMap("warning")) {
				Set tSC = $$$ERROR($$$GeneralError,"Could not parse Commands XData block.")
				For tType = "error","warning" {       
					Set tIndex = ""
					For {
						Set tIndex = $Order(tMap(tType,tIndex),1,tError)
						If (tIndex = "") {
							Quit
						}
						Set tSC = $$$ADDSC(tSC,$$$ERROR($$$GeneralError,tError))
					}
				}
				Quit
			}
			
			Do %code.WriteLine(" Kill pCommandStructure")
			
			Set tChild = ""
			For {
				Set tChild = $Order(tMap(1,"c",tChild))
				Quit:(tChild="")
				#Define empty """"""
				If (tMap(tChild) = "command") {
					Set tName = $$$QUOTE(tMap(tChild,"a","name"))
					Set tExample = $$$QUOTE($Get(tMap(tChild,"a","example")))
					If ($Get(tMap(tChild,"a","default")) = "true") {
						Do %code.WriteLine(" Set pCommandStructure(0,""default"") = "_tName)
					}
					If $Data(tMap(tChild,"a","aliases")) {
						Do %code.WriteLine(" Set pCommandStructure("_tName_",""aliases"") = "_$$$QUOTE(tMap(tChild,"a","aliases")))
						Set tAliasList = $ListFromString(tMap(tChild,"a","aliases"))
						Set tPtr = 0
						While $ListNext(tAliasList,tPtr,tAlias) {
							Do %code.WriteLine(" Set pCommandStructure(1,"_$$$QUOTE(tAlias)_") = "_tName)
						}
					}
					If $Data(tMap(tChild,"a","dataPrefix"),tDataPrefix) {
						Do %code.WriteLine(" Set pCommandStructure("_tName_",""dataPrefix"") = "_$$$QUOTE(tDataPrefix))
					}
					If $Data(tMap(tChild,"a","trailingModifiers"),tTrailingModifiers) {
						Do %code.WriteLine(" Set pCommandStructure("_tName_",""trailingModifiers"") = "_$Case(tTrailingModifiers,"true":1,:0))
					}
					
					// Children of command
					Set tCommChild = ""
					For {
						Set tCommChild = $Order(tMap(tChild,"c",tCommChild))
						Quit:(tCommChild="")
						
						Set tDesc = $$$QUOTE($Get(tMap(tCommChild,"a","description")))
						
						If (tMap(tCommChild) = "example") {
							Set tContentNode = $Order(tMap(tCommChild,"c",0))
							If (tContentNode '= "") {
								// Different version of $$$QUOTE to convert newlines into $c(10) (for example) - this is what zwrite calls.
								Set tExampleContent = $$Quote^%qcr($Replace($ZStrip(tMap(tContentNode),"<>C"),$c(10),$c(13,10)))
								Do %code.WriteLine(" Set pCommandStructure("_tName_",""examples"",$i(pCommandStructure("_tName_",""examples""))) = "_tExampleContent)
								Do:(tDesc'=$$$empty) %code.WriteLine(" Set pCommandStructure("_tName_",""examples"",pCommandStructure("_tName_",""examples""),""description"") = "_tDesc)
							}
						} ElseIf (tMap(tCommChild) = "description") {
							Set tContentNode = $Order(tMap(tCommChild,"c",0))
							If (tContentNode '= "") {
								// Different version of $$$QUOTE to convert newlines into $c(10) (for example) - this is what zwrite calls.
								Set tDescContent = $$Quote^%qcr($Replace($ZStrip(tMap(tContentNode),"<>C"),$c(10),$c(13,10)))
								Do %code.WriteLine(" Set pCommandStructure("_tName_",""description"") = "_tDescContent)
							}
						} Else {
							// Common: name, required, description
							Set tChildName = $$$QUOTE(tMap(tCommChild,"a","name"))
							Set tRequired = $Case($Get(tMap(tCommChild,"a","required")),"true":1,:0)
							
							If (tMap(tCommChild) = "modifier") {
								// Also: aliases, value, valueList
								Set tValue = $Get(tMap(tCommChild,"a","value"))
								Set tValueList = $$$QUOTE($Get(tMap(tCommChild,"a","valueList")))
								Set tDataAlias = $$$QUOTE($Get(tMap(tCommChild,"a","dataAlias")))
								Set tDataValue = $$$QUOTE($Get(tMap(tCommChild,"a","dataValue")))
								If $Data(tMap(tCommChild,"a","aliases")) {
									Do %code.WriteLine(" Set pCommandStructure("_tName_",""modifiers"","_tChildName_",""aliases"") = "_$$$QUOTE(tMap(tCommChild,"a","aliases")))
									Set tAliasList = $ListFromString(tMap(tCommChild,"a","aliases"))
									Set tPtr = 0
									While $ListNext(tAliasList,tPtr,tAlias) {
										Do %code.WriteLine(" Set pCommandStructure("_tName_",""modifiers"",1,"_$$$QUOTE(tAlias)_") = "_tChildName)
									}
								}
								Do %code.WriteLine(" Set pCommandStructure("_tName_",""modifiers"","_tChildName_",""value"") = "_$Case(tValue,"true":1,:0))
								Do %code.WriteLine(" Set pCommandStructure("_tName_",""modifiers"","_tChildName_",""required"") = "_tRequired)
								Do:(tDesc'=$$$empty) %code.WriteLine(" Set pCommandStructure("_tName_",""modifiers"","_tChildName_",""description"") = "_tDesc)
								Do:(tValueList'=$$$empty) %code.WriteLine(" Set pCommandStructure("_tName_",""modifiers"","_tChildName_",""valueList"") = "_tValueList)
								Do:(tDataAlias'=$$$empty) %code.WriteLine(" Set pCommandStructure("_tName_",""modifiers"","_tChildName_",""dataAlias"") = "_tDataAlias)
								Do:(tDataValue'=$$$empty) %code.WriteLine(" Set pCommandStructure("_tName_",""modifiers"","_tChildName_",""dataValue"") = "_tDataValue)
							} ElseIf (tMap(tCommChild) = "parameter") {
								// Also: example
								Set tExample = $$$QUOTE($Get(tMap(tCommChild,"a","example")))
								Set tTrailing = $Case($Get(tMap(tCommChild,"a","trailing")),"true":1,:0)
								Do %code.WriteLine(" Set pCommandStructure("_tName_",""parameters"",$i(pCommandStructure("_tName_",""parameters""))) = "_tChildName)
								Do %code.WriteLine(" Set pCommandStructure("_tName_",""parameters"","_tChildName_",""trailing"") = "_tTrailing)
								Do %code.WriteLine(" Set pCommandStructure("_tName_",""parameters"","_tChildName_",""required"") = "_tRequired)
								Do:(tDesc'=$$$empty) %code.WriteLine(" Set pCommandStructure("_tName_",""parameters"","_tChildName_",""description"") = "_tDesc)
								Do:(tExample'=$$$empty) %code.WriteLine(" Set pCommandStructure("_tName_",""parameters"","_tChildName_",""example"") = "_tExample)
							}
						}
					}
				}
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()  
	}
	Quit tSC
}

/// Utility method for setting multiple subscripts based on .-delimited <var>pDataName</var>
ClassMethod SetData(pTargetArray, pDataName, pDataValue) [ Private ]
{
	Set tPieces = $ListFromString(pDataName,".")
	Set tValue = pDataValue
	For i=$ListLength(tPieces):-1:1 {
		Kill tData
		Merge tData($ListGet(tPieces,i)) = tValue
		Kill tValue
		Merge tValue = tData
	}
	Merge pTargetArray("data") = tValue
}

}
