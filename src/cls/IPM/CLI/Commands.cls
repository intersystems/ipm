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

<!-- A parameter is a space-delimited string provided to a command without a modifier. These appear in order at the end of the command. -->
<xs:element name="parameter">
  <xs:complexType>
    <!-- Parameter name -->
    <xs:attribute name="name" type="string" use="required"/>

    <!-- Parameter required? -->
    <xs:attribute name="required" type="xs:boolean" use="optional" default="false"/>

    <!-- Whether the parameter is deprecated -->
    <xs:attribute name="deprecated" type="xs:boolean" use="optional" default="false"/>

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

<!-- Modifier required -->
<xs:attribute name="required" type="xs:boolean" use="optional" default="false"/>

<!-- Whether the modifier is deprecated -->
<xs:attribute name="deprecated" type="xs:boolean" use="optional" default="false"/>

<!-- Comma-separated list of aliases -->
<xs:attribute name="aliases" type="string" use="optional"/>

<!-- If true, the modifier name is followed in the command string by a value -->
<xs:attribute name="value" type="xs:boolean" use="optional" default="false"/>

<!-- Description of the modifier -->
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

/// Turns the Command XData block into a subscripted array as follows:
/// pCommandStructure(1, "<alias>") = "<command name>"
/// pCommandStructure("<command-name>") ->
/// 		"description" = describes the command
/// 		"groups","-":
/// 			"modifiers","<modifier-num>" = "<modifier-name>"
/// 			"examples","<example-number>" = "<example-command
/// 				"description" = description of example command
/// 		"modifiers":
/// 			"1","<modifier-alias>" = "<modifier-name>"
/// 			"<modifier-name>":
/// 				"aliases" = aliases for the modifier
/// 				"description" = describes the modifier
/// 				"required" = whether or not modifier is required for the command
/// 				"deprecated" = whether or not modifier is deprecated for the command
/// 				"trailing" = whether modifier is a trailing modifier
/// 		"parameters":
/// 			"<parameter>":
/// 				"description" = description of parameter
/// 				"required" = is parameter required
/// 				"deprecated" = whether or not parameter is deprecated for the command
ClassMethod %GetOneCommandStructure(Output pCommandStructure) [ CodeMode = objectgenerator ]
{
    #define DefaultGroup "-"

    set tSC = $$$OK
    try {
        set tClassName = %classname

        #; Don't run on base class
        if (tClassName = "%IPM.CLI") {
            quit
        }

        #; Find named XDATA block
        if ##class(%Dictionary.CompiledXData).%ExistsId(tClassName_"||Commands") {
            set tCompiledClass = ##class(%Dictionary.CompiledClass).%OpenId(tClassName,,.tSC)
            if '$isobject(tCompiledClass)||$$$ISERR(tSC) quit

            set tIndex = tCompiledClass.XDatas.FindObjectId(tClassName_"||Commands")
            if (tIndex = "") {
                set tSC = $$$ERROR($$$XDataBlockMissing,tClassName,"Commands")
                quit
            }

            #; Get XDATA as stream
            set tStream = tCompiledClass.XDatas.GetAt(tIndex).Data
            do tStream.Rewind()

            #; Create an XML import handler ( use the internal handler )
            set tHandler = ##class(%XML.ImportHandler).%New("CacheTemp",$$$IntHandler)

            #; Create the Entity Resolver
            set tResolver = ##class(%XML.SAX.XDataEntityResolver).%New(tClassName)

            #; Parse the XML data in the specfied stream
            set tSC = ##Class(%XML.SAX.Parser).ParseStream(tStream,tHandler,tResolver,,,"Schema")
            if $$$ISERR(tSC) {
                quit
            }

            #; Copy tree because handler will delete it's copy when it goes out of scope
            merge tMap = ^CacheTemp(tHandler.Tree)

            if $data(tMap("error"))||$data(tMap("warning")) {
                set tSC = $$$ERROR($$$GeneralError,"Could not parse Commands XData block.")
                for tType = "error","warning" {
                    set tIndex = ""
                    for {
                        set tIndex = $order(tMap(tType,tIndex),1,tError)
                        if (tIndex = "") {
                            quit
                        }
                        set tSC = $$$ADDSC(tSC,$$$ERROR($$$GeneralError,tError))
                    }
                }
                quit
            }

            do %code.WriteLine(" Kill pCommandStructure")
            // Compute the max length of a command. Used for pretty printing in %Help
            set tMaxLengthCommand = 0
            set tChild = ""
            for {
                set tChild = $order(tMap(1,"c",tChild))
                quit:(tChild="")
                #Define empty """"""
                if (tMap(tChild) = "command") {
                    set tName = tMap(tChild,"a","name")
                    if ($length(tName) > tMaxLengthCommand) {
                        set tMaxLengthCommand = $length(tName)
                    }
                    set tName = $$$QUOTE(tName)
                    set tExample = $$$QUOTE($get(tMap(tChild,"a","example")))
                    if ($get(tMap(tChild,"a","default")) = "true") {
                        do %code.WriteLine(" Set pCommandStructure(0,""default"") = "_tName)
                    }
                    if $data(tMap(tChild,"a","aliases")) {
                        do %code.WriteLine(" Set pCommandStructure("_tName_",""aliases"") = "_$$$QUOTE(tMap(tChild,"a","aliases")))
                        set tAliasList = $listfromstring(tMap(tChild,"a","aliases"))
                        set tPtr = 0
                        while $listnext(tAliasList,tPtr,tAlias) {
                            do %code.WriteLine(" Set pCommandStructure(1,"_$$$QUOTE(tAlias)_") = "_tName)
                        }
                    }
                    if $data(tMap(tChild,"a","dataPrefix"),tDataPrefix) {
                        do %code.WriteLine(" Set pCommandStructure("_tName_",""dataPrefix"") = "_$$$QUOTE(tDataPrefix))
                    }
                    if $data(tMap(tChild,"a","trailingModifiers"),tTrailingModifiers) {
                        do %code.WriteLine(" Set pCommandStructure("_tName_",""trailingModifiers"") = "_$case(tTrailingModifiers,"true":1,:0))
                    }

                    // Children of command
                    set tCommChildOne = ""
                    for {
                        set tCommChildOne = $order(tMap(tChild,"c",tCommChildOne))
                        quit:(tCommChildOne="")

                        set tCommChildList = $listbuild(tCommChildOne)
                        set tGroupName = $$$DefaultGroup
                        if (tMap(tCommChildOne) = "group") {
                        set tCommChildList = ""
                        set tGroupChild = ""
                        set tGroupName = $get(tMap(tCommChildOne,"a","name"))
                        for {
                            set tGroupChild = $order(tMap(tCommChildOne, "c", tGroupChild))
                            quit:(tGroupChild="")
                            set tCommChildList = tCommChildList _ $listbuild(tGroupChild)
                        }
                        }
                        set tGroupName = $$$QUOTE(tGroupName)

                        set ptr = 0
                        while $listnext(tCommChildList, ptr, tCommChild) {
                            set tDesc = $$$QUOTE($get(tMap(tCommChild,"a","description")))

                            if (tMap(tCommChild) = "example") {
                                set tContentNode = $order(tMap(tCommChild,"c",0))
                                if (tContentNode '= "") {
                                    // Different version of $$$QUOTE to convert newlines into $c(10) (for example) - this is what zwrite calls.
                                    set tExampleContent = $$Quote^%qcr($replace($zstrip(tMap(tContentNode),"<>C"),$char(10),$char(13,10)))
                                    if 0,(tGroupName = $$$QUOTE($$$DefaultGroup)) {
                                        do %code.WriteLine(" Set pCommandStructure("_tName_",""examples"",$i(pCommandStructure("_tName_",""examples""))) = "_tExampleContent)
                                        do:(tDesc'=$$$empty) %code.WriteLine(" Set pCommandStructure("_tName_",""examples"",pCommandStructure("_tName_",""examples""),""description"") = "_tDesc)
                                    } else {
                                        do %code.WriteLine(" Set tExampleIndex = $i(pCommandStructure("_tName_",""groups"","_tGroupName_",""examples""))")
                                        do %code.WriteLine(" Set pCommandStructure("_tName_",""groups"","_tGroupName_",""examples"",tExampleIndex) = "_tExampleContent)
                                        do:(tDesc'=$$$empty) %code.WriteLine(" Set pCommandStructure("_tName_",""groups"","_tGroupName_",""examples"",tExampleIndex,""description"") = "_tDesc)
                                    }
                                }
                            } elseif (tMap(tCommChild) = "description") || (tMap(tCommChild) = "summary") {
                                set tContentNode = $order(tMap(tCommChild,"c",0))
                                if (tContentNode '= "") {
                                    // Different version of $$$QUOTE to convert newlines into $c(10) (for example) - this is what zwrite calls.
                                    set tDescContent = $$Quote^%qcr($replace($zstrip(tMap(tContentNode),"<>C"),$char(10),$char(13,10)))
                                    do %code.WriteLine(" Set pCommandStructure("_tName_","_$$$QUOTE(tMap(tCommChild))_") = "_tDescContent)
                                }
                            } else {
                                // Common to both modifier and parameter
                                set tChildName = $$$QUOTE(tMap(tCommChild,"a","name"))
                                set tRequired = $case($get(tMap(tCommChild,"a","required")),"true":1,:0)
                                set tDeprecated = $case($get(tMap(tCommChild,"a","deprecated")),"true":1,:0)

                                if (tMap(tCommChild) = "modifier") {
                                    // Also: aliases, value, valueList
                                    set tValue = $get(tMap(tCommChild,"a","value"))
                                    set tValueList = $$$QUOTE($get(tMap(tCommChild,"a","valueList")))
                                    set tDataAlias = $$$QUOTE($get(tMap(tCommChild,"a","dataAlias")))
                                    set tDataValue = $$$QUOTE($get(tMap(tCommChild,"a","dataValue")))
                                    if $data(tMap(tCommChild,"a","aliases")) {
                                        do %code.WriteLine(" Set pCommandStructure("_tName_",""modifiers"","_tChildName_",""aliases"") = "_$$$QUOTE(tMap(tCommChild,"a","aliases")))
                                        set tAliasList = $listfromstring(tMap(tCommChild,"a","aliases"))
                                        set tPtr = 0
                                        while $listnext(tAliasList,tPtr,tAlias) {
                                        do %code.WriteLine(" Set pCommandStructure("_tName_",""modifiers"",1,"_$$$QUOTE(tAlias)_") = "_tChildName)
                                        }
                                    }
                                    do %code.WriteLine(" Set pCommandStructure("_tName_",""groups"","_tGroupName_",""modifiers"","_tCommChild_") = " _ tChildName)
                                    do %code.WriteLine(" Set pCommandStructure("_tName_",""modifiers"","_tChildName_",""group"") = "_tGroupName)
                                    do %code.WriteLine(" Set pCommandStructure("_tName_",""modifiers"","_tChildName_",""value"") = "_$case(tValue,"true":1,:0))
                                    do %code.WriteLine(" Set pCommandStructure("_tName_",""modifiers"","_tChildName_",""required"") = "_tRequired)
                                    do %code.WriteLine(" Set pCommandStructure("_tName_",""modifiers"","_tChildName_",""deprecated"") = "_tDeprecated)
                                    do:(tDesc'=$$$empty) %code.WriteLine(" Set pCommandStructure("_tName_",""modifiers"","_tChildName_",""description"") = "_tDesc)
                                    do:(tValueList'=$$$empty) %code.WriteLine(" Set pCommandStructure("_tName_",""modifiers"","_tChildName_",""valueList"") = "_tValueList)
                                    do:(tDataAlias'=$$$empty) %code.WriteLine(" Set pCommandStructure("_tName_",""modifiers"","_tChildName_",""dataAlias"") = "_tDataAlias)
                                    do:(tDataValue'=$$$empty) %code.WriteLine(" Set pCommandStructure("_tName_",""modifiers"","_tChildName_",""dataValue"") = "_tDataValue)
                                } elseif (tMap(tCommChild) = "parameter") {
                                    // Also: example
                                    set tExample = $$$QUOTE($get(tMap(tCommChild,"a","example")))
                                    set tTrailing = $case($get(tMap(tCommChild,"a","trailing")),"true":1,:0)
                                    do %code.WriteLine(" Set pCommandStructure("_tName_",""parameters"",$i(pCommandStructure("_tName_",""parameters""))) = "_tChildName)
                                    do %code.WriteLine(" Set pCommandStructure("_tName_",""parameters"","_tChildName_",""trailing"") = "_tTrailing)
                                    do %code.WriteLine(" Set pCommandStructure("_tName_",""parameters"","_tChildName_",""required"") = "_tRequired)
                                    do %code.WriteLine(" Set pCommandStructure("_tName_",""parameters"","_tChildName_",""deprecated"") = "_tDeprecated)
                                    do:(tDesc'=$$$empty) %code.WriteLine(" Set pCommandStructure("_tName_",""parameters"","_tChildName_",""description"") = "_tDesc)
                                    do:(tExample'=$$$empty) %code.WriteLine(" Set pCommandStructure("_tName_",""parameters"","_tChildName_",""example"") = "_tExample)
                                }
                            }
                        }
                    }
                }
            }
            do %code.WriteLine(" Set pCommandStructure(-1, ""maxLength"") = "_tMaxLengthCommand)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

}
