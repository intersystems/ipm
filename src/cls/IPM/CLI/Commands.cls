IncludeGenerator %occSAX

Class %IPM.CLI.Commands
{

/// Name of include file that will contain accessor macros for modifiers
/// and parameters referenced in the "Commands" XData block. <br />
/// If provided, an include file will be generated and included in the sub-class
/// during compilation. <br />
/// @API.Parameter
/// @API.Overrideable
Parameter CommandsAccessorIncludeFilename As STRING;

/// Description of commands to use for this CLI
XData Commands [ XMLNamespace = "http://www.intersystems.com/PackageManager/CLI" ]
{
<?xml version="1.0"?>
<commands>
</commands>
}

/// This is the Schema which defines the form of the Commands XData block
XData Schema [ Internal, MimeType = application/xml ]
{
<?xml version="1.0"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">

<xs:element name="commands">
<xs:complexType>
<xs:choice minOccurs="0" maxOccurs="unbounded">

<xs:element name="command">
<xs:complexType>
<xs:choice minOccurs="0" maxOccurs="unbounded">

<!-- A modifier is a flag that controls the behavior of the command. -->
<xs:element name="modifier" type="modifier"/>

<!-- A group contains command modifiers that have specific usage. -->
<xs:element name="group" type="group"/>

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
<xs:element name="description" type="description" minOccurs="1" maxOccurs="1" />

<!-- Summary of command -->
<xs:element name="summary" type="description" />
</xs:choice>

<!-- Name of the command -->
<xs:attribute name="name" type="string" use="required"/>

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


<!-- A modifier is a flag that controls the behavior of the command. -->
<xs:complexType name="modifier">
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

<!-- Group controls the domain of functionality that some modifiers belong to, for example: modifiers for 'repo' command that is used for remote repository -->
<xs:complexType name="group">
<xs:choice minOccurs="0" maxOccurs="unbounded">
<xs:element name="modifier" type="modifier"/>
<xs:element name="example" type="example"/>
</xs:choice>
<xs:attribute name="name" type="string" use="required"/>
</xs:complexType>

<!-- example element with content -->
<xs:complexType name="example">
<xs:simpleContent>
<xs:extension base="string">
<xs:attribute name="description" type="string" use="required" />
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

ClassMethod %GetOneCommandStructure(Output pCommandStructure) [ CodeMode = objectgenerator ]
{
  #define DefaultGroup "-"

	Set tSC = $$$OK
	Try {
		Set tClassName = %classname

		#; Don't run on base class
		If (tClassName = "%IPM.CLI") {
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
			// Compute the max length of a command. Used for pretty printing in %Help
			Set tMaxLengthCommand = 0
			Set tChild = ""
			For {
				Set tChild = $Order(tMap(1,"c",tChild))
				Quit:(tChild="")
				#Define empty """"""
				If (tMap(tChild) = "command") {
					Set tName = tMap(tChild,"a","name")
					If ($Length(tName) > tMaxLengthCommand) {
						Set tMaxLengthCommand = $Length(tName)
					}
					Set tName = $$$QUOTE(tName)
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
					Set tCommChildOne = ""
					For {
						Set tCommChildOne = $Order(tMap(tChild,"c",tCommChildOne))
						Quit:(tCommChildOne="")

            Set tCommChildList = $ListBuild(tCommChildOne)
            Set tGroupName = $$$DefaultGroup
            If (tMap(tCommChildOne) = "group") {
              Set tCommChildList = ""
              Set tGroupChild = ""
              Set tGroupName = $Get(tMap(tCommChildOne,"a","name"))
              For {
                Set tGroupChild = $Order(tMap(tCommChildOne, "c", tGroupChild))
                Quit:(tGroupChild="")
                Set tCommChildList = tCommChildList _ $ListBuild(tGroupChild)
              }
            }
            Set tGroupName = $$$QUOTE(tGroupName)
						
            Set ptr = 0
            While $ListNext(tCommChildList, ptr, tCommChild) {
              Set tDesc = $$$QUOTE($Get(tMap(tCommChild,"a","description")))
              
              If (tMap(tCommChild) = "example") {
                Set tContentNode = $Order(tMap(tCommChild,"c",0))
                If (tContentNode '= "") {
                  // Different version of $$$QUOTE to convert newlines into $c(10) (for example) - this is what zwrite calls.
                  Set tExampleContent = $$Quote^%qcr($Replace($ZStrip(tMap(tContentNode),"<>C"),$Char(10),$Char(13,10)))
                  If 0,(tGroupName = $$$QUOTE($$$DefaultGroup)) {
                    Do %code.WriteLine(" Set pCommandStructure("_tName_",""examples"",$i(pCommandStructure("_tName_",""examples""))) = "_tExampleContent)
                    Do:(tDesc'=$$$empty) %code.WriteLine(" Set pCommandStructure("_tName_",""examples"",pCommandStructure("_tName_",""examples""),""description"") = "_tDesc)
                  } Else {
                    Do %code.WriteLine(" Set tExampleIndex = $i(pCommandStructure("_tName_",""groups"","_tGroupName_",""examples""))")
                    Do %code.WriteLine(" Set pCommandStructure("_tName_",""groups"","_tGroupName_",""examples"",tExampleIndex) = "_tExampleContent)
                    Do:(tDesc'=$$$empty) %code.WriteLine(" Set pCommandStructure("_tName_",""groups"","_tGroupName_",""examples"",tExampleIndex,""description"") = "_tDesc)
                  }
                }
              } ElseIf (tMap(tCommChild) = "description") || (tMap(tCommChild) = "summary") {
                Set tContentNode = $Order(tMap(tCommChild,"c",0))
                If (tContentNode '= "") {
                  // Different version of $$$QUOTE to convert newlines into $c(10) (for example) - this is what zwrite calls.
								Set tDescContent = $$Quote^%qcr($Replace($ZStrip(tMap(tContentNode),"<>C"),$Char(10),$Char(13,10)))
								Do %code.WriteLine(" Set pCommandStructure("_tName_","_$$$QUOTE(tMap(tCommChild))_") = "_tDescContent)
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
                  Do %code.WriteLine(" Set pCommandStructure("_tName_",""groups"","_tGroupName_",""modifiers"","_tCommChild_") = " _ tChildName)
                  Do %code.WriteLine(" Set pCommandStructure("_tName_",""modifiers"","_tChildName_",""group"") = "_tGroupName)
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
			Do %code.WriteLine(" Set pCommandStructure(-1, ""maxLength"") = "_tMaxLengthCommand)
		}
	} Catch e {
		Set tSC = e.AsStatus()  
	}
	Quit tSC
}

}
