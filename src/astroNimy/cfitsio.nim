# -*- nimrod -*-
#
# cfitsio.nim
#
# Maurizio Tomasi
# Created on 5 Dic 2014
#
# Bindings to the CFITSIO library
# 
# Updated for Nim 1.0.0+ by Liam Scaife

import strutils

when defined(windows):
    const LibraryName = "cfitsio.dll"
elif defined(macosx):
    const LibraryName = "libcfitsio(|.0).dylib"
else:
    const LibraryName = "libcfitsio.so"

const
    flenFileName* = 1025 ## Maximum length (in characters) of the name of a file
    flenKeyword* = 72 ## Maximum length (in characters) of a keyword (including the comments)
    flenCard* = 81 ## Maximum length (in characters) of a keyword card
    flenValue* = 71 ## Maximum length (in characters) of a keyword value
    flenComment* = 73 ## Maximum length (in characters) of a keyword comment
    flenErrMsg* = 81 ## Maximum length (in characters) of an error message
    flenStatus* = 31 ## Maximum length (in characters) of a short error message ("status message")

    tBit* = 1 ## Bit datatype
    tByte* = 11 ## Byte (8-bit unsigned integer) datatype
    tLogical* = 14 ## Logical (Boolean) datatype
    tString* = 16 ## String datatype
    tShort* = 21 ## Short (16-bit signed integer) datatype
    tLong* = 41 ## Long (32-bit or 64-bit signed integer) datatype
    tLongLong* = 81 ## Long-long (64-bit signed integer) datatype
    tFloat* = 42 ## Float (32-bit floating-point number) datatype
    tDouble* = 82 ## Double (64-bit floating-point number) datatype
    tComplex* = 83 ## Complex (2 x 32-bit complex floating-point number) datatype
    tDblComplex* = 163 ## Double complex (2 x 64-bit complex floating-point number) datatype
    tInt* = 31 ## Integer datatype (its size matches the size of a pointer)
    tSbyte* = 12 ## Signed byte (8-bit signed integer) datatype
    tUint* = 30 ## Unsigned int (its size matches the size of a pointer)
    tUshort* = 20 ## Unsigned short (16-bit integer) datatype
    tUlong* = 40 ## Unsigned long (32-bit integer) datatype
    tInt32bit* = 41 ## Shortcut for tLong

type
    DataType* = enum
        dtBit,
        dtInt8, dtUint8, dtInt16, dtUint16, dtInt32, dtInt64,
        dtFloat32, dtFloat64,
        dtComplex32, dtComplex64,
        dtLogical,
        dtString

    InternalFitsStruct = pointer ## Used internally by these bindings

    EFitsException* = object of Exception
        ## Generic exception
        code : int ## CFITSIO status code
        errorStack : seq[string] ## List of error messages associated with the error

    IoMode* = enum  ## Possible ways to open a FITS file
        ReadOnly = 0, ReadWrite = 1

    HduType* = enum ## Recognized types of HDUs in a FITS file
        Any = -1, Image = 0, AsciiTable = 1, BinaryTable = 2

    FileNameStr* = array[0..flenFileName, char]
    KeywordStr* = array[0..flenKeyword, char]
    CardStr* = array[0..flenCard, char]
    ValueStr* = array[0..flenValue, char]
    CommentStr* = array[0..flenComment, char]
    ErrMsgStr* = array[0..flenErrMsg, char]

    FitsFile* {. final .} = object
        ## Connection to an opened FITS file
        file : InternalFitsStruct
        fileName : string
        opened : bool

    Complex32 = object
        re : float32
        im : float32

    Complex64 = object
        re : float64
        im : float64

#-------------------------------------------------------------------------------

proc fitsGetErrStatus(statusCode : cint,
                      errorText : ErrMsgStr) {. cdecl,
                                                dynlib : LibraryName,
                                                importc : "ffgerr" .}

proc fitsReadErrMsg(errorText : ErrMsgStr) : cint {. cdecl,
                                                     dynlib : LibraryName,
                                                     importc : "ffgmsg" .}

proc raiseFitsException(statusCode : int, spec : string) {. noinline, noreturn .} =
    var errorText : ErrMsgStr
    fitsGetErrStatus(cint(statusCode), errorText)

    var message : string = $errorText
    if spec != "":
        message = message & " (" & spec & ")"

    var exception : ref EFitsException
    new(exception)
    exception.code = statusCode
    exception.msg = message

    # Get the list of error messages from CFITSIO's error stack.
    # Unfortunately, there is no way to know in advance how many
    # messages are in the stack.
    newSeq(exception.errorStack, 0)
    while fitsReadErrMsg(errorText) != 0:
        add(exception.errorStack, $errorText)

    raise exception

proc raiseFitsException(statusCode : int) {. noinline, noreturn .} =
    raiseFitsException(statusCode, "")

#-------------------------------------------------------------------------------

proc raiseIfNotOpened(fileObj : var FitsFile) =
    if not fileObj.opened:
        # Exception 104 is FILE_NOT_OPENED: it is used when a
        # openFile/openTable/etc fails, but we stretch it a bit to
        # mean that a read/write operation has been attempted to a
        # file that has not been opened or that has already been
        # closed.
        raiseFitsException(104, "file not opened")

#-------------------------------------------------------------------------------

proc dataTypeChar(dataType : DataType) : char {. noSideEffect, inline .} =
    case dataType
    of dtBit: result = 'X'
    of dtInt8: result = 'S'
    of dtUint8: result = 'B'
    of dtInt16: result = 'I'
    of dtUint16: result = 'U'
    of dtInt32: result = 'J'
    of dtInt64: result = 'K'
    of dtFloat32: result = 'E'
    of dtFloat64: result = 'D'
    of dtComplex32: result = 'C'
    of dtComplex64: result = 'M'
    of dtLogical: result = 'L'
    of dtString: result = 'A'

proc codeToDataType(code : int) : DataType {. noSideEffect, inline .} =
    case code
    of tBit: result = dtBit
    of tByte: result = dtUint8
    of tLogical: result = dtLogical
    of tString: result = dtString
    of tShort: result = dtInt16
    of tLong: result = dtInt64
    of tLongLong: result = dtInt64
    of tFloat: result = dtFloat32
    of tDouble: result = dtFloat64
    of tComplex: result = dtComplex32
    of tDblComplex: result = dtComplex64
    of tInt: result = dtInt32
    of tSbyte: result = dtInt8
    of tUint: result = dtInt64
    of tUshort: result = dtUint16
    of tUlong: result = dtInt64
    else:
        raise newException(KeyError, "data type " & $code & " is not recognized by CFITSIO")

