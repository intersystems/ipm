Class %IPM.Utils.FileBinaryTar Extends (%RegisteredObject, %ArrayOfDataTypes)
{

Parameter BLOCKSIZE As %Integer = 512;

/// name of file
Property name As %String(CAPTION = "Header", MAXLEN = 100, TRUNCATE = 1);

/// file mode
Property mode As %String(CAPTION = "Header", MAXLEN = 8);

/// owner user ID
Property uid As %String(CAPTION = "Header", MAXLEN = 8) [ InitialExpression = {..Dec2Oct(0, 6)} ];

/// owner group ID
Property gid As %String(CAPTION = "Header", MAXLEN = 8) [ InitialExpression = {..Dec2Oct(0, 6)} ];

/// length of file in bytes
Property size As %String(CAPTION = "Header", MAXLEN = 12);

/// modify time of file
Property mtime As %String(CAPTION = "Header", MAXLEN = 12);

/// checksum for header
Property chksum As %String(CAPTION = "Header", MAXLEN = 8) [ InitialExpression = {$JUSTIFY("", 8)} ];

/// type of file
Property typeflag As %String(CAPTION = "Header", DISPLAYLIST = ",REGULAR,LINK,RESERVED,CHARACTER SPECIAL,BLOCK SPECIAL,DIRECTORY,FIFO SPECIAL,RESERVED", MAXLEN = 1, VALUELIST = ",0,1,2,3,4,5,6,7,x,g,L,K");

/// name of linked file
Property linkname As %String(CAPTION = "Header", MAXLEN = 100, TRUNCATE = 1);

/// USTAR indicator
Property magic As %String(CAPTION = "Header", MAXLEN = 6, TRUNCATE = 1) [ InitialExpression = "ustar" ];

/// USTAR version
Property version As %String(CAPTION = "Header", MAXLEN = 2) [ InitialExpression = "00" ];

/// owner user name
Property uname As %String(CAPTION = "Header", MAXLEN = 32, TRUNCATE = 1);

/// owner group name
Property gname As %String(CAPTION = "Header", MAXLEN = 32, TRUNCATE = 1);

/// device major number
Property devmajor As %String(CAPTION = "Header", MAXLEN = 8) [ InitialExpression = {..Dec2Oct(0, 6)} ];

/// device minor number
Property devminor As %String(CAPTION = "Header", MAXLEN = 8) [ InitialExpression = {..Dec2Oct(0, 6)} ];

/// prefix for file name
Property prefix As %String(CAPTION = "Header", MAXLEN = 155, TRUNCATE = 1);

/// file data
Property fileData As %Stream.Object;

Method nameGet() As %String
{
  Return i%prefix_i%name
}

Method sizeGet() As %Integer
{
  Return $$oct2dec^%Wmdc(i%size)
}

Method sizeSet(pSize As %Integer) As %Status
{
  set i%size = ..Dec2Oct(pSize, 11)
  if ($length(i%size)>12) {
    return $$$ERROR(5001, "Size too big")
  }
  return $$$OK
}

Method modeSet(pMode As %Integer) As %Status
{
  if $$$isWINDOWS {
    set mode = 0
    set mask = 0
  } else {
    set mode = pMode
    set mask = 4095
  }
  set i%mode = ..Dec2Oct(mode, 6, mask)
  return $$$OK
}

Method mtimeSet(pTime As %Integer) As %Status
{
  set mtime =..Dec2Oct(pTime, 11)
  set i%mtime = mtime
  return $$$OK
}

Method chksumSet(pVal As %Integer) As %Status
{
  set tVal =..Dec2Oct(pVal, 6)
  set i%chksum = tVal
  return $$$OK
}

ClassMethod Dec2Oct(pVal As %Integer, pLen As %Integer, pMask As %Integer = 0) As %String
{
  set val = pVal
  if (pMask>0) {
    set val = $ZBOOLEAN(val, pMask, 1)
  }
  set val = $$dec2oct^%Wmdc(val)
  set val = $JUSTIFY(val, pLen)
  set val = $TRANSLATE(val, " ", 0)
  set val = val _ $c(32)
  return val
}

Method FindPath(pPath As %String = "", Output found As FileBinaryTar) As %Status
{
  set found = $$$NULLOREF
  set pPath = $tr(pPath, "\", "/")
  set tmp = ..GetAt($p(pPath, "/"))
  if '$isobject(tmp) {
    return $$$ERROR($$$GeneralError, "Path '"_pPath_"' not found")
  }
  if $l(pPath, "/")>1 {
    return tmp.FindPath($p(pPath, "/", 2, *), .found)
  }
  set found = tmp
  Return $$$OK
}

ClassMethod ExtractFile(aFileName As %String = "", Gzip As %Boolean = 1, pTargetDirectory As %String) As FileBinaryTar
{
  if aFileName = "" {
    Return $$$ERROR($$$GeneralError, "Filename not specified")
  }
  if Gzip {
    set fileStream=##class(%Stream.FileBinaryGzip).%New()
  } else {
    set fileStream=##class(%Stream.FileBinary).%New()
  }
  set fileStream.Filename=aFileName
  Return ..ExtractStream(fileStream, pTargetDirectory)
}

Method ExtractTo(pDest As %String) As %Status
{
  if ..name'="" {
    if ..typeflag=5 {
      set fullPath = ##class(%File).NormalizeDirectory(..name, pDest)
      set sc = ##class(%File).CreateDirectoryChain(fullPath)
      if $$$ISERR(sc) {
        return sc
      }
    } else {
      #; no idea, why it's needed, but IRIS.DAT filename not allowed
      set irisdat = 0
      set fullPath = ##class(%File).NormalizeFilename(..name, pDest)
      if $Extract(fullPath, * - 7, *) = "IRIS.DAT" {
        set irisdat = 1
        set fullPath = $Extract(fullPath, 1, * - 8) _ "iris.dat"
      }
      set fs = ##class(%Stream.FileBinary).%New()
      set fs.Filename = fullPath
      do fs.CopyFromAndSave(..fileData)
      $$$ThrowOnError(fs.LinkToFile(fullPath))
      $$$ThrowOnError(fs.CopyFromAndSave(..fileData))
      do fs.%Close()
      if irisdat {
        set to = $Extract(fullPath, 1, * - 8) _ "IRIS.DAT"
        $$$ThrowOnError(##class(%File).Rename(fullPath, to))
      }
    }
  }
}

ClassMethod ExtractStream(aFileStream As %Stream.Object, pTargetDirectory As %String) As FileBinaryTar
{
  #dim tFile As FileBinaryTar
  set blockSize = ..#BLOCKSIZE
  set result=..%New()
  while 'aFileStream.AtEnd {
    set tFile=..%New()
    set longLink4Name=""
    set longLink4Link=""
    do {
      set repeat=0
      set tHeader=aFileStream.Read(blockSize)
      do tFile.ParseHeader(tHeader)
      if tFile.name="./" {
        set repeat=1
        continue
      }
      If ($EXTRACT(tFile.name, 1, 2) = "./") {
        Set tFile.name = $EXTRACT(tFile.name, 3, *)
      }
      quit:tFile.name=""
      set $EXTRACT(tHeader, 149, 156) = $JUSTIFY("", 8)
      set chksumExpected = $zcrc(tHeader, 0)
      set chksum = $$oct2dec^%Wmdc(+tFile.chksum)
      if (chksumExpected'=chksum) {
        throw ##class(%Exception.General).%New("Checksum mismatch: "_chksumExpected_":"_chksum)
      }
      set fileSize=tFile.size
      set typeFlag=tFile.typeflag
      if (typeFlag="L") || (typeFlag="K") {
        set readBlocks=fileSize \ blockSize
        set:fileSize#blockSize>0 readBlocks=readBlocks + 1
        set longLink=aFileStream.Read(readBlocks * blockSize)
        set longLink=$zstrip(longLink,"<>",$char(0,32))
        set:(typeFlag="L") longLink4Name=longLink
        set:(typeFlag="K") longLink4Link=longLink
        set repeat=1
        continue
      }
      set repeat=0
      set:longLink4Name'="" tFile.name=longLink4Name
      set:longLink4Link'="" tFile.linkname=longLink4Link
    } while repeat
    set fileName=tFile.name
    quit:fileName=""
    if ( (tFile.typeflag'="g") && (tFile.typeflag=5) ) { 
      // save directory
      do tFile.ExtractTo(pTargetDirectory)
      //      do ..AddToArray(tFile, result)
    }
    
    continue:fileSize=0
    set readBlocks=fileSize \ blockSize
    set:fileSize#blockSize>0 readBlocks=readBlocks + 1
    set tFile.fileData=##class(%Stream.FileBinary).%New()
    for tPos=1:1:readBlocks {
      set tData=aFileStream.Read(blockSize)
      if (tPos=readBlocks)&&(fileSize#blockSize>0) {
        set tData=$extract(tData, 1, fileSize#blockSize)
      }
      do tFile.fileData.Write(tData)
    }
    if (fileSize'=tFile.fileData.Size) {
      throw ##class(%Exception.General).%New("File size mismatch: "_fileSize_":"_tFile.fileData.Size)
    }
    if tFile.typeflag'="g" { 
      // save file
      do tFile.ExtractTo(pTargetDirectory)
    }
  }
  Return result
}

ClassMethod AddToArray(pFile As FileBinaryTar, pArray As FileBinaryTar) [ Internal, Private ]
{
  if ('$isobject(pFile)) || ('$isobject(pArray)) {
    return
  }
  
  set tFileName= $zstrip(pFile.name,"<>", "/")
  set tItem=pArray
  for i=1:1:$length(tFileName, "/")-1 {
    set tPathItem=$piece(tFileName, "/", i)
    if 'tItem.IsDefined(tPathItem) {
      do tItem.SetAt(..%New(), tPathItem)
    }
    set tItem=tItem.GetAt(tPathItem)
  }
  do tItem.SetAt(pFile, $piece(tFileName, "/", $length(tFileName, "/")))
}

