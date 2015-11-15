unit QRDecoder;

interface

uses SysUtils, Generics.Collections, DecodeHintType, BitMatrixx,
  BitmatrixParser, DecoderResult, ReedSolomonDecoder, GenericGF,
  QRCodeDecoderMetaData, version, FormatInformation, ErrorCorrectionLevel,
  Datablock, DecodedBitStreamParser;

type

  TQRDecoder = class

  private
    rsDecoder: TReedSolomonDecoder;

    function correctErrors(codewordBytes: TArray<Byte>;
      numDataCodewords: Integer): boolean;
    function decode(parser: TBitMatrixParser;
      hints: TDictionary<TDecodeHintType, TObject>): TDecoderResult; overload;

  public
    constructor Create;
    function decode(bits: TBitMatrix;
      hints: TDictionary<TDecodeHintType, TObject>): TDecoderResult; overload;
  end;

implementation

{ TDecoder }
constructor TQRDecoder.Create;
begin
  rsDecoder := TReedSolomonDecoder.Create(TGenericGF.QR_CODE_FIELD_256);
end;

function TQRDecoder.correctErrors(codewordBytes: TArray<Byte>;
  numDataCodewords: Integer): boolean;
var
  i, numCodewords, numECCodewords: Integer;
  codewordsInts: TArray<Integer>;

begin

  numCodewords := Length(codewordBytes);
  SetLength(codewordsInts, numCodewords);

  i := 0;
  while ((i < numCodewords)) do
  begin
    codewordsInts[i] := (codewordBytes[i] and $FF);
    inc(i)
  end;

  numECCodewords := (Length(codewordBytes) - numDataCodewords);
  if (not self.rsDecoder.decode(codewordsInts, numECCodewords)) then
  begin
    Result := false;
    exit
  end;

  i := 0;
  while ((i < numDataCodewords)) do
  begin
    codewordBytes[i] := PByte(@codewordsInts[i])^;
    inc(i)
  end;

  Result := true;

end;

function TQRDecoder.decode(bits: TBitMatrix;
  hints: TDictionary<TDecodeHintType, TObject>): TDecoderResult;
var
  parser: TBitMatrixParser;

begin

  parser := TBitMatrixParser.createBitMatrixParser(bits);
  if (parser = nil) then
  begin
    Result := nil;
    exit
  end;

  Result := self.decode(parser, hints);
  if (Result = nil) then
  begin

    parser.remask;
    parser.setMirror(true);
    if (parser.readVersion = nil) then
    begin
      Result := nil;
      exit
    end;

    if (parser.readFormatInformation = nil) then
    begin
      Result := nil;
      exit
    end;

    parser.mirror;
    Result := self.decode(parser, hints);
    if (Result <> nil) then
      Result.Other := TQRCodeDecoderMetaData.Create(true)
  end;

  Result := Result;

end;

function TQRDecoder.decode(parser: TBitMatrixParser;
  hints: TDictionary<TDecodeHintType, TObject>): TDecoderResult;
var
  Datablock: TDataBlock;
  dataBlocks: TArray<TDataBlock>;
  version: TVersion;
  formatInfo: TFormatInformation;
  ecLevel: TErrorCorrectionLevel;
  codeWords, resultBytes, codewordBytes: TArray<Byte>;
  totalBytes, resultOffset, i, numDataCodewords: Integer;

begin

  version := parser.readVersion;
  if (version = nil) then
  begin
    Result := nil;
    exit
  end;

  formatInfo := parser.readFormatInformation;
  if (formatInfo = nil) then
  begin
    Result := nil;
    exit
  end;

  ecLevel := formatInfo.ErrorCorrectionLevel;
  codeWords := parser.readCodewords;
  if (codeWords = nil) then
  begin
    Result := nil;
    exit
  end;

  dataBlocks := Datablock.getDataBlocks(codeWords, version, ecLevel);
  totalBytes := 0;

  for Datablock in dataBlocks do
  begin
    inc(totalBytes, Length(Datablock.codeWords))
  end;

  resultBytes := TArray<Byte>.Create();
  SetLength(resultBytes, totalBytes);
  resultOffset := 0;

  for Datablock in dataBlocks do
  begin
    codewordBytes := Datablock.codeWords;
    numDataCodewords := Length(Datablock.codeWords);
    if (not self.correctErrors(codewordBytes, numDataCodewords)) then
    begin
      Result := nil;
      exit
    end;

    i := 0;
    while ((i < numDataCodewords)) do
    begin
      inc(resultOffset);
      resultBytes[resultOffset] := codewordBytes[i];
      inc(i)
    end
  end;

  Result := TDecodedBitStreamParser.decode(resultBytes, version,
    ecLevel, hints);
end;

end.