#-------------------------------------------------------------------------------

proc fitsOpenFile(filePtr : ptr InternalFitsStruct,
                  fileName : cstring,
                  ioMode : IoMode,
                  status : ptr cint): cint {. cdecl,
                                              dynlib : LibraryName,
                                              importc : "ffopen" .}

proc openFile*(fileName : string, ioMode : IoMode): FitsFile =
    ## Open an existing FITS file. The parameter `ioMode` specifies if
    ## the file will be opened only for reading (``ReadOnly``) or for
    ## reading and writing (``ReadWrite``). If the file does not
    ## exist, a EFitsException will be raised.

    var status : cint = 0
    result.file = nil
    result.fileName = fileName
    result.opened = false
    if fitsOpenFile(addr(result.file), fileName, ioMode, addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileName & "\"")

    result.opened = true

#-------------------------------------------------------------------------------

proc fitsOpenData(filePtr : ptr InternalFitsStruct,
                  fileName : cstring,
                  ioMode : IoMode,
                  status : ptr cint): cint {. cdecl,
                                              dynlib : LibraryName,
                                              importc : "ffdopn" .}

proc openData*(fileName : string, ioMode : IoMode): FitsFile =
    ## This function is similar to `openFile`, but it automatically
    ## moves the current HDU pointer to the first HDU containing data
    ## (either an image or a table).

    var status : cint = 0
    result.file = nil
    result.fileName = fileName
    result.opened = false
    if fitsOpenData(addr(result.file), fileName, ioMode, addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileName & "\"")

    result.opened = true

#-------------------------------------------------------------------------------

proc fitsOpenTable(filePtr : ptr InternalFitsStruct,
                   fileName : cstring,
                   ioMode : IoMode,
                   status : ptr cint): cint {. cdecl,
                                               dynlib : LibraryName,
                                               importc : "fftopn" .}

proc openTable*(fileName : string, ioMode : IoMode) : FitsFile =
    ## This function is similar to `openFile`, but it automatically
    ## moves the current HDU pointer to the first HDU containing an
    ## ASCII or binary table. If no HDUs containing tables are found,
    ## a ``EFitsException`` is raised.

    var status : cint = 0
    result.file = nil
    result.fileName = fileName
    result.opened = false
    if fitsOpenTable(addr(result.file), fileName, ioMode, addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileName & "\"")

    result.opened = true

#-------------------------------------------------------------------------------

proc fitsOpenImage(filePtr : ptr InternalFitsStruct,
                   fileName : cstring,
                   ioMode : IoMode,
                   status : ptr cint): cint {. cdecl,
                                               dynlib : LibraryName,
                                               importc : "ffiopn" .}

proc openImage*(fileName : string, ioMode : IoMode) : FitsFile =
    ## This function is similar to `openFile`, but it automatically
    ## moves the current HDU pointer to the first HDU containing a 2D
    ## image. If no HDUs containing images are found, a
    ## ``EFitsException`` is raised.

    var status : cint = 0
    result.file = nil
    result.fileName = fileName
    result.opened = false
    if fitsOpenImage(addr(result.file), fileName, ioMode, addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileName & "\"")

    result.opened = true

#-------------------------------------------------------------------------------

proc fitsCreateFile(filePtr : ptr InternalFitsStruct,
                    fileName : cstring,
                    status : ptr cint) : cint {. cdecl,
                                                 dynlib : LibraryName,
                                                 importc : "ffinit" .}

type
    OverwriteMode* = enum
        Overwrite, DoNotOverwrite

proc createFile*(fileName : string,
                 overwriteMode : OverwriteMode = Overwrite) : FitsFile =
    ## Create a new, empty FITS file with name `fileName`. If it is
    ## impossible to create the file, a ``EFitsException`` exception
    ## will be raised. Once the file is created, you should populate
    ## it using the function createTable.

    var status : cint = 0
    result.file = nil
    result.fileName = fileName
    result.opened = false

    var realName = fileName
    if overwriteMode == Overwrite and realName[0] != '!':
        realName = '!' & realName

    if fitsCreateFile(addr(result.file), realName, addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileName & "\"")

    result.opened = true

#-------------------------------------------------------------------------------

proc fitsCreateDiskFile(filePtr : ptr InternalFitsStruct,
                        fileName : cstring,
                        status : ptr cint) : cint {. cdecl,
                                                     dynlib : LibraryName,
                                                     importc : "ffdkinit" .}

proc createDiskFile*(fileName : string,
                     overwriteMode : OverwriteMode = Overwrite) : FitsFile =
    ## This function is similar to `createFile`, but it ensures that a
    ## real FITS file is indeed created on disk. (The `createFile`
    ## function parses `fileName` and, depending on its format, might
    ## choose to create a memory file -- see the CFITSIO documentation
    ## about the function ``ffinit`` for more details.)

    var status : cint = 0
    result.file = nil
    result.fileName = fileName
    result.opened = false

    var realName = fileName
    if overwriteMode == Overwrite and realName[0] != '!':
        realName = '!' & realName

    if fitsCreateDiskFile(addr(result.file), realName, addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileName & "\"")

    result.opened = true

#-------------------------------------------------------------------------------

proc fitsCloseFile(filePtr : InternalFitsStruct,
                   status : ptr cint) : cint {. cdecl,
                                                dynlib : LibraryName,
                                                importc : "ffclos" .}

proc closeFile*(fileObj : var FitsFile) =
    ## Close a FITS file. If contents have been written or updated, it
    ## is important to call this function: the latest modifications
    ## might not have been written to disk yet. Note that this
    ## function *might fail*, so it is possible that it throws a
    ## ``EFitsException`` exception.

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    if fitsCloseFile(fileObj.file, addr(status)) != 0:
        raiseFitsException(status, "(file: \"" & fileObj.fileName & "\"")

    fileObj.opened = false

#-------------------------------------------------------------------------------

proc fitsDeleteFile(filePtr : InternalFitsStruct,
                    status : ptr cint) : cint {. cdecl,
                                                 dynlib : LibraryName,
                                                 importc : "ffdelt" .}

proc deleteFile*(fileObj : var FitsFile) =
    ## Delete an opened FITS file from the disk.

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    if fitsDeleteFile(fileObj.file, addr(status)) != 0:
        raiseFitsException(status, "(file: \"" & fileObj.fileName & "\"")

    fileObj.opened = false