Method ParseHeader(aHeaderData As %String) As %Status [ CodeMode = objectgenerator, Internal ]
{
  set tProps=%class.Properties
  Set tPropKey = ""
  For {
    Set tProp = %class.Properties.GetNext(.tPropKey)
    Quit:(tPropKey = "")
    CONTINUE:"Header"'=tProp.Parameters.GetAt("CAPTION")
    set tProps(tProp.SequenceNumber)=tProp
  }	
  Set tPropKey = "", tPos = 0
  For {
    Set tPropKey = $Order(tProps(tPropKey),1,tProp)
    Quit:tPropKey=""
    Set tLen = tProp.Parameters.GetAt("MAXLEN")
    Do %code.WriteLine($char(9)_"Set i%"_tProp.Name_" = $zstrip($extract(aHeaderData, "_$increment(tPos)_", "_$increment(tPos, tLen - 1)_"), ""<>"", $c(0,32))")
    Do:tProp.Name="typeflag" %code.WriteLine($char(9)_"Set:i%"_tProp.Name_"=$c(0) i%"_tProp.Name_" = 0")
  }
  Return $$$OK
}

ClassMethod Compact(Path As %String = "", gzip As %Boolean = 1, pFileName As %String = "", relativeTo As %String = "") As %Stream.FileBinary
{
  if (gzip) {
    set archive = ##class(%Stream.FileBinaryGzip).%New()
  } ELSE {
    set archive = ##class(%Stream.FileBinary).%New()		
  }
  if (pFileName'="") {
    Set tSC = archive.LinkToFile(pFileName)
    $$$ThrowOnError(tSC)
  }
  
  if relativeTo="" {
    set relativeTo = ##class(%File).ParentDirectoryName(Path)
  }
  set relativeTo = ##class(%File).NormalizeDirectory(relativeTo)

  Do ..ConstructTar(Path, relativeTo, archive)
  Set tSC = archive.%Save()
  $$$ThrowOnError(tSC)
  Do archive.%Close()
  
  return archive
}

