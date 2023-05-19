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

Method GetResults(Output pContent, Output pContentMap) [ Internal ]
{
	Merge pContent = ..Content
	Merge pContentMap = ..ContentMap
}

Method Reapply(ByRef pXMLStream As %Stream.Object, pIndent As %Boolean = 1) As %Status
{
	Set tSC = $$$OK
	Try {
		// Construct XSLT to add comments back in.
		Do ..GetResults(.tContent, .tContentMap)
		If '$Data(tContent) {
			// No-op.
			Quit
		}
		
		Set tXSL = ##class(%Stream.TmpBinary).%New()
		Do tXSL.Write("<?xml version=""1.0"" encoding=""UTF-8""?>")
		Do tXSL.Write("<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform"" xmlns:xslt=""http://xml.apache.org/xslt"">")
		Do tXSL.Write("<xsl:output method=""xml"" "_$Select(pIndent:"indent=""yes"" xslt:indent-amount=""2""",1:"")_"/>")
    	If ('pIndent) {
	    	// Add leading and trailing newline
	    	Set tNewline = "<xsl:text>"_$ZConvert($c(10),"O","XML")_"</xsl:text>"
	    	Do tXSL.Write("<xsl:template match=""/"">")
	    	Do tXSL.Write(tNewline)
	    	Do tXSL.Write("<xsl:apply-templates select=""*""/>")
	    	Do tXSL.Write(tNewline)
	    	Do tXSL.Write("</xsl:template>")
    	}
		Do tXSL.Write("<xsl:template match=""node()|@*"">")
    	Do tXSL.Write("<xsl:copy>")
        Do tXSL.Write("<xsl:text /><xsl:apply-templates select=""node()|@*""/><xsl:text />")
    	Do tXSL.Write("</xsl:copy>")
		Do tXSL.Write("</xsl:template>")
		
		// First pass: build map of comments to associated elements (with filters)
		#define BEFORE 0
		#define AFTER 1
		For tIndex=1:1:$Get(tContent) {
			Set tItem = tContent(tIndex)
			Set tPath = tContentMap(tIndex)
			
			// Hash to avoid <SUBSCRIPT> errors for very long paths
			Set tHash = $zcrc($ListGet(tPath,2),7)
			Set tLocationHashMap(tHash) = $ListGet(tPath,2)
			Set tLocationHashMap(tHash,tIndex) = tItem
			
			If ($ListGet(tItem) = "comment") {
				Set tHasComments(tHash) = ""
			}
		}
		
		// Second pass: write XSLT to add comments
		Set tKey = ""
		For {
			Set tKey = $Order(tLocationHashMap(tKey),1,tMatchExpression)
			Quit:tKey=""
			
			// Only do anything if we actually have a comment.
			If '$Data(tHasComments(tKey)) {
				Continue
			}
			
			If $Data(..ReplacePaths(tKey),tReplaceExpression) {
				// After tMatchExpression was stored, the real expression to use was updated (to add a counter).
				// Use that expression instead.
				Set tMatchExpression = tReplaceExpression
			}
			
			Do tXSL.Write("<xsl:template match="""_tMatchExpression_""">")
			
			Set tBeforeKey = ""
			Set tLineNumber = 1
			For {
				Set tBeforeKey = $Order(tLocationHashMap(tKey,tBeforeKey),1,tData)
				Quit:tBeforeKey=""
				
				Set $ListBuild(tType,tText) = tData
				
				If (pIndent && (tType = "characters")) {
					If (tLineNumber = 1) && ($Extract(tText) = $c(10)) {
						Set tText = $Piece(tText,$c(10),1,*-1)
					}
					Do tXSL.Write("<xsl:text>"_$ZConvert(tText,"O","XML")_"</xsl:text>")
				} ElseIf (tType = "comment") {
					Do tXSL.WriteLine("<xsl:comment>"_$ZConvert(tText,"O","XML")_"</xsl:comment>")
				}
				Set tLineNumber = tLineNumber + 1
			}
			
			Do tXSL.Write("<xsl:copy><xsl:copy-of select=""@*""/>")
			Do tXSL.Write("<xsl:apply-templates select=""node()|@*"" /></xsl:copy></xsl:template>")
		}
		
		Do tXSL.Write("</xsl:stylesheet>")
		
		// Apply XSLT to input stream.
		Set tSC = ##class(%XML.XSLT.Transformer).TransformStream(pXMLStream, tXSL, .tOutStream)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set pXMLStream = tOutStream
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod BuildAttributeFilter(pAttrList As %List) As %String [ Private ]
{
	If (pAttrList = "") {
		Quit ""
	}
	
	Set tPointer = 0
	Set tExpr = ""
	While $ListNext(pAttrList,tPointer,tAttr) {
		Set tExpr = tExpr_"[@"_$ListGet(tAttr)_"='"_$Replace($ListGet(tAttr,2),"'","\'")_"']"
	}
	Quit tExpr
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
Method comment(chars As %String, length As %Integer)
{
	Set ..UnmappedContent($Increment(..UnmappedContent)) = $lb("comment",chars)
	Set ..LastNodeType = "comment"
	Quit
}

/// Returns current position in the XML document, as an XPath expression with information on the next non-comment node.
Method GetPosition() As %String
{
	Set tPath = ""
	Set tType = ""
	For i=1:1:$Get(..Path) {
		Kill tVal1,tVal2
		Set $ListBuild(tType,tVal1,tFilter) = ..Path(i)
		If (i = ..Path) {
			Set tNext = $Case(tType,
				"element":"/"_tVal1_tFilter,
				"document":"/",
				:"")
		} Else {
			Set tNext = $Case(tType,
				"element":"/"_tVal1_tFilter,
				:"")
		}
		Set tPath = tPath_tNext
		If $Data(tVal1) {
			If ($Get(tFilter) = "") && $Data(..PathCounts(i-1,tVal1),tCount) {
				// If there is no filter, always refer to the node by position.
				Set tPath = tPath_"["_tCount_"]"
			} ElseIf ($Get(tFilter) '= "") && (i = ..Path) {
				Set tHash = $zcrc(tPath,7)
				If $Data(..PathCounts(tHash),tCount) {
					If (tCount = 1) {
						// Flag that we have another occurrence of this path that needs to be updated to refer
						// to the first occurrence.
						Set ..ReplacePaths(tHash) = tPath_"[1]"
					}
					Set tPath = tPath_"["_$Increment(..PathCounts(tHash))_"]"
				} Else {
					Set ..PathCounts(tHash) = 1
				}
			}
		}
	}
	Quit $ListBuild(tType,tPath)
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
	Kill ..Content
	Kill ..ContentMap
	Kill ..UnmappedContent
	Kill ..PathCounts
	Kill ..ReplacePaths
	Set ..Path($i(..Path)) = $lb("document")
	Set ..LastNodeType = "document"
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
Method startElement(uri As %Library.String, localname As %Library.String, qname As %Library.String, attrs As %Library.List)
{
	// Extract just qname/value from attrs, build $lb($lb(qname,value),$lb(qname,value),...)
	Set tModArgs = ""
	Set tPointer = 0
	Set tQName = ""
	Set tPosition = 0
	While $ListNext(attrs,tPointer,tAttrValue) {
		If (tPosition#5) = 2 {
			Set tQName = tAttrValue
		} ElseIf (tPosition#5) = 4 {
			Set tModArgs = tModArgs_$ListBuild($ListBuild(tQName,tAttrValue))
			Set tQName = ""
		}
		Set tPosition = tPosition + 1
	}
	
	Set tFilter = ..BuildAttributeFilter(tModArgs)
	
	Set tPathCount = $Get(..PathCounts(..Path,localname_tFilter),0) + 1
	Set ..PathCounts(..Path,localname_tFilter) = tPathCount
	
	// Update path info
	Set ..Path($Increment(..Path)) = $lb("element",localname,tFilter)
	Set tNext = ..Path
	For {
		Set tNext = $Order(..Path(tNext))
		Quit:tNext=""
		Kill ..Path(tNext)
	}
	
	Do ..MapContent()
	Set ..LastNodeType = "element"
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
Method endElement(uri As %Library.String, localname As %Library.String, qname As %Library.String)
{
	Set ..LastNodeType = "element"
	Kill ..PathCounts(..Path)
	Kill ..UnmappedContent
	Set ..Path = ..Path - 1
}

Method MapContent()
{
	If $Data(..UnmappedContent,tContentCount) {
		Set tPosition = ..GetPosition()
		Set tRemovedOneIndent = 0
		For tIndex=1:1:tContentCount {
			Set tContent = $Get(..UnmappedContent(tIndex))
			If ($ListGet(tContent,2) '= "") {
				Set ..Content($i(..Content)) = tContent
				Set ..ContentMap(..Content) = tPosition
			}
		}
		Kill ..UnmappedContent
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
Method characters(chars As %Library.String, length As %Library.Integer)
{
	// Strip trailing $c(10) and any number of spaces following it.
	Set tExtraChars = chars
	If (tExtraChars '= "") {
		Set ..UnmappedContent($i(..UnmappedContent)) = $lb("characters",tExtraChars)
	}
}

}