#-------------------------------------------------------------------------------

proc fitsFileName(filePtr : InternalFitsStruct,
                  fileName : array[0..flenFileName, char],
                  status : ptr cint) : cint {. cdecl,
                                               dynlib : LibraryName,
                                               importc : "ffflnm" .}

proc getFileName*(fileObj : var FitsFile) : string =
    ## Return the name of the file associated with the ``FitsFile`` object.

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    var cResult : array[0..flenFileName, char]
    if fitsFileName(fileObj.file, cResult, addr(status)) != 0:
        raiseFitsException(status, "(file: \"" & fileObj.fileName & "\"")
    result = $cResult

#-------------------------------------------------------------------------------

proc fitsFileMode(filePtr : InternalFitsStruct,
                  mode : ptr IoMode,
                  status : ptr cint) : cint {. cdecl,
                                               dynlib : LibraryName,
                                               importc : "ffflmd" .}

proc getFileMode*(fileObj : var FitsFile) : IoMode =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    var mode : IoMode
    if fitsFileMode(fileObj.file, addr(mode), addr(status)) != 0:
        raiseFitsException(status, "(file: \"" & fileObj.fileName & "\"")
    result = mode

#-------------------------------------------------------------------------------

proc fitsUrlType(filePtr : InternalFitsStruct,
                 urlType : array[0..flenFileName, char],
                 status : ptr cint) : cint {. cdecl,
                                              dynlib : LibraryName,
                                              importc : "ffurlt" .}

proc getUrlType*(fileObj : var FitsFile) : string =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    var cResult : array[0..flenFileName, char]
    if fitsUrlType(fileObj.file, cResult, addr(status)) != 0:
        raiseFitsException(status, "(file: \"" & fileObj.fileName & "\"")
    result = $cResult

#-------------------------------------------------------------------------------

proc fitsMovabsHdu(filePtr : InternalFitsStruct,
                   hduNum : cint,
                   hduType : ptr cint,
                   status : ptr cint) : cint {. cdecl,
                                                dynlib : LibraryName,
                                                importc : "ffmahd" .}

proc moveToAbsHdu*(fileObj : var FitsFile, num : int) : HduType =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    var cHduType : cint = 0
    if fitsMovabsHdu(fileObj.file, cint(num), addr(cHduType), addr(status)) != 0:
        raiseFitsException(status, "HDU number " & $num &
                                   " in file \"" & fileObj.fileName & "\"")
    result = HduType(cHduType)

#-------------------------------------------------------------------------------

proc fitsMovrelHdu(filePtr : InternalFitsStruct,
                   hduNum : cint,
                   hduType : ptr cint,
                   status : ptr cint) : cint {. cdecl,
                                                dynlib : LibraryName,
                                                importc : "ffmrhd" .}

proc moveToRelHdu*(fileObj : var FitsFile,
                   num : int) : HduType =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    var cHduType : cint = 0
    if fitsMovrelHdu(fileObj.file, cint(num), addr(cHduType), addr(status)) != 0:
        raiseFitsException(status, "relative HDU number " & $num &
                                   " in file \"" & fileObj.fileName & "\"")
    result = HduType(cHduType)

#-------------------------------------------------------------------------------

proc fitsMovnamHdu(filePtr : InternalFitsStruct,
                   hduType : cint,
                   extName : cstring,
                   extVer : cint,
                   status : ptr cint) : cint {. cdecl,
                                                dynlib : LibraryName,
                                                importc : "ffmnhd" .}