ClassMethod ConstructTar(Path As %String, RelativeTo As %String, archive As %Stream.GlobalBinary)
{
  QUIT:Path=archive.Filename // skip archive itself
  set blockSize = ..#BLOCKSIZE
  if ##class(%File).DirectoryExists(Path) {
    set Path = ##class(%File).NormalizeDirectory(Path)
    set prefix = ##class(%File).GetDirectory($Extract(Path,1,*-1))
    set prefix = $PIECE(Path, RelativeTo, 2, *)
    set flag = 5 // Directory
    set size = 0
    set name = ##class(%File).GetFilename($Extract(Path,1,*-1))
    set prefix = $Extract(prefix,1,*-$Length(name)-1)
    if $$$isWINDOWS {
      // Archive should have Unix-style slashes, so change to that on Windows
      set prefix = $Replace(prefix,"\","/")
    }
  } else {
    set Path = ##class(%File).NormalizeFilename(Path)
    set prefix = ##class(%File).GetDirectory(Path)
    set prefix = $PIECE(prefix, RelativeTo, 2, *)
    set flag = 0 // Ordinary File
    set size = ##class(%File).GetFileSize(Path)
    set name = ##class(%File).GetFilename(Path)
    if $$$isWINDOWS {
      // Archive should have Unix-style slashes, so change to that on Windows
      set prefix = $Replace(prefix,"\","/")
    }
  }

  set mtime = ##class(%File).GetFileDateModified(Path, 1)
  set mtime = $ZDATETIME(mtime, -2)

  set mode = ##class(%File).Attributes(Path)

  set header = ""
  if name'="" {
    set obj = ..%New()
    set obj.name = name
    set obj.prefix = prefix
    set obj.size = size
    set obj.mode = mode
    set obj.mtime = mtime
    set obj.typeflag = flag	
  
    set obj.uid = ""
    set obj.gid = ""
    set obj.uname = ""
    set obj.gname = ""
    
    set header = obj.ConstructHeader()
    set obj.chksum = $ZCRC(header, 0)
    set header = obj.ConstructHeader()
  }

  if (size > 0) {
    do archive.Write(header)
    set fs = ##class(%Stream.FileBinary).%New()
    set fs.Filename = Path
    do archive.CopyFrom(fs)
    if (size # blockSize) > 0 {
      set paddingSize = blockSize - (size # blockSize)
      set padding = $TRANSLATE($JUSTIFY("", paddingSize), " ", $CHAR(0))
      do archive.Write(padding)
    }
  } else {
    if (Path '= RelativeTo) {
      do archive.Write(header)
    }
    set rs = ##class(%File).FileSetFunc(Path, , "Type", 1)
    while rs.%Next() {
      do ..ConstructTar(rs.Name, RelativeTo, archive)
    }
  }
}

Method ConstructHeader() As %Binary [ CodeMode = objectgenerator, Internal ]
{
  set blockSize = ..#BLOCKSIZE
  set tProps=%class.Properties
  Set tPropKey = ""
  For {
    Set tProp = %class.Properties.GetNext(.tPropKey)
    Quit:(tPropKey = "")
    CONTINUE:"Header"'=tProp.Parameters.GetAt("CAPTION")
    set tProps(tProp.SequenceNumber)=tProp
  }	
  Do %code.WriteLine($char(9)_"Set tHeader = $TRANSLATE($JUSTIFY("""", "_blockSize_"), "" "", $CHAR(0))")
  Set tPropKey = "", tPos = 1
  For {
    Set tPropKey = $Order(tProps(tPropKey),1,tProp)
    Quit:tPropKey=""
    Set tLen = tProp.Parameters.GetAt("MAXLEN")
    Do %code.WriteLine($char(9)_"Set tVal = i%"_tProp.Name)
    If (tProp.Parameters.GetAt("TRUNCATE")) {
      Do %code.WriteLine($char(9)_"Set tVal = $extract(tVal, 1, "_(tLen-1)_")")
      Do %code.WriteLine($char(9)_"Set tPadding = $justify("""", "_(tLen)_" - $length(tVal))")
      Do %code.WriteLine($char(9)_"Set tPadding = $translate(tPadding, $char(32), $char(0))")
      Do %code.WriteLine($char(9)_"Set tVal = tVal _ tPadding")
    } else {
      Do %code.WriteLine($char(9)_"Set tVal = tVal _ $translate($justify("""", "_(tLen)_" - $length(tVal)), $char(32), $char(0))")
    }
    Do %code.WriteLine($char(9)_"Set tVal = $extract(tVal, 1, "_(tLen)_")")
    Do %code.WriteLine($char(9)_"Set $extract(tHeader, "_tPos_", "_(tPos+tLen-1)_") = tVal")
    Set tPos = tPos + tLen
  }
  Do %code.WriteLine($char(9)_"Return tHeader")
  Return $$$OK
}

}
