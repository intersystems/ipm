Include (%occSAX, %syGluedef, %IPM.Formatting)

Class %IPM.CLI Extends %IPM.CLI.Commands
{

/// Name of include file that will contain accessor macros for modifiers
/// and parameters referenced in the "Commands" XData block. <br />
/// If provided, an include file will be generated and included in the sub-class
/// during compilation. <br />
/// @API.Parameter
/// @API.Overrideable
Parameter CommandsAccessorIncludeFilename As STRING;

/// Displays help for a given command
ClassMethod %Help(ByRef pCommandInfo) [ Final ]
{
    set tCommand = $get(pCommandInfo("parameters","command"))
    set tVerbose = ''$data(pCommandInfo("modifiers","verbose"))
    set tMarkdown = ''$data(pCommandInfo("modifiers","markdown"))
    if (tMarkdown) {
        // Force verbose for markdown because summary mode not supported
        set tVerbose = 1
    }
    do ..%GetCommandStructure(.tCommandStruct)

    if (tCommand '= "") && '$data(tCommandStruct(tCommand)) {
        // See if it's an alias. (If not, we'll show help for everything.)
        if '$data(tCommandStruct(1,tCommand),tCommand) {
            write !, $$$FormattedLine($$$Red, "WARNING: Command "_$$$QUOTE(tCommand)_" does not exist so showing all available commands.")
            write !
        }
    }

    // Single command
    if (tCommand '= "") && (tCommand '= +tCommand) && $data(tCommandStruct(tCommand)) {
        kill tOneCommandStruct
        merge tOneCommandStruct = tCommandStruct(tCommand)
        set phases = $select(tCommand = "module-action":##class(%IPM.Main).#STANDARDPHASES,1:$listbuild("module-action"))
        if ((tCommand = "module-action") || ($listfind(##class(%IPM.Main).#STANDARDPHASES,tCommand))) {
            do ..UnifyLifecycles(.tOneCommandStruct,.tCommandStruct,phases)
        }
        do ..%HelpForCommand(tCommand,.tOneCommandStruct,1,tMarkdown)
    } else {
        // For markdown mode only, merge aliases into main part of tCommandStruct array.
        // This gets the commands in alphabetical order.
        if tMarkdown {
            set tCommand = ""
            for {
                set tCommand = $order(tCommandStruct(1,tCommand))
                if (tCommand = "") {
                    quit
                }
                set tCommandStruct(tCommand) = tCommandStruct(1,tCommand)
            }
        }

        // List commands
        if 'tMarkdown {
            write !, $$$FormattedLine($$$Underlined, "Available commands:")
            write !
        }
        set tCommand = ""
        while 1 {
            set tCommand = $order(tCommandStruct(tCommand))
            if (tCommand = "") {
                quit
            }
            // Skip numbered subscripts.
            if (tCommand = +tCommand) {
                continue
            }

            kill tOneCommandStruct
            merge tOneCommandStruct = tCommandStruct(tCommand)
            set phases = $select(tCommand = "module-action":##class(%IPM.Main).#STANDARDPHASES,1:$listbuild("module-action"))
            if ((tCommand = "module-action") || ($listfind(##class(%IPM.Main).#STANDARDPHASES,tCommand))) {
                do ..UnifyLifecycles(.tOneCommandStruct,.tCommandStruct,phases)
            }
            do ..%HelpForCommand(tCommand,.tOneCommandStruct,tVerbose,tMarkdown,$get(tCommandStruct(-1, "maxLength"),0))

            write !
        }

        if 'tVerbose {
            write !, "For more detail, run:", !?2, "help <command-name>", !, "or", !?2, "help -v"
        }
    }
    write !
}

ClassMethod UnifyLifecycles(
	ByRef tOneCommandStruct,
	ByRef tCommandStruct,
	phases As %List)
{
    set ptr = 0
    while $listnext(phases, ptr, currPhase) {
        set key = $order(tCommandStruct(currPhase,"groups","-","modifiers",""),1,modifier)
        while (key'="") {
            if ('$data(tOneCommandStruct("modifiers",modifier))) {
                // Modifier is not present yet
                set tOneCommandStruct("groups","-","modifiers",key) = modifier
                merge tOneCommandStruct("modifiers",modifier) = tCommandStruct(currPhase,"modifiers",modifier)
            }
            set key = $order(tCommandStruct(currPhase,"groups","-","modifiers",key),1,modifier)
        }
    }
}

ClassMethod %HelpForCommand(
	pCommandName As %String,
	ByRef pCommandStruct,
	pDetailed As %Boolean = 0,
	pMarkdownFormat As %Boolean = 0,
	pMaxLength As %Integer = 0)
{
    /// Section separator in Markdown
    #define SectionSeparator $Case(pMarkdownFormat, 1: "-----", : "")
    // Macro to escape if in markdown
    #define Escape(%string) $Select(pMarkdownFormat:$Replace(%string,"[","\["),1:%string)
    // Macro to format strings if printing to terminal and to escape if in markdown
    #define EscapeOrFormat(%string, %format) $Case(pMarkdownFormat, 1:$Replace(%string, "[", "\["), :$$$FormattedLine(%format, %string))
    // Bullet point if in Terminal
    #define BulletPoint $Case(pMarkdownFormat, 1: "", :$Char(9675)_" ")
    // Black square if in Terminal
    #define BlackSquare $Case(pMarkdownFormat, 1: "", :$Char(9632)_" ")

    #define DefaultGroup "-"

    #define Indent 4

    set tIsAlias = $data(pCommandStruct)<10
    if pMarkdownFormat && tIsAlias {
        write !, "----", !, "h2. ", pCommandName
        write !, "_Alias for [", pCommandStruct, "|#", pCommandStruct, "]_"
        write !, $$$SectionSeparator
    }

    // Don't show full documentation for aliases
    if tIsAlias {
        return
    }

    if ('pDetailed) {
        set tIndent = 10
        if (pMaxLength > tIndent) {
            // Do twice max length to account for aliases (which are usually shorter so this should be sufficient)
            set tIndent = 2 * pMaxLength + 2
        }
        // Command name and aliases
        write pCommandName
        if $data(pCommandStruct("aliases"), tAliases) {
            write ", "_$replace(tAliases, ",", ", ")
        }
        // Summary
        if $data(pCommandStruct("summary"), tSummary) {
            write ?tIndent, $zstrip(tSummary, "<>CW")
        } elseif $data(pCommandStruct("description"), tDescription) {
            write ?tIndent, $zstrip(tDescription, "<>CW")
        }
        quit
    }

    write !, $select(pMarkdownFormat:"----",1:""), !
    if pMarkdownFormat {
        write "h2. "
    }
    write $$$EscapeOrFormat(pCommandName, ..TerminalPromptColor())

    if pMarkdownFormat {
        write !, "Syntax: {{", pCommandName
    }

    if $data(pCommandStruct("modifiers")) && '$get(pCommandStruct("trailingModifiers"),0) {
        write $$$EscapeOrFormat(" [flags]", ..TerminalPromptColor())
    }

    if $data(pCommandStruct("parameters")) {
        set tKey = ""
        set tEndingBrackets = 0
        while 1 {
            set tKey = $order(pCommandStruct("parameters",tKey),1,tParamName)
            // Only deal with ordered parameters, not named
            if (tKey = "") || (tKey '= +tKey) {
                quit
            }

            write " "
            // Non-required parameters are surrounded with [] brackets
            if 'pCommandStruct("parameters", tParamName, "required") {
                write $$$EscapeOrFormat("[", ..TerminalPromptColor())
                set tEndingBrackets = tEndingBrackets + 1
            }
            write $$$EscapeOrFormat("<"_tParamName_">", ..TerminalPromptColor())
        }

        for i=1:1:tEndingBrackets {
            write $$$EscapeOrFormat("]", ..TerminalPromptColor())
        }
    }

    if $data(pCommandStruct("modifiers")) && $get(pCommandStruct("trailingModifiers"),0) {
        write $$$EscapeOrFormat(" [flags]", ..TerminalPromptColor())
    }

    if pMarkdownFormat {
        write "}}"
    }

    if $data(pCommandStruct("aliases"), tAliases) {
        write !, ?$$$Indent, $$$BlackSquare_"Alias"_$case($length(tAliases, ","), 1:"", :"es")_": "_$replace(tAliases, ",", ", ")
    }

    if $data(pCommandStruct("description"), tDescription) {
        write !, ?$$$Indent, $$$BlackSquare_"Description: "_tDescription
    }
    do ..%HelpForCommandDetails(.pCommandStruct, pMarkdownFormat)
}

ClassMethod %HelpForCommandDetails(
	ByRef pCommandStruct,
	pMarkdownFormat As %Boolean = 0) [ Internal ]
{
    do ..%HelpForCommandParameters(.pCommandStruct, pMarkdownFormat)
    do ..%HelpForCommandModifiers(.pCommandStruct, pMarkdownFormat)
    do ..%HelpForCommandExamples(.pCommandStruct, pMarkdownFormat)

    quit

    // Examples
    if $data(pCommandStruct("examples")) {

    }
}

ClassMethod %HelpForCommandParameters(
	ByRef pCommandStruct,
	pMarkdownFormat As %Boolean = 0) [ Internal ]
{
    if ('$data(pCommandStruct("parameters"))) {
        quit
    }

    write !!
    if (pMarkdownFormat) {
        write "h3."
    } else {
        write ?$$$Indent
    }
    write $$$BlackSquare_"Arguments"
    if pMarkdownFormat {
        write !,"||Name||Description||"
      }
      set tKey = ""
      for {
        set tKey = $order(pCommandStruct("parameters",tKey),1,tParamName)
        quit:(tKey="")
        quit:(tKey'=+tKey) //Only deal with ordered parameters, not named

        write !
        if pMarkdownFormat {
              write "|"
        } else {
              write ?($$$Indent*2)
        }
        write $$$BulletPoint_tParamName
        if pMarkdownFormat {
              write " |"
        }

        kill tParamInfo merge tParamInfo = pCommandStruct("parameters",tParamName)
        if ($data(tParamInfo("description"), tDescription)) {
              write ": "_tDescription
        }
        if pMarkdownFormat {
              write " |"
        }
      }
}

ClassMethod %HelpForCommandModifiers(
	ByRef pCommandStruct,
	pMarkdownFormat As %Boolean = 0) [ Internal ]
{
    if ('$data(pCommandStruct("groups"))) {
        quit
    }
    set tGroupName = ""
    for {
        set tGroupName = $order(pCommandStruct("groups", tGroupName))
        quit:tGroupName=""
        write !!
        if (pMarkdownFormat) {
            write "h3."
        } else {
            write ?$$$Indent
        }
        if (tGroupName = $$$DefaultGroup) {
            write $$$BlackSquare _ "Flags:"
        } else {
            write $$$BlackSquare _ tGroupName _ ":"
        }
        if pMarkdownFormat {
            write !, "||Flag||Description||Aliases||"
        }
        set tKeyId = ""
        while 1 {
            set tKeyId = $order(pCommandStruct("groups", tGroupName, "modifiers", tKeyId), 1, tKey)
            if (tKeyId = "") {
                quit
            }

            write !
            if pMarkdownFormat {
                write "|"
            } else {
                write ?($$$Indent*2)
            }
            write $$$BulletPoint_"-"_tKey

            kill tModInfo
            merge tModInfo = pCommandStruct("modifiers",tKey)
            if ($data(tModInfo("aliases"),tAliases)) {
                write ", -", $replace(tAliases,",",", -")
            }
            if $get(tModInfo("value")) {
                if $data(tModInfo("valueList"),tValueList) {
                    write " <",$replace(tValueList,",","/"),">"
                } else {
                    write " <value>"
                }
            }
            if pMarkdownFormat {
                write " |"
            }
            if ($data(tModInfo("description"),tDescription)) {
                write " : "_tDescription
            }
            if pMarkdownFormat {
                write " |"
            }
        }
        merge tGroupStruct = pCommandStruct("groups", tGroupName)
        do ..%HelpForCommandExamples(.tGroupStruct, pMarkdownFormat)
    }
}

ClassMethod %HelpForCommandExamples(
	ByRef pCommandStruct,
	pMarkdownFormat As %Boolean = 0) [ Internal ]
{
    if ('$data(pCommandStruct("examples"))) {
        quit
    }

    write !!
    if (pMarkdownFormat) {
        write "h3."
    } else {
        write ?$$$Indent
    }
    write $$$BlackSquare_"Examples"
    if pMarkdownFormat {
        write !,"||Command||Description||"
    }
    set tKey = ""
    for {
        set tKey = $order(pCommandStruct("examples",tKey))
        if (tKey = "") {
            quit
        }

        write !
        if pMarkdownFormat {
            write "|{{"
        } else {
            write ?($$$Indent*2)
        }
        write $$$BulletPoint_pCommandStruct("examples",tKey)
        if pMarkdownFormat {
            write "}}|"
        } else {
            write ?($$$Indent*2)
        }
        if $data(pCommandStruct("examples",tKey,"description"),tDesc) {
            if 'pMarkdownFormat {
                write !, ?($$$Indent*3)
            }
            write tDesc
        } else {
            if 'pMarkdownFormat {
                write !, ?($$$Indent*2)
            }
        }
        if pMarkdownFormat {
            write " |"
        }
    }
}

/// Parses a command, validating it based on the Commands XData block and structuring output as follows:
/// pCommandInfo = "<command name>"
/// pCommandInfo("modifiers","<modifier-name>") = "<modifier-value>"
/// pCommandInfo("parameters","<parameter-name>") = "<parameter-value>"
/// pCommandInfo("data","<data-name>") = "<data-value>"
ClassMethod %ParseCommandInput(
	pCommandString As %String,
	Output pCommandInfo) As %Status [ Final ]
{
    set tSC = $$$OK
    kill pCommandInfo
    try {
        do ..%GetCommandStructure(.tCommandStructure)

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

        set tState = $$$COMMAND
        set tPos = 1
        set tAccum = ""
        set tModifier = ""
        set tDataName = ""
        set tParamCount = 0
        set tIsCustomData = 0
        set tPreEscapeState = ""
        for {
            set tChar = $extract(pCommandString,tPos)
            set tPos = tPos + 1

            if (tState = $$$ESCAPECHAR) {
                if (tChar '= """") && (tChar '= "\") {
                    set tAccum = tAccum_"\"
                }
            }

            if (tChar = " ") || (tChar = "") {
                if (tState = $$$COMMAND) && (tAccum'="") {
                    if $data(tCommandStructure(tAccum)) {
                        // tAccum contains command name.
                        set pCommandInfo = tAccum
                    } elseif $data(tCommandStructure(1,tAccum),tAliasFor) {
                        // tAccum contains an alias - use the real name.
                        set pCommandInfo = tAliasFor
                    } elseif $data(tCommandStructure(0,"default"),tDefaultCommand) {
                        // tAccum just got the first parameter, so pass it along to the default command.
                        set pCommandInfo = tDefaultCommand
                        set tParamName = $get(tCommandStructure(tDefaultCommand,"parameters",$increment(tParamCount)))
                        if (tParamName = "") {
                            $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Too many parameters to command '%1'; only %2 expected.",pCommandInfo,tParamCount-1)))
                        }
                        set pCommandInfo("parameters",tParamName) = tAccum
                    } else {
                        $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Unknown command: %1",tAccum)))
                    }
                    set tAccum = ""
                    set tState = $$$PREARGUMENT
                } elseif (tState = $$$MODIFIERNAME) {
                    set modifierSubscript = pCommandInfo
                    if $data(tCommandStructure(pCommandInfo,"modifiers",tAccum)) {
                        set tModifier = tAccum
                    } elseif $data(tCommandStructure(pCommandInfo,"modifiers",1,tAccum),tAliasFor) {
                        set tModifier = tAliasFor
                    } elseif (($data(pCommandInfo("parameters","actions"),phases)) && (pCommandInfo = "module-action")) || ($listfind(##class(%IPM.Main).#STANDARDPHASES,pCommandInfo)) {

                        // Lifecycle phases can be called directly or through module-action, we need to share modifiers
                        if (pCommandInfo = "module-action") {
                            set phases = $listfromstring(phases)
                        } else {
                            set phases = $listbuild("module-action")
                        }
                        set ptr = 0
                        while $listnext(phases,ptr,currPhase) {
                            if $data(tCommandStructure(currPhase,"modifiers",tAccum)) {
                                set tModifier = tAccum
                                set modifierSubscript = currPhase
                            } elseif $data(tCommandStructure(currPhase,"modifiers",1,tAccum),tAliasFor) {
                                set tModifier = tAliasFor
                                set modifierSubscript = currPhase
                            } else {
                                $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Unknown modifier for command '%1': %2",pCommandInfo,tAccum)))
                            }
                        }
                    } else {
                        $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Unknown modifier for command '%1': %2",pCommandInfo,tAccum)))
                    }
                    if $data(tCommandStructure(modifierSubscript,"modifiers",tModifier,"dataAlias"),tDataAlias) {
                        set tDataName = tDataAlias
                        if $data(tCommandStructure(modifierSubscript,"modifiers",tModifier,"dataValue"),tDataValue) {
                            do ..SetData(.pCommandInfo,tDataAlias,tDataValue)
                            set tDataName = ""
                            set tState = $$$PREARGUMENT
                        } else {
                            set tState = $$$MODIFIERVALUE
                        }
                    } elseif tCommandStructure(modifierSubscript,"modifiers",tModifier,"value") {
                        set tState = $$$MODIFIERVALUE
                    } else {
                        set pCommandInfo("modifiers",tModifier) = ""
                        set tDataName = ""
                        set tState = $$$PREARGUMENT
                    }
                    set tAccum = ""
                } elseif (tState = $$$MODIFIERVALUE) {
                    if ($get(tDataName) '= "") {
                        do ..SetData(.pCommandInfo,tDataName,tAccum,tIsCustomData)
                        set tDataName = ""
                        set tIsCustomData = 0
                    } else {
                        set pCommandInfo("modifiers",tModifier) = tAccum
                    }
                    set tAccum = ""
                    set tState = $$$PREARGUMENT
                } elseif (tState = $$$PARAMETERVALUE) || ((tState = $$$TRAILINGPARAMETERVALUE) && (tChar = "")) {
                    set tParamName = $get(tCommandStructure(pCommandInfo,"parameters",$increment(tParamCount)))
                    if (tParamName = "") {
                        $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Too many parameters to command '%1'; only %2 expected.",pCommandInfo,tParamCount-1)))
                    }
                    set pCommandInfo("parameters",tParamName) = tAccum
                    set tAccum = ""
                    set tState = $$$PREARGUMENT
                } elseif (tState = $$$TRAILINGPARAMETERVALUE) {
                    set tAccum = tAccum_tChar
                }

                if '((tState = $$$MODIFIERVALUEQUOTED) || (tState = $$$PARAMETERVALUEQUOTED)) {
                    quit:(tChar="")
                    continue
                }
            } elseif (tChar = "-") {
                if (tState = $$$PREARGUMENT) {
                    set tState = $$$MODIFIERNAME
                    set tModifier = ""
                    continue
                } elseif ((tState = $$$PARAMETERVALUE) || (tState = $$$TRAILINGPARAMETERVALUE))
                    && $get(tCommandStructure(pCommandInfo,"trailingModifiers")) {
                    set tParamName = $get(tCommandStructure(pCommandInfo,"parameters",$increment(tParamCount)))
                    if (tParamName = "") {
                        $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Too many parameters to command '%1'; only %2 expected.",pCommandInfo,tParamCount-1)))
                    }
                    if ($extract(tAccum,*) = " ") {
                        set pCommandInfo("parameters",tParamName) = $extract(tAccum,1,*-1) // Strip the space.
                    } else {
                        set pCommandInfo("parameters",tParamName) = tAccum
                    }
                    set tAccum = ""
                    set tState = $$$MODIFIERNAME
                    set tModifier = ""
                    continue
                }
            } elseif (tChar = "\") {
                if (tState = $$$MODIFIERVALUEQUOTED) || (tState = $$$PARAMETERVALUEQUOTED) {
                    set tPreEscapeState = tState
                    set tState = $$$ESCAPECHAR
                    continue
                }
            } elseif (tChar = """") {
                if (tState = $$$PREARGUMENT) {
                    set tState = $$$PARAMETERVALUEQUOTED
                    continue
                } if (tState = $$$MODIFIERVALUE) && (tAccum = "") {
                    set tState = $$$MODIFIERVALUEQUOTED
                    continue
                } elseif (tState = $$$PARAMETERVALUE) && (tAccum = "") {
                    set tState = $$$PARAMETERVALUEQUOTED
                    continue
                } elseif (tState = $$$MODIFIERVALUEQUOTED) {
                    if ($get(tDataName) '= "") {
                        do ..SetData(.pCommandInfo,tDataName,tAccum,tIsCustomData)
                        set tIsCustomData = 0
                    } else {
                        set pCommandInfo("modifiers",tModifier) = tAccum
                    }
                    set tAccum = ""
                    set tState = $$$PREARGUMENT
                    continue
                } elseif (tState = $$$PARAMETERVALUEQUOTED) {
                    set tParamName = $get(tCommandStructure(pCommandInfo,"parameters",$increment(tParamCount)))
                    if (tParamName = "") {
                        $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Too many parameters to command '%1'; only %2 expected.",pCommandInfo,tParamCount-1)))
                    }
                    set pCommandInfo("parameters",tParamName) = tAccum
                    set tAccum = ""
                    set tState = $$$PREARGUMENT
                    continue
                }
            } elseif (tChar = "=") {
                if (tState = $$$DATANAME) {
                    set tDataName = tAccum
                    set tState = $$$MODIFIERVALUE
                    set tAccum = ""
                    continue
                }
            } else {
                if (tState = $$$PREARGUMENT) {
                    set tParamName = $get(tCommandStructure(pCommandInfo,"parameters",tParamCount+1))
                    if (tParamName = "") {
                        $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Too many parameters to command '%1'; only %2 expected.",pCommandInfo,tParamCount)))
                    }
                    if $get(tCommandStructure(pCommandInfo,"parameters",tParamName,"trailing")) {
                        set tState = $$$TRAILINGPARAMETERVALUE
                    } else {
                        set tState = $$$PARAMETERVALUE
                        set tEndPos = $locate(pCommandString, "\s", tPos)
                        if (tEndPos > 0) {
                            set tAccum = tChar_ $extract(pCommandString, tPos, tEndPos - 1)
                        } else {
                            set tAccum = tChar_ $extract(pCommandString, tPos, *)
                        }
                        set tPos = tEndPos
                        continue
                    }
                } elseif (tState = $$$MODIFIERNAME) {
                    set tDataPrefix = $get(tCommandStructure(pCommandInfo,"dataPrefix"))
                    if (tAccum = "") && (tDataPrefix '= "") && (tChar = tDataPrefix) {
                        set tState = $$$DATANAME
                        set tDataName = ""
                        set tIsCustomData = 1
                        continue
                    }
                }
            }

            if (tChar = "") {
                $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Invalid trailing input: %1",tAccum)))
            }

            // Default: accumulate
            set tAccum = tAccum _ tChar

            if (tState = $$$ESCAPECHAR) {
                set tState = tPreEscapeState
            }
        }
        // TODO: Extra validation.
    } catch e {
        if e.%IsA("%Exception.SystemException") {
            set tSC = $system.Status.EmbedStatus($$$ERROR($$$GeneralError,$$$FormatText("Error parsing command: %1",pCommandString)),e.AsStatus())
        } else {
            set tSC = e.AsStatus()
        }
    }
    quit tSC
}

/// Read JSON and construct a command matching the schema in the Commands XData blocks
/// that can be parsed using <method>%ParseCommandInput</method>. <br />
/// JSON format: <br />
/// {
/// 	"command": "command name",
/// 	"parameters": { ... },
/// 	"modifiers": { ... },
/// 	"custom_modifiers": { ... }
/// }
/// where each nested object contains key-value pairs.
ClassMethod ParseJsonToCommand(pJson As %Library.DynamicObject)
{
    do ..%GetCommandStructure(.allCommandsArray)
    set command = pJson.%Get("command")
    if (command = "") {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"Missing 'command' property in JSON"))
    }
    set quotedName = $$$QUOTE(command)
    if '$data(allCommandsArray(command)) {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"Command "_quotedName_" does not exist."))
    }
    merge commandArray = allCommandsArray(command)

    /*
     * NOTE: The below code does have a lot of common pieces to it
     * that could be refactored to smaller helper methods but has
     * been left this way for easier readability and understanding
     */

    set modList = ""
    #dim modifiers As %Library.DynamicObject
    set modifiers = pJson.%Get("modifiers")
    if $isobject(modifiers) {
        #dim modIter As %Iterator.Object
        set modIter = modifiers.%GetIterator()
        while modIter.%GetNext(.key, .value) {
            set modName = key
            // Check that modifier exists on command
            if '$data(commandArray("modifiers", key)) {
                // Check if modifier is an alias. If so, set modName to actual modifier
                if '$data(commandArray("modifiers", 1, key), modName) {
                    $$$ThrowStatus($$$ERROR($$$GeneralError,"Invalid modifier: -"_modName_" does not exist for command "_quotedName))
                }
            }
            set modHasValue = $get(commandArray("modifiers", modName, "value"), 0)
            if modHasValue {
                // Ensure value is not ""
                if (value = "") {
                    $$$ThrowStatus($$$ERROR($$$GeneralError,"Non-empty value required for modifier "_modName_" for command "_quotedName))
                }
            }
            // Validation passed so add to list
            set modList = modList_$listbuild("-"_modName)
            if modHasValue {
                set modList = modList_$listbuild(value)
            }
        }
    }

    set paramList = ""
    #dim parameters As %Library.DynamicObject
    set parameters = pJson.%Get("parameters")
    if $isobject(parameters) {
        #dim paramIter As %Iterator.Object
        set paramIter = parameters.%GetIterator()
        while paramIter.%GetNext(.key, .value) {
            // Check that parameter exists for command
            if '$data(commandArray("parameters", key)) {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"Invalid parameter: "_$$$QUOTE(key)_" does not exist for command "_quotedName))
            }
            if (value = "") {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"Non-empty value required for parameter "_$$$QUOTE(key)_" for command "_quotedName))
            }
            // Validation passed so add to list
            set paramList = paramList_$listbuild(value)
        }
    }

    set customModList = ""
    #dim customModifiers As %Library.DynamicObject
    set customModifiers = pJson.%Get("custom_modifiers")
    if $isobject(customModifiers) {
        // Get data prefix
        set dataPrefix = $get(commandArray("dataPrefix"))
        if (dataPrefix = "") {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"Command "_quotedName_" does not support custom modifiers"))
        }
        #dim customModIter As %Iterator.Object
        set customModIter = customModifiers.%GetIterator()
        while customModIter.%GetNext(.key, .value) {
            // Ensure value is not ""
            if (value = "") {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"Non-empty value required for all custom modifiers but absent for "_$$$QUOTE(key)_" for command "_quotedName))
            }
            // Validation passed so add to list
            set customModList = customModList_$listbuild("-"_dataPrefix_key_"="_value)
        }
    }

    // Construct command
    set hasTrailingModiifers = $get(commandArray("trailingModifiers"),0)
    set commandList = $listbuild(command) _ $case(hasTrailingModiifers, 1: paramList_modList, : modList_paramList) _ customModList
    return $listtostring(commandList, " ")
}

ClassMethod %GetCommandStructure(Output pCommandStructure)
{
    do ..%GetOneCommandStructure(.pCommandStructure)
}

/// Utility method for setting multiple subscripts based on .-delimited <var>pDataName</var>
ClassMethod SetData(
	pTargetArray,
	pDataName,
	pDataValue,
	pCustomParam = 0) [ Private, PublicList = pTargetArray ]
{
    if (pCustomParam && (pDataName'[".")) {
        // dubplicate param without prefix zpm for compatibility
        do ..SetData(.pTargetArray, "." _ pDataName, pDataValue, pCustomParam)
        set pDataName = "zpm."_pDataName
    }
    set tPieces = $listfromstring(pDataName,".")
    set tData = $name(pTargetArray("data"))
    set tPtr = 0
    while $listnext(tPieces, tPtr, tValue) {
        continue:tValue=""
        set tData = $name(@tData@(tValue))
    }
    set @tData = pDataValue
}

/// Draw a border around a list of strings. Optionally provide a text format for the strings. <br />
/// @Argument	pLineList		List of strings to write. <br />
/// @Argument	pTextFormat		Text format (e.g. $$$Red, $$$Bold, etc.). <br />
ClassMethod DrawBorder(
	pLineList As %Library.List,
	pTextFormat As %Integer = {$$$Default})
{
    // Find longest line in list
    set ptr = 0
    set maxLength = 0
    while $listnext(pLineList, ptr, line) {
        set lineLength = $length(line)
        if (lineLength > maxLength) {
            set maxLength = lineLength
        }
    }

    set verticalBorderCharacter = "||"
    set horizonatalBorderCharacter = "="

    set horizontalBorder = ""
    for i=1:1:(maxLength + 6) {
        set horizontalBorder = horizontalBorder _ horizonatalBorderCharacter
    }

    write !, horizontalBorder
    set ptr = 0
    while $listnext(pLineList, ptr, line) {
        write !, verticalBorderCharacter_" ", $$$FormattedLine(pTextFormat, line), ?(maxLength + 3), " "_verticalBorderCharacter
    }
    write !, horizontalBorder
    write !
}

/// INTENDED USE: <br />
/// - Intended for developer use if there is a subclass of this class that implements the Commands XData block. <br />
/// WHAT IT DOES: <br />
/// - Generates an include file with name <parameter>CommandsAccessorIncludeFilename</parameter>. This contains macros
/// to be used to obtain subscripts of the subscripted array generated by <method>GetCommandStructure</method> rather
/// than directly accessing subscripts using strings. <br />
/// HOW TO USE: <br />
/// - Override <parameter>CommandsAccessorIncludeFilename</parameter>. <br />
/// - Call this method on the subclass. <br />
/// - Add the created include file to the top of the subclass. <br />
/// - Add the include file to source control. <br />
/// - Use macros from the include file to access subscripted values in the output
/// of <method>%GetCommandStructure</method> by passing the array as the only argument
/// to macros to obtain the value of a single subscript/check its existence. <br />
ClassMethod GenerateCommandsIncludeFile() [ Internal ]
{
    do ..%GetCommandStructure(.commandStructure)

    // Array of lines to write to include file
    #dim lineArray As %String
    #define WriteLine(%line) Set lineArray($Increment(lineArray)) = %line

    // Names of subscripts
    set modifierSubscript = "modifiers"
    set parameterSubscript = "parameters"

    // Indicate how this was generated
    $$$WriteLine("#; Generated by: "_$classname()_":GenerateCommandsIncludeFile")
    $$$WriteLine("")

    set commandName = ""
    while 1 {
        set commandName = $order(commandStructure(commandName))
        if (commandName = "") {
            quit
        }
        // Skip aliases
        if $isvalidnum(commandName) {
            continue
        }
        // Skip if no modifiers or parameters
        if '($data(commandStructure(commandName, modifierSubscript)) || $data(commandStructure(commandName, parameterSubscript))) {
            continue
        }

        set formattedCommandName = ..FormatName(commandName)
        $$$WriteLine("#; Command: "_commandName)
        $$$WriteLine("")
        // Modifiers
        set modifierName = ""
        while 1 {
            set modifierName = $order(commandStructure(commandName, modifierSubscript, modifierName))
            if (modifierName = "") {
                quit
            }
            // Skip aliases
            if $isvalidnum(modifierName) {
                continue
            }
            set formattedModifierName = ..FormatName(modifierName)
            $$$WriteLine("/// Check for Modifier: "_modifierName)
            $$$WriteLine("#define HasMod"_formattedCommandName_formattedModifierName_"(%array) ''$Data(%array("_$$$QUOTE(modifierSubscript)_", "_$$$QUOTE(modifierName)_"))")
            // Only get modifier if it has value = true
            if +$get(commandStructure(commandName, modifierSubscript, modifierName, "value")) {
                $$$WriteLine("/// Get Modifier: "_modifierName)
                $$$WriteLine("#define GetMod"_formattedCommandName_formattedModifierName_"(%array) $Get(%array("_$$$QUOTE(modifierSubscript)_", "_$$$QUOTE(modifierName)_"))")
            }
        }

        // Parameters
        set parameterName = ""
        while 1 {
            set parameterName = $order(commandStructure(commandName, parameterSubscript, parameterName))
            if (parameterName = "") {
                quit
            }
            // Skip aliases
            if $isvalidnum(parameterName) {
                continue
            }
            set formattedParameterName = ..FormatName(parameterName)
            $$$WriteLine("/// Check for Parameter: "_parameterName)
            $$$WriteLine("#define HasParam"_formattedCommandName_formattedParameterName_"(%array) ''$Data(%array("_$$$QUOTE(parameterSubscript)_", "_$$$QUOTE(parameterName)_"))")
            $$$WriteLine("/// Get Parameter: "_parameterName)
            $$$WriteLine("#define GetParam"_formattedCommandName_formattedParameterName_"(%array) $Get(%array("_$$$QUOTE(parameterSubscript)_", "_$$$QUOTE(parameterName)_"))")
        }

        // Blank line after all commands
        $$$WriteLine("")
    }
    set filename = ..#CommandsAccessorIncludeFilename
    do ##class(%IPM.Utils.Module).CreateOrUpdateIncludeFile(filename, .lineArray)
}

/// Format the given name such that all punctuation characters are remove and
/// the name is in camelCase, with the first letter capitalized. <br />
/// @Argument	pName		String to format. <br />
ClassMethod FormatName(pName As %String) As %String
{
    set resultString = ""
    // First letter should always be capital
    set letterCapital = 1
    for i=1:1:$length(pName) {
        set letter = $extract(pName, i)
        // Special characters should be removed and next letter should be capitalized
        if ($zstrip(letter, "*P") = "") {
            set letterCapital = 1
            continue
        }
        if letterCapital {
            set letter = $$$ucase(letter)
            set letterCapital = 0
        }
        set resultString = resultString _ letter
    }
    return resultString
}

ClassMethod TerminalPromptColor() As %String
{
    quit $case(##class(%IPM.Repo.UniversalSettings).GetValue("TerminalPrompt"),"green":$$$Green,"red":$$$Red,"magenta":$$$Magenta,"yellow":$$$Yellow,"blue":$$$Blue,"cyan":$$$Cyan,"none":$$$Default,:$$$Default)
}

}