proc moveToNamedHdu*(fileObj : var FitsFile,
                     hduType : HduType,
                     name : string,
                     ver : int = 0) =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    if fitsMovnamHdu(fileObj.file, cint(hduType), name, cint(ver), addr(status)) != 0:
        raiseFitsException(status, "HDU " & name &
                                   " in file \"" & fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsGetNumHdus(filePtr : InternalFitsStruct,
                    num : ptr cint,
                    status : ptr cint) : cint {. cdecl,
                                                 dynlib : LibraryName,
                                                 importc : "ffthdu" .}

proc getNumberOfHdus*(fileObj : var FitsFile) : int =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    var cResult : cint = 0
    if fitsGetNumHdus(fileObj.file, addr(cResult), addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileObj.fileName & "\"")

    result = int(cResult)

#-------------------------------------------------------------------------------

proc fitsReadKey(filePtr : InternalFitsStruct,
                 datatype : cint,
                 keyname : cstring,
                 value : ptr char,
                 comment : cstring,
                 status : ptr cint) : cint {. cdecl,
                                              dynlib : LibraryName,
                                              importc : "ffgky" .}

template defineReadKeyProc(name : untyped, t : typeDesc, cfitsioType : int) =
    proc name*(fileObj : var FitsFile, keyName : string) : t =

        raiseIfNotOpened(fileObj)

        var status : cint = 0
        if fitsReadKey(fileObj.file, cfitsioType,
                       keyName, cast[ptr char](addr(result)), nil,
                       addr(status)) != 0:
            raiseFitsException(status, "key \"" & keyName & "\"" &
                                       " in file \"" & fileObj.fileName & "\"")

defineReadKeyProc(readIntKey, int, tInt)
defineReadKeyProc(readInt64Key, int64, tLongLong)
defineReadKeyProc(readFloatKey, float64, tDouble)

proc readLogicKey*(fileObj : var FitsFile, keyName : string) : bool =
    raiseIfNotOpened(fileObj)

    result = (readIntKey(fileObj, keyName) != 0)

proc readStringKey*(fileObj : var FitsFile, keyName : string) : string =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    var cResult : ValueStr

    if fitsReadKey(fileObj.file, tString,
                   keyName, cast[ptr char](addr(cResult)), nil,
                   addr(status)) != 0:
        raiseFitsException(status, "key \"" & keyName & "\"")

    result = $cResult

template defReadComplex(floatType : typeDesc,
                        complexType : typeDesc,
                        cfitsioType : cint,
                        name : untyped) =
    proc name*(fileObj : var FitsFile, keyName : string) : complexType =

        raiseIfNotOpened(fileObj)

        var status : cint = 0
        var cResult : array[0..1, floatType]

        if fitsReadKey(fileObj.file, cfitsioType,
                       keyName, cast[ptr char](addr(cResult)), nil,
                       addr(status)) != 0:
            raiseFitsException(status, "key \"" & keyName & "\"")

        result.re = cResult[0]
        result.im = cResult[1]

defReadComplex(float32, Complex32, tComplex, readComplex32Key)
defReadComplex(float64, Complex64, tDblComplex, readComplex64Key)

#-------------------------------------------------------------------------------

proc fitsWriteKey(filePtr : InternalFitsStruct,
                  dataType : cint,
                  keyName : cstring,
                  value : pointer,
                  comment : cstring,
                  status : ptr cint) : cint {. cdecl,
                                               dynlib : LibraryName,
                                               importc : "ffpky" .}

proc fitsUpdateKey(filePtr : InternalFitsStruct,
                   dataType : cint,
                   keyName : cstring,
                   value : pointer,
                   comment : cstring,
                   status : ptr cint) : cint {. cdecl,
                                                dynlib : LibraryName,
                                                importc : "ffuky" .}

template defWriteKey(name : untyped,
                     fitsFunc : untyped,
                     dataType : typeDesc,
                     dtDataType : cint) =

    proc name*(fileObj : var FitsFile,
               keyName : string,
               value : dataType,
               comment : string = "") =

        raiseIfNotOpened(fileObj)

        var status : cint = 0
        var cValue : dataType = value

        if fitsFunc(fileObj.file, dtDataType, keyName, addr(cValue),
                    comment, addr(status)) != 0:
            raiseFitsException(status, "unable to write key \"" & keyName & "\"" &
                                       " in file \"" & fileObj.fileName & "\"")

defWriteKey(writeIntKey, fitsWriteKey, int, tInt)
defWriteKey(writeInt64Key, fitsWriteKey, int64, tLongLong)
defWriteKey(writeFloatKey, fitsWriteKey, float64, tDouble)

defWriteKey(updateIntKey, fitsUpdateKey, int, tInt)
defWriteKey(updateInt64Key, fitsUpdateKey, int64, tLongLong)
defWriteKey(updateFloatKey, fitsUpdateKey, float64, tDouble)

template defWriteStrKey(name : untyped, fitsFunc : untyped) =

    proc name*(fileObj : var FitsFile,
               keyName : string,
               value : string,
               comment : string = "") =

        raiseIfNotOpened(fileObj)

        var status : cint = 0
        if fitsFunc(fileObj.file, tString, keyName, cstring(value),
                    comment, addr(status)) != 0:
            raiseFitsException(status, "unable to write key \"" & keyName & "\"" &
                                       " in file \"" & fileObj.fileName & "\"")

defWriteStrKey(writeStringKey, fitsWriteKey)
defWriteStrKey(updateStringKey, fitsUpdateKey)

#-------------------------------------------------------------------------------

proc fitsWriteKeyNull(fileObj : InternalFitsStruct,
                      keyName : cstring,
                      comment : cstring,
                      status : ptr cint) : cint {. cdecl,
                                                   dynlib : LibraryName,
                                                   importc : "ffpkyu" .}

proc fitsUpdateKeyNull(fileObj : InternalFitsStruct,
                       keyName : cstring,
                       comment : cstring,
                       status : ptr cint) : cint {. cdecl,
                                                    dynlib : LibraryName,
                                                    importc : "ffukyu" .}

template defWriteKeyNull(name : untyped, fitsFunc : untyped) =

    proc name*(fileObj : var FitsFile, keyName : string, comment : string) =

        raiseIfNotOpened(fileObj)

        var status : cint = 0
        if fitsFunc(fileObj.file, keyName, comment, addr(status)) != 0:
            raiseFitsException(status, "unable to write key \"" & keyName & "\"" &
                                   " in file \"" & fileObj.fileName & "\"")

defWriteKeyNull(writeNullKey, fitsWriteKeyNull)
defWriteKeyNull(updateNullKey, fitsUpdateKeyNull)

#-------------------------------------------------------------------------------

proc fitsWriteComment(fileObj : InternalFitsStruct,
                      comment : cstring,
                      status : ptr cint) : cint {. cdecl,
                                                   dynlib : LibraryName,
                                                   importc : "ffpcom" .}

proc writeComment*(fileObj : var FitsFile, comment : string) =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    if fitsWriteComment(fileObj.file, comment, addr(status)) != 0:
        raiseFitsException(status, "unable to write comment \"" & comment & "\"" &
                                   " in file \"" & fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsModifyComment(fileObj : InternalFitsStruct,
                       keyName : cstring,
                       comment : cstring,
                       status : ptr cint) : cint {. cdecl,
                                                    dynlib : LibraryName,
                                                    importc : "ffmcom" .}

proc modifyComment*(fileObj : var FitsFile, keyName : string, comment : string) =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    if fitsModifyComment(fileObj.file, keyName, comment, addr(status)) != 0:
        raiseFitsException(status, "unable to modify comment for key \"" & keyName &
                                   "\" in file \"" & fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsRenameKey(fileObj : InternalFitsStruct,
                   oldName : cstring,
                   newName : cstring,
                   status : ptr cint) : cint {. cdecl,
                                                dynlib : LibraryName,
                                                importc : "ffmnam" .}

proc renameKey*(fileObj : var FitsFile, oldName : string, newName : string) =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    if fitsRenameKey(fileObj.file, oldName, newName, addr(status)) != 0:
        raiseFitsException(status, "unable to rename key \"" & oldName & "\"" &
                                   " in file \"" & fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsWriteKeyUnit(fileObj : InternalFitsStruct,
                      keyName : cstring,
                      unit : cstring,
                      status : ptr cint) : cint {. cdecl,
                                                   dynlib : LibraryName,
                                                   importc : "ffpunt" .}

proc writeKeyUnit*(fileObj : var FitsFile, keyName : string, unit : string) =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    if fitsWriteKeyUnit(fileObj.file, keyName, unit, addr(status)) != 0:
        raiseFitsException(status, "unable to add a measure unit to key \"" &
                                   keyName & "\" in file \"" & fileObj.fileName &
                                   "\"")

#-------------------------------------------------------------------------------

proc fitsDeleteRecord(fileObj : InternalFitsStruct,
                      pos : int,
                      status : ptr cint) : cint {. cdecl,
                                                   dynlib : LibraryName,
                                                   importc : "ffdrec" .}

proc fitsDeleteKey(fileObj : InternalFitsStruct,
                   keyName : cstring,
                   status : ptr cint) : cint {. cdecl,
                                                dynlib : LibraryName,
                                                importc : "ffdkey" .}

proc deleteKey*(fileObj : var FitsFile, keyIndex : int) =
    ## Delete the key whose index is `keyIndex` (the first key has index 1)

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    if fitsDeleteRecord(fileObj.file, keyIndex, addr(status)) != 0:
        raiseFitsException(status, "unable to delete key at index " &
                                   $keyIndex & " in file \"" &
                                   fileObj.fileName & "\"")

proc deleteKey*(fileObj : var FitsFile, keyName : string) =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    if fitsDeleteKey(fileObj.file, keyName, addr(status)) != 0:
        raiseFitsException(status, "unable to delete key \"" &
                                   keyName & "\" in file \"" &
                                   fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsWriteHistory(fileObj : InternalFitsStruct,
                      history : cstring,
                      status : ptr cint) : cint {. cdecl,
                                                   dynlib : LibraryName,
                                                   importc : "ffphis" .}

proc writeHistory*(fileObj : var FitsFile, history : string) =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    if fitsWriteHistory(fileObj.file, history, addr(status)) != 0:
        raiseFitsException(status, "unable to write history \"" & history & "\"" &
                                   " in file \"" & fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsWriteDate(fileObj : InternalFitsStruct,
                   status : ptr cint) : cint {. cdecl,
                                                dynlib : LibraryName,
                                                importc : "ffpdat" .}

proc writeDate*(fileObj : var FitsFile) =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    if fitsWriteDate(fileObj.file, addr(status)) != 0:
        raiseFitsException(status, "unable to write the current date" &
                                   " in file \"" & fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsReadKeyUnit(filePtr : InternalFitsStruct,
                     keyName : cstring,
                     unit : CommentStr,
                     status : ptr cint) : cint {. cdecl,
                                                  dynlib : LibraryName,
                                                  importc : "ffgunt" .}

proc readKeyUnit*(fileObj : var FitsFile, keyName : string) : string =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    var unit : CommentStr
    if fitsReadKeyUnit(fileObj.file, keyName, unit, addr(status)) != 0:
        raiseFitsException(status, "key \"" & keyName & "\"" &
                                   " in file \"" & fileObj.fileName & "\"")

    result = $unit

#-------------------------------------------------------------------------------

proc fitsGetNumRows(filePtr : InternalFitsStruct,
                    num : ptr clonglong,
                    status : ptr cint) : cint {. cdecl,
                                                dynlib : LibraryName,
                                                importc : "ffgnrwll" .}

proc getNumberOfRows*(fileObj : var FitsFile) : int64 =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    var cResult : clonglong = 0
    if fitsGetNumRows(fileObj.file, addr(cResult), addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileObj.fileName & "\"")

    result = int64(cResult)

#-------------------------------------------------------------------------------

proc fitsGetColNum(filePtr : InternalFitsStruct,
                   caseSen : cint,
                   templ : cstring,
                   colNum : ptr cint,
                   status : ptr cint) : cint {. cdecl,
                                                dynlib : Libraryname,
                                                importc : "ffgcno" .}

type
    CaseHandling* = enum
        PreserveCase, IgnoreCase

proc getColumnNumber*(fileObj : var FitsFile,
                      name : string,
                      caseHandling : CaseHandling = IgnoreCase) : int =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    var caseSen : cint
    case caseHandling
    of PreserveCase : caseSen = 1
    of IgnoreCase : caseSen = 0

    var cResult : cint = 0
    if fitsGetColNum(fileObj.file, caseSen, name, addr(cResult), addr(status)) != 0:
        raiseFitsException(status, "column \"" & name & "\"" &
                                   " in file \"" & fileObj.fileName & "\"")

    result = cResult

#-------------------------------------------------------------------------------

proc fitsGetNumCols(filePtr : InternalFitsStruct,
                    num : ptr cint,
                    status : ptr cint) : cint {. cdecl,
                                                dynlib : LibraryName,
                                                importc : "ffgncl" .}

proc getNumberOfColumns*(fileObj : var FitsFile) : int =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    var cResult : cint = 0
    if fitsGetNumCols(fileObj.file, addr(cResult), addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileObj.fileName & "\"")

    result = cResult

#-------------------------------------------------------------------------------

proc fitsGetColType(filePtr : InternalFitsStruct,
                    colnum : cint,
                    typecode : ptr cint,
                    repeat : ptr clong,
                    width : ptr clong,
                    status : ptr cint) : cint {. cdecl,
                                                 dynlib : LibraryName,
                                                 importc : "ffgtclll" .}

type
    TableColumnInfo* = object
        dataType* : DataType
        repeatCount* : int64
        width* : int64

proc getColumnType*(fileObj : var FitsFile, colNum : int) : TableColumnInfo =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    var typecode : cint = 0
    var repeat : clong
    var width : clong

    if fitsGetColType(fileObj.file, cint(colNum),
                      addr(typecode), addr(repeat), addr(width),
                      addr(status)) != 0:
        raiseFitsException(status, "column " & $colNum &
                                   ", file \"" & fileObj.fileName & "\"")

    result.dataType = codeToDataType(typecode)
    result.repeatCount = int64(repeat)
    result.width = int64(width)

#-------------------------------------------------------------------------------

proc fitsGetRowSize(filePtr : InternalFitsStruct,
                    nrows : ptr clong,
                    status : ptr cint) : cint {. cdecl,
                                                 dynlib : LibraryName,
                                                 importc : "ffgrsz" .}

proc getOptimalNumberOfRowsForIO*(fileObj : var FitsFile) : int64 =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    var cResult : clong = 0
    if fitsGetRowSize(fileObj.file, addr(cResult), addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileObj.fileName & "\"")

    result = int64(cResult)

#-------------------------------------------------------------------------------

proc fitsReadCol(filePtr : InternalFitsStruct,
                 dataType : cint,
                 colNum : cint,
                 firstRow : int64,
                 firstElem : int64,
                 numOfElements : int64,
                 nullValue : ptr char,
                 destArray : ptr char,
                 anyNull : ptr cint,
                 status : ptr cint) : cint {. cdecl,
                                              dynlib : LibraryName,
                                              importc : "ffgcv" .}

proc fitsReadColNull(filePtr : InternalFitsStruct,
                     dataType : cint,
                     colNum : cint,
                     firstRow : int64,
                     firstElem : int64,
                     numOfElements : int64,
                     destArray : ptr char,
                     nullArray : ptr bool,
                     anyNull : ptr cint,
                     status : ptr cint) : cint {. cdecl,
                                                  dynlib : LibraryName,
                                                  importc : "ffgcf" .}

template defReadColumn(cfitsioType : int,
                       datatype : typeDesc,
                       name : untyped,
                       null : untyped) =

    # First implementation, with default value for NULL
    proc name*(fileObj : var FitsFile,
               colNum : int,
               firstRow : int,
               firstElem : int,
               numOfElements : int,
               dest : var openArray[datatype],
               destFirstIdx : int,
               nullValue : datatype) =

        raiseIfNotOpened(fileObj)

        var anyNull : cint
        var status : cint = 0
        var cNull = nullValue

        if fitsReadCol(fileObj.file,
                       cfitsioType,
                       cint(colNum),
                       int64(firstRow),
                       int64(firstElem),
                       int64(numOfElements),
                       cast[ptr char](addr(cNull)),
                       cast[ptr char](addr(dest[destFirstIdx])),
                       addr(anyNull),
                       addr(status)) != 0:
            raiseFitsException(status, "column number " & $colNum &
                                       " in file \"" & fileObj.fileName & "\"")

    # Second implementation, with an explicit "destNull" argument
    proc name*(fileObj : var FitsFile,
               colNum : int,
               firstRow : int,
               firstElem : int,
               numOfElements : int,
               dest : var openArray[datatype],
               destNull : var openArray[bool],
               destFirstIdx : int) =

        raiseIfNotOpened(fileObj)

        var anyNull : cint
        var status : cint = 0
        var cDestNull : seq[int8]
        newSeq(cDestNull, numOfElements)

        if fitsReadColNull(fileObj.file,
                           cfitsioType,
                           cint(colNum),
                           int64(firstRow),
                           int64(firstElem),
                           int64(numOfElements),
                           cast[ptr char](addr(dest[destFirstIdx])),
                           cast[ptr bool](addr(cDestNull[0])),
                           addr(anyNull),
                           addr(status)) != 0:
            raiseFitsException(status, "column number " & $colNum &
                                       " in file \"" & fileObj.fileName & "\"")

        # Convert the array of bytes initialized by CFITSIO into bool values
        for idx in 0 .. numOfElements-1:
            destNull[destFirstIdx + idx] = (cDestNull[idx] != 0)

    # Third implementation, similar to the first one but simpler
    proc name*(fileObj : var FitsFile,
               colNum : int,
               firstRow : int,
               firstElem : int,
               dest : var openArray[datatype],
               nullValue : datatype) =
        name(fileObj, colNum, firstRow, firstElem, len(dest),
             dest, low(dest), nullValue)

    # Fourth implementation, similar to the second one but simpler
    proc name*(fileObj : var FitsFile,
               colNum : int,
               firstRow : int,
               firstElem : int,
               dest : var openArray[datatype],
               destNull : var openArray[bool]) =
        name(fileObj, colNum, firstRow, firstElem, len(dest),
             dest, destNull, low(dest))

    # Two more implementations, the simplest ones

    proc name*(fileObj : var FitsFile,
               colNum : int,
               dest : var openArray[datatype],
               nullValue : datatype) =
        name(fileObj, colNum, 1, 1, dest, nullValue)

    proc name*(fileObj : var FitsFile,
               colNum : int,
               dest : var openArray[datatype],
               destNull : var openArray[bool]) =
        name(fileObj, colNum, 1, 1, dest, destNull)

defReadColumn(tSbyte, int8, readColumnOfInt8, 0'i8)
defReadColumn(tShort, int16, readColumnOfInt16, 0'i16)
defReadColumn(tInt, int32, readColumnOfInt32, 0'i32)
defReadColumn(tLongLong, int64, readColumnOfInt64, 0'i64)
defReadColumn(tFloat, float32, readColumnOfFloat32, 0.0'f32)
defReadColumn(tDouble, float64, readColumnOfFloat64, 0.0'f64)

#-------------------------------------------------------------------------------

proc fitsReadColStr(filePtr : InternalFitsStruct,
                    colnum : cint,
                    firstrow : int64,
                    firstelem : int64,
                    nelements : int64,
                    nulstr : cstring,
                    dest : ptr cstring,
                    anynull : ptr cint,
                    status : ptr cint) : cint {. cdecl,
                                                 dynlib : LibraryName,
                                                 importc : "ffgcvs" .}

proc readColumnOfString*(fileObj : var FitsFile,
                         colNum : int,
                         firstRow : int,
                         firstElem : int,
                         numOfElements : int,
                         dest : var openArray[string],
                         destFirstIdx : int,
                         nullValue : string = "") =

        raiseIfNotOpened(fileObj)

        var anyNull : cint
        var status : cint = 0

        let columnInfo = getColumnType(fileObj, colNum)

        var cDest : seq[ptr char]
        newSeq(cDest, numOfElements)
        for idx in 0 .. numOfElements - 1:
            cDest[idx] = createU(char, columnInfo.width)

        try:
            if fitsReadColStr(fileObj.file,
                              cint(colNum),
                              int64(firstRow),
                              int64(firstElem),
                              int64(numOfElements),
                              nullValue,
                              cast[ptr cstring](addr(cDest[0])),
                              addr(anyNull),
                              addr(status)) != 0:
                raiseFitsException(status, "column number " & $colNum &
                                           " in file \"" & fileObj.fileName & "\"")

            for idx in 0 .. (numOfElements - 1):
                dest[destFirstIdx + idx] = $(cDest[idx])

        finally:
            for idx in 0 .. (numOfElements - 1):
                dealloc(cDest[idx])

proc readColumnOfString*(fileObj : var FitsFile,
                         colNum : int,
                         firstRow : int,
                         firstElem : int,
                         dest : var openArray[string],
                         nullValue : string = "") =
    readColumnOfString(fileObj, colNum, firstRow, firstElem,
                       len(dest), dest, low(dest), nullValue)

proc readColumnOfString*(fileObj : var FitsFile,
                         colNum : int,
                         dest : var openArray[string],
                         nullValue : string = "") =
    readColumnOfString(fileObj, colNum, 1, 1, dest, nullValue)

#-------------------------------------------------------------------------------

proc fitsCreateTable(filePtr : InternalFitsStruct,
                     tableType : cint,
                     naxis2 : int64,
                     tFields : cint,
                     ttype : cstringArray,
                     tform : cstringArray,
                     tunit : cstringArray,
                     extname : cstring,
                     status : ptr cint) : cint {. cdecl,
                                                  dynlib : LibraryName,
                                                  importc : "ffcrtb" .}

type
    TableType* = range[AsciiTable..BinaryTable]

    TableColumn* = object
        name* : string
        repeatCount* : int
        unit* : string
        case dataType* : DataType
        of dtString: width* : int
        else: nil

proc tableTypeToInt(tableType : TableType) : cint {. noSideEffect, inline .} =
    case tableType
    of AsciiTable: result = 1
    of BinaryTable: result = 2

proc createTable*(fileObj : var FitsFile,
                  tableType : TableType,
                  numOfElements : int64,
                  fields : openArray[TableColumn],
                  extname : string) =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    var ttypeSeq : seq[string]
    var tformSeq : seq[string]
    var tunitSeq : seq[string]

    newSeq(ttypeSeq, len(fields))
    newSeq(tformSeq, len(fields))
    newSeq(tunitSeq, len(fields))

    for idx in countup(low(fields), high(fields)):
        let zeroIdx = idx - low(fields)
        ttypeSeq[zeroIdx] = fields[idx].name
        if fields[idx].dataType == dtString:
            tformSeq[zeroIdx] =
                $(fields[idx].width * fields[idx].repeatCount) &
                dataTypeChar(fields[idx].dataType) &
                $(fields[idx].width)
        else:
            tformSeq[zeroIdx] =
                dataTypeChar(fields[idx].dataType) & $(fields[idx].repeatCount)
        tunitSeq[zeroIdx] = fields[idx].unit

    var ttype = allocCStringArray(ttypeSeq)
    var tform = allocCStringArray(tformSeq)
    var tunit = allocCStringArray(tunitSeq)

    try:
        if fitsCreateTable(fileObj.file, tableTypeToInt(tableType),
                           numOfElements, cint(len(fields)),
                           ttype, tform, tunit,
                           extname, addr(status)) != 0:
            raiseFitsException(status, "unable to create table \"" &
                                       extname & "\" in file \"" &
                                       fileObj.fileName & "\"")
    finally:
        deallocCStringArray(ttype)
        deallocCStringArray(tform)
        deallocCStringArray(tunit)

#-------------------------------------------------------------------------------

proc fitsWriteColNull(filePtr : InternalFitsStruct,
                      dataType : cint,
                      colNum : cint,
                      firstRow : int64,
                      firstElem : int64,
                      numOfElements : int64,
                      sourceArray : pointer,
                      nullPtr : pointer,
                      status : ptr cint) : cint {. cdecl,
                                                   dynlib : LibraryName,
                                                   importc : "ffpcn" .}

template defWriteCol(name : untyped, cfitsioType : int, dataType : typeDesc) =

    proc name*(fileObj : var FitsFile,
               colNum : int,
               firstRow : int,
               firstElem : int,
               numOfElements : int,
               values : var openArray[dataType], # We need "var" for using "addr"
               valueFirstIdx : int,
               nullPtr : ptr dataType = nil) =

        raiseIfNotOpened(fileObj)

        var status : cint = 0

        if fitsWriteColNull(fileObj.file, cfitsioType, cint(colNum),
                            int64(firstRow), int64(firstElem),
                            int64(numOfElements), addr(values[valueFirstIdx]),
                            nullPtr, addr(status)) != 0:
            raiseFitsException(status, "unable to write " & $numOfElements &
                                       "rows in column " & $colNum &
                                       "in file \"" &
                                       fileObj.fileName & "\"")

    proc name*(fileObj : var FitsFile,
               colNum : int,
               firstRow : int,
               firstElem : int,
               values : var openArray[dataType], # We need "var" for using "addr"
               nullPtr : ptr dataType = nil) =
        name(fileObj, colNum, firstRow, firstElem, len(values),
             values, low(values), nullPtr)

    proc name*(fileObj : var FitsFile,
               colNum : int,
               values : var openArray[dataType], # We need "var" for using "addr"
               nullPtr : ptr dataType = nil) =
        name(fileObj, colNum, 1, 1, values, nullPtr)

defWriteCol(writeColumnOfInt8, tSbyte, int8)
defWriteCol(writeColumnOfInt16, tShort, int16)
defWriteCol(writeColumnOfInt32, tInt, int32)
defWriteCol(writeColumnOfInt64, tLongLong, int64)
defWriteCol(writeColumnOfFloat32, tFloat, float32)
defWriteCol(writeColumnOfFloat64, tDouble, float64)

#-------------------------------------------------------------------------------

proc fitsWriteColStr(filePtr : InternalFitsStruct,
                     colNum : cint,
                     firstRow : int64,
                     firstElem : int64,
                     numOfElements : int64,
                     sourceArray : pointer,
                     status : ptr cint) : cint {. cdecl,
                                                  dynlib : LibraryName,
                                                  importc : "ffpcls" .}

proc writeColumnOfString*(fileObj : var FitsFile,
                          colNum : int,
                          firstRow : int,
                          firstElem : int,
                          numOfElements : int,
                          values : var openArray[string],
                          valueFirstIdx : int,
                          nullPtr : ptr string = nil) =

    raiseIfNotOpened(fileObj)

    var status : cint = 0

    # It is slightly inefficient to convert each string in
    # "values" into a cstring, as we're going to use only those
    # that go from index "valueFirstIdx" up to "valueFirstIdx +
    # numOfElements - 1". But the code is much simpler, and cases
    # where this matters are probably very rare.

    var cValues = allocCStringArray(values)
    try:
        if fitsWriteColStr(fileObj.file,
                           cint(colNum),
                           int64(firstRow),
                           int64(firstElem),
                           int64(numOfElements),
                           cast[ptr cstring](addr(cValues[valueFirstIdx])),
                           addr(status)) != 0:
            raiseFitsException(status, "column number " & $colNum &
                                       " in file \"" & fileObj.fileName & "\"")

    finally:
        deallocCStringArray(cValues)

proc writeColumnOfString*(fileObj : var FitsFile,
                          colNum : int,
                          firstRow : int,
                          firstElem : int,
                          values : var openArray[string],
                          nullPtr : ptr string = nil) =
    writeColumnOfString(fileObj, colNum, firstRow, firstElem, len(values),
                        values, low(values), nullPtr)

proc writeColumnOfString*(fileObj : var FitsFile,
                          colNum : int,
                          values : var openArray[string],
                          nullPtr : ptr string = nil) =
    writeColumnOfString(fileObj, colNum, 1, 1, values, nullPtr)

#-------------------------------------------------------------------------------

proc fitsGetImgType(file : InternalFitsStruct,
                    bitpix : ptr cint,
                    status : ptr cint) : cint {. cdecl,
                                                 dynlib : LibraryName,
                                                 importc : "ffgidt" .}

proc getImageType*(fileObj : var FitsFile) : int =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    var cResult : cint = 0
    if fitsGetImgType(fileObj.file, addr(cResult), addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileObj.fileName & "\"")

    result = int(cResult)

#-------------------------------------------------------------------------------

proc fitsGetImgDim(file : InternalFitsStruct,
                   naxis : ptr cint,
                   status : ptr cint) : cint {. cdecl,
                                                dynlib : LibraryName,
                                                importc : "ffgidm" .}

proc getImageDimensions*(fileObj : var FitsFile) : int =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    var cResult : cint = 0
    if fitsGetImgDim(fileObj.file, addr(cResult), addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileObj.fileName & "\"")

    result = int(cResult)

#-------------------------------------------------------------------------------

proc fitsGetImgSizell(file : InternalFitsStruct,
                      maxdim : cint,
                      naxes : ptr int64,
                      status : ptr cint) : cint {. cdecl,
                                                   dynlib : LibraryName,
                                                   importc : "ffgiszll" .}

proc getImageSize*(fileObj : var FitsFile) : seq[int64] =

    raiseIfNotOpened(fileObj)

    var status : cint = 0
    newSeq(result, getImageDimensions(fileObj))
    if fitsGetImgSizell(fileObj.file, cint(len(result)),
                        addr(result[0]), addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileObj.fileName & "\"")

#-------------------------------------------------------------------------------

proc fitsCreateImg(file : InternalFitsStruct,
                   bitpix : cint,
                   naxis : cint,
                   naxes : ptr int64,
                   status : ptr cint) : cint {. cdecl,
                                                dynlib : LibraryName,
                                                importc: "ffcrimll" .}

proc createImage*(fileObj : var FitsFile,
                  bitsPerPixel : int,
                  axesDim : openArray[int64]) =

    raiseIfNotOpened(fileObj)

    var dimensions = newSeq[int64](len(axesDim));
    for i in countup(0, len(axesDim) - 1):
        dimensions[i] = axesDim[i]

    var status : cint = 0
    if fitsCreateImg(fileObj.file, cint(bitsPerPixel),
                     cint(len(axesDim)), addr(dimensions[0]),
                     addr(status)) != 0:
        raiseFitsException(status, "file \"" & fileObj.fileName & "\"")

proc createImage*(fileObj : var FitsFile,
                  dataType : DataType,
                  axesDim : openArray[int64]) =

    var bitsPerPixel = case dataType
        of dtInt8: 8
        of dtInt16: 16
        of dtInt32: 32
        of dtInt64: 64
        of dtFloat32: -32
        of dtFloat64: -64
        else:
            # 211: BAD_BITPIX
            raiseFitsException(211, "wrong type " & $dataType)

    createImage(fileObj, bitsPerPixel, axesDim)

#-------------------------------------------------------------------------------

proc fitsWritePixll(file : InternalFitsStruct,
                    datatype : cint,
                    fpixel : ptr int64,
                    nelements : int64,
                    arr : pointer,
                    status : ptr cint) : cint {. cdecl,
                                                 dynlib : LibraryName,
                                                 importc: "ffppxll" .}

template defWritePixel(name : untyped, cfitsioType : int, dataType : typeDesc) =

    proc name*(fileObj : var FitsFile, 
               coord : openArray[int64],
               values : var openArray[dataType],
               firstElem : int,
               numOfElements : int) =

        raiseIfNotOpened(fileObj)

        var coordArray = newSeq[int64](len(coord))
        for i in countup(0, len(coord) - 1):
            coordArray[i] = coord[i]

        var status : cint = 0
        if fitsWritePixll(fileObj.file, cfitsioType, addr(coordArray[0]),
                          int64(numOfElements), addr(values[firstElem]),
                          addr(status)) != 0:
            raiseFitsException(status, "file \"" & fileObj.fileName & "\"")

    proc name*(fileObj : var FitsFile, 
               coord : openArray[int64],
               values : var openArray[dataType]) =
        name(fileObj, coord, values, 0, len(values))

defWritePixel(writePixelOfInt8, tSbyte, int8)
defWritePixel(writePixelOfInt16, tShort, int16)
defWritePixel(writePixelOfInt32, tInt, int32)
defWritePixel(writePixelOfInt64, tLongLong, int64)
defWritePixel(writePixelOfFloat32, tFloat, float32)
defWritePixel(writePixelOfFloat64, tDouble, float64)

#-------------------------------------------------------------------------------

proc fitsReadPixll(file : InternalFitsStruct,
                   datatype : cint,
                   fpixel : ptr int64,
                   nelements : int64,
                   nullValue : pointer,
                   arr : pointer,
                   anynul : ptr cint,
                   status : ptr cint) : cint {. cdecl,
                                                dynlib : LibraryName,
                                                importc: "ffgpxvll" .}

template defReadPixel(name : untyped, 
                      cfitsioType : int, 
                      dataType : typeDesc,
                      defaultNull : untyped) =

    proc name*(fileObj : var FitsFile, 
               coord : openArray[int64],
               values : var openArray[dataType],
               firstElem : int,
               numOfElements : int,
               nullValue : dataType) =

        raiseIfNotOpened(fileObj)

        var coordArray = newSeq[int64](len(coord))
        for i in countup(0, len(coord) - 1):
            coordArray[i] = coord[i]

        var status : cint = 0
        var concreteNull = nullValue
        var anyNull : cint = 0
        if fitsReadPixll(fileObj.file, cfitsioType, addr(coordArray[0]),
                          int64(numOfElements), addr(concreteNull),
                          addr(values[firstElem]), addr(anyNull),
                          addr(status)) != 0:
            raiseFitsException(status, "file \"" & fileObj.fileName & "\"")

    proc name*(fileObj : var FitsFile, 
               coord : openArray[int64],
               values : var openArray[dataType],
               firstElem : int,
               numOfElements : int) =
        name(fileObj, coord, values, firstElem, numOfElements, defaultNull)

    proc name*(fileObj : var FitsFile, 
               coord : openArray[int64],
               values : var openArray[dataType]) =
        name(fileObj, coord, values, 0, len(values))

defReadPixel(readPixelOfInt8, tSbyte, int8, 0'i8)
defReadPixel(readPixelOfInt16, tShort, int16, 0'i16)
defReadPixel(readPixelOfInt32, tInt, int32, 0'i32)
defReadPixel(readPixelOfInt64, tLongLong, int64, 0'i64)
defReadPixel(readPixelOfFloat32, tFloat, float32, 0'f32)
defReadPixel(readPixelOfFloat64, tDouble, float64, 0'f64)