/// Use: Extracts XML comments from a document and allows them to be added back in later,
/// assuming that the XPath paths to their previous locations are still valid.
Class %IPM.Utils.XMLCommentHandler Extends %XML.SAX.ContentHandler
{

/// Content (comments/whitespace) that have been found but not yet mapped to their appropriate position in the document.
Property UnmappedContent [ MultiDimensional, Private ];

/// ..Content = <number of comment/whitespace items extracted from document>
/// ..Content(i) = $lb((comment|characters),<text>)
Property Content [ MultiDimensional, Private ];

/// ..ContentMap(i) = <XPath expression for location of ..Content(i)>
Property ContentMap [ MultiDimensional, Private ];

/// ..Path = <depth of current path in document>
/// ..Path(i) = $ListBuild(<containing element descriptor>,<previous element descriptor>,<previous padding characters>)
Property Path [ MultiDimensional, Private ];

/// Last node type (document, element, comment)
Property LastNodeType As %String [ Private ];

/// If no attributes are available to identify an element, then occurrences of element paths are counted and used instead (stored here)
/// ..PathCount($zcrc(<path>,7)) = <count>
Property PathCounts [ MultiDimensional, Private ];

/// In case a duplicate path is found later in processing, this is used to track what the replacement should be.
/// ..ReplacePaths($zcrc(<original path>,7)) = <path to really use>
Property ReplacePaths [ MultiDimensional, Private ];

Method GetResults(
	Output pContent,
	Output pContentMap) [ Internal ]
{
    merge pContent = ..Content
    merge pContentMap = ..ContentMap
}

Method Reapply(
	ByRef pXMLStream As %Stream.Object,
	pIndent As %Boolean = 1) As %Status
{
    set tSC = $$$OK
    try {
        // Construct XSLT to add comments back in.
        do ..GetResults(.tContent, .tContentMap)
        if '$data(tContent) {
            // No-op.
            quit
        }

        set tXSL = ##class(%Stream.TmpBinary).%New()
        do tXSL.Write("<?xml version=""1.0"" encoding=""UTF-8""?>")
        do tXSL.Write("<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform"" xmlns:xslt=""http://xml.apache.org/xslt"">")
        do tXSL.Write("<xsl:output method=""xml"" "_$select(pIndent:"indent=""yes"" xslt:indent-amount=""2""",1:"")_"/>")
        if ('pIndent) {
            // Add leading and trailing newline
            set tNewline = "<xsl:text>"_$zconvert($char(10),"O","XML")_"</xsl:text>"
            do tXSL.Write("<xsl:template match=""/"">")
            do tXSL.Write(tNewline)
            do tXSL.Write("<xsl:apply-templates select=""*""/>")
            do tXSL.Write(tNewline)
            do tXSL.Write("</xsl:template>")
        }
        do tXSL.Write("<xsl:template match=""node()|@*"">")
        do tXSL.Write("<xsl:copy>")
        do tXSL.Write("<xsl:text /><xsl:apply-templates select=""node()|@*""/><xsl:text />")
        do tXSL.Write("</xsl:copy>")
        do tXSL.Write("</xsl:template>")

        // First pass: build map of comments to associated elements (with filters)
        #define BEFORE 0
        #define AFTER 1
        for tIndex=1:1:$get(tContent) {
            set tItem = tContent(tIndex)
            set tPath = tContentMap(tIndex)

            // Hash to avoid <SUBSCRIPT> errors for very long paths
            set tHash = $zcrc($listget(tPath,2),7)
            set tLocationHashMap(tHash) = $listget(tPath,2)
            set tLocationHashMap(tHash,tIndex) = tItem

            if ($listget(tItem) = "comment") {
                set tHasComments(tHash) = ""
            }
        }

        // Second pass: write XSLT to add comments
        set tKey = ""
        for {
            set tKey = $order(tLocationHashMap(tKey),1,tMatchExpression)
            quit:tKey=""

            // Only do anything if we actually have a comment.
            if '$data(tHasComments(tKey)) {
                continue
            }

            if $data(..ReplacePaths(tKey),tReplaceExpression) {
                // After tMatchExpression was stored, the real expression to use was updated (to add a counter).
                // Use that expression instead.
                set tMatchExpression = tReplaceExpression
            }

            do tXSL.Write("<xsl:template match="""_tMatchExpression_""">")

            set tBeforeKey = ""
            set tLineNumber = 1
            for {
                set tBeforeKey = $order(tLocationHashMap(tKey,tBeforeKey),1,tData)
                quit:tBeforeKey=""

                set $listbuild(tType,tText) = tData

                if (pIndent && (tType = "characters")) {
                    if (tLineNumber = 1) && ($extract(tText) = $char(10)) {
                        set tText = $piece(tText,$char(10),1,*-1)
                    }
                    do tXSL.Write("<xsl:text>"_$zconvert(tText,"O","XML")_"</xsl:text>")
                } elseif (tType = "comment") {
                    do tXSL.WriteLine("<xsl:comment>"_$zconvert(tText,"O","XML")_"</xsl:comment>")
                }
                set tLineNumber = tLineNumber + 1
            }

            do tXSL.Write("<xsl:copy><xsl:copy-of select=""@*""/>")
            do tXSL.Write("<xsl:apply-templates select=""node()|@*"" /></xsl:copy></xsl:template>")
        }

        do tXSL.Write("</xsl:stylesheet>")

        // Apply XSLT to input stream.
        set tSC = ##class(%XML.XSLT.Transformer).TransformStream(pXMLStream, tXSL, .tOutStream)
        if $$$ISERR(tSC) {
            quit
        }

        set pXMLStream = tOutStream
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod BuildAttributeFilter(pAttrList As %List) As %String [ Private ]
{
    if (pAttrList = "") {
        quit ""
    }
    set tPointer = 0
    set tExpr = ""
    while $listnext(pAttrList,tPointer,tAttr) {
        set tExpr = tExpr_"[@"_$listget(tAttr)_"='"_$replace($listget(tAttr,2),"'","\'")_"']"
    }
    quit tExpr
}

/// Receive notification of comments.
/// 
/// <p>The Parser will call this method to report each occurence of
/// a comment in the XML document.</p>
/// 
/// <p>The application must not attempt to read from the array
/// outside of the specified range.</p>
/// <ul>
/// <li>chars: The characters from the XML document.</li>
/// <li>length: The number of characters to read from the array.</li>
/// </ul>
/// <p>
/// Exceptions thrown: SAXException - Any SAX exception, possibly
/// wrapping another exception.</p>
Method comment(
	chars As %String,
	length As %Integer)
{
    set ..UnmappedContent($increment(..UnmappedContent)) = $listbuild("comment",chars)
    set ..LastNodeType = "comment"
    quit
}

/// Returns current position in the XML document, as an XPath expression with information on the next non-comment node.
Method GetPosition() As %String
{
    set tPath = ""
    set tType = ""
    for i=1:1:$get(..Path) {
        kill tVal1,tVal2
        set $listbuild(tType,tVal1,tFilter) = ..Path(i)
        if (i = ..Path) {
            set tNext = $case(tType,
                "element":"/"_tVal1_tFilter,
                "document":"/",
                :"")
        } else {
            set tNext = $case(tType,
                "element":"/"_tVal1_tFilter,
                :"")
        }
        set tPath = tPath_tNext
        if $data(tVal1) {
            if ($get(tFilter) = "") && $data(..PathCounts(i-1,tVal1),tCount) {
                // If there is no filter, always refer to the node by position.
                set tPath = tPath_"["_tCount_"]"
            } elseif ($get(tFilter) '= "") && (i = ..Path) {
                set tHash = $zcrc(tPath,7)
                if $data(..PathCounts(tHash),tCount) {
                    if (tCount = 1) {
                        // Flag that we have another occurrence of this path that needs to be updated to refer
                        // to the first occurrence.
                        set ..ReplacePaths(tHash) = tPath_"[1]"
                    }
                    set tPath = tPath_"["_$increment(..PathCounts(tHash))_"]"
                } else {
                    set ..PathCounts(tHash) = 1
                }
            }
        }
    }
    quit $listbuild(tType,tPath)
}

/// Receive notification of the beginning of the document.
/// 
/// <p>
/// By default, do nothing.  Application writers may override this
/// method in a subclass to take specific actions at the beginning
/// of a document (such as allocating the root node of a tree or
/// creating an output file)
/// <p>
Method startDocument()
{
    kill ..Content
    kill ..ContentMap
    kill ..UnmappedContent
    kill ..PathCounts
    kill ..ReplacePaths
    set ..Path($increment(..Path)) = $listbuild("document")
    set ..LastNodeType = "document"
}

/// Receive notification of the start of an element.
/// 
/// <p>
/// By default, do nothing.  Application writers may override this
/// method in a subclass to take specific actions at the start of
/// each element (such as allocating a new tree node or writin
/// output to a file).
/// </p>
/// <p>
/// <ul>
/// <li>uri: The URI of the associated namespace for this element</li>
/// <li>localname: the local part of the element name</li>
/// <li>qname: the QName of this element</li>
/// <li>attrs: a list in $List format consisting of a repeating group of attributes.</li>
/// </ul>
/// <p>
/// The format of the repeating group is as follows:
/// <ul>
/// <li>+0 - uri: The URI of the associated namespace for this attribute</li>
/// <li>+1 - localname: The local part of the name of this attribute</li>
/// <li>+2 - qname: The QName of this attribute</li>
/// <li>+3 - type: The type of this attribute ("CDATA", NMTOKEN", "ENTITY", etc.)</li>
/// <li>+4 - value: The value of this attribute</li>
/// </ul>
/// </p>
Method startElement(
	uri As %Library.String,
	localname As %Library.String,
	qname As %Library.String,
	attrs As %Library.List)
{
    // Extract just qname/value from attrs, build $lb($lb(qname,value),$lb(qname,value),...)
    set tModArgs = ""
    set tPointer = 0
    set tQName = ""
    set tPosition = 0
    while $listnext(attrs,tPointer,tAttrValue) {
        if (tPosition#5) = 2 {
            set tQName = tAttrValue
        } elseif (tPosition#5) = 4 {
            set tModArgs = tModArgs_$listbuild($listbuild(tQName,tAttrValue))
            set tQName = ""
        }
        set tPosition = tPosition + 1
    }

    set tFilter = ..BuildAttributeFilter(tModArgs)

    set tPathCount = $get(..PathCounts(..Path,localname_tFilter),0) + 1
    set ..PathCounts(..Path,localname_tFilter) = tPathCount

    // Update path info
    set ..Path($increment(..Path)) = $listbuild("element",localname,tFilter)
    set tNext = ..Path
    for {
        set tNext = $order(..Path(tNext))
        quit:tNext=""
        kill ..Path(tNext)
    }

    do ..MapContent()
    set ..LastNodeType = "element"
}

/// Receive notification of the end of an element.
/// 
/// <p>
/// By default, do nothing.  Application writers may override this
/// method in a subclass to take specific actions at the end of
/// each element (such as finalising a tree node or writing
/// output to a file).
/// </p>
/// 
/// <p>
/// <ul>
/// <li>uri: The URI of the associated namespace for this element</li>
/// <li>localname: The local part of the element name</li>
/// <li>qname: The QName of this element</li>
/// </ul>
/// </p>
Method endElement(
	uri As %Library.String,
	localname As %Library.String,
	qname As %Library.String)
{
    set ..LastNodeType = "element"
    kill ..PathCounts(..Path)
    kill ..UnmappedContent
    set ..Path = ..Path - 1
}

Method MapContent()
{
    if $data(..UnmappedContent,tContentCount) {
        set tPosition = ..GetPosition()
        set tRemovedOneIndent = 0
        for tIndex=1:1:tContentCount {
            set tContent = $get(..UnmappedContent(tIndex))
            if ($listget(tContent,2) '= "") {
                set ..Content($increment(..Content)) = tContent
                set ..ContentMap(..Content) = tPosition
            }
        }
        kill ..UnmappedContent
    }
}

/// Receive notification of character data inside an element.
/// 
/// <p>
/// By default, do nothing.  Application writers may override this
/// method to take specific actions for each chunk of character data
/// (such as adding the data to a node or buffer, or printing it to
/// a file).
/// </P>
/// <p>
/// <ul>
/// <li>chars: The characters.</li>
/// <li>length: The number of characters to use from the character
/// array.</li>
/// </ul>
Method characters(
	chars As %Library.String,
	length As %Library.Integer)
{
    // Strip trailing $c(10) and any number of spaces following it.
    set tExtraChars = chars
    if (tExtraChars '= "") {
        set ..UnmappedContent($increment(..UnmappedContent)) = $listbuild("characters",tExtraChars)
    }
}

}